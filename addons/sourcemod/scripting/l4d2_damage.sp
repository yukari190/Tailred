#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

#define BRIDGE_CAR_DMG 6.0
#define CAR_STANDING_DMG 100.0
#define HANDTRUCK_STANDING_DMG 8.0
#define OVER_HIT_INTERVAL 1.4

#define MELEE_NERF_PERCENTAGE 50.0

#define TONGUE_DRAG_FIRST_DMG_INTERVAL 1.0
#define TONGUE_DRAG_FIRST_DMG 3.0
#define TONGUE_DRAG_DMG_INTERVAL 0.23
#define TONGUE_CHOKE_DAMAGE_AMOUNT 1.0

enum TankOrSIWeapon
{
    TANKWEAPON,
    CHARGERWEAPON
}

Handle hPuddles, hInflictorTrie;
ConVar hCvarPounceInterrupt, tongue_choke_damage_interval, tongue_choke_damage_amount, tongue_drag_damage_amount;
bool bAltTick[MAXPLAYERS + 1], bIsBridge, bIgnoreOverkill[MAXPLAYERS + 1], inWait[MAXPLAYERS + 1];
int iHunterSkeetDamage[MAXPLAYERS+1], iPounceInterrupt = 150, iGameMode;

public Plugin myinfo = 
{
	name = "L4D2 Merge Damage",
	author = "Visor, Sir, Tabun, Jacob, Jahze, ProdigySim, Don, sheo, Stabby, dcx2, 趴趴酱",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	hPuddles = CreateTrie();
    hInflictorTrie = CreateTrie();
    SetTrieValue(hInflictorTrie, "weapon_tank_claw",      TANKWEAPON);
    SetTrieValue(hInflictorTrie, "tank_rock",             TANKWEAPON);
    SetTrieValue(hInflictorTrie, "weapon_charger_claw",   CHARGERWEAPON);
	
	tongue_choke_damage_interval = FindConVar("tongue_choke_damage_interval");
	tongue_choke_damage_amount = FindConVar("tongue_choke_damage_amount");
	tongue_drag_damage_amount = FindConVar("tongue_drag_damage_amount");
    hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
	
	SetConVarFloat(tongue_choke_damage_interval, 0.2);
	SetConVarInt(tongue_choke_damage_amount, 1);
	SetConVarInt(tongue_drag_damage_amount, 1);
	iPounceInterrupt = GetConVarInt(hCvarPounceInterrupt);

	hCvarPounceInterrupt.AddChangeHook(ConVarChange);
	tongue_choke_damage_interval.AddChangeHook(ConVarChange);
	tongue_choke_damage_amount.AddChangeHook(ConVarChange);
	tongue_drag_damage_amount.AddChangeHook(ConVarChange);
	
	HookEvent("ability_use", Event_AbilityUse);
	HookEvent("tongue_grab", OnTongueGrab);
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
	iPounceInterrupt = hCvarPounceInterrupt.IntValue;
}

public void OnMapStart()
{
	iGameMode = Gamemode();
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

public void OnEntityCreated(int entity, const char[] classname)
{
    if (StrEqual(classname, "insect_swarm"))
    {
        char trieKey[8];
        IndexToKey(entity, trieKey, sizeof(trieKey));

        int[] count = new int[MaxClients + 1];
        SetTrieArray(hPuddles, trieKey, count, MaxClients + 1);
    }
}

public void OnEntityDestroyed(int entity)
{
    char trieKey[8];
    IndexToKey(entity, trieKey, sizeof(trieKey));

    int[] count = new int[MaxClients + 1];
    if (GetTrieArray(hPuddles, trieKey, count, MaxClients + 1))
    {
        RemoveFromTrie(hPuddles, trieKey);
    }
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		iHunterSkeetDamage[i] = 0;
	}
}

public void L4D2_OnPlayerHurtPost(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype)
{
	if (!IsValidInfected(victim)) return;
	
	if (strcmp(Weapon, "inferno") == 0 || !IsValidInGame(attacker) || strcmp(Weapon, "entityflame") == 0)
	{
		if(GetInfectedClass(victim) == ZC_TANK)
		{
			ExtinguishEntity(victim);
		}
		else
		{
			CreateTimer(1.0, Extinguish, victim);
		}
	}
}

