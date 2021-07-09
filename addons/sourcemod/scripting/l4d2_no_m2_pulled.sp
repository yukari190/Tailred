#pragma semicolon 1

#include <sourcemod>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

public Plugin:myinfo = 
{
	name = "L4D2 No M2 Reg on Hunters and Pulled Survivors",
	author = "Visor, Sir",
	description = "Self-descriptive",
	version = "3.4",
	url = "https://github.com/Attano/Equilibrium"
};

public Action:L4D_OnShovedBySurvivor(shover, shovee, const Float:vector[3])
{
	if (!IsSurvivor(shover) || !IsHunter(shovee) || IsSurvivor(shovee))
		return Plugin_Continue;
	if (!IsTankOrCharger(shovee) && !(IsHunter(shovee) && L4D2_GetInfectedVictim(shovee) == -1))
	  return Plugin_Continue;
	return Plugin_Handled;
}

public Action:L4D2_OnEntityShoved(shover, shovee_ent, weapon, Float:vector[3], bool:bIsHunterDeadstop)
{
	if (!IsSurvivor(shover) || IsSurvivor(shovee_ent)) return Plugin_Continue;
	if (IsHunter(shovee_ent)) return Plugin_Handled;
	if (IsTankOrCharger(shovee_ent) || (IsHunter(shovee_ent) && L4D2_GetInfectedVictim(shovee_ent) == -1))
	  return Plugin_Handled;
	return Plugin_Continue;
}

stock bool:IsSurvivor(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 2;
}

stock bool:IsInfected(client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

stock bool:IsHunter(client)  
{
	if (!IsInfected(client))
		return false;
		
	if (!IsPlayerAlive(client))
		return false;

	if (GetEntProp(client, Prop_Send, "m_zombieClass") != 3)
		return false;

	return true;
}

bool IsTankOrCharger(int client)  
{
	L4D2_Infected class = L4D2_GetInfectedClass(client);
	return (class == L4D2Infected_Charger || class == L4D2Infected_Tank);
}
