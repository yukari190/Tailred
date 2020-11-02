#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

#define UNDO_PERM 0
#define UNDO_TEMP 1
#define UNDO_SIZE 16

#define STACK_VICTIM 0
#define STACK_DAMAGE 1
#define STACK_DISTANCE 2
#define STACK_TYPE 3
#define STACK_SIZE 4

#define ANNOUNCE_NONE 0
#define ANNOUNCE_CONSOLE 1
#define ANNOUNCE_CHAT 2

#define FFTYPE_NOTUNDONE 0
#define FFTYPE_TOOCLOSE 1
#define FFTYPE_CHARGERCARRY 2
#define FFTYPE_STUPIDBOTS 4
#define FFTYPE_MELEEFLAG 0x8000

ConVar hRageRock;
ConVar hRageHittables;
ConVar hHittable;
ConVar hWitch;
ConVar hFF;
ConVar hSpit;
ConVar hCommon;
ConVar hHunter;
ConVar hSmoker;
ConVar hJockey;
ConVar hCharger;
ConVar hSpitFlags;
ConVar hCommonFlags;
ConVar hGodframeGlows;
ConVar hRock;

ConVar hCvarEnableShotFF;
ConVar hCvarModifier;
ConVar hCvarMinFF;
ConVar hCvarMaxFF;
bool bBuckshot[MAXPLAYERS + 1];

ConVar g_cvarEnable;
ConVar g_cvarBlockZeroDmg;
ConVar g_cvarPermDamageFraction;

int g_lastHealth[MAXPLAYERS+1][UNDO_SIZE][2];
int g_lastReviveCount[MAXPLAYERS+1] = { 0, ... };
int g_currentUndo[MAXPLAYERS+1] = { 0, ... };
int g_targetTempHealth[MAXPLAYERS+1] = { 0, ... };
int g_lastPerm[MAXPLAYERS+1] = { 100, ... };
int g_lastTemp[MAXPLAYERS+1] = { 0, ... };

bool g_chargerCarryNoFF[MAXPLAYERS+1] = { false, ... };
bool g_stupidGuiltyBots[MAXPLAYERS+1] = { false, ... };

float fFakeGodframeEnd[MAXPLAYERS + 1];
int iLastSI[MAXPLAYERS + 1];

int pelletsShot[MAXPLAYERS+1][MAXPLAYERS+1];

int frustrationOffset[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "L4D2 Godframes Control combined with FF Plugins",
	author = "Stabby, CircleSquared, Tabun, Visor, dcx, Sir, Spoon",
	version = "0.6",
	description = "Allows for control of what gets godframed and what doesnt along with integrated FF Support from l4d2_survivor_ff (by dcx and Visor) and l4d2_shotgun_ff (by Visor)"
};

