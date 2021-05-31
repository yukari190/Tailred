#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

#define BRIDGE_CAR_DMG 6.0
#define CAR_STANDING_DMG 100.0
#define HANDTRUCK_STANDING_DMG 8.0
#define OVER_HIT_INTERVAL 1.4

#define TICK_TIME 0.200072
#define SPIT_DMG 2.0
#define SPIT_ALTERNATE_DMG -1.0
#define SPIT_MAX_TICKS 28.0
#define SPIT_GODFRAME_TICKS 4

#define CHARGER_DMG_DEFAULT 10.0
#define CHARGER_DMG_STUMBLE_DEFAULT 2.0
#define CHARGER_DMG_POUND_DEFAULT 15.0

#define CHARGER_DMG_PUNCH 6.0
#define CHARGER_DMG_FIRSTPUNCH -1.0
#define CHARGER_DMG_IMPACT 10.0
#define CHARGER_DMG_STUMBLE 2.0
#define CHARGER_DMG_POUND 15.0
#define CHARGER_DMG_CAPPEDVICTIM 6.0
#define CHARGER_DMG_INCAPPED 30.0

#define TONGUE_DRAG_FIRST_DMG_INTERVAL 1.0
#define TONGUE_DRAG_FIRST_DMG 3.0
#define TONGUE_DRAG_DMG_INTERVAL 0.23
#define TONGUE_CHOKE_DAMAGE_AMOUNT 1.0

public Plugin myinfo = 
{
	name = "L4D2 Damage Survivor",
	author = "Visor, Sir, Tabun, Jacob, Jahze, ProdigySim, Don, sheo, Stabby, dcx2",
	description = "",
	version = "1.0",
	url = ""
};

StringMap hPuddles;
ConVar tongue_choke_damage_interval;
ConVar tongue_choke_damage_amount;
ConVar tongue_drag_damage_amount;
bool bAltTick[MAXPLAYERS + 1];
bool bIsBridge;
bool bIgnoreOverkill[MAXPLAYERS + 1];
bool bChargerPunched[MAXPLAYERS + 1];
bool bChargerCharging[MAXPLAYERS + 1];

public void OnPluginStart()
{
	hPuddles = new StringMap();
	
	tongue_choke_damage_interval = FindConVar("tongue_choke_damage_interval");
	tongue_choke_damage_amount = FindConVar("tongue_choke_damage_amount");
	tongue_drag_damage_amount = FindConVar("tongue_drag_damage_amount");
	
	SetConVarFloat(tongue_choke_damage_interval, 0.2);
	SetConVarInt(tongue_choke_damage_amount, 1);
	SetConVarInt(tongue_drag_damage_amount, 1);

	tongue_choke_damage_interval.AddChangeHook(ConVarChange);
	tongue_choke_damage_amount.AddChangeHook(ConVarChange);
	tongue_drag_damage_amount.AddChangeHook(ConVarChange);
	
	HookEvent("tongue_grab", OnTongueGrab);
    HookEvent("player_spawn", PlayerSpawn_Event, EventHookMode_Post);
    HookEvent("charger_charge_start", ChargeStart_Event, EventHookMode_Post);
    HookEvent("charger_charge_end", ChargeEnd_Event, EventHookMode_Post);
}

public void OnPluginEnd()
{
	ResetConVar(tongue_choke_damage_interval);
	ResetConVar(tongue_choke_damage_amount);
	ResetConVar(tongue_drag_damage_amount);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(tongue_choke_damage_interval, 0.2);
	SetConVarInt(tongue_choke_damage_amount, 1); // hack-hack: game tries to change this cvar for some reason, can't be arsed so HARDCODETHATSHIT
	SetConVarInt(tongue_drag_damage_amount, 1);
}

public void OnMapStart()
{
	char buffer[64];
	GetCurrentMap(buffer, sizeof(buffer));
	if (StrContains(buffer, "c5m5", false) != -1)
	{
		bIsBridge = true;
	}
	else
	{
		bIsBridge = false;
	}
}

public void L4D2_OnRealRoundStart()
{
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
		bAltTick[i] = false;
        bChargerPunched[i] = false;
        bChargerCharging[i] = false;
    }
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "insect_swarm"))
    {
        char trieKey[8];
        IndexToKey(entity, trieKey, sizeof(trieKey));

        int[] count = new int[MaxClients + 1];
        hPuddles.SetArray(trieKey, count, MaxClients + 1);
    }
}