public Action Extinguish(Handle timer, any client)
{
    if(IsValidInGame(client) && !inWait[client])
    {
        ExtinguishEntity(client);
        inWait[client] = true;
        CreateTimer(1.2, ExtinguishWait, client);
    }
}

public Action ExtinguishWait(Handle timer, any client)
{
	if (IsValidInGame(client))
		inWait[client] = false;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client)) return;
	
	if (nowteam > 1 && oldteam <= 1)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	else if (nowteam <= 1 && oldteam > 1)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidEdict(victim) || !IsValidInGame(victim) || !IsValidEdict(inflictor)) return Plugin_Continue;
	
	char classname[64];
	if (IsValidInGame(attacker) && attacker == inflictor) GetClientWeapon(inflictor, classname, sizeof(classname));
	else GetEdictClassname(inflictor, classname, sizeof(classname));
	
	if (StrEqual(classname, "prop_physics", false) || StrEqual(classname, "prop_car_alarm", false))
	{
		if (bIgnoreOverkill[victim] || (victim == attacker)) return Plugin_Handled;
		if (GetClientTeam(victim) == 2)
		{
			char sModelName[128];
			GetEntPropString(inflictor, Prop_Data, "m_ModelName", sModelName, 128);
			
			if (IsPlayerIncap(victim)) return Plugin_Continue;
			else
			{
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
			}
			bIgnoreOverkill[victim] = true;	//standardise them bitchin over-hits
			CreateTimer(OVER_HIT_INTERVAL, Timed_ClearInvulnerability, victim);
			return Plugin_Changed;
		}
	}
	
	if (GetClientTeam(victim) == 3)
	{
		int class = GetInfectedClass(victim);
		
		if (IsValidInfected(attacker) && GetInfectedClass(attacker) != ZC_TANK) return Plugin_Handled;
		if (IsValidSurvivor(attacker))
		{
			if (class != ZC_BOOMER && class != ZC_SPITTER && damage == 250.0 && (damageType & DMG_CLUB) && weapon == -1) return Plugin_Handled;
			
			if (class == ZC_TANK && IsMelee(weapon))
			{
				damage = damage / 100.0 * (100.0 - MELEE_NERF_PERCENTAGE);
				return Plugin_Changed;
			}
			
			if (damage > 0)
			{
				float health = float(GetClientHealth(victim));
				
				if (IsFakeClient(victim))
				{
					if (class == ZC_HUNTER && GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
					{
						iHunterSkeetDamage[victim] += RoundToFloor(damage);
						if (iHunterSkeetDamage[victim] >= iPounceInterrupt || IsMelee(weapon))
						{
							iHunterSkeetDamage[victim] = 0;
							damage = health;
							return Plugin_Changed;
						}
					}
					else if (class == ZC_CHARGER)
					{
						if (IsCharging(victim))
						{
							if (IsMelee(weapon))
							{
								if (health < 325.0) damage = health;
								else damage = 325.0;
							}
							damage = (damage - FloatFraction(damage) + 1.0) * 3.0;
							return Plugin_Changed;
						}
					}
				}
			
				if (IsMelee(weapon))
				{
					if (class <= 5)
					{
						damage = health;
						return Plugin_Changed;
					}
					else if (class == ZC_CHARGER)
					{
						if (health < 325.0) damage = health;
						else damage = 325.0;
						return Plugin_Changed;
					}
				}
			}
		}

	}
	else if (GetClientTeam(victim) == 2)
	{
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
			if (GetTrieArray(hPuddles, trieKey, count, MaxClients + 1))
			{
				count[victim]++;
				if (GetPuddleLifetime(inflictor) >= 4 * 0.200072 && count[victim] < 4) count[victim] = 4 + 1;
				SetTrieArray(hPuddles, trieKey, count, MaxClients + 1);
				if (bAltTick[victim])
				{
					bAltTick[victim] = false;
					damage = 3.0;
				}
				else
				{
					damage = 2.0;
					bAltTick[victim] = true;
				}
				if (4 >= count[victim] || count[victim] > 28) damage = 0.0;
				if (count[victim] > 28) AcceptEntityInput(inflictor, "Kill");
				return Plugin_Changed;
			}
		}
		
		if (IsValidInfected(attacker))
		{
			if (GetInfectedClass(attacker) == ZC_TANK)
			{
				if (IsPlayerIncap(victim)) damage = 36.0;
				else if (StrEqual(classname, "tank_rock", false)) damage = 24.0;
				return Plugin_Changed;
			}
			
			if (GetInfectedClass(attacker) == ZC_CHARGER)
			{
				TankOrSIWeapon inflictorID;
				if (!GetTrieValue(hInflictorTrie, classname, inflictorID)) return Plugin_Continue;
				if (inflictorID != CHARGERWEAPON) return Plugin_Continue;
				
				if (damage == 10.0)
				{
					if (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0)
					{
						damage = 10.0;
						return Plugin_Changed;
					}
					else
					{
						damage = 6.0;
						return Plugin_Changed;
					}
				}
				else if (damage == 15.0 && (damageForce[0] == 0.0 && damageForce[1] == 0.0 && damageForce[2] == 0.0))
				{
					damage = IsPlayerIncap(victim) ? 30.0 : 15.0;
					return Plugin_Changed;
				}
				damage = 6.0;
				return Plugin_Handled;
			}
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

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    char abilityName[64];
    
    if (!IsValidInfected(client)) { return; }
    
    GetEventString(event, "ability", abilityName, sizeof(abilityName));
    
    if (strcmp(abilityName, "ability_lunge", false) == 0)
    {
        iHunterSkeetDamage[client] = 0;
    }
}

public Action OnTongueGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (!IsValidSurvivor(client)) return;
	
	if (iGameMode == GAMEMODE_COOP)
	{
		CreateTimer(TONGUE_DRAG_FIRST_DMG_INTERVAL, FirstDamage, client);
	}
	else if (iGameMode == GAMEMODE_VERSUS)
	{
		UpdateDragDamageInterval(client, TONGUE_DRAG_FIRST_DMG_INTERVAL);
		CreateTimer(TONGUE_DRAG_FIRST_DMG_INTERVAL, FirstDamage, client);
	}
}