public void OnPluginStart()
{
	hGodframeGlows = CreateConVar("gfc_godframe_glows", "1", "Changes the rendering of survivors while godframed (red/transparent).", 0, true, 0.0, true, 1.0 );
	hRageHittables = CreateConVar("gfc_hittable_rage_override", "1", "Allow tank to gain rage from hittable hits. 0 blocks rage gain.", 0, true, 0.0, true, 1.0 );
	hRageRock = CreateConVar(	"gfc_rock_rage_override", "1", "Allow tank to gain rage from godframed hits. 0 blocks rage gain.", 0, true, 0.0, true, 1.0 );
	hHittable = CreateConVar(	"gfc_hittable_override", "1", "Allow hittables to always ignore godframes.", 0, true, 0.0, true, 1.0 );
	hRock = CreateConVar(	"gfc_rock_override", "0", "Allow hittables to always ignore godframes.", 0, true, 0.0, true, 1.0 );
	hWitch = CreateConVar( 		"gfc_witch_override", "1", "Allow witches to always ignore godframes.", 0, true, 0.0, true, 1.0 );
	hFF = CreateConVar( 		"gfc_ff_min_time", "0.8", "Minimum time before FF damage is allowed.", 0, true, 0.0, true, 3.0 );
	hSpit = CreateConVar( 		"gfc_spit_extra_time", "0.4", "Additional godframe time before spit damage is allowed.", 0, true, 0.0, true, 3.0 );
	hCommon = CreateConVar( 	"gfc_common_extra_time", "0.6", "Additional godframe time before common damage is allowed.", 0, true, 0.0, true, 3.0 );
	hHunter = CreateConVar( 	"gfc_hunter_duration", "1.8", "How long should godframes after a pounce last?", 0, true, 0.0, true, 3.0 );
	hJockey = CreateConVar( 	"gfc_jockey_duration", "0.0", "How long should godframes after a ride last?", 0, true, 0.0, true, 3.0 );
	hSmoker = CreateConVar( 	"gfc_smoker_duration", "0.0", "How long should godframes after a pull or choke last?", 0, true, 0.0, true, 3.0 );
	hCharger = CreateConVar( 	"gfc_charger_duration", "2.1", "How long should godframes after a pummel last?", 0, true, 0.0, true, 3.0 );
	hSpitFlags = CreateConVar( 	"gfc_spit_zc_flags", "6", "Which classes will be affected by extra spit protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.", 0, true, 0.0, true, 15.0 );
	hCommonFlags= CreateConVar( "gfc_common_zc_flags", "9", "Which classes will be affected by extra common protection time. 1 - Hunter. 2 - Smoker. 4 - Jockey. 8 - Charger.", 0, true, 0.0, true, 15.0 );

	g_cvarEnable = 				CreateConVar("l4d2_undoff_enable", 		"7", 	"Bit flag: Enables plugin features (add together): 1=too close, 2=Charger carry, 4=guilty bots, 7=all, 0=off", FCVAR_NOTIFY);
	g_cvarBlockZeroDmg =		CreateConVar("l4d2_undoff_blockzerodmg","7", 	"Bit flag: Block 0 damage friendly fire effects like recoil and vocalizations/stats (add together): 4=bot hits human block recoil, 2=block vocals/stats on ALL difficulties, 1=block vocals/stats on everything EXCEPT Easy (flag 2 has precedence), 0=off", FCVAR_NOTIFY);
	g_cvarPermDamageFraction = 	CreateConVar("l4d2_undoff_permdmgfrac", "1.0", 	"Minimum fraction of damage applied to permanent health", FCVAR_NOTIFY, true, 0.0, true, 1.0);

	hCvarEnableShotFF = CreateConVar("l4d2_shotgun_ff_enable", "1", "Enable Shotgun FF Module?");
	hCvarModifier = CreateConVar("l4d2_shotgun_ff_multi", "0.5", "Shotgun FF damage modifier value", 0, true, 0.0, true, 5.0);
	hCvarMinFF = CreateConVar("l4d2_shotgun_ff_min", "1.0", "Minimum allowed shotgun FF damage; 0 for no limit", 0, true, 0.0);
	hCvarMaxFF = CreateConVar("l4d2_shotgun_ff_max", "8.0", "Maximum allowed shotgun FF damage; 0 for no limit", 0, true, 0.0);

	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
	HookEvent("friendly_fire", Event_FriendlyFire, EventHookMode_Pre);
	HookEvent("charger_carry_start", Event_ChargerCarryStart, EventHookMode_Post);
	HookEvent("charger_carry_end", Event_ChargerCarryEnd, EventHookMode_Post);
	HookEvent("heal_begin", Event_HealBegin, EventHookMode_Pre);
	HookEvent("heal_end", Event_HealEnd, EventHookMode_Pre);
	HookEvent("heal_success", Event_HealSuccess, EventHookMode_Pre);
	HookEvent("player_incapacitated_start", Event_PlayerIncapStart, EventHookMode_Pre);

	HookEvent("tongue_release", PostSurvivorRelease);
	HookEvent("pounce_end", PostSurvivorRelease);
	HookEvent("jockey_ride_end", PostSurvivorRelease);
	HookEvent("charger_pummel_end", PostSurvivorRelease);
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		fFakeGodframeEnd[i] = 0.0;
		bBuckshot[i] = false;
	}
}

