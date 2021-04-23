#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[TR]l4d2library>

public Plugin myinfo =
{
	name = "L4D Weapon Limits",
	author = "CanadaRox, Stabby",
	description = "Restrict weapons individually or together",
	version = "1.3",
	url = "https://www.github.com/CanadaRox/sourcemod-plugins/tree/master/weapon_limits"
}

enum struct LimitArrayEntry
{
	int LAE_iLimit;
	int LAE_WeaponArray[view_as<int>(WeaponId)/32+1];
}

ArrayList hLimitArray;
bool bIsLocked;
bool bIsIncappedWithMelee[MAXPLAYERS + 1];

public void OnPluginStart()
{
	hLimitArray = new ArrayList(sizeof(LimitArrayEntry));
	
	RegServerCmd("l4d_wlimits_add", AddLimit_Cmd, "Add a weapon limit");
	RegServerCmd("l4d_wlimits_lock", LockLimits_Cmd, "Locks the limits to improve search speeds");
	RegServerCmd("l4d_wlimits_clear", ClearLimits_Cmd, "Clears all weapon limits (limits must be locked to be cleared)");
	
	//HookEvent("player_incapacitated_start", OnIncap);
	//HookEvent("revive_success", OnRevive);
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_WeaponCanUse, WeaponCanUse);
}

public void L4D2_OnRealRoundEnd()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		bIsIncappedWithMelee[i] = false;
	}
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(2.0, RoundStartDelay_Timer);
}

public Action RoundStartDelay_Timer(Handle timer)
{
	//FindAmmoSpawn();
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
		PrintToServer("Usage: l4d_wlimits_add <limit> <ammo> <weapon1> <weapon2> ... <weaponN>");
		return Plugin_Handled;
	}

	char sTempBuff[32];
	GetCmdArg(1, sTempBuff, sizeof(sTempBuff));

	LimitArrayEntry newEntry;
	WeaponId wepid;
	newEntry.LAE_iLimit = StringToInt(sTempBuff);

	for (int i = 2; i <= args; ++i)
	{
		GetCmdArg(i, sTempBuff, sizeof(sTempBuff));
		wepid = L4D2_WeaponNameToId(sTempBuff);
		newEntry.LAE_WeaponArray[view_as<int>(wepid)/32] |= (1 << (view_as<int>(wepid) % 32));
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
		hLimitArray.Clear();
	}
}

public Action WeaponCanUse(int client, int weapon)
{
	if (GetClientTeam(client) != 2 || !bIsLocked) return Plugin_Continue;
	WeaponId wepid = L4D2_IdentifyWeapon(weapon);
	LimitArrayEntry arrayEntry;
	int wep_slot = L4D2_GetSlotFromWeaponId(wepid);
	int player_weapon = GetPlayerWeaponSlot(client, wep_slot);
	WeaponId player_wepid = L4D2_IdentifyWeapon(player_weapon);
	for (int i = 0; i < GetArraySize(hLimitArray); ++i)
	{
		hLimitArray.GetArray(i, arrayEntry);
		if (arrayEntry.LAE_WeaponArray[view_as<int>(wepid)/32] & (1 << (view_as<int>(wepid) % 32)) && GetWeaponCount(arrayEntry.LAE_WeaponArray) >= arrayEntry.LAE_iLimit)
		{
			if (!player_wepid || wepid == player_wepid || !(arrayEntry.LAE_WeaponArray[view_as<int>(player_wepid)/32] & (1 << (view_as<int>(player_wepid) % 32))))
			{
				if (wep_slot == 0) L4D2_GiveDefaultAmmo(client);
				if (player_wepid == WEPID_MELEE && wepid == WEPID_MELEE) return Plugin_Continue;
				if (player_wepid) PrintToChat(client, "[Weapon Limits] 该武器组已达到最大数量 %d", arrayEntry.LAE_iLimit);
				return Plugin_Handled;
			}
		}
	}
	return Plugin_Continue;
}

/*public Action:OnIncap(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (GetClientTeam(client) == 2 && L4D2_IdentifyWeapon(GetPlayerWeaponSlot(client, 1)) == WEPID_MELEE)
	{
		bIsIncappedWithMelee[client] = true;
	}
}

public Action:OnRevive(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "subject"));
	if (bIsIncappedWithMelee[client])
	{
		bIsIncappedWithMelee[client] = false;
	}
}*/

int GetWeaponCount(const int[] mask)
{
	int count;
	WeaponId wepid;
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == 2 && IsPlayerAlive(i))
		{
			for (int j = 0; j < 5; ++j)
			{
				wepid = L4D2_IdentifyWeapon(GetPlayerWeaponSlot(i, j));
				if (mask[view_as<int>(wepid)/32] & (1 << (view_as<int>(wepid) % 32))/* || (j == 1 && bIsIncappedWithMelee[i] && wepid != WEPID_PISTOL_MAGNUM)*/)
				{
					++count;
				}
			}
		}
	}
	return count;
}

/*int FindAmmoSpawn()
{
	char classname[64];
	for (int i = MaxClients; i < GetEntityCount(); ++i)
	{
		if (IsValidEntity(i))
		{
			GetEdictClassname(i, classname, sizeof(classname));
			if (StrEqual(classname, "weapon_ammo_spawn"))
			{
				return i;
			}
		}
	}
	int ammo = CreateEntityByName("weapon_ammo_spawn");
	DispatchSpawn(ammo);
	LogMessage("No ammo pile found, creating one: %d", iAmmoPile);
	return ammo;
}*/
