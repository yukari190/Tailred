#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>

float fLastMeleeSwing[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name = "Fast melee fix",
	author = "sheo",
	description = "Fixes the bug with too fast melee attacks",
	version = "2.1",
	url = "http://steamcommunity.com/groups/b1com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	char gfstring[128];
	GetGameFolderName(gfstring, sizeof(gfstring));
	if (!StrEqual(gfstring, "left4dead2", false))
	{
		SetFailState("Plugin supports Left 4 dead 2 only!");
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("weapon_fire", Event_WeaponFire);
}

public void OnClientPutInServer(int client)
{
	fLastMeleeSwing[client] = 0.0;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidEntity(client) || !IsClientInGame(client) || IsFakeClient(client)) return;
	if (nowteam == 2 && oldteam != 2) SDKHook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
	else if (nowteam != 2 && oldteam == 2) SDKUnhook(client, SDKHook_WeaponSwitchPost, OnWeaponSwitched);
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && !IsFakeClient(client))
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