public Action PostSurvivorRelease(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("victim"));

	if (!IsValidInGame(victim)) { return; }

	if (StrContains(name, "tongue") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hSmoker);
		iLastSI[victim] = 2;
	}
	else if (StrContains(name, "pounce") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hHunter);
		iLastSI[victim] = 1;
	}
	else if (StrContains(name, "jockey") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hJockey);
		iLastSI[victim] = 4;
	}
	else if (StrContains(name, "charger") != -1)
	{
		fFakeGodframeEnd[victim] = GetGameTime() + GetConVarFloat(hCharger);
		iLastSI[victim] = 8;
	}
	
	if (fFakeGodframeEnd[victim] > GetGameTime() && GetConVarBool(hGodframeGlows)) {
		SetGodframedGlow(victim);
		CreateTimer(fFakeGodframeEnd[victim] - GetGameTime(), Timed_ResetGlow, victim);
	}

	return;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client)) return;
	if (nowteam == 2 && oldteam != 2)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(client, SDKHook_TraceAttack, TraceAttackUndoFF);
	}
	else if (nowteam != 2 && oldteam == 2)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(client, SDKHook_TraceAttack, TraceAttackUndoFF);
	}
	for (int j = 0; j < UNDO_SIZE; j++)
	{
		g_lastHealth[client][j][UNDO_PERM] = 0;
		g_lastHealth[client][j][UNDO_TEMP] = 0;
	}
}

