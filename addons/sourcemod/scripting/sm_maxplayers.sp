#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

ConVar hMaxPlayers, hVisibleMaxPlayers;

public void OnPluginStart()
{
	hMaxPlayers = FindConVar("sv_maxplayers");
	hVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	
	RegServerCmd("sm_maxplayers", CMD_MaxPlayers);
}

public Action CMD_MaxPlayers(int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	int iSlot = StringToInt(buffer);
	if (iSlot < 0 || iSlot > 28)
	{
		PrintToServer("[Slots]有效范围 0 - 28");
		return Plugin_Handled;
	}
	SetConVarInt(hMaxPlayers, iSlot);
	SetConVarInt(hVisibleMaxPlayers, iSlot);
	return Plugin_Handled;
}
