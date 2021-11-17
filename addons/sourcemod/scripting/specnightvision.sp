#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2util>

#define IMPULS_FLASHLIGHT 100

public Plugin myinfo =
{
	name = "Spectator Nightvision",
	description = "Yukari190",
	author = "-",
	version = "-",
	url = "-"
};

float PressTime[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_team", PlayerTeam_Event);
}

public void PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidAndInGame(client) || IsFakeClient(client)) return;
	CreateTimer(2.0, TeamChange_Timer, client);
}

public Action TeamChange_Timer(Handle timer, any client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == 1)
			SetNightVision(client, true);
		else
			SetNightVision(client, false);
	}
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impuls, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidSpectator(client)) return Plugin_Continue;
	if (impuls != IMPULS_FLASHLIGHT) return Plugin_Continue;
	
	float time = GetEngineTime();
	if(time - PressTime[client] < 0.3)
	{
		SwitchNightVision(client); 				 
	}
	PressTime[client] = time; 
	return Plugin_Continue;
}

void SwitchNightVision(int client)
{
	if (GetNightVision(client))
	{
		SetNightVision(client, false);
	}
	else
	{
		SetNightVision(client, true);
	}
}

void SetNightVision(int client, bool enable)
{
	if (enable)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	}
}

bool GetNightVision(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_bNightVisionOn"));
}