public void OnEntityDestroyed(int entity)
{
    char trieKey[8];
    IndexToKey(entity, trieKey, sizeof(trieKey));

    int[] count = new int[MaxClients + 1];
    if (hPuddles.GetArray(trieKey, count, MaxClients + 1))
    {
        hPuddles.Remove(trieKey);
    }
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!L4D2_IsValidClient(victim) || !IsValidEdict(inflictor)) return Plugin_Continue;
	
	char classname[64];
	GetEdictClassname(inflictor, classname, sizeof(classname));
	
	if (StrEqual(classname, "prop_physics", false) || StrEqual(classname, "prop_car_alarm", false))
	{
		if (bIgnoreOverkill[victim] || (victim == attacker)) return Plugin_Handled;
		
		char sModelName[128];
		GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModelName, 128);
		
		if (L4D2_IsPlayerIncap(victim)) return Plugin_Continue;
		if (StrContains(sModelName, "cara_", false) != -1 || StrContains(sModelName, "taxi_", false) != -1 || StrContains(sModelName, "police_car", false) != -1)
		{
			if (bIsBridge)
			{
				damage = 4.0 * BRIDGE_CAR_DMG;
				inflictor = 0;	//because valve is silly and damage on incapped players would be ignored otherwise
			}
			else damage = CAR_STANDING_DMG;
		}
		else if (StrContains(sModelName, "dumpster", false) != -1) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props/cs_assault/forklift.mdl", false)) damage = CAR_STANDING_DMG;			
		else if (StrEqual(sModelName, "models/props_vehicles/airport_baggage_cart2.mdl", false)) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props_unique/haybails_single.mdl", false)) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props_foliage/Swamp_FallenTree01_bare.mdl", false)) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props_foliage/tree_trunk_fallen.mdl", false)) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props_fairgrounds/bumpercar.mdl", false)) damage = CAR_STANDING_DMG;
		else if (StrEqual(sModelName, "models/props/cs_assault/handtruck.mdl", false)) damage = HANDTRUCK_STANDING_DMG;
		
		bIgnoreOverkill[victim] = true;	//standardise them bitchin over-hits
		CreateTimer(OVER_HIT_INTERVAL, Timed_ClearInvulnerability, victim);
		return Plugin_Changed;
	}
	
	if (GetEntProp(victim, Prop_Send, "m_pounceAttacker") > 0 || GetEntProp(victim, Prop_Send, "m_jockeyAttacker") > 0)
	{
		if (damage > 30.0 && (damageType & DMG_FALL))
		{
			damage = 30.0;
			return Plugin_Changed;
		}
	}
	
	if (StrEqual(classname, "insect_swarm"))
	{
		char trieKey[8];
		IndexToKey(inflictor, trieKey, sizeof(trieKey));
		int[] count = new int[MaxClients + 1];
		if (hPuddles.GetArray(trieKey, count, MaxClients + 1))
		{
			count[victim]++;
			if (GetPuddleLifetime(inflictor) >= SPIT_GODFRAME_TICKS * TICK_TIME && count[victim] < SPIT_GODFRAME_TICKS)
				count[victim] = SPIT_GODFRAME_TICKS + 1;
			hPuddles.SetArray(trieKey, count, MaxClients + 1);
			if (SPIT_ALTERNATE_DMG > -1.0 && bAltTick[victim])
			{
				bAltTick[victim] = false;
				damage = SPIT_ALTERNATE_DMG;
			}
			else
			{
				damage = SPIT_DMG;
				bAltTick[victim] = true;
			}
			if (SPIT_GODFRAME_TICKS >= count[victim] || count[victim] > SPIT_MAX_TICKS) damage = 0.0;
			if (count[victim] > SPIT_MAX_TICKS) AcceptEntityInput(inflictor, "Kill");
			return Plugin_Changed;
		}
	}
	
	if (L4D2_IsValidClient(attacker) && L4D2_IsInfected(attacker))
	{
		L4D2_Infected iClass = L4D2_GetInfectedClass(attacker);
		if (iClass == L4D2Infected_Tank)
		{
			if (L4D2_IsPlayerIncap(victim)) damage = 36.0;
			else if (StrEqual(classname, "tank_rock", false)) damage = 24.0;
			return Plugin_Changed;
		}
		
		if (iClass == L4D2Infected_Charger)
		{
			if (attacker == inflictor)
			{
				GetClientWeapon(inflictor, classname, sizeof(classname));
			}
			if (!StrEqual(classname, "weapon_charger_claw", false)) return Plugin_Continue;
			
			if (damage == CHARGER_DMG_DEFAULT)
			{
				if (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0)
				{
					damage = CHARGER_DMG_IMPACT;
					return Plugin_Changed;
				}
				else
				{
					float dmgFirst = CHARGER_DMG_FIRSTPUNCH;
					if (!bChargerPunched[attacker] && dmgFirst > -1.0)
					{
						bChargerPunched[attacker] = true;
						damage = dmgFirst;
						return Plugin_Changed;
					}
					damage = L4D2_IsBeingAttacked(victim) ? CHARGER_DMG_CAPPEDVICTIM : CHARGER_DMG_PUNCH;
					return Plugin_Changed;
				}
			}
			else if (damage == CHARGER_DMG_STUMBLE_DEFAULT)
			{
				damage = CHARGER_DMG_STUMBLE;
				return Plugin_Changed;
			}
			else if (damage == CHARGER_DMG_POUND_DEFAULT && (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0))
			{
				damage = L4D2_IsPlayerIncap(victim) ? CHARGER_DMG_INCAPPED : CHARGER_DMG_POUND;
				return Plugin_Changed;
			}
			L4D2_CPrintToChatAll("{W}-{B}Charger Damage{W}- {O}warning, charger doing a type of damage it shouldn't! infl.: [%s] type [%d] damage [%.0f] force [%.0f %.0f %.0f]", classname, damageType, damage, damageForce[0], damageForce[1], damageForce[2]);
		}
	}
	return Plugin_Continue;
}

