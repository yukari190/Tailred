#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public void OnPluginStart()
{
	RegServerCmd("autoloadlgofnoc", AutoloadLgofnoc);
}

public Action AutoloadLgofnoc(int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	ServerCommand("sm_softmatch %s", buffer);
	return Plugin_Handled;
}
