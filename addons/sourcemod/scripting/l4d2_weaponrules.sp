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

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY 1
#include <l4d2util>

int
	g_GlobalWeaponRules[WEPID_SIZE] = {-1, ...};

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
	RegServerCmd("l4d2_addweaponrule", AddWeaponRuleCb);
	RegServerCmd("l4d2_resetweaponrules", ResetWeaponRulesCb);
	RegAdminCmd("sm_item_track", Command_ItemTrack, ADMFLAG_ROOT);
	
	ResetWeaponRules();
}

public Action ResetWeaponRulesCb(int args)
{
	ResetWeaponRules();
	return Plugin_Handled;
}

void ResetWeaponRules()
{
	for (int i = 0; i < WEPID_SIZE; i++)
	{
		g_GlobalWeaponRules[i] = -1;
	}
}

public Action AddWeaponRuleCb(int args)
{
	if (args < 2)
	{
		PrintToServer("Usage: l4d2_addweaponrule <match> <replace>");
		return Plugin_Handled;
	}
	
	char weaponbuf[64];
	GetCmdArg(1, weaponbuf, sizeof(weaponbuf));
	int match = WeaponNameToId2(weaponbuf);
	GetCmdArg(2, weaponbuf, sizeof(weaponbuf));
	int to = WeaponNameToId2(weaponbuf);
	AddWeaponRule(match, to);
	return Plugin_Handled;
}

void AddWeaponRule(int match, int to)
{
	if (IsValidWeaponId(match) && (to == -1 || IsValidWeaponId(to)))
	{
		g_GlobalWeaponRules[match] = to;
	}
}

public Action Command_ItemTrack(int client, int args)
{
	WeaponSearchLoop();
	return Plugin_Handled;
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(0.3, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStartDelay(Handle hTimer)
{
	WeaponSearchLoop();
	return Plugin_Stop;
}

void WeaponSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = (MaxClients + 1); i <= iEntCount; i++)
	{
		int source = IdentifyWeapon(i);
		if (source > WEPID_NONE && g_GlobalWeaponRules[source] != -1)
		{
			if (g_GlobalWeaponRules[source] == WEPID_NONE)
			{
				KillEntity(i);
			}
			else
			{
				ConvertWeaponSpawn(i, g_GlobalWeaponRules[source]);
			}
		}
	}
}

int WeaponNameToId2(const char[] name)
{
	char namebuf[64] = "weapon_";
	int wepid = WeaponNameToId(name);
	
	if (wepid == WEPID_NONE)
	{
		strcopy(namebuf[7], sizeof(namebuf) - 7, name);
		wepid = WeaponNameToId(namebuf);
	}

	return wepid;
}
