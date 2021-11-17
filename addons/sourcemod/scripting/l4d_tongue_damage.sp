/*
*	Tongue Damage
*	Copyright (C) 2021 Silvers
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

bool g_bChoking[MAXPLAYERS+1], g_bBlockReset[MAXPLAYERS+1];
Handle g_hTimers[MAXPLAYERS+1];

ConVar 
	tongue_drag_damage_amount2,
	tongue_drag_damage_interval,
	tongue_drag_first_damage_interval,
	tongue_drag_first_damage;

float 
	fDamage,
	fTimer,
	fFirstTimer,
	fFirstDamage;

// ====================================================================================================
//					PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "[L4D & L4D2] Tongue Damage",
	author = "SilverShot",
	description = "Control the Smokers tongue damage when pulling a Survivor.",
	version = "1.6.1",
	url = "https://forums.alliedmods.net/showthread.php?t=318959"
}

public void OnPluginStart()
{
	ConVar tongue_drag_damage_amount = FindConVar("tongue_drag_damage_amount");
	tongue_drag_damage_amount.SetInt(0);
	tongue_drag_damage_amount.AddChangeHook(tongue_drag_damage_amount_ValueChanged);
	
	ConVar tongue_choke_damage_amount = FindConVar("tongue_choke_damage_amount");
	tongue_choke_damage_amount.AddChangeHook(tongue_choke_damage_amount_ValueChanged);
	
	char value[32];
	ConVar tongue_choke_damage_interval = FindConVar("tongue_choke_damage_interval");
	tongue_choke_damage_interval.GetString(value, sizeof(value));
	
	tongue_drag_damage_amount2 = CreateConVar("tongue_drag_damage_amount2", "3", "How much damage the tongue drag does.", CVAR_FLAGS);
	tongue_drag_damage_interval = CreateConVar("tongue_drag_damage_interval", value, "How often the drag does damage.", CVAR_FLAGS);
	tongue_drag_first_damage_interval = CreateConVar("tongue_drag_first_damage_interval", "-1.0", "After how many seconds do we apply our first tick of damage? | 0.0 to Disable.", CVAR_FLAGS);
	tongue_drag_first_damage = CreateConVar("tongue_drag_first_damage", "3.0", "How much damage do we apply on the first tongue hit? | Only applies when first_damage_interval is used", CVAR_FLAGS);
	
	tongue_drag_damage_amount2.AddChangeHook(ConVarChange);
	tongue_drag_damage_interval.AddChangeHook(ConVarChange);
	tongue_drag_first_damage_interval.AddChangeHook(ConVarChange);
	tongue_drag_first_damage.AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
	
	HookEvent("tongue_grab",		Event_GrabStart);
	HookEvent("tongue_release",	Event_GrabStop);
	HookEvent("choke_start",			Event_ChokeStart);
	HookEvent("choke_end",			Event_ChokeStop);
	HookEvent("round_end", view_as<EventHook>(OnRoundEnd), EventHookMode_PostNoCopy);
	HookEvent("mission_lost", view_as<EventHook>(OnRoundEnd), EventHookMode_PostNoCopy);
	HookEvent("map_transition", view_as<EventHook>(OnRoundEnd), EventHookMode_PostNoCopy);
	HookEvent("finale_win", view_as<EventHook>(OnRoundEnd), EventHookMode_PostNoCopy);
}

public void tongue_drag_damage_amount_ValueChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(convar, 0);
}

public void tongue_choke_damage_amount_ValueChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(convar, 1); // hack-hack: game tries to change this cvar for some reason, can't be arsed so HARDCODETHATSHIT
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fDamage = tongue_drag_damage_amount2.FloatValue;
	fTimer = tongue_drag_damage_interval.FloatValue;
	fFirstTimer = tongue_drag_first_damage_interval.FloatValue;
	fFirstDamage = tongue_drag_first_damage.FloatValue;
}

// ====================================================================================================
//					FUNCTION
// ====================================================================================================
public void OnClientDisconnect(int client)
{
	delete g_hTimers[client];
	g_bBlockReset[client] = false;
}

public void OnRoundEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hTimers[i];
		g_bBlockReset[i] = false;
	}
}

public void Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
	g_bChoking[GetClientOfUserId(event.GetInt("victim"))] = true;
}

public void Event_ChokeStop(Event event, const char[] name, bool dontBroadcast)
{
	g_bChoking[GetClientOfUserId(event.GetInt("victim"))] = false;
}

public void Event_GrabStart(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("victim");
	int client = GetClientOfUserId(userid);
	if (IsValidAndInGame(client))
	{
		// Fix floating bug
		if (GetEntityFlags(client) & FL_ONGROUND == 0)
			SetEntityMoveType(client, MOVETYPE_WALK);

		// Apply damage
		if (fFirstTimer < 0.0)
		{
			delete g_hTimers[client];
			g_hTimers[client] = CreateTimer(fTimer, TimerDamage, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			return;
		}
		
		CreateTimer(fFirstTimer, FirstDamage, userid, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public void Event_GrabStop(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("victim"));
	if (IsValidAndInGame(client))
	{
		// Don't kill timer if events called from timer
		if( g_bBlockReset[client] )
		{
			g_bBlockReset[client] = false;
		} else {
			delete g_hTimers[client];
		}
	}
}

public Action FirstDamage(Handle hTimer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (IsValidAndInGame(client) && IsPlayerAlive(client) && !IsSurvivorBeingChoked(client))
	{
		int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
		if (IsValidAndInGame(attacker))
		{
			HurtEntity(client, attacker, fFirstDamage);
		}
		
		delete g_hTimers[client];
		g_hTimers[client] = CreateTimer(fTimer, TimerDamage, userid, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	
	return Plugin_Stop;
}

public Action TimerDamage(Handle timer, any client)
{
	client = GetClientOfUserId(client);
	if (IsValidAndInGame(client) && IsPlayerAlive(client))
	{
		if (g_bChoking[client])
			return Plugin_Continue;

		if (!IsSurvivorBeingChoked(client))
		{
			int attacker = GetEntPropEnt(client, Prop_Send, "m_tongueOwner");
			if (IsValidAndInGame(attacker))
			{
				// Prevent errors when clients die from HurtEntity during timer callback triggering the "tongue_release" event and delete timer.
				// Thanks to "asherkin" and "Dysphie" for finding the issue.

				// Error log:
				// Plugin "l4d_tongue_damage.smx" encountered error 23: Native detected error
				// Invalid timer handle e745136f (error 1) during timer end, displayed function is timer callback, not the stack trace
				// Unable to call function "TimerDamage" due to above error(s).

				g_bBlockReset[client] = true;
				HurtEntity(client, attacker, fDamage);
				if (g_bBlockReset[client] == false)
				{
					g_hTimers[client] = null;
					return Plugin_Stop;
				}

				g_bBlockReset[client] = false;
				return Plugin_Continue;
			}
		}
	}

	g_hTimers[client] = null;
	return Plugin_Stop;
}

void HurtEntity(int victim, int client, float damage)
{
	SDKHooks_TakeDamage(victim, client, client, damage, DMG_SLASH);
}

bool IsSurvivorBeingChoked(int client)
{
	return (GetEntProp(client, Prop_Send, "m_isHangingFromTongue") > 0);
}

stock bool IsValidAndInGame(int client)
{
	return L4D2Util_IsValidClient(client) && IsClientInGame(client);
}

stock bool L4D2Util_IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}
