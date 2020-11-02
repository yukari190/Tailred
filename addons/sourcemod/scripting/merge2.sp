#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <dhooks>
#include <left4dhooks>
#include <l4d2util_stocks>

Handle hCLunge_ActivateAbility;
Handle hTongueParalyzeTimer;
ConVar hConVar;
ConVar hCvarMaxZombies;
int tmpValueOld;
int iDamage[MAXPLAYERS + 1][MAXPLAYERS + 1];
float fSuspectedBackjump[MAXPLAYERS + 1];
float fGhostDelay;
float fReported[MAXPLAYERS + 1][MAXPLAYERS + 1];

public Plugin myinfo =
{
    name        = "L4D2 merge",
    author      = "Visor, Stabby, Tabun, someone",
    description = "",
    version     = "1.2"
}

public void OnPluginStart()
{
    Handle gameConf = LoadGameConfigFile("l4d2_nobackjump"); 
    int LungeActivateAbilityOffset = GameConfGetOffset(gameConf, "CLunge_ActivateAbility");
    delete gameConf;
	
    hCLunge_ActivateAbility = DHookCreate(LungeActivateAbilityOffset, HookType_Entity, ReturnType_Void, ThisPointer_CBaseEntity, CLunge_ActivateAbility);
    DHookAddEntityListener(ListenType_Created, OnEntityCreated);
	
	hConVar = FindConVar("z_common_limit");
	hCvarMaxZombies = FindConVar("z_max_player_zombies");
	AddCommandListener(TeamCmd, "jointeam");
	
    HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
    HookEvent("player_jump", OnPlayerJump);
	HookEvent("player_bot_replace", OnTankGoneAi);
    HookEvent("player_hurt", Event_PlayerHurt);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("charger_carry_start", Event_CHJ_Attack);
    HookEvent("charger_pummel_start", Event_CHJ_Attack);
    HookEvent("lunge_pounce", Event_CHJ_Attack);
    HookEvent("jockey_ride", Event_CHJ_Attack);
    HookEvent("tongue_grab", Event_SmokerAttackFirst);
    HookEvent("choke_start", Event_SmokerAttackSecond);
}

public void OnPluginEnd()
{
    SetConVarInt(hConVar, tmpValueOld);
}

public void OnConfigsExecuted()
{
    fGhostDelay = GetConVarFloat(FindConVar("z_ghost_delay_min"));
}

public void OnMapStart()
{
	tmpValueOld = GetConVarInt(hConVar);
    if (L4D_IsMissionFinalMap())
    {
		SetConVarInt(hConVar, 2);
    }
}

public void OnMapEnd()
{
    SetConVarInt(hConVar, tmpValueOld);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "ability_lunge"))
        DHookEntity(hCLunge_ActivateAbility, false, entity); 
}

public Action Event_PlayerHurt(Event event, const char[] name, bool bDontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidInfected(victim) || IsTargetedSi(victim) < 0)
        return;

    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker == 0 || !IsClientInGame(attacker) || !IsValidSurvivor(attacker) || IsFakeClient(attacker) || !IsPlayerAlive(attacker))
        return;

    iDamage[attacker][victim] += event.GetInt("dmg_health");
}

public Action Event_PlayerDeath(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client == 0 || !IsClientInGame(client) || !IsValidInfected(client)) return;

    int zombieclass = IsTargetedSi(client);
    if (zombieclass < 0) return;    

    for (int i = 1; i <= MaxClients; i++)
    {
        iDamage[i][client] = 0;
    }

    if (zombieclass == ZC_SMOKER)
    {
        ClearTimer(hTongueParalyzeTimer);
    }
}

public Action Event_CHJ_Attack(Event event, const char[] name, bool bDontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    if (attacker == 0 || !IsClientInGame(attacker) || !IsValidInfected(attacker) || !IsPlayerAlive(attacker))
        return;
        
    int victim = GetClientOfUserId(event.GetInt("victim"));
    if (victim == 0 || !IsClientInGame(victim) || !IsValidSurvivor(victim) || IsFakeClient(victim) || !IsPlayerAlive(victim))
        return;
        
    PrintInflictedDamage(victim, attacker);
}

public Action Event_SmokerAttackFirst(Event event, const char[] name, bool bDontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int checks = 0;

    Handle hEventMembers = CreateStack(3);
    PushStackCell(hEventMembers, attacker);
    PushStackCell(hEventMembers, victim);
    PushStackCell(hEventMembers, checks);

    hTongueParalyzeTimer = CreateTimer(1.1, CheckSurvivorState, hEventMembers, TIMER_FLAG_NO_MAPCHANGE);
}

