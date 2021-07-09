#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

// Macros for easily referencing the Undo Damage array
#define UNDO_PERM 0
#define UNDO_TEMP 1
#define UNDO_SIZE 16

// Macros for stack argument array
#define STACK_VICTIM 0
#define STACK_DAMAGE 1
#define STACK_DISTANCE 2
#define STACK_TYPE 3
#define STACK_SIZE 4

// Announcement flags
#define ANNOUNCE_NONE 0
#define ANNOUNCE_CONSOLE 1
#define ANNOUNCE_CHAT 2

// Flags for different types of Friendly Fire
#define FFTYPE_NOTUNDONE 0
#define FFTYPE_TOOCLOSE 1
#define FFTYPE_CHARGERCARRY 2
#define FFTYPE_STUPIDBOTS 4
#define FFTYPE_MELEEFLAG 0x8000

static const float gfc_ff_min_time = 0.8;
static const float gfc_spit_extra_time = 0.4;
static const float gfc_common_extra_time = 0.6;
static const float gfc_hunter_duration = 1.8;
static const float gfc_jockey_duration = 0.0;
static const float gfc_smoker_duration = 0.0;
static const float gfc_charger_duration = 2.1;
static const int gfc_spit_zc_flags = 6;
static const int gfc_common_zc_flags = 9;
static const int l4d2_undoff_enable = 7;  //Bit flag: Enables plugin features (add together): 1=too close, 2=Charger carry, 4=guilty bots, 7=all, 0=off
static const int l4d2_undoff_blockzerodmg = 7;  //Bit flag: Block 0 damage friendly fire effects like recoil and vocalizations/stats (add together): 4=bot hits human block recoil, 2=block vocals/stats on ALL difficulties, 1=block vocals/stats on everything EXCEPT Easy (flag 2 has precedence), 0=off
static const float l4d2_undoff_permdmgfrac = 1.0;
static const float l4d2_shotgun_ff_multi = 0.5;
static const float l4d2_shotgun_ff_min = 1.0;
static const float l4d2_shotgun_ff_max = 8.0;

int g_lastHealth[MAXPLAYERS+1][UNDO_SIZE][2];					// The Undo Damage array, with correlated arrays for holding the last revive count and current undo index
int g_lastReviveCount[MAXPLAYERS+1] = { 0, ... };
int g_currentUndo[MAXPLAYERS+1] = { 0, ... };
int g_targetTempHealth[MAXPLAYERS+1] = { 0, ... };				// Healing is weird, so this keeps track of our target OR the target's temp health
int g_lastPerm[MAXPLAYERS+1] = { 100, ... };					// The permanent damage fraction requires some coordination between OnTakeDamage and player_hurt
int g_lastTemp[MAXPLAYERS+1] = { 0, ... };

bool bBuckshot[MAXPLAYERS + 1];
bool g_chargerCarryNoFF[MAXPLAYERS+1] = { false, ... };		// Flags for knowing when to undo friendly fire
bool g_stupidGuiltyBots[MAXPLAYERS+1] = { false, ... };

float fFakeGodframeEnd[MAXPLAYERS + 1];
int iLastSI[MAXPLAYERS + 1];

int pelletsShot[MAXPLAYERS + 1][MAXPLAYERS + 1];

int frustrationOffset[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "L4D2 Godframes Control combined with FF Plugins",
	author = "Stabby, CircleSquared, Tabun, Visor, dcx, Sir, Spoon",
	version = "0.6.2",
	description = "Allows for control of what gets godframed and what doesnt along with integrated FF Support from l4d2_survivor_ff (by dcx and Visor) and l4d2_shotgun_ff (by Visor)"
};

public void OnPluginStart()
{
	HookEvent("friendly_fire", Event_FriendlyFire, EventHookMode_Pre);
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd, EventHookMode_Post);
	HookEvent("heal_begin", Event_HealBegin, EventHookMode_Pre);
	HookEvent("heal_end", Event_HealEnd, EventHookMode_Pre);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStart, EventHookMode_Pre);

	//Fake godframes
	HookEvent("tongue_release", PostSurvivorRelease);
	HookEvent("pounce_end", PostSurvivorRelease);
	HookEvent("jockey_ride_end", PostSurvivorRelease);
	HookEvent("charger_pummel_end", PostSurvivorRelease);
}

