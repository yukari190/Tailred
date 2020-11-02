#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#include "modules/functions.sp"
#include "modules/configs.sp"

#include "modules/MatchMode.sp"
#include "modules/CvarSettings.sp"

public Plugin myinfo = 
{
	name = "LGOFNOC Config Manager",
	author = "Confogl Team",
	description = "A competitive configuration management system for Source games",
	version = "1.3",
	url = ""
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	RegPluginLibrary("lgofnoc");
	return APLRes_Success;
}

public void OnPluginStart()
{
	Configs_OnModuleStart();
	MM_OnModuleStart();
	CVS_OnModuleStart();
	HookEvent("player_disconnect", PlayerDisconnect_Event);
	AddCustomServerTag("lgofnoc", true);
}

public void OnPluginEnd()
{
	CVS_OnModuleEnd();
	RemoveCustomServerTag("lgofnoc");
	MM_OnModuleEnd();
}

public void OnConfigsExecuted()
{
	CVS_OnConfigsExecuted();
}

/* Events */
public Action PlayerDisconnect_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidEntity(client) || !IsClientInGame(client) || IsFakeClient(client)) return;
	MM_PlayerDisconnect();
}