public Action CheckSurvivorState(Handle timer, any hEventMembers)
{
    int checks, victim, attacker;
    if (!IsStackEmpty(hEventMembers))
    {
        PopStackCell(hEventMembers, checks);
        PopStackCell(hEventMembers, victim);
        PopStackCell(hEventMembers, attacker);
    }

    if (IsSurvivorParalyzed(victim))
    {
        PrintInflictedDamage(victim, attacker);
    }
}

public Action Event_SmokerAttackSecond(Event event, const char[] name, bool bDontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));

    ClearTimer(hTongueParalyzeTimer);
    PrintInflictedDamage(victim, attacker);
}

public void PrintInflictedDamage(int iSurvivor, int iInfected)
{
    float fGameTime = GetGameTime();
    if ((fReported[iSurvivor][iInfected] + fGhostDelay) >= fGameTime)    // Used as a workaround to prevent double prints that might happen for Charger/Smoker
        return;

    if (iDamage[iSurvivor][iInfected] == 0)   // Don't bother
        return;

    PrintToChat(iSurvivor, 
    "\x04[DmgReport]\x01 \x03%N\x01(\x04%s\x01) took \x05%d\x01 damage from you!", 
    iInfected, 
    L4D2_InfectedNames[GetEntProp(iInfected, Prop_Send, "m_zombieClass")], 
    iDamage[iSurvivor][iInfected]);

    fReported[iSurvivor][iInfected] = GetGameTime();
    iDamage[iSurvivor][iInfected] = 0;
}

public Action OnTankGoneAi(Event event, const char[] name, bool bDontBroadcast)
{	
	int newTank = GetClientOfUserId(event.GetInt("bot"));
	if (GetClientTeam(newTank) == 3 && GetEntProp(newTank, Prop_Send, "m_zombieClass") == 8)
	{
		ForcePlayerSuicide(newTank);
	}
}

public Action OnRoundStart(Event event, const char[] name, bool bDontBroadcast)
{
    for (int i = 1; i <= MAXPLAYERS; i++) fSuspectedBackjump[i] = 0.0;
}

public Action OnPlayerJump(Event event, const char[] name, bool bDontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsHunter(client) && !IsGhost(client) && IsOutwardJump(client)) fSuspectedBackjump[client] = GetGameTime();
}

public MRESReturn CLunge_ActivateAbility(int ability, Handle hParams)
{
    int client = GetEntPropEnt(ability, Prop_Send, "m_owner");
    if (fSuspectedBackjump[client] + 1.5 > GetGameTime())
    {
        return MRES_Supercede;
    }
    return MRES_Ignored;
}

public Action TeamCmd(int client, const char[] command, int argc)
{
	if (client && argc > 0)
	{
		char sBuffer[128];
		GetCmdArg(1, sBuffer, sizeof(sBuffer));
		int newteam = StringToInt(sBuffer);
		if (GetClientTeam(client)==2 && (StrEqual("Infected", sBuffer, false) || newteam==3))
		{
			int zombies = 0;
			for (int i=1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i)==3)
					zombies++;
			}
			if (zombies>=GetConVarInt(hCvarMaxZombies))
				return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
    if (StrEqual(key,"CommonLimit"))
    {
        if (retVal > GetConVarInt(hConVar))
        {
            retVal = GetConVarInt(hConVar);
            return Plugin_Handled;
        }
    }
    return Plugin_Continue;
}

bool IsOutwardJump(int client)
{
    return GetEntProp(client, Prop_Send, "m_isAttemptingToPounce") == 0 && !(GetEntityFlags(client) & FL_ONGROUND);
}

bool IsHunter(int client)
{
    if (client < 1 || client > MaxClients) return false;
    if (!IsClientInGame(client) || !IsPlayerAlive(client)) return false;
    if (GetClientTeam(client) != 3 || GetEntProp(client, Prop_Send, "m_zombieClass") != 3) return false;
    return true;
}

bool IsGhost(int client)
{
    return GetEntProp(client, Prop_Send, "m_isGhost") == 1;
}

bool IsSurvivorParalyzed(int client)
{
    return (GetGameTime() - GetEntDataFloat(client, 13292) >= 1.0) && (GetEntData(client, 13284) > 0);
}

int IsTargetedSi(int client)
{
    int zombieclass = GetInfectedClass(client);

    if (zombieclass == ZC_CHARGER || 
    zombieclass == ZC_HUNTER || 
    zombieclass == ZC_JOCKEY || 
    zombieclass == ZC_SMOKER
    ) return zombieclass;

    return -1;
}

void ClearTimer(Handle &timer)
{
    if (timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }     
}