public void L4D_OnRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++) //clear both fake and real just because
	{
		fFakeGodframeEnd[i] = 0.0;
		bBuckshot[i] = false;
	}
}

public Action PostSurvivorRelease(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event,"victim"));

	if (!L4D2_IsValidClient(victim)) { return; } //just in case

	//sets fake godframe time based on cvars for each ZC
	if (StrContains(name, "tongue") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + gfc_smoker_duration;
		iLastSI[victim] = 2;
	} else
	if (StrContains(name, "pounce") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + gfc_hunter_duration;
		iLastSI[victim] = 1;
	} else
	if (StrContains(name, "jockey") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + gfc_jockey_duration;
		iLastSI[victim] = 4;
	} else
	if (StrContains(name, "charger") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + gfc_charger_duration;
		iLastSI[victim] = 8;
	}
	
	if (fFakeGodframeEnd[victim] > GetGameTime()) {
		SetGodframedGlow(victim);
		CreateTimer(fFakeGodframeEnd[victim] - GetGameTime(), Timed_ResetGlow, victim);
	}

	return;
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_TraceAttack, TraceAttackUndoFF);
	bBuckshot[client] = false;
	
	for (int j = 0; j < UNDO_SIZE; j++)
	{
		g_lastHealth[client][j][UNDO_PERM] = 0;
		g_lastHealth[client][j][UNDO_TEMP] = 0;
	}
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_TraceAttack, TraceAttackUndoFF);
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																												   //
//																												   //
//                             --------------    Godframe Control      --------------							   //
//																												   //
//																												   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

