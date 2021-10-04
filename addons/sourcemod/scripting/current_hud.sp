#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>
#include <readyup>

public Plugin myinfo = 
{
    name = "Current Hud",
    author = "Yukari190",
    description = "",
    version = "1.0"
};

float fVersusBossBuffer;

bool bCur[MAXPLAYERS+1];

public void OnPluginStart()
{
	ConVar hVsBossBuffer;
	(hVsBossBuffer = FindConVar("versus_boss_buffer")).AddChangeHook(GameConVarChanged);
	fVersusBossBuffer	= hVsBossBuffer.FloatValue;
	
	RegConsoleCmd("sm_curhud", CMD_CURHUD);
	CreateTimer(0.2, HudDrawTimer, _, TIMER_REPEAT);
}

public void GameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fVersusBossBuffer	= convar.FloatValue;
}

public void OnClientDisconnect(int client)
{
	bCur[client] = false;
}

public void L4D2_OnRealRoundEnd()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsValidAndInGame(index)) continue;
		ShowVGUIPanel(index, "ready_countdown", _, false);
		bCur[index] = false;
	}
}

public void OnRoundIsLive()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsValidAndInGame(index)) continue;
		ShowVGUIPanel(index, "ready_countdown", _, true);
		bCur[index] = true;
	}
}

public Action CMD_CURHUD(int client, int args)
{
	if (!client) return Plugin_Handled;
	bCur[client] = !bCur[client];
	ShowVGUIPanel(client, "ready_countdown", _, bCur[client]);
	return Plugin_Handled;
}

public Action HudDrawTimer(Handle hTimer)
{
	CTimer_Start(L4D2Direct_GetScavengeRoundSetupTimer(), float(GetHighestSurvivorFlow()));
}

int GetHighestSurvivorFlow()
{
	int flow = -1;
	
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0) {
		flow = RoundToNearest(100.0 * (L4D2Direct_GetFlowDistance(client) + fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	}
	
	return flow < 100 ? flow : 100;
}
