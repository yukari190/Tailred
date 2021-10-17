#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <colors>
#include <l4d2lib>
#include <l4d2util>

#define GAMEDATA_FILE          "l4d_wlimits"
#define GAMEDATA_USE_AMMO      "CWeaponAmmoSpawn_Use"
#define WEAPON_LIMITS_SOUND    "player/suit_denydevice.wav"

public Plugin myinfo =
{
	name = "L4D Weapon Limits",
	author = "CanadaRox, Stabby, Forgetest",
	description = "Restrict weapons individually or together",
	version = "1.3.5",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

enum struct LimitArrayEntry
{
	int LAE_iLimit;
	int LAE_WeaponArray[view_as<int>(WeaponId)/32+1];
}

Handle hSDKGiveDefaultAmmo = null;
ArrayList hLimitArray;
bool bIsLocked;
bool bIsIncappedWithMelee[MAXPLAYERS + 1];

public void OnPluginStart()
{
	LoadGameData();
	
	hLimitArray = new ArrayList(sizeof(LimitArrayEntry));
	
	RegServerCmd("l4d_wlimits_add", AddLimit_Cmd, "Add a weapon limit");
	RegServerCmd("l4d_wlimits_lock", LockLimits_Cmd, "Locks the limits to improve search speeds");
	RegServerCmd("l4d_wlimits_clear", ClearLimits_Cmd, "Clears all weapon limits (limits must be locked to be cleared)");
	
	HookEvent("player_incapacitated_start", OnIncap);
	HookEvent("revive_success", OnRevive);
	HookEvent("player_death", OnDeath);
	HookEvent("player_bot_replace", OnBotReplacedPlayer);
	HookEvent("bot_player_replace", OnPlayerReplacedBot);
}

public void OnMapStart()
{
	PrecacheSound(WEAPON_LIMITS_SOUND);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (team == 2)
	{
		SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
	}
	else if (oldteam == 2)
	{
		SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUse);
	}
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		bIsIncappedWithMelee[i] = false;
	}
}

public Action AddLimit_Cmd(int args)
{
	if (bIsLocked)
	{
		PrintToServer("Limits have been locked");
		return Plugin_Handled;
	}
	else if (args < 2)
	{
		PrintToServer("Usage: l4d_wlimits_add <limit> <weapon1> <weapon2> ... <weaponN>");
		return Plugin_Handled;
	}

	char sTempBuff[32];
	GetCmdArg(1, sTempBuff, sizeof(sTempBuff));

	LimitArrayEntry newEntry;
	int wepid;
	newEntry.LAE_iLimit = StringToInt(sTempBuff);

	for (int i = 2; i <= args; ++i)
	{
		GetCmdArg(i, sTempBuff, sizeof(sTempBuff));
		wepid = view_as<int>(WeaponNameToId(sTempBuff));
		newEntry.LAE_WeaponArray[wepid/32] |= (1 << (wepid % 32));
	}
	hLimitArray.PushArray(newEntry);
	return Plugin_Handled;
}

public Action LockLimits_Cmd(int args)
{
	if (bIsLocked)
	{
		PrintToServer("Weapon limits already locked");
	}
	else
	{
		bIsLocked = true;
	}
}

public Action ClearLimits_Cmd(int args)
{
	if (bIsLocked)
	{
		bIsLocked = false;
		PrintToChatAll("[L4D Weapon Limits] Weapon limits cleared!");
		if (hLimitArray != null)
			hLimitArray.Clear();
	}
}