public Action Timed_SetFrustration(Handle timer, any client) {
	if (IsClientConnected(client) && IsPlayerAlive(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8) {
		int frust = GetEntProp(client, Prop_Send, "m_frustration");
		frust += frustrationOffset[client];
		
		if (frust > 100) frust = 100;
		else if (frust < 0) frust = 0;
		
		SetEntProp(client, Prop_Send, "m_frustration", frust);
		frustrationOffset[client] = 0;
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!L4D2_IsValidSurvivor(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor)) { return Plugin_Continue; }

	//CountdownTimer cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
	//if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }

	char sClassname[64];
	GetEntityClassname(inflictor, sClassname, 64);

	float fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();

	if (StrEqual(sClassname, "infected") && (iLastSI[victim] & gfc_common_zc_flags)) //commons
	{
		fTimeLeft += gfc_common_extra_time;
	}
	if (StrEqual(sClassname, "insect_swarm") && (iLastSI[victim] & gfc_spit_zc_flags)) //spit
	{
		fTimeLeft += gfc_spit_extra_time;
	}
	if (L4D2_IsValidSurvivor(attacker)) //friendly fire
	{	
		//Block FF While Capped
		if (IsSurvivorBusy(victim)) return Plugin_Handled;

		//Block AI FF
		if (IsFakeClient(victim) && IsFakeClient(attacker)) return Plugin_Handled;

		/**
		#define DMG_PLASMA	(1 << 24)	// < Shot by Cremator
					
		Special case -- let this function know that we've manually applied damage
		I am expecting some info about HL3 at GDC in March, so I felt like choosing this
		exotic damage flag that stands for a cut enemy from HL2
		**/

		if (damagetype == DMG_PLASMA) return Plugin_Continue;

		fTimeLeft += gfc_ff_min_time;

		if (l4d2_undoff_enable)
		{
			bool undone = false;
			int dmg = RoundToFloor(damage);	// Damage to survivors is rounded down
	
			// Only check damage to survivors
			// - if it is greater than 0, OR
			// - if a human survivor did 0 damage (so we know when the engine forgives our friendly fire for us)
			if (dmg > 0 && !IsFakeClient(attacker))
			{
				// Remember health for undo
				int victimPerm = GetClientHealth(victim);
				int victimTemp = L4D_GetPlayerTempHealth(victim);
				// if attacker is not ourself, check for undo damage
				if (attacker != victim)
				{
					char weaponName[32];
					GetSafeEntityName(weapon, weaponName, sizeof(weaponName));
					float Distance = GetClientsDistance(victim, attacker);
					float FFDist = GetWeaponFFDist(weaponName);

					if ((l4d2_undoff_enable & FFTYPE_TOOCLOSE) && (Distance < FFDist))
					{
						undone = true;
					}
					else if ((l4d2_undoff_enable & FFTYPE_CHARGERCARRY) && (g_chargerCarryNoFF[victim]))
					{
						undone = true;
					}
					else if ((l4d2_undoff_enable & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
					{
						undone = true;
					}
					else if (dmg == 0)
					{
						// In order to get here, you must be a human Survivor doing 0 damage to another Survivor
						undone = (l4d2_undoff_blockzerodmg & 0x02) || ((l4d2_undoff_blockzerodmg & 0x01));
					}
				}
		
				// TODO: move to player_hurt?  and check to make sure damage was consistent between the two?
				// We prefer to do this here so we know what the player's state looked like pre-damage
				// Specifically, what portion of the damage was applied to perm and temp health,
				// since we can't tell after-the-fact what the damage was applied to
				// Unfortunately, not all calls to OnTakeDamage result in the player being hurt (e.g. damage during god frames)
				// So we use player_hurt to know when OTD actually happened
				if (!undone && dmg > 0)
				{			
					int PermDmg = RoundToCeil(l4d2_undoff_permdmgfrac * dmg);
					if (PermDmg >= victimPerm)
					{
						// Perm damage won't reduce permanent health below 1 if there is sufficient temp health
						PermDmg = victimPerm - 1;
					}
					int TempDmg = dmg - PermDmg;
					if (TempDmg > victimTemp)
					{
						// If TempDmg exceeds current temp health, transfer the difference to perm damage
						PermDmg += (TempDmg - victimTemp);
						TempDmg = victimTemp;
					}
				
					// Don't add to undo list if player is incapped
					if (!L4D_IsPlayerIncapacitated(victim))
					{
						// point at next undo cell
						int nextUndo = (g_currentUndo[victim] + 1) % UNDO_SIZE;
							
						if (PermDmg < victimPerm)
						{
							// This will call player_hurt, so we should store the damage done so that it can be added back if it is undone
							g_lastHealth[victim][nextUndo][UNDO_PERM] = PermDmg;
							g_lastHealth[victim][nextUndo][UNDO_TEMP] = TempDmg;
							
							// We need some way to tell player_hurt how much perm/temp health we expected the player to have after this attack
							// This is used to implement the fractional damage to perm health
							// We can't just set their health here because this attack might not actually do damage
							g_lastPerm[victim] = victimPerm - PermDmg;
							g_lastTemp[victim] = victimTemp - TempDmg;
						}
						else
						{
							// This will call player_incap_start, so we should store their exact health and incap count at the time of attack
							// If the incap is undone, we will restore these settings instead of adding them
							g_lastHealth[victim][nextUndo][UNDO_PERM] = victimPerm;
							g_lastHealth[victim][nextUndo][UNDO_TEMP] = victimTemp;
							
							// This is used to tell player_incap_start the exact amount of damage that was done by the attack
							g_lastPerm[victim] = PermDmg;
							g_lastTemp[victim] = TempDmg;
							
							// TODO: can we move to incapstart?
							g_lastReviveCount[victim] = L4D_GetPlayerReviveCount(victim);
						}
					}
				}
			}
			
			if (undone) return Plugin_Handled;
		}

		if (fTimeLeft <= 0.0 && IsT1Shotgun(weapon))
		{	
			pelletsShot[victim][attacker]++;

			if (!bBuckshot[attacker])
			{
				bBuckshot[attacker] = true;
				Handle stack = CreateStack(3);
				PushStackCell(stack, weapon);
				PushStackCell(stack, attacker);
				PushStackCell(stack, victim);
				RequestFrame(ProcessShot, stack);
			}
			return Plugin_Handled;
		}
	}

	if (L4D2_IsValidClient(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8) {
		if (StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "prop_car_alarm")) {
			frustrationOffset[attacker] = -100;
			CreateTimer(0.1, Timed_SetFrustration, attacker);
		} else
		if (weapon == 52) {	//tank rock
			frustrationOffset[attacker] = -100;
			CreateTimer(0.1, Timed_SetFrustration, attacker);
		} 
	}

	if (fTimeLeft > 0) //means fake god frames are in effect
	{
		if (StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "prop_car_alarm")) //hittables
		{
			return Plugin_Continue;
		}
		if (StrEqual(sClassname, "witch")) //witches
		{
			return Plugin_Continue;
		}
		return Plugin_Handled;
	}
	else
	{
		iLastSI[victim] = 0;
	}
	return Plugin_Continue;
}

bool IsSurvivorBusy(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0);
}
public Action Timed_ResetGlow(Handle timer, any client) {
	ResetGlow(client);
}

void ResetGlow(int client) {
	if (L4D2_IsValidClient(client)) {
		// remove transparency/color
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

void SetGodframedGlow(int client) {	//there might be issues with realism
	if (L4D2_IsValidClient(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2) {
		// make player transparent/red while godframed
		SetEntityRenderMode( client, RENDER_GLOW );
		SetEntityRenderColor (client, 255,0,0,200 );
	}
}

public void OnMapStart() {
	for (int i = 0; i <= MaxClients; i++) {
		ResetGlow(i);
	}
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																												   //
//																												   //
//                             --------------    JUST UNDO FF STUFF      --------------							   //
//																												   //
//																												   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

// The sole purpose of this hook is to prevent survivor bots from causing the vision of human survivors to recoil
public Action TraceAttackUndoFF(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	// If none of the flags are enabled, don't do anything
	if (!l4d2_undoff_enable) return Plugin_Continue;
	
	// Only interested in Survivor victims
	if (!L4D2_IsValidSurvivor(victim)) return Plugin_Continue;
	
	// If a valid survivor bot shoots a valid survivor human, block it to prevent survivor vision from getting experiencing recoil (it would have done 0 damage anyway)
	if ((l4d2_undoff_blockzerodmg & 0x04) && L4D2_IsValidSurvivor(attacker) && IsFakeClient(attacker) && L4D2_IsValidSurvivor(victim) && !IsFakeClient(victim))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Apply fractional permanent damage here
// Also announce damage, and undo guilty bot damage
public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype, int hitgroup)
{
	if (!l4d2_undoff_enable) return;

	if (!L4D2_IsValidSurvivor(victim)) return;
	
	// When incapped you continuously get hurt by the world, so we just ignore incaps altogether
	if (damage > 0 && !L4D_IsPlayerIncapacitated(victim))
	{
		// Cycle the undo pointer when we have confirmed that the damage was actually taken
		g_currentUndo[victim] = (g_currentUndo[victim] + 1) % UNDO_SIZE;
		
		// victim values are what OnTakeDamage expected us to have, current values are what the game gave us
		int victimPerm = g_lastPerm[victim];
		int victimTemp = g_lastTemp[victim];
		int currentTemp = L4D_GetPlayerTempHealth(victim);

		// If this feature is enabled, some portion of damage will be applied to the temp health
		if (l4d2_undoff_permdmgfrac < 1.0 && victimPerm != health)
		{
			// make sure we don't give extra health
			int totalHealthOld = health + currentTemp, totalHealthNew = victimPerm + victimTemp;
			if (totalHealthOld == totalHealthNew)
			{
				SetEntityHealth(victim, victimPerm);
				L4D_SetPlayerTempHealth(victim, victimTemp);
			}
		}
	}
	
	// Announce damage, and check for guilty bots that slipped through OnTakeDamage
	if (L4D2_IsValidSurvivor(attacker))
	{
		// Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
		// So we must check here to see if the bots are guilty and undo the damage after-the-fact
		if ((l4d2_undoff_enable & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
		{
			UndoDamage(victim);
		}
	}
}

// When a Survivor is incapped by damage, player_hurt will not fire
// So you may notice that the code here has some similarities to the code for player_hurt
public Action Event_PlayerIncapStart(Event event, const char[] name, bool dontBroadcast)
{
	// Cycle the incap pointer, now that the damage has been confirmed
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Cycle the undo pointer when we have confirmed that the damage was actually taken
	g_currentUndo[victim] = (g_currentUndo[victim] + 1) % UNDO_SIZE;
	
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
 
	// Announce damage, and check for guilty bots that slipped through OnTakeDamage
	if (L4D2_IsValidSurvivor(attacker))
	{
		// Unfortunately, the friendly fire event only fires *after* OnTakeDamage has been called so it can't be blocked in time
		// So we must check here to see if the bots are guilty and undo the damage after-the-fact
		if ((l4d2_undoff_enable & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
		{
			UndoDamage(victim);
		}
	}
}

// If a bot is guilty of creating a friendly fire event, undo it
// Also give the human some reaction time to realize the bot ran in front of them
public Action Event_FriendlyFire(Event event, const char[] name, bool dontBroadcast)
{
	if (!(l4d2_undoff_enable & FFTYPE_STUPIDBOTS)) return Plugin_Continue;

	int client = GetClientOfUserId(GetEventInt(event, "guilty"));
	if (IsFakeClient(client))
	{
		g_stupidGuiltyBots[client] = true;
		CreateTimer(0.4, StupidGuiltyBotDelay, client);
	}
	return Plugin_Continue;
}

public Action StupidGuiltyBotDelay(Handle timer, any client)
{
	g_stupidGuiltyBots[client] = false;
}

// While a Charger is carrying a Survivor, undo any friendly fire done to them
// since they are effectively pinned and pinned survivors are normally immune to FF
public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!(l4d2_undoff_enable & FFTYPE_CHARGERCARRY)) return Plugin_Continue;
	
	int client = GetClientOfUserId(GetEventInt(event, "victim"));

	g_chargerCarryNoFF[client] = true;
	return Plugin_Continue;
}

// End immunity about one second after the carry ends
// (there is some time between carryend and pummelbegin,
// but pummelbegin does not always get called if the charger died first, so it is unreliable
// and besides the survivor has natural FF immunity when pinned)
public Action Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "victim"));
	CreateTimer(1.0, ChargerCarryFFDelay, client);	
	return Plugin_Continue;
}

public Action ChargerCarryFFDelay(Handle timer, any client)
{
	g_chargerCarryNoFF[client] = false;
}

// For health kit undo, we must remember the target in HealBegin
public Action Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!l4d2_undoff_enable) 			return Plugin_Continue;	// Not enabled?  Done

	int subject = GetClientOfUserId(GetEventInt(event, "subject"));
	int userid = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!L4D2_IsSurvivorAlive(subject) || !L4D2_IsSurvivorAlive(userid)) return Plugin_Continue;
	
	// Remember the target for HealEnd, since that parameter is a lie for that event
	g_targetTempHealth[userid] = subject;

	return Plugin_Continue;
}

// When healing ends, remember how much temp health the target had
// This way it can be restored in UndoDamage
public Action Event_HealEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!l4d2_undoff_enable) 			return Plugin_Continue;	// Not enabled?  Done

	int userid = GetClientOfUserId(GetEventInt(event, "userid"));
	int subject = g_targetTempHealth[userid];	// this is used first to carry the subject...
	int tempHealth;
	
	if (!L4D2_IsSurvivorAlive(subject))
	{
		PrintToServer("Who did you heal? (%d)", subject);	
		return Plugin_Continue;
	}
	
	tempHealth =  L4D_GetPlayerTempHealth(subject);
	if (tempHealth < 0) tempHealth = 0;
	
	// ...and second it is used to store the subject's temp health (since success knows the subject)
	g_targetTempHealth[userid] = tempHealth;
	
	return Plugin_Continue;
}