public Action Timed_SetFrustration(Handle timer, any client)
{
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
	if (!IsValidSurvivor(victim) || !IsValidEdict(attacker) || !IsValidEdict(inflictor)) { return Plugin_Continue; }

	//CountdownTimer cTimerGod = L4D2Direct_GetInvulnerabilityTimer(victim);
	//if (cTimerGod != CTimer_Null) { CTimer_Invalidate(cTimerGod); }

	char sClassname[64];
	GetEntityClassname(inflictor, sClassname, 64);

	float fTimeLeft = fFakeGodframeEnd[victim] - GetGameTime();

	if (StrEqual(sClassname, "infected") && (iLastSI[victim] & GetConVarInt(hCommonFlags)))
	{
		fTimeLeft += GetConVarFloat(hCommon);
	}
	if (StrEqual(sClassname, "insect_swarm") && (iLastSI[victim] & GetConVarInt(hSpitFlags)))
	{
		fTimeLeft += GetConVarFloat(hSpit);
	}
	if (IsValidSurvivor(attacker))
	{	
		if (IsSurvivorBusy(victim)) return Plugin_Handled;

		if (IsFakeClient(victim) && IsFakeClient(attacker)) return Plugin_Handled;

		if (damagetype == DMG_PLASMA) return Plugin_Continue;

		fTimeLeft += GetConVarFloat(hFF);

		if (GetConVarInt(g_cvarEnable))
		{
			bool undone = false;
			int dmg = RoundToFloor(damage);

			if (dmg > 0 && !IsFakeClient(attacker))
			{
				int victimPerm = GetClientHealth(victim);
				int victimTemp = L4D_GetPlayerTempHealth(victim);
				if (attacker != victim)
				{
					char weaponName[32];
					GetSafeEntityName(weapon, weaponName, sizeof(weaponName));
					float Distance = GetClientsDistance(victim, attacker);
					float FFDist = GetWeaponFFDist(weaponName);

					if ((GetConVarInt(g_cvarEnable) & FFTYPE_TOOCLOSE) && (Distance < FFDist))
					{
						undone = true;
					}
					else if ((GetConVarInt(g_cvarEnable) & FFTYPE_CHARGERCARRY) && (g_chargerCarryNoFF[victim]))
					{
						undone = true;
					}
					else if ((GetConVarInt(g_cvarEnable) & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
					{
						undone = true;
					}
					else if (dmg == 0)
					{
						undone = (GetConVarInt(g_cvarBlockZeroDmg) & 0x02) || ((GetConVarInt(g_cvarBlockZeroDmg) & 0x01));
					}
				}

				if (!undone && dmg > 0)
				{			
					int PermDmg = RoundToCeil(GetConVarFloat(g_cvarPermDamageFraction) * dmg);
					if (PermDmg >= victimPerm)
					{
						PermDmg = victimPerm - 1;
					}
					int TempDmg = dmg - PermDmg;
					if (TempDmg > victimTemp)
					{
						PermDmg += (TempDmg - victimTemp);
						TempDmg = victimTemp;
					}
				
					if (!L4D_IsPlayerIncapacitated(victim))
					{
						int nextUndo = (g_currentUndo[victim] + 1) % UNDO_SIZE;
							
						if (PermDmg < victimPerm)
						{
							g_lastHealth[victim][nextUndo][UNDO_PERM] = PermDmg;
							g_lastHealth[victim][nextUndo][UNDO_TEMP] = TempDmg;
							
							g_lastPerm[victim] = victimPerm - PermDmg;
							g_lastTemp[victim] = victimTemp - TempDmg;
						}
						else
						{
							g_lastHealth[victim][nextUndo][UNDO_PERM] = victimPerm;
							g_lastHealth[victim][nextUndo][UNDO_TEMP] = victimTemp;
							
							g_lastPerm[victim] = PermDmg;
							g_lastTemp[victim] = TempDmg;
							
							g_lastReviveCount[victim] = L4D_GetPlayerReviveCount(victim);
						}
					}
				}
			}
			
			if (undone) return Plugin_Handled;
		}

		if (GetConVarBool(hCvarEnableShotFF) && fTimeLeft <= 0.0 && IsT1Shotgun(weapon))
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

	if (IsValidInGame(attacker) && GetClientTeam(attacker) == 3 && GetEntProp(attacker, Prop_Send, "m_zombieClass") == 8)
	{
		if (StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "prop_car_alarm"))
		{
			if (GetConVarBool(hRageHittables))
			{
				frustrationOffset[attacker] = -100;
			}
			else
			{
				frustrationOffset[attacker] = 0;
			}
			CreateTimer(0.1, Timed_SetFrustration, attacker);
		}
		else if (weapon == 52)
		{
			if (GetConVarBool(hRageRock))
			{
				frustrationOffset[attacker] = -100;
			}
			else
			{
				frustrationOffset[attacker] = 0;
			}
			CreateTimer(0.1, Timed_SetFrustration, attacker);
		} 
	}

	if (fTimeLeft > 0)
	{
		if (StrEqual(sClassname, "prop_physics") || StrEqual(sClassname, "prop_car_alarm")) //hittables
		{
			if (GetConVarBool(hHittable)) { return Plugin_Continue; }
		}
		if (IsTankRock(inflictor))
		{
			if (GetConVarBool(hRock)) { return Plugin_Continue; }
		}
		if (StrEqual(sClassname, "witch"))
		{
			if (GetConVarBool(hWitch)) { return Plugin_Continue; }
		}
		return Plugin_Handled;
	}
	else
	{
		iLastSI[victim] = 0;
	}
	return Plugin_Continue;
}

int IsSurvivorBusy(int client)
{
	return (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 || 
	GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0);
}
public Action Timed_ResetGlow(Handle timer, any client)
{
	ResetGlow(client);
}

void ResetGlow(int client)
{
	if (IsValidInGame(client))
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255,255,255,255);
	}
}

void SetGodframedGlow(int client)
{
	if (IsValidInGame(client) && IsPlayerAlive(client) && GetClientTeam(client) == 2)
	{
		SetEntityRenderMode( client, RENDER_GLOW );
		SetEntityRenderColor (client, 255,0,0,200 );
	}
}

public void OnMapStart()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		ResetGlow(i);
	}
}

