#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2util>

public Plugin myinfo = 
{
	name = "Tank Management",
	author = "",
	description = "",
	version = "1.0",
	url = ""
};

/*public void OnPluginStart()
{
	HookEvent("player_incapacitated", PlayerIncap);
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
	if (!IsValidSurvivor(victim) || !L4D2Util_IsValidClient(attacker) || !IsTank(attacker) || IsFakeClient(attacker)) return;
	if (damage < 5) return;
	SetTankFrustration(attacker, 100);
}

public Action PlayerIncap(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSurvivor(victim) || !L4D2Util_IsValidClient(attacker) || !IsTank(attacker) || IsFakeClient(attacker)) return;
	SetTankFrustration(attacker, 100);
}*/

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!L4D2Util_IsValidClient(client) || !IsTank(client)) return Plugin_Continue;
	
	if (IsFakeClient(client))
	{
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == 54 || sequence == 55 || sequence == 57) SetEntProp(client, Prop_Send, "m_nSequence", 0);
		if (sequence == 56) buttons |= IN_ATTACK;
		if ((buttons & IN_ATTACK2)) buttons |= IN_ATTACK;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}
