#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define FILE_PM "logs/PlayerMessage.log"
#define FILE_SM "logs/SubmitMessage.log"

public Plugin myinfo =
{
	name = "Server Chatlog",
	description = "闲月疏云, Yukari190",
	author = "",
	version = "1.2",
	url = ""
};

static const char sTeamName[3][] =
{
	"旁观者",
	"生还者",
	"感染者"
};

char 
	sPM_Path[PLATFORM_MAX_PATH],
	sSM_Path[PLATFORM_MAX_PATH];

public void OnPluginStart()
{
	BuildPath(Path_SM, sPM_Path, PLATFORM_MAX_PATH, FILE_PM);
	BuildPath(Path_SM, sSM_Path, PLATFORM_MAX_PATH, FILE_SM);
	
	RegConsoleCmd("sm_submit", OnSubmit);
	HookEvent("player_say", OnPlayerSay);
}

public Action OnSubmit(int client, int args)
{
	char tmpSteamId[512], message[2048];
	GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
	GetCmdArg(1, message, sizeof(message));
	LogToFile(sSM_Path, "%N[%s](%s): %s", client, sTeamName[GetClientTeam(client) - 1], tmpSteamId, message);
}

public void OnPlayerSay(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	char message[2048], username[MAX_NAME_LENGTH], tmpSteamId[512];
	event.GetString("text", message, sizeof(message));
	
	if (client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		GetClientName(client, username, sizeof(username));
		GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
		LogToFile(sPM_Path, "%s[%s](%s): %s", username, tmpSteamId, sTeamName[GetClientTeam(client) - 1], message);
	}
	else
	{
		LogToFile(sPM_Path, "[Server]: %s", message);
	}
}
