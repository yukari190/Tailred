#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util>

#define STATE_SPAWNREADY 0
#define STATE_TOOCLOSE 256
#define SPAWN_RANGE 150

public Plugin myinfo =
{
	name = "L4D2 Finale Incap Distance Fixifier",
	author = "CanadaRox",
	description = "",
	version = "1.0.1",
	url = "https://bitbucket.org/CanadaRox/random-sourcemod-stuff"
};

bool bIsFinale;

public void OnPluginStart()
{
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);	
	HookEvent("finale_vehicle_leaving", FinaleEnd_Event, EventHookMode_PostNoCopy);
}

public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	bIsFinale = true;
}

public Action FinaleEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsIncapacitated(index)) continue;
		ForcePlayerSuicide(index);
	}
}

public void L4D2_OnRealRoundStart()
{
	bIsFinale = false;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (team == 3)
	{
		SDKHook(client, SDKHook_PreThinkPost, HookCallback);
	}
	else if (oldteam == 3)
	{
		SDKUnhook(client, SDKHook_PreThinkPost, HookCallback);
	}
}

public Action HookCallback(int client)
{
	if (!bIsFinale || !IsValidAndInGame(client) || !IsInfectedGhost(client)) return;
	if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") == STATE_TOOCLOSE && !TooClose(client))
	{
		SetEntProp(client, Prop_Send, "m_ghostSpawnState", STATE_SPAWNREADY);
	}
}

bool TooClose(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		GetClientAbsOrigin(index, fSurvLocation);
		MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		if (GetVectorLength(fVector) <= SPAWN_RANGE) return true;
	}
	return false;
}
