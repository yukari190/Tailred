#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

#define ANIM_HUNTER_LENGTH 2.2
#define ANIM_CHARGER_STANDARD_LENGTH 2.9
#define ANIM_CHARGER_SLAMMED_WALL_LENGTH 3.9
#define ANIM_CHARGER_SLAMMED_GROUND_LENGTH 4.0
#define ANIM_EVENT_CHARGER_GETUP 78

#define INDEX_HUNTER 0
#define INDEX_CHARGER 1
#define INDEX_CHARGER_WALL 2
#define INDEX_CHARGER_GROUND 3

enum PlayerState
{
    UPRIGHT = 0,
    INCAPPED,
    SMOKED,
    JOCKEYED,
    HUNTER_GETUP,
    INSTACHARGED, // 5
    CHARGED,
    CHARGER_GETUP,
    MULTI_CHARGED,
    TANK_ROCK_GETUP,
    TANK_PUNCH_FLY, // 10
    TANK_PUNCH_GETUP,
    TANK_PUNCH_FIX,
    TANK_PUNCH_JOCKEY_FIX,
}

int getUpAnimations[8][5] =
{
    {621, 656, 660, 661, 629}, {620, 667, 671, 672, 629}, {629, 674, 678, 679, 637}, {625, 671, 675, 676, 634},
    {528, 759, 763, 764, 537}, {537, 819, 823, 824, 546}, {528, 759, 763, 764, 537}, {531, 762, 766, 767, 540}
};

int incapAnimations[8][2] =
{
    {613, 614}, {612, 613}, {621, 622}, {617, 618},
    {520, 521}, {525, 526}, {520, 521}, {523, 524}
};

PlayerState playerState[8] = view_as<PlayerState>(UPRIGHT);
bool isSurvivorStaggerBlocked[8];
bool interrupt[8];
bool bArClientAlreadyChecked[MAXPLAYERS + 1];
int pendingGetups[8] = 0;
int currentSequence[8] = 0;
int tankFlyAnim[8] = {628, 628, 636, 633, 536, 545, 536, 539};

public Plugin myinfo =
{
    name = "L4D2 Get-Up Fix",
    author = "Darkid, Blade, ProdigySim, DieTeetasse, Stabby, Jahze, Standalone (aka Manu), Visor",
    description = "Double/no/self-clear get-up fix.",
    version = "3.7",
    url = ""
}

public void OnPluginStart()
{
    InitSurvivorModelTrie(); // 不必要, 但是可以加快IdentifySurvivor()的调用.
    
    HookEvent("tongue_grab", smoker_land);
    HookEvent("jockey_ride", jockey_land);
    HookEvent("jockey_ride_end", jockey_clear);
    HookEvent("tongue_release", smoker_clear);
    HookEvent("pounce_stopped", hunter_clear);
    HookEvent("pounce_end", PounceOrPummel);
    HookEvent("charger_impact", multi_charge);
    HookEvent("charger_carry_end", charger_land_instant);
    HookEvent("charger_pummel_start", charger_land);
    HookEvent("charger_pummel_end", charger_clear);
    HookEvent("charger_killed", ChargerKilled);
    HookEvent("player_incapacitated", player_incap);
    HookEvent("revive_success", player_revive);
    HookEvent("player_bot_replace", OnBotSwap);
    HookEvent("bot_player_replace", OnBotSwap);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
    if (!IsValidInGame(client)) return;
    if (nowteam == 2 && oldteam != 2) SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
    else if (nowteam != 2 && oldteam == 2) SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 0; i < 8; i++)
	{
		playerState[i] = view_as<PlayerState>(UPRIGHT);
		isSurvivorStaggerBlocked[i] = false;
	}
}

public Action smoker_land(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(HUNTER_GETUP)) interrupt[survivor] = true;
}

public Action jockey_land(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    playerState[survivor] = view_as<PlayerState>(JOCKEYED);
}

public Action jockey_clear(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(JOCKEYED)) playerState[survivor] = view_as<PlayerState>(UPRIGHT);
}

public Action smoker_clear(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) return;
    playerState[survivor] = view_as<PlayerState>(UPRIGHT);
    CreateTimer(0.04, CancelGetup, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action hunter_clear(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    CreateTimer(0.2, HookOnThink, client);
    isSurvivorStaggerBlocked[survivor] = true;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) return;
    if (isGettingUp(survivor))
	{
        pendingGetups[survivor]++;
        return;
    }
    playerState[survivor] = view_as<PlayerState>(HUNTER_GETUP);
    CreateTimer(0.04, GetupTimer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action multi_charge(Event event, const char[] name, bool dontBroadcast)
{
    SurvivorCharacter survivor = IdentifySurvivor(GetClientOfUserId(event.GetInt("victim")));
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) return;
    playerState[survivor] = view_as<PlayerState>(MULTI_CHARGED);
}

public Action charger_land_instant(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    CreateTimer(0.2, HookOnThink, client);
    isSurvivorStaggerBlocked[survivor] = true;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) pendingGetups[survivor]++;
    playerState[survivor] = view_as<PlayerState>(INSTACHARGED);
}

