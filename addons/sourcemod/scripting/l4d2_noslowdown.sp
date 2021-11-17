/*
	SourcePawn is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2015 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2015 ITB CompuPhase.
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
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

#define SURVIVOR_RUNSPEED		220.0

public Plugin myinfo =
{
	name = "L4D2 Slowdown Control",
	author = "Visor, Sir, darkid, Forgetest",
	version = "2.6.2",
	description = "Manages the water/gunfire slowdown for both teams",
	url = "https://github.com/ConfoglTeam/ProMod"
};

ConVar 
	hCvarSurvivorLimpspeed,
	hCvarTankSpeedVS;

float fTankRunSpeed;
int iSurvivorLimpHealth;

public void OnPluginStart()
{
	hCvarSurvivorLimpspeed = FindConVar("survivor_limp_health");
	hCvarTankSpeedVS = FindConVar("z_tank_speed_vs");
	hCvarSurvivorLimpspeed.AddChangeHook(OnConVarChanged);
	hCvarTankSpeedVS.AddChangeHook(OnConVarChanged);
	OnConVarChanged(null, "", "");
	
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSurvivorLimpHealth = hCvarSurvivorLimpspeed.IntValue;
	fTankRunSpeed = hCvarTankSpeedVS.FloatValue;
}

public void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidInfected(victim)) 
	{
		SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
	}
}

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (!client) return Plugin_Continue;
	
	bool bInWater = (GetEntityFlags(client) & FL_INWATER) ? true : false;
	
	if (IsSurvivor(client))
	{
		// Adrenaline = Don't care, don't mess with it.
		// Limping = 260 speed (both in water and on the ground)
		// Healthy = 260 speed (both in water and on the ground)
		if (GetEntProp(client, Prop_Send, "m_bAdrenalineActive")) 
		  return Plugin_Continue;

		if (bInWater && !IsLimping(client))
		{
			retVal = SURVIVOR_RUNSPEED;
			return Plugin_Handled;
		}
	}
	else if (IsTank(client)) 
	{
		//if (bInWater)
		{
			retVal = fTankRunSpeed;
			return Plugin_Handled;
		}
	}
	
	return Plugin_Continue;
}

bool IsLimping(int client)
{
	return RoundToFloor(GetClientHealth(client) + L4D_GetTempHealth(client)) < iSurvivorLimpHealth;
}
