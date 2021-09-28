/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

int g_GlobalWeaponRules[view_as<int>(WEPID_SIZE)] = {-1, ...};

public Plugin myinfo =
{
	name = "L4D2 Weapon Rules",
	author = "ProdigySim", //Update syntax and add support sm1.11 - A1m`
	version = "1.0.2",
	description = "^",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnPluginStart()
{
	for (int i = 0; i < view_as<int>(WEPID_SIZE); i++) g_GlobalWeaponRules[i] = -1;
	
	RegServerCmd("l4d2_addweaponrule", AddWeaponRuleCb);
	RegServerCmd("l4d2_resetweaponrules", ResetWeaponRulesCb);
	
	HookEvent("player_use", SpawnerGiveItem_Event, EventHookMode_PostNoCopy);
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(0.3, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStartDelay(Handle hTimer)
{
	WeaponSearchLoop();
}

public Action SpawnerGiveItem_Event(Event event, const char[] name, bool dontBroadcast)
{
	WeaponSearchLoop();
}

void WeaponSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		WeaponId source = IdentifyWeapon(i);
		if (g_GlobalWeaponRules[source] != -1)
		{
			if (g_GlobalWeaponRules[source] == view_as<int>(WEPID_NONE))
			  RemoveEntityLog(i);
			else
			  ConvertWeaponSpawn(i, view_as<WeaponId>(g_GlobalWeaponRules[source]));
		}
	}
}

public Action AddWeaponRuleCb(int args)
{
    if (args < 2)
    {
        LogMessage("Usage: l4d2_addweaponrule <match> <replace>");
        return Plugin_Handled;
    }
    char weaponbuf[64];
    GetCmdArg(1, weaponbuf, sizeof(weaponbuf));
    WeaponId match = WeaponNameToId2(weaponbuf);
    GetCmdArg(2, weaponbuf, sizeof(weaponbuf));
    WeaponId to = WeaponNameToId2(weaponbuf);
	if (IsValidWeaponId(match) && (to == view_as<WeaponId>(-1) || IsValidWeaponId(to))) g_GlobalWeaponRules[match] = view_as<int>(to);
    return Plugin_Handled;
}

public Action ResetWeaponRulesCb(int args)
{
	for (int i = 0; i < view_as<int>(WEPID_SIZE); i++)
	{
		g_GlobalWeaponRules[i] = -1;
	}
    return Plugin_Handled;
}

WeaponId WeaponNameToId2(const char[] name)
{
    static char namebuf[64]="weapon_";
    WeaponId wepid = WeaponNameToId(name);
    if (wepid == WEPID_NONE)
    {
        strcopy(namebuf[7], sizeof(namebuf)-7, name);
        wepid = WeaponNameToId(namebuf);
    }
    return wepid;
}

void RemoveEntityLog(int entity)
{
	char pluginName[128], classname[64];
	GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
	GetEdictClassname(entity, classname, 64);
	if (!AcceptEntityInput(entity, "kill"))
	{
		LogError("[%s] 删除实体 %s 失败", pluginName, classname);
	}
	else
	{
		PrintToServer("[%s] Removed %s", pluginName, classname);
	}
}