public Action charger_land(Event event, const char[] name, bool dontBroadcast)
{
    SurvivorCharacter survivor = IdentifySurvivor(GetClientOfUserId(event.GetInt("victim")));
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) return;
    playerState[survivor] = view_as<PlayerState>(CHARGED);
}

public Action charger_clear(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("victim"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    CreateTimer(0.1, Timer_ProcessClient, client);
    CreateTimer(0.2, HookOnThink, client);
    isSurvivorStaggerBlocked[survivor] = true;
    if (playerState[survivor] == view_as<PlayerState>(INCAPPED)) return;
    playerState[survivor] = view_as<PlayerState>(CHARGER_GETUP);
    CreateTimer(0.04, GetupTimer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action PounceOrPummel(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.1, Timer_ProcessClient, event.GetInt("victim"));
}

public Action ChargerKilled(Event event, const char[] name, bool dontBroadcast)
{
    CreateTimer(0.5, GetupTimer2, event.GetInt("attacker"));
}

public Action player_incap(Event event, const char[] name, bool dontBroadcast)
{
    SurvivorCharacter survivor = IdentifySurvivor(GetClientOfUserId(event.GetInt("userid")));
    if (survivor == SC_NONE) return;
    if (playerState[survivor] == view_as<PlayerState>(INSTACHARGED)) pendingGetups[survivor]++;
    playerState[survivor] = view_as<PlayerState>(INCAPPED);
}

public Action player_revive(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("subject"));
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    playerState[survivor] = view_as<PlayerState>(UPRIGHT);
    CreateTimer(0.04, CancelGetup, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action OnBotSwap(Event event, const char[] name, bool dontBroadcast)
{
    int bot = GetClientOfUserId(event.GetInt("bot"));
	int player = GetClientOfUserId(event.GetInt("player"));
	if (StrEqual(name, "player_bot_replace"))
	{
		SurvivorCharacter survivor = IdentifySurvivor(bot);
		if (survivor == SC_NONE) return;
		if (isSurvivorStaggerBlocked[survivor]) SDKHook(bot, SDKHook_PostThink, OnThink);
	}
	else
	{
		SurvivorCharacter survivor = IdentifySurvivor(player);
		if (survivor == SC_NONE) return;
		if (isSurvivorStaggerBlocked[survivor]) SDKHook(player, SDKHook_PostThink, OnThink);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    SurvivorCharacter survivor = IdentifySurvivor(victim);
    if (survivor == SC_NONE) return;
    char weapon[32];
    GetEdictClassname(inflictor, weapon, sizeof(weapon));
    if (strcmp(weapon, "weapon_tank_claw") == 0)
	{
        if (playerState[survivor] == view_as<PlayerState>(CHARGER_GETUP)) interrupt[survivor] = true;
        else if (playerState[survivor] == view_as<PlayerState>(MULTI_CHARGED)) pendingGetups[survivor]++;

        if (playerState[survivor] == view_as<PlayerState>(TANK_ROCK_GETUP)) playerState[survivor] = view_as<PlayerState>(TANK_PUNCH_FIX);
        else if (playerState[survivor] == view_as<PlayerState>(JOCKEYED))
		{
            playerState[survivor] = view_as<PlayerState>(TANK_PUNCH_JOCKEY_FIX);
            CreateTimer(0.04, TankLandTimer, victim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        } else
		{
            playerState[survivor] = view_as<PlayerState>(TANK_PUNCH_FLY);
            CreateTimer(0.04, TankLandTimer, victim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        }
    }
	else if (strcmp(weapon, "tank_rock") == 0)
	{
        if (playerState[survivor] == view_as<PlayerState>(CHARGER_GETUP)) interrupt[survivor] = true;
        else if (playerState[survivor] == view_as<PlayerState>(MULTI_CHARGED)) pendingGetups[survivor]++;
        playerState[survivor] = view_as<PlayerState>(TANK_ROCK_GETUP);
        CreateTimer(0.04, GetupTimer, victim, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    }
    return;
}

public Action TankLandTimer(Handle timer, any client)
{
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return Plugin_Stop;
    if (GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim[survivor] || 
		GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim[survivor] + 1) return Plugin_Continue;
    if (playerState[survivor] == view_as<PlayerState>(TANK_PUNCH_JOCKEY_FIX))
	{
        if (GetEntProp(client, Prop_Send, "m_nSequence") == tankFlyAnim[survivor]+2) return Plugin_Continue;
        L4D2Direct_DoAnimationEvent(client, 96); // 96 is the tank punch getup.
    }
    if (playerState[survivor] == view_as<PlayerState>(TANK_PUNCH_FLY)) playerState[survivor] = view_as<PlayerState>(TANK_PUNCH_GETUP);
    CreateTimer(0.04, GetupTimer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
    return Plugin_Stop;
}

public Action GetupTimer(Handle timer, any client)
{
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return Plugin_Stop;
    if (currentSequence[survivor] == 0)
	{
        currentSequence[survivor] = GetEntProp(client, Prop_Send, "m_nSequence");
        pendingGetups[survivor]++;
        return Plugin_Continue;
    }
	else if (interrupt[survivor])
	{
        interrupt[survivor] = false;
        return Plugin_Stop;
    }

    if (currentSequence[survivor] == GetEntProp(client, Prop_Send, "m_nSequence")) return Plugin_Continue;
    else if (playerState[survivor] == view_as<PlayerState>(TANK_PUNCH_FIX))
	{
        L4D2Direct_DoAnimationEvent(client, 96); // 96 is the tank punch getup.
        playerState[survivor] = view_as<PlayerState>(TANK_PUNCH_GETUP);
        currentSequence[survivor] = 0;
        CreateTimer(0.04, TankLandTimer, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }
	else
	{
        playerState[survivor] = view_as<PlayerState>(UPRIGHT);
        pendingGetups[survivor]--;
        CreateTimer(0.04, CancelGetup, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        return Plugin_Stop;
    }
}

public Action CancelGetup(Handle timer, any client)
{
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return Plugin_Stop;
    if (pendingGetups[survivor] <= 0)
	{
        pendingGetups[survivor] = 0;
        currentSequence[survivor] = 0;
        return Plugin_Stop;
    }
    pendingGetups[survivor]--;
    SetEntPropFloat(client, Prop_Send, "m_flCycle", 1000.0); // Jumps to frame 1000 in the animation, effectively skipping it.
    return Plugin_Continue;
}

public Action Timer_ProcessClient(Handle timer, any client)
{
	ProcessClient(client);
}

int ProcessClient(int client)
{
    SurvivorCharacter charIndex = IdentifySurvivor(client);    
    if (charIndex == SC_NONE) return;
    
    int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
    
    if (sequence != getUpAnimations[charIndex][INDEX_HUNTER] && sequence != getUpAnimations[charIndex][INDEX_CHARGER]
    &&  sequence != getUpAnimations[charIndex][INDEX_CHARGER_GROUND] && sequence != getUpAnimations[charIndex][INDEX_CHARGER_WALL])
    {
        if (sequence != incapAnimations[charIndex][0] && sequence != incapAnimations[charIndex][1]) L4D2Direct_DoAnimationEvent(client, ANIM_EVENT_CHARGER_GETUP);
        return;
    }
    
    Handle tempStack = CreateStack(3);
    PushStackCell(tempStack, client);
    PushStackCell(tempStack, sequence);
    
    if (sequence == getUpAnimations[charIndex][INDEX_HUNTER]) CreateTimer(ANIM_HUNTER_LENGTH, Timer_CheckClient, tempStack);
    else if (sequence == getUpAnimations[charIndex][INDEX_CHARGER]) CreateTimer(ANIM_CHARGER_STANDARD_LENGTH, Timer_CheckClient, tempStack);
    else if (sequence == getUpAnimations[charIndex][INDEX_CHARGER_WALL]) CreateTimer(ANIM_CHARGER_SLAMMED_WALL_LENGTH - 2.5*GetEntPropFloat(client, Prop_Send, "m_flCycle"), Timer_CheckClient, tempStack);
    else CreateTimer(ANIM_CHARGER_SLAMMED_GROUND_LENGTH - 2.5*GetEntPropFloat(client, Prop_Send, "m_flCycle"), Timer_CheckClient, tempStack);
}

public Action Timer_CheckClient(Handle timer, any tempStack)
{
    int client, oldSequence;
    float duration;
    PopStackCell(tempStack, oldSequence);
    PopStackCell(tempStack, client);
    
    SurvivorCharacter charIndex = IdentifySurvivor(client);    
    if (charIndex == SC_NONE) return;
    
    int newSequence = GetEntProp(client, Prop_Send, "m_nSequence");
    
    if (newSequence == oldSequence) return;
    if (newSequence == getUpAnimations[charIndex][INDEX_HUNTER]) duration = ANIM_HUNTER_LENGTH;
    else if (newSequence == getUpAnimations[charIndex][INDEX_CHARGER]) duration = ANIM_CHARGER_STANDARD_LENGTH;
    else if (newSequence == getUpAnimations[charIndex][INDEX_CHARGER_WALL]) duration = ANIM_CHARGER_SLAMMED_WALL_LENGTH;
    else if (newSequence == getUpAnimations[charIndex][INDEX_CHARGER_GROUND]) duration = ANIM_CHARGER_SLAMMED_GROUND_LENGTH;
    else return;
    
    SetEntPropFloat(client, Prop_Send, "m_flCycle", duration);
}

public Action GetupTimer2(Handle timer, any attacker)
{
    if (!IsValidInGame(attacker)) return;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			if (!bArClientAlreadyChecked[index])
			{
				int seq = GetEntProp(index, Prop_Send, "m_nSequence");
				SurvivorCharacter character = IdentifySurvivor(index);
				
				if (character == SC_NONE) return;
				
				if (seq == getUpAnimations[character][INDEX_CHARGER_WALL])
				{
					if (index == attacker) SetEntPropFloat(attacker, Prop_Send, "m_flCycle", ANIM_CHARGER_SLAMMED_WALL_LENGTH);
					else
					{
						bArClientAlreadyChecked[index] = true;
						CreateTimer(ANIM_CHARGER_SLAMMED_WALL_LENGTH, ResetAlreadyCheckedBool, index);
						ProcessClient(index);
					}
					break;
				}
				else if (seq == getUpAnimations[character][INDEX_CHARGER_GROUND])
				{
					if (index == attacker) SetEntPropFloat(attacker, Prop_Send, "m_flCycle", ANIM_CHARGER_SLAMMED_GROUND_LENGTH);
					else
					{
						bArClientAlreadyChecked[index] = true;
						CreateTimer(ANIM_CHARGER_SLAMMED_GROUND_LENGTH, ResetAlreadyCheckedBool, index);
						ProcessClient(index);
					}
					break;
				}            
			}
		}
	}
}

public Action ResetAlreadyCheckedBool(Handle timer, any client)
{
    bArClientAlreadyChecked[client] = false;
}

public Action HookOnThink(Handle timer, any client)
{
    if (IsValidSurvivor(client)) SDKHook(client, SDKHook_PostThink, OnThink);
}

public Action OnThink(int client)
{
    SurvivorCharacter survivor = IdentifySurvivor(client);
    if (survivor == SC_NONE) return;
    int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
    if (sequence != getUpAnimations[survivor][INDEX_HUNTER] && sequence != getUpAnimations[survivor][INDEX_CHARGER] 
	&& sequence != getUpAnimations[survivor][INDEX_CHARGER_WALL] && sequence != getUpAnimations[survivor][INDEX_CHARGER_GROUND] 
	&& sequence != getUpAnimations[survivor][4])
    {
        isSurvivorStaggerBlocked[survivor] = false;
        SDKUnhook(client, SDKHook_PostThink, OnThink);
    }
}

public Action L4D2_OnStagger(int target, int source) 
{
    if (source != 0 && IsValidInfected(source))
    {
        int sourceClass = GetInfectedClass(source);
        if (sourceClass == ZC_HUNTER || sourceClass == ZC_JOCKEY)
        {
            SurvivorCharacter survivor = IdentifySurvivor(target);
            if (survivor == SC_NONE) return Plugin_Continue;
            if (isSurvivorStaggerBlocked[survivor]) return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

public Action L4D2_OnPounceOrLeapStumble(int victim, int attacker)
{
	if (IsValidInfected(attacker))
	{
		int sourceClass = GetInfectedClass(attacker);
		if (sourceClass == ZC_HUNTER || sourceClass == ZC_JOCKEY)
		{
			SurvivorCharacter survivor = IdentifySurvivor(victim);
			if (survivor == SC_NONE) return Plugin_Continue;
			if (isSurvivorStaggerBlocked[survivor]) return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

stock bool isGettingUp(any survivor)
{
	switch (playerState[survivor])
	{
		case (view_as<PlayerState>(HUNTER_GETUP)): return true;
		case (view_as<PlayerState>(CHARGER_GETUP)): return true;
		case (view_as<PlayerState>(MULTI_CHARGED)): return true;
		case (view_as<PlayerState>(TANK_PUNCH_GETUP)): return true;
		case (view_as<PlayerState>(TANK_ROCK_GETUP)): return true;
	}
	return false;
}