public Action WeaponCanUse(int client, int weapon)
{
	// TODO: There seems to be an issue that this hook will be constantly called
	//       when client with no weapon on equivalent slot just eyes or walks on it.
	//       If the weapon meets limit, client will have the warning spamming unexpectedly.
	
	if (!IsValidAndInGame(client) || !bIsLocked) return Plugin_Continue;
	
	int wepid = view_as<int>(IdentifyWeapon(weapon));
	int wep_slot = GetSlotFromWeaponId(view_as<WeaponId>(wepid));
	int player_weapon = GetPlayerWeaponSlot(client, wep_slot);
	int player_wepid = view_as<int>(IdentifyWeapon(player_weapon));

	LimitArrayEntry arrayEntry;
	
	for (int i = 0; i < hLimitArray.Length; ++i)
	{
		hLimitArray.GetArray(i, arrayEntry);
		if (arrayEntry.LAE_WeaponArray[wepid/32] & (1 << (wepid % 32)) && GetWeaponCount(arrayEntry.LAE_WeaponArray) >= arrayEntry.LAE_iLimit)
		{
			if (!player_wepid || wepid == player_wepid || !(arrayEntry.LAE_WeaponArray[player_wepid/32] & (1 << (player_wepid % 32))))
			{
				// Swap melee, np
				if (player_wepid == view_as<int>(WEPID_MELEE) && wepid == view_as<int>(WEPID_MELEE))
					return Plugin_Continue;
				
				if (wep_slot == 0)
					GiveDefaultAmmo(client);
					
				CPrintToChat(client, "{B}[{W}Weapon Limits{B}]{W} 该武器组已达到最大数量 {O}%d", arrayEntry.LAE_iLimit);
				EmitSoundToClient(client, WEAPON_LIMITS_SOUND);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

public void OnIncap(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && GetClientTeam(client) == 2 && IdentifyWeapon(GetPlayerWeaponSlot(client, 1)) == WEPID_MELEE)
	{
		bIsIncappedWithMelee[client] = true;
	}
}

public void OnRevive(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (client > 0 && bIsIncappedWithMelee[client])
	{
		bIsIncappedWithMelee[client] = false;
	}
}

public void OnDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (client > 0 && GetClientTeam(client) == 2 && bIsIncappedWithMelee[client])
	{
		bIsIncappedWithMelee[client] = false;
	}
}

public void OnBotReplacedPlayer(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!bot && GetClientTeam(bot) != 2)
		return;
	
	int player = GetClientOfUserId(event.GetInt("player"));
	bIsIncappedWithMelee[bot] = bIsIncappedWithMelee[player];
	bIsIncappedWithMelee[player] = false;
}

public void OnPlayerReplacedBot(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player && GetClientTeam(player) != 2)
		return;
	
	int bot = GetClientOfUserId(event.GetInt("bot"));
	bIsIncappedWithMelee[player] = bIsIncappedWithMelee[bot];
	bIsIncappedWithMelee[bot] = false;
}

int GetWeaponCount(const int[] mask)
{
	bool queryMelee = !!(mask[view_as<int>(WEPID_MELEE) / 32] & (1 << (view_as<int>(WEPID_MELEE) % 32)));
	
	int count;
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
	
		for (int j = 0; j < 5; ++j)
		{
			int wepid = view_as<int>(IdentifyWeapon(GetPlayerWeaponSlot(index, j)));
			if (mask[wepid/32] & (1 << (wepid % 32)) || (j == 1 && queryMelee && bIsIncappedWithMelee[index]))
			{
				++count;
			}
		}
	}
	return count;
}

void GiveDefaultAmmo(int client)
{
	// NOTE:
	// Previously the plugin seems to cache an index of one ammo pile in current map, and is supposed to use it here.
	// For some reason, the caching never runs, and the code is completely wrong either.
	// Therefore, it has been consistently using an SDKCall like below ('0' should be the index of ammo pile).
	// However, since it actually has worked without error and crash for a long time, I would decide to leave it still.
	// If your server suffers from this, please try making use of the functions commented below.
	
	SDKCall(hSDKGiveDefaultAmmo, 0, client);
}

void LoadGameData()
{
	/* Preparing SDK Call */
	/* {{{ */
	GameData conf = LoadGameConfigFile(GAMEDATA_FILE);

	if (conf == null)
		SetFailState("Gamedata missing: %s", GAMEDATA_FILE);

	StartPrepSDKCall(SDKCall_Entity);

	if (!PrepSDKCall_SetFromConf(conf, SDKConf_Signature, GAMEDATA_USE_AMMO))
		SetFailState("Gamedata missing signature: %s", GAMEDATA_USE_AMMO);

	// Client that used the ammo spawn
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSDKGiveDefaultAmmo = EndPrepSDKCall();
	
	if (hSDKGiveDefaultAmmo == null)
		SetFailState("Failed to finish SDKCall setup: %s", GAMEDATA_USE_AMMO);
	/* }}} */
}