// Save the amount of health restored as negative so it can be undone
public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!l4d2_undoff_enable) return Plugin_Continue;	// Not enabled?  Done
	
	int subject = GetClientOfUserId(GetEventInt(event, "subject"));
	int userid = GetClientOfUserId(GetEventInt(event, "userid"));

	if (!L4D2_IsSurvivorAlive(subject)) return Plugin_Continue;

	int nextUndo = (g_currentUndo[subject] + 1) % UNDO_SIZE;
	g_lastHealth[subject][nextUndo][UNDO_PERM] = -GetEventInt(event, "health_restored");
	g_lastHealth[subject][nextUndo][UNDO_TEMP] = g_targetTempHealth[userid];
	g_currentUndo[subject] = nextUndo;

	return Plugin_Continue;
}

// The magic behind Undo Damage
// Cycles through the array, can also undo incapacitations
void UndoDamage(int client)
{
	if (L4D2_IsValidSurvivor(client))
	{
		int thisUndo = g_currentUndo[client];
		int undoPerm = g_lastHealth[client][thisUndo][UNDO_PERM];
		int undoTemp = g_lastHealth[client][thisUndo][UNDO_TEMP];

		int newHealth, newTemp;
		if (L4D_IsPlayerIncapacitated(client))
		{
			// If player is incapped, restore their previous health and incap count
			newHealth = undoPerm;
			newTemp = undoTemp;
			
			CheatCommand(client, "give", "health");
			L4D_SetPlayerReviveCount(client, g_lastReviveCount[client]);
		}
		else
		{
			// add perm and temp health back to their existing health
			newHealth = GetClientHealth(client) + undoPerm;
			newTemp = undoTemp;
			if (undoPerm >= 0)
			{
				// undoing damage, so add current temp health do undoTemp
				newTemp += L4D_GetPlayerTempHealth(client);
			}
			else
			{
				// undoPerm is negative when undoing healing, so don't add current temp health
				// instead, give the health kit that was undone
				CheatCommand(client, "give", "weapon_first_aid_kit");
			}
		}
		if (newHealth > 100) newHealth = 100;						// prevent going over 100 health
		if (newHealth + newTemp > 100) newTemp = 100 - newHealth;
		SetEntityHealth(client, newHealth);
		L4D_SetPlayerTempHealth(client, newTemp);

		// clear out the undo so it can't happen again
		g_lastHealth[client][thisUndo][UNDO_PERM] = 0;
		g_lastHealth[client][thisUndo][UNDO_TEMP] = 0;
		
		// point to the previous undo
		if (thisUndo <= 0) thisUndo = UNDO_SIZE;
		thisUndo = thisUndo - 1;
		g_currentUndo[client] = thisUndo;
	}
}

