#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

public Plugin myinfo = 
{
	name = "L4D2 Damage Infected",
	author = "Visor, Sir, Tabun, Jacob, Jahze, ProdigySim, Don, sheo, Stabby, dcx2",
	description = "",
	version = "1.0",
	url = ""
};

public Action L4D2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidInfected(victim))
	  return Plugin_Continue;
	
	if (IsValidInfected(attacker) && GetInfectedClass(attacker) != L4D2Infected_Tank)
	  return Plugin_Handled;
	
	L4D2_Infected class = GetInfectedClass(victim);
	
	if (IsValidSurvivor(attacker))
	{
		if (class != L4D2Infected_Boomer && class != L4D2Infected_Spitter && damage == 250.0 && (damageType & DMG_CLUB) && weapon == -1)
		  return Plugin_Handled;
	}
	return Plugin_Continue;
}
