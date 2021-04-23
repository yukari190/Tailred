#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[TR]l4d2library>

int g_PlayerSecondaryWeapons[MAXPLAYERS + 1];

public Plugin myinfo =
{
	name        = "L4D2 Drop Secondary",
	author      = "Jahze, Visor",
	version     = "2.0",
	description = "Survivor players will drop their secondary weapon when they die",
	url         = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart() 
{
	HookEvent("player_use", OnPlayerUse, EventHookMode_Post);
	HookEvent("player_bot_replace", OnBotSwap);
	HookEvent("bot_player_replace", OnBotSwap);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 0; i <= MAXPLAYERS; i++) g_PlayerSecondaryWeapons[i] = -1;
}

public Action OnPlayerUse(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client)) 
	{
		int weapon = GetPlayerWeaponSlot(client, 1);
		WeaponId source = L4D2_IdentifyWeapon(weapon);
		if (IsSecondaryWeapon(source))
		{
			g_PlayerSecondaryWeapons[client] = (weapon == -1 ? weapon : EntIndexToEntRef(weapon));
		}
	}
}

public Action OnBotSwap(Event event, const char[] name, bool dontBroadcast) 
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	int player = GetClientOfUserId(event.GetInt("player"));
	if (L4D2_IsValidClient(bot) && L4D2_IsValidClient(player)) 
	{
		if (StrEqual(name, "player_bot_replace")) 
		{
			g_PlayerSecondaryWeapons[bot] = g_PlayerSecondaryWeapons[player];
			g_PlayerSecondaryWeapons[player] = -1;
		}
		else 
		{
			g_PlayerSecondaryWeapons[player] = g_PlayerSecondaryWeapons[bot];
			g_PlayerSecondaryWeapons[bot] = -1;
		}
	}
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) 
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client)) 
	{
		int weapon = EntRefToEntIndex(g_PlayerSecondaryWeapons[client]);
		if (L4D2_IdentifyWeapon(weapon) != WEPID_NONE && client == GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity"))
		{
			SDKHooks_DropWeapon(client, weapon);
		}
	}
}

bool IsSecondaryWeapon(WeaponId source)
{
	if (source == WEPID_PISTOL_MAGNUM) return true;
	if (source == WEPID_PISTOL) return true;
	if (source == WEPID_MELEE) return true;
	return false;
}