// Gets the distance between two survivors
// Accounting for any difference in height
float GetClientsDistance(int victim, int attacker)
{
	float attackerPos[3], victimPos[3];
	float mins[3], maxs[3], halfHeight;
	GetClientMins(victim, mins);
	GetClientMaxs(victim, maxs);
	
	halfHeight = maxs[2] - mins[2] + 10;
	
	GetClientAbsOrigin(victim,victimPos);
	GetClientAbsOrigin(attacker,attackerPos);
	
	float posHeightDiff = attackerPos[2] - victimPos[2];
	
	if (posHeightDiff > halfHeight)
	{
		attackerPos[2] -= halfHeight;
	}
	else if (posHeightDiff < (-1.0 * halfHeight))
	{
		victimPos[2] -= halfHeight;
	}
	else
	{
		attackerPos[2] = victimPos[2];
	}
	
	return GetVectorDistance(victimPos ,attackerPos, false);
}

// Gets per-weapon friendly fire undo distances
float GetWeaponFFDist(char[] weaponName)
{
	if (StrEqual(weaponName, "weapon_melee") 
		|| StrEqual(weaponName, "weapon_pistol"))
	{
		return 25.0;
	}
	else if (StrEqual(weaponName, "weapon_smg") 
			|| StrEqual(weaponName, "weapon_smg_silenced") 
			|| StrEqual(weaponName, "weapon_smg_mp5") 
			|| StrEqual(weaponName, "weapon_pistol_magnum"))
	{
		return 30.0;
	}
	else if	(StrEqual(weaponName, "weapon_pumpshotgun")
			|| StrEqual(weaponName, "weapon_shotgun_chrome") 
			|| StrEqual(weaponName, "weapon_hunting_rifle") 
			|| StrEqual(weaponName, "weapon_sniper_scout") 
			|| StrEqual(weaponName, "weapon_sniper_awp"))
	{
		return 37.0;
	}

	return 0.0;
}