public Action TraceAttackUndoFF(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
	if (!GetConVarInt(g_cvarEnable)) return Plugin_Continue;
	
	if (!IsValidSurvivor(victim)) return Plugin_Continue;
	
	if ((GetConVarInt(g_cvarBlockZeroDmg) & 0x04) && IsValidSurvivor(attacker) && IsFakeClient(attacker) && !IsFakeClient(victim))
	{
		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarInt(g_cvarEnable)) return Plugin_Continue;

	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidSurvivor(victim)) return Plugin_Continue;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int dmg = event.GetInt("dmg_health");
	int currentPerm = event.GetInt("health");
	
	char weaponName[32];
	event.GetString("weapon", weaponName, sizeof(weaponName));
	
	if (dmg > 0 && !L4D_IsPlayerIncapacitated(victim))
	{
		g_currentUndo[victim] = (g_currentUndo[victim] + 1) % UNDO_SIZE;
		
		int victimPerm = g_lastPerm[victim];
		int victimTemp = g_lastTemp[victim];
		int currentTemp = L4D_GetPlayerTempHealth(victim);

		// If this feature is enabled, some portion of damage will be applied to the temp health
		if (GetConVarFloat(g_cvarPermDamageFraction) < 1.0 && victimPerm != currentPerm)
		{
			int totalHealthOld = currentPerm + currentTemp, totalHealthNew = victimPerm + victimTemp;
			if (totalHealthOld == totalHealthNew)
			{
				SetEntityHealth(victim, victimPerm);
				L4D_SetPlayerTempHealth(victim, victimTemp);
			}
		}
	}
	
	if (IsValidSurvivor(attacker))
	{
		if ((GetConVarInt(g_cvarEnable) & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
		{
			UndoDamage(victim);
		}
	}

	return Plugin_Continue;
}

public Action Event_PlayerIncapStart(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	g_currentUndo[victim] = (g_currentUndo[victim] + 1) % UNDO_SIZE;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
 
	if (IsValidSurvivor(attacker))
	{
		if ((GetConVarInt(g_cvarEnable) & FFTYPE_STUPIDBOTS) && (g_stupidGuiltyBots[victim]))
		{
			UndoDamage(victim);
		}
	}
}

public Action Event_FriendlyFire(Event event, const char[] name, bool dontBroadcast)
{
	if (!(GetConVarInt(g_cvarEnable) & FFTYPE_STUPIDBOTS)) return Plugin_Continue;

	int client = GetClientOfUserId(event.GetInt("guilty"));
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

public Action Event_ChargerCarryStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!(GetConVarInt(g_cvarEnable) & FFTYPE_CHARGERCARRY)) return Plugin_Continue;
	
	int client = GetClientOfUserId(event.GetInt("victim"));

	g_chargerCarryNoFF[client] = true;
	return Plugin_Continue;
}

public Action Event_ChargerCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	CreateTimer(1.0, ChargerCarryFFDelay, client);	
	return Plugin_Continue;
}

public Action ChargerCarryFFDelay(Handle timer, any client)
{
	g_chargerCarryNoFF[client] = false;
}

public Action Event_HealBegin(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarInt(g_cvarEnable)) 			return Plugin_Continue;

	int subject = GetClientOfUserId(event.GetInt("subject"));
	int userid = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsSurvivorAlive(subject) || !IsSurvivorAlive(userid)) return Plugin_Continue;
	
	g_targetTempHealth[userid] = subject;

	return Plugin_Continue;
}

public Action Event_HealEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarInt(g_cvarEnable)) 			return Plugin_Continue;

	int userid = GetClientOfUserId(event.GetInt("userid"));
	int subject = g_targetTempHealth[userid];
	int tempHealth;
	
	if (!IsSurvivorAlive(subject))
	{
		PrintToServer("Who did you heal? (%d)", subject);	
		return Plugin_Continue;
	}
	
	tempHealth =  L4D_GetPlayerTempHealth(subject);
	if (tempHealth < 0) tempHealth = 0;
	
	g_targetTempHealth[userid] = tempHealth;
	
	return Plugin_Continue;
}