public Action FirstDamage(Handle timer, any client)
{
	if (!IsValidSurvivor(client) || !IsSurvivorBeingDragged(client))
	{
		return Plugin_Stop;
	}
	
	if (iGameMode == GAMEMODE_COOP)
	{
		SDKHooks_TakeDamage(client, 0, 0, TONGUE_DRAG_FIRST_DMG, DMG_GENERIC);
		CreateTimer(TONGUE_DRAG_DMG_INTERVAL + 0.1, FixDragInterval, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if (iGameMode == GAMEMODE_VERSUS)
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
	if (!IsValidSurvivor(client) || !IsSurvivorBeingDragged(client))
	{
		return Plugin_Stop;
	}
	SDKHooks_TakeDamage(client, 0, 0, TONGUE_CHOKE_DAMAGE_AMOUNT, DMG_GENERIC);
	return Plugin_Continue;
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

bool IsCharging(int client)
{
	int abilityEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return (IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0);
}

void UpdateDragDamageInterval(int client, float key)
{
	SetEntDataFloat(client, 13372, GetGameTime() + key);
}

bool IsSurvivorBeingDragged(int client)
{
	return (GetEntProp(client, Prop_Send, "m_tongueOwner") > 0 && !IsSurvivorBeingChoked(client));
}

bool IsSurvivorBeingChoked(int client)
{
	return (GetEntProp(client, Prop_Send, "m_isHangingFromTongue") > 0);
}

bool IsTongue(int victim, int smoker)
{
	if (!IsClientConnected(smoker) || !IsClientInGame(smoker)) return false;
	int target = GetEntPropEnt(smoker, Prop_Send, "m_tongueVictim");
	return (IsValidSurvivor(target) && IsPlayerAlive(target) && victim == target);
}