void GetSafeEntityName(int entity, char[] TheName, int TheNameSize)
{
	if (entity > 0 && IsValidEntity(entity))
	{
		GetEntityClassname(entity, TheName, TheNameSize);
	}
	else
	{
		strcopy(TheName, TheNameSize, "Invalid");
	}
}

// I believe this is from Mr. Zero's stocks?
int L4D_GetPlayerTempHealth(int client)
{
	if (!L4D2_IsValidSurvivor(client)) return 0;
	
	Handle painPillsDecayCvar = null;
	if (painPillsDecayCvar == null)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == null)
		{
			return -1;
		}
	}

	int tempHealth = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(painPillsDecayCvar))) - 1;
	return tempHealth < 0 ? 0 : tempHealth;
}

void L4D_SetPlayerTempHealth(int client, int tempHealth)
{
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", float(tempHealth));
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
}

int L4D_GetPlayerReviveCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

void L4D_SetPlayerReviveCount(int client, any count)
{
	SetEntProp(client, Prop_Send, "m_currentReviveCount", count);
}

bool L4D_IsPlayerIncapacitated(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
}

void CheatCommand(int client, const char[] command, const char[] arguments)
{
    int flags = GetCommandFlags(command);
    SetCommandFlags(command, flags & ~FCVAR_CHEAT);
    FakeClientCommand(client, "%s %s", command, arguments);
    SetCommandFlags(command, flags);
}

