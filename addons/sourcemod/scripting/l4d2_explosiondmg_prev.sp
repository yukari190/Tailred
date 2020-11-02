#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <l4d2lib>

public Plugin myinfo =
{
	name = "L4D2 Explosion Damage Prevention",
	author = "Sir",
	version = "1.0",
	description = "不再受到攻击者的爆炸伤害 (world)",
	url = ""
};

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidClient(client)) return;
	if (nowteam == 3 && oldteam != 3)
	  SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	else if (nowteam != 3 && oldteam == 3)
	  SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	// Is the Victim an infected molested by Explosive damage caused by a non-client?
	if (!IsInfected(victim) || IsValidClient(attacker) || !(damagetype & DMG_BLAST)) return Plugin_Continue;
	return Plugin_Handled;
}

bool IsInfected(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3;
}

bool IsValidClient(int client)
{
	if (client <= 0 || client > MaxClients) return false;
	return (IsClientInGame(client));
}
