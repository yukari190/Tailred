#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

/*
* Version 0.6.6
* - Better looking Output.
* - Added Tank Name display when Tank dies, normally it only showed the Tank's name if the Tank survived
* 
* Version 0.6.6b
* - Fixed Printing Two Tanks when last map Tank survived.
* Added by; Sir
*/    

public Plugin myinfo =
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade",
	description = "Announce damage dealt to tanks by survivors",
	version = "0.6.6",
};

float g_fMaxTankHealth;

int 
	g_iWasTank[MAXPLAYERS + 1],
	g_iWasTankAI,
	g_iLastTankHealth,
	g_iSurvivorLimit,
	g_iDamage[MAXPLAYERS + 1];

ConVar 
	g_hCvarEnabled,
	g_hCvarTankHealth,
	g_hCvarSurvivorLimit;

bool 
	g_bEnabled,
	g_bAnnounceTankDamage,
	bPrintedHealth;

public void OnPluginStart()
{
	g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled", "1", "Announce damage done to tanks when enabled", FCVAR_NONE|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_hCvarTankHealth = FindConVar("z_tank_health");
	
	g_hCvarEnabled.AddChangeHook(ConVarChange);
	g_hCvarSurvivorLimit.AddChangeHook(ConVarChange);
	g_hCvarTankHealth.AddChangeHook(ConVarChange);
	FindConVar("mp_gamemode").AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_bEnabled = g_hCvarEnabled.BoolValue;
	g_iSurvivorLimit = g_hCvarSurvivorLimit.IntValue;
	
	if (L4D2_IsVersus()) g_fMaxTankHealth = g_hCvarTankHealth.FloatValue * 1.5;
	else g_fMaxTankHealth = g_hCvarTankHealth.FloatValue;
	if (g_fMaxTankHealth <= 0.0) g_fMaxTankHealth = 1.0; // No dividing by 0!
}

public void L4D2_OnRealRoundStart()
{
	bPrintedHealth = false;
	ClearTankDamage();
}

public void L4D2_OnRealRoundEnd()
{
	if (g_bAnnounceTankDamage)
	{
		PrintRemainingHealth();
		PrintTankDamage();
	}
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
	if (victim != FindAnyTank() || IsIncapacitated(victim)) return;
	if (!IsValidSurvivor(attacker)) return;
	
	g_iDamage[attacker] += damage;
	g_iLastTankHealth = health;
}

public void L4D2_OnTankDeath(int tankClient, int attacker)
{
	if (IsValidAndInGame(attacker)) g_iDamage[attacker] += g_iLastTankHealth;
	
	if (IsValidAndInGame(tankClient) && !IsFakeClient(tankClient)) g_iWasTank[tankClient] = 1;
	else g_iWasTankAI = 1;
	
	if (g_bAnnounceTankDamage) PrintTankDamage();
	ClearTankDamage();
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	g_bAnnounceTankDamage = true;
	g_iLastTankHealth = GetClientHealth(tankClient);
}

void PrintRemainingHealth()
{
	bPrintedHealth = true;
	if (!g_bEnabled) return;
	int tankclient = FindAnyTank();
	if (!tankclient) return;
	
	char name[MAX_NAME_LENGTH];
	if (IsFakeClient(tankclient)) name = "AI";
	else GetClientName(tankclient, name, sizeof(name));
	CPrintToChatAll("{W}[{O}!{W}] {B}Tank {W}({G}%s{W}) 还有 {O}%d {W}剩余HP", name, g_iLastTankHealth);
}

void PrintTankDamage()
{
	if (!g_bEnabled) return;
	
	if (!bPrintedHealth)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iWasTank[i] > 0)
			{
				char name[MAX_NAME_LENGTH];
				GetClientName(i, name, sizeof(name));
				CPrintToChatAll("{W}[{O}!{W}] {W}对 {B}Tank {W}({G}%s{W}) 造成的{B}伤害", name);
				g_iWasTank[i] = 0;
			}
			else if(g_iWasTankAI > 0) 
				CPrintToChatAll("{W}[{O}!{W}] {W}对 {B}Tank {W}({G}AI{W}) 造成的{B}伤害");
			g_iWasTankAI = 0;
		}
	}
	
	int client;
	int percent_total; // Accumulated total of calculated percents, for fudging out numbers at the end
	int damage_total; // Accumulated total damage dealt by survivors, to see if we need to fudge upwards to 100%
	int survivor_index = -1;
	int[] survivor_clients = new int[g_iSurvivorLimit]; // Array to store survivor client indexes in, for the display iteration
	int percent_damage, damage;
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		client = L4D2_GetSurvivorOfIndex(i);
		if (client == 0) continue;
		if (g_iDamage[client] == 0) continue;
		survivor_index++;
		survivor_clients[survivor_index] = client;
		damage = g_iDamage[client];
		damage_total += damage;
		percent_damage = GetDamageAsPercent(damage);
		percent_total += percent_damage;
	}
	SortCustom1D(survivor_clients, g_iSurvivorLimit, SortByDamageDesc);
	
	int percent_adjustment;
	// Percents add up to less than 100% AND > 99.5% damage was dealt to tank
	if ((percent_total < 100 && float(damage_total) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0))))
	{
		percent_adjustment = 100 - percent_total;
	}
	
	int last_percent = 100; // Used to store the last percent in iteration to make sure an adjusted percent doesn't exceed the previous percent
	int adjusted_percent_damage;
	for (int k; k <= survivor_index; k++)
	{
		client = survivor_clients[k];
		damage = g_iDamage[client];
		percent_damage = GetDamageAsPercent(damage);
		// Attempt to adjust the top damager's percent, defer adjustment to next player if it's an exact percent
		// e.g. 3000 damage on 6k health tank shouldn't be adjusted
		if (percent_adjustment != 0 && // Is there percent to adjust
		damage > 0 &&  // Is damage dealt > 0%
		!IsExactPercent(damage) // Percent representation is not exact, e.g. 3000 damage on 6k tank = 50%
		)
		{
			adjusted_percent_damage = percent_damage + percent_adjustment;
			if (adjusted_percent_damage <= last_percent) // Make sure adjusted percent is not higher than previous percent, order must be maintained
			{
				percent_damage = adjusted_percent_damage;
				percent_adjustment = 0;
			}
		}
		last_percent = percent_damage;
		for (int i = 1; i <= MaxClients; i++)
		{
    		if (IsClientInGame(i))
    		{
				CPrintToChat(i, "{B}[{W}%d{B}] ({W}%i%%{B}) {G}%N", damage, percent_damage, client);
			}
		}
	}
}

void ClearTankDamage()
{
	g_iLastTankHealth = 0;
	g_iWasTankAI = 0;
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		g_iDamage[i] = 0; 
		g_iWasTank[i] = 0;
	}
	g_bAnnounceTankDamage = false;
}

int GetDamageAsPercent(int damage)
{
	return RoundToNearest((damage / g_fMaxTankHealth) * 100.0);
}

//comparing the type of int with the float, how different is it
bool IsExactPercent(int damage)
{
	float fDamageAsPercent = (damage / g_fMaxTankHealth) * 100.0;
	float fDifference = float(GetDamageAsPercent(damage)) - fDamageAsPercent;
	return (FloatAbs(fDifference) < 0.001) ? true : false;
}

public int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	// By damage, then by client index, descending
	if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
	else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}