/* //////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//																												   //
//																												   //
//                             --------------    L4D2 Shotgun FF      --------------							   //
//																												   //
//																												   //
////////////////////////////////////////////////////////////////////////////////////////////////////////////////// */

bool IsT1Shotgun(int weapon)
{
	if (!IsValidEdict(weapon)) return false;
	char classname[64];
	GetEdictClassname(weapon, classname, sizeof(classname));
	return (StrEqual(classname, "weapon_pumpshotgun") || StrEqual(classname, "weapon_shotgun_chrome"));
}

void ProcessShot(ArrayStack stack)
{
	int victim, attacker, weapon;
	if (!IsStackEmpty(stack))
	{
		PopStackCell(stack, victim);
		PopStackCell(stack, attacker);
		PopStackCell(stack, weapon);
	}
	
	if (L4D2_IsValidClient(victim) && L4D2_IsValidClient(attacker))
	{
		// Replicate natural behaviour
		float minFF = l4d2_shotgun_ff_min;
		float maxFF = l4d2_shotgun_ff_max <= 0.0 ? 99999.0 : l4d2_shotgun_ff_max;
		float damage = L4D2_Max(minFF, L4D2_Min((pelletsShot[victim][attacker] * l4d2_shotgun_ff_multi), maxFF));
		int newPelletCount = RoundFloat(damage);
		pelletsShot[victim][attacker] = 0;
		for (int i = 0; i < newPelletCount; i++)
		{
			SDKHooks_TakeDamage(victim, attacker, attacker, 1.0, DMG_PLASMA, weapon, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	bBuckshot[attacker] = false;

	CloseHandle(stack);
}