public Action Timed_ClearInvulnerability(Handle thisTimer, any victim)
{
	bIgnoreOverkill[victim] = false;
}

/* --------------------------------------
 *                Event(s)
 * -------------------------------------- */

public Action OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!L4D2_IsValidClient(client) || !L4D2_IsSurvivor(client)) return;
	
	if (L4D2_IsCoop())
	{
		CreateTimer(TONGUE_DRAG_FIRST_DMG_INTERVAL, FirstDamage, client);
	}
	else if (L4D2_IsVersus())
	{
		UpdateDragDamageInterval(client, TONGUE_DRAG_FIRST_DMG_INTERVAL);
		CreateTimer(TONGUE_DRAG_FIRST_DMG_INTERVAL, FirstDamage, client);
	}
}

public Action FirstDamage(Handle timer, any client)
{
	if (!L4D2_IsValidClient(client) || !L4D2_IsBeingDragged(client))
	{
		return Plugin_Stop;
	}
	
	if (L4D2_IsCoop())
	{
		SDKHooks_TakeDamage(client, client, client, TONGUE_DRAG_FIRST_DMG, DMG_GENERIC);
		CreateTimer(TONGUE_DRAG_DMG_INTERVAL + 0.1, FixDragInterval, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (L4D2_IsVersus())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsTongue(client, i))
			{
				SDKHooks_TakeDamage(client, i, i, TONGUE_DRAG_FIRST_DMG - TONGUE_CHOKE_DAMAGE_AMOUNT, DMG_GENERIC);
				UpdateDragDamageInterval(client, TONGUE_DRAG_DMG_INTERVAL);
				//PrintToChatAll("victim:%N  inflictor:%N  attacker:%N", client, i, i);
				return Plugin_Continue;
			}
			
		}
	}
	return Plugin_Continue;
}

public Action FixDragInterval(Handle timer, any client)
{
	if (!L4D2_IsValidClient(client) || !L4D2_IsBeingDragged(client))
	{
		return Plugin_Stop;
	}
	SDKHooks_TakeDamage(client, client, client, TONGUE_CHOKE_DAMAGE_AMOUNT, DMG_GENERIC);
	return Plugin_Continue;
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client) || L4D2_GetInfectedClass(client) != L4D2Infected_Charger)
		return Plugin_Continue;
    bChargerPunched[client] = false;
    bChargerCharging[client] = false;
    return Plugin_Continue;
}

public Action ChargeStart_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (L4D2_IsValidClient(client)) bChargerCharging[client] = true;    
}
public Action ChargeEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (L4D2_IsValidClient(client)) bChargerCharging[client] = false;   
}

//Utility
float GetPuddleLifetime(int puddle)
{
	return ITimer_GetElapsedTime(view_as<IntervalTimer>(GetEntityAddress(puddle) + view_as<Address>(2968)));
}

void IndexToKey(int index, char[] str, int maxlength)
{
	Format(str, maxlength, "%x", index);
}

void UpdateDragDamageInterval(int client, float key)
{
	SetEntDataFloat(client, 13372, GetGameTime() + key);
}

bool IsTongue(int victim, int smoker)
{
	if (!IsClientInGame(smoker)) return false;
	int target = L4D2_GetInfectedVictim(smoker);
	return (victim == target);
}
