#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>

#define MELEE_NERF_PERCENTAGE 20.0


public Plugin myinfo = 
{
	name = "L4D2 Damage Infected",
	author = "Visor, Sir, Tabun, Jacob, Jahze, ProdigySim, Don, sheo, Stabby, dcx2",
	description = "",
	version = "1.0",
	url = ""
};

ConVar hCvarPounceInterrupt;
int iHunterSkeetDamage[MAXPLAYERS+1];
int iPounceInterrupt = 150;
bool inWait[MAXPLAYERS + 1];

public void OnPluginStart()
{
	hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
	iPounceInterrupt = GetConVarInt(hCvarPounceInterrupt);
	hCvarPounceInterrupt.AddChangeHook(ConVarChange);
	
	HookEvent("ability_use", Event_AbilityUse);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iPounceInterrupt = hCvarPounceInterrupt.IntValue;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    char abilityName[64];
    
    if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client)) { return; }
    
    event.GetString("ability", abilityName, sizeof(abilityName));
    
    if (strcmp(abilityName, "ability_lunge", false) == 0)
    {
        iHunterSkeetDamage[client] = 0;
    }
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		iHunterSkeetDamage[i] = 0;
		inWait[i] = false;
	}
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
	if (!L4D2_IsInfected(victim)) return;
	
	if (strcmp(weapon, "inferno") == 0 || !L4D2_IsValidClient(attacker) || strcmp(weapon, "entityflame") == 0)
	{
		if (L4D2_GetInfectedClass(victim) == L4D2Infected_Tank)
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
    if (L4D2_IsValidClient(client) && !inWait[client])
    {
        ExtinguishEntity(client);
        inWait[client] = true;
        CreateTimer(1.2, ExtinguishWait, client);
    }
}

public Action ExtinguishWait(Handle timer, any client)
{
	inWait[client] = false;
}

public Action L4D2_OnJoinInfected(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwayInfected(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!L4D2_IsValidClient(victim))
	  return Plugin_Continue;
	
	if (!L4D2_IsValidClient(attacker) && (damageType & DMG_BLAST))
	  return Plugin_Handled;
	
	if (!L4D2_IsValidClient(attacker))
	  return Plugin_Continue;
	
	L4D2_Infected class = L4D2_GetInfectedClass(victim);
	if (L4D2_IsInfected(attacker) && L4D2_GetInfectedClass(attacker) != L4D2Infected_Tank)
	  return Plugin_Handled;
	if (L4D2_IsSurvivor(attacker))
	{
		if (class != L4D2Infected_Boomer && class != L4D2Infected_Spitter && damage == 250.0 && (damageType & DMG_CLUB) && weapon == -1)
		  return Plugin_Handled;
		
		if (class == L4D2Infected_Tank && IsMelee(weapon))
		{
			damage = damage / 100.0 * (100.0 - MELEE_NERF_PERCENTAGE);
			return Plugin_Changed;
		}
		
		if (damage > 0)
		{
			float health = float(GetClientHealth(victim));
			
			if (class == L4D2Infected_Hunter && IsFakeClient(victim) && GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
			{
				iHunterSkeetDamage[victim] += RoundToFloor(damage);
				if (iHunterSkeetDamage[victim] >= iPounceInterrupt || IsMelee(weapon))
				{
					iHunterSkeetDamage[victim] = 0;
					damage = health;
					return Plugin_Changed;
				}
			}
			
			if (class == L4D2Infected_Charger)
			{
				if (IsMelee(weapon))
				{
					if (health < 325.0) damage = health;
					else damage = 325.0;
				}
				if (IsCharging(victim) && IsFakeClient(victim))
				{
					damage = (damage - FloatFraction(damage) + 1.0) * 3.0;
				}
				return Plugin_Changed;
			}
			
			if (IsMelee(weapon))
			{
				if (class <= L4D2Infected_Jockey)
				{
					damage = health;
					return Plugin_Changed;
				}
			}
		}
	}
	return Plugin_Continue;
}

bool IsMelee(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char strClassName[64];
		GetEdictClassname(entity, strClassName, sizeof(strClassName));
		return StrContains(strClassName, "melee", false) != -1;
	}
	return false;
}

bool IsCharging(int client)
{
	int abilityEnt = GetEntPropEnt(client, Prop_Send, "m_customAbility");
	return (IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging") > 0);
}
