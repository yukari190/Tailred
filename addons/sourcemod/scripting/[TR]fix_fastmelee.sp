#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[TR]l4d2library>

float fLastMeleeSwing[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Fast melee fix",
	author = "sheo",
	description = "Fixes the bug with too fast melee attacks",
	version = "2.1",
	url = "http://steamcommunity.com/groups/b1com"
};

public void OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnClientPutInServer(int client)
{
	fLastMeleeSwing[client] = 0.0;
}

public Action L4D2_OnJoinSurvivor(int client)
{
	if (IsFakeClient(client)) return;
	SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	if (IsFakeClient(client)) return;
	SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && !IsFakeClient(client))
	{
		char sBuffer[64];
		event.GetString("weapon", sBuffer, 64);
		if (StrEqual(sBuffer, "melee"))
		{
			fLastMeleeSwing[client] = GetGameTime();
		}
	}
}

public void OnWeaponSwitched(int client, int weapon)
{
	if (!IsFakeClient(client) && IsValidEntity(weapon))
	{
		char sBuffer[32];
		GetEntityClassname(weapon, sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer, "weapon_melee"))
		{
			float fShouldbeNextAttack = fLastMeleeSwing[client] + 0.92, fByServerNextAttack = GetGameTime() + 0.5;
			SetEntPropFloat(weapon, Prop_Send, "m_flNextPrimaryAttack", (fShouldbeNextAttack > fByServerNextAttack) ? fShouldbeNextAttack : fByServerNextAttack);
		}
	}
}