public Action Event_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarInt(g_cvarEnable)) return Plugin_Continue;	// Not enabled?  Done
	
	int subject = GetClientOfUserId(event.GetInt("subject"));
	int userid = GetClientOfUserId(event.GetInt("userid"));

	if (!IsSurvivorAlive(subject)) return Plugin_Continue;

	int nextUndo = (g_currentUndo[subject] + 1) % UNDO_SIZE;
	g_lastHealth[subject][nextUndo][UNDO_PERM] = - event.GetInt("health_restored");
	g_lastHealth[subject][nextUndo][UNDO_TEMP] = g_targetTempHealth[userid];
	g_currentUndo[subject] = nextUndo;

	return Plugin_Continue;
}

void UndoDamage(int client)
{
	if (IsValidSurvivor(client))
	{
		int thisUndo = g_currentUndo[client];
		int undoPerm = g_lastHealth[client][thisUndo][UNDO_PERM];
		int undoTemp = g_lastHealth[client][thisUndo][UNDO_TEMP];

		int newHealth, newTemp;
		if (L4D_IsPlayerIncapacitated(client))
		{
			newHealth = undoPerm;
			newTemp = undoTemp;
			
			ClientCheatCommand(client, "give", "health");
			L4D_SetPlayerReviveCount(client, g_lastReviveCount[client]);
		}
		else
		{
			newHealth = GetClientHealth(client) + undoPerm;
			newTemp = undoTemp;
			if (undoPerm >= 0)
			{
				newTemp += L4D_GetPlayerTempHealth(client);
			}
			else
			{
				ClientCheatCommand(client, "give", "weapon_first_aid_kit");
			}
		}
		if (newHealth > 100) newHealth = 100;						// prevent going over 100 health
		if (newHealth + newTemp > 100) newTemp = 100 - newHealth;
		SetEntityHealth(client, newHealth);
		L4D_SetPlayerTempHealth(client, newTemp);

		g_lastHealth[client][thisUndo][UNDO_PERM] = 0;
		g_lastHealth[client][thisUndo][UNDO_TEMP] = 0;
		
		if (thisUndo <= 0) thisUndo = UNDO_SIZE;
		thisUndo = thisUndo - 1;
		g_currentUndo[client] = thisUndo;
	}
}

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

public float GetWeaponFFDist(char[] weaponName)
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

int L4D_GetPlayerTempHealth(int client)
{
	if (!IsValidSurvivor(client)) return 0;
	Handle painPillsDecayCvar = INVALID_HANDLE;
	if (painPillsDecayCvar == INVALID_HANDLE)
	{
		painPillsDecayCvar = FindConVar("pain_pills_decay_rate");
		if (painPillsDecayCvar == INVALID_HANDLE)
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
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated", 1));
}

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
	
	if (IsValidInGame(victim) && IsValidInGame(attacker))
	{
		float minFF = GetConVarFloat(hCvarMinFF);
		float maxFF = GetConVarFloat(hCvarMaxFF) <= 0.0 ? 99999.0 : GetConVarFloat(hCvarMaxFF);
		float damage = MAX(minFF, MIN((pelletsShot[victim][attacker] * GetConVarFloat(hCvarModifier)), maxFF));
		int newPelletCount = RoundFloat(damage);
		pelletsShot[victim][attacker] = 0;
		for (int i = 0; i < newPelletCount; i++)
		{
			SDKHooks_TakeDamage(victim, attacker, attacker, 1.0, DMG_PLASMA, weapon, NULL_VECTOR, NULL_VECTOR);
		}
	}
	
	bBuckshot[attacker] = false;
}

bool IsTankRock(int entity)
{
    if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
    {
        char classname[64];
        GetEdictClassname(entity, classname, sizeof(classname));
        return StrEqual(classname, "tank_rock");
    }
    return false;
}