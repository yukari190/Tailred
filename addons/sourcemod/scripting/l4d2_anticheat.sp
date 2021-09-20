#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define CLS_CVAR_MAXLEN	64

static const char LogFile[] = "logs/anticheat.txt";

enum CLSAction
{
	CLSA_Kick=0,
	CLSA_Log
};

enum struct CLSEntry
{
	bool CLSE_hasMin;
	float CLSE_min;
	bool CLSE_hasMax;
	float CLSE_max;
	CLSAction CLSE_action;
	char CLSE_cvar[CLS_CVAR_MAXLEN];
}

ArrayList ClientSettingsArray;
Handle ClientSettingsCheckTimer;

float LerpTime[MAXPLAYERS+1];

char path[256];

public void OnPluginStart()
{
	BuildPath(Path_SM, path, 256, LogFile);
	
	for (int i = 1; i <= MAXPLAYERS; i++) LerpTime[i] = -1.0;

	ClientSettingsArray = new ArrayList(sizeof(CLSEntry));
	RegConsoleCmd("sm_clientsettings", _ClientSettings_Cmd, "列出由lgofnoc强制执行的客户端设置");
	RegServerCmd("sm_trackclientcvar", _TrackClientCvar_Cmd, "添加要由lgofnoc跟踪和实施的客户端CVar");
	RegServerCmd("sm_resetclientcvars", _ResetTracking_Cmd, "Remove all tracked client cvars. Cannot be called during matchmode");
	RegServerCmd("sm_startclientchecking", _StartClientChecking_Cmd, "开始检查并强制执行此插件跟踪的客户端cvar");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	if (ClientSettingsCheckTimer != INVALID_HANDLE)
	{
		KillTimer(ClientSettingsCheckTimer);
		ClientSettingsCheckTimer = INVALID_HANDLE;
	}
}

public void OnClientSettingsChanged(int client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client)) AdjustRates(client);
}

public Action L4D2_OnJoinInfected(int client)
{
	SDKHook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action L4D2_OnAwayInfected(int client)
{
	SDKUnhook(client, SDKHook_SetTransmit, Hook_SetTransmit);
}

public Action Hook_SetTransmit(int client, int entity)
{
	if (IsValidAndInGame(client) && IsValidSurvivor(entity) && IsInfectedGhost(client))
	  return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	CreateTimer(1.0, TimerAdjustRates, client);
}

public Action TimerAdjustRates(Handle timer, any client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client)) AdjustRates(client);
}

//Event
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		LerpTime[client] = -1.0;
	}
}

//Command
public Action _ClientSettings_Cmd(int client, int args)
{
	int clscount = GetArraySize(ClientSettingsArray);
	ReplyToCommand(client, "[lgofnoc] Tracked Client CVars (Total %d)", clscount);
	for (int i = 0; i < clscount; i++)
	{
		CLSEntry clsetting;
		static char message[256], shortbuf[64];
		ClientSettingsArray.GetArray(i, clsetting, sizeof(clsetting));
		Format(message, sizeof(message), "[lgofnoc] Client CVar: %s ", clsetting.CLSE_cvar);
		if (clsetting.CLSE_hasMin)
		{
			Format(shortbuf, sizeof(shortbuf), "Min: %f ", clsetting.CLSE_min);
			StrCat(message, sizeof(message), shortbuf);
		}
		if (clsetting.CLSE_hasMax)
		{
			Format(shortbuf, sizeof(shortbuf), "Max: %f ", clsetting.CLSE_max);
			StrCat(message, sizeof(message), shortbuf);
		}
		switch (clsetting.CLSE_action)
		{
			case CLSA_Kick: StrCat(message, sizeof(message), "Action: Kick");
			case CLSA_Log: StrCat(message, sizeof(message), "Action: Log");
		}
		ReplyToCommand(client, message);
	}
	return Plugin_Handled;
}

public Action _TrackClientCvar_Cmd(int args)
{
	if (args < 3 || args == 4)
	{
		PrintToServer("Usage: lgofnoc_trackclientcvar <cvar> <hasMin> <min> [<hasMax> <max> [<action>]]");
		return Plugin_Handled;
	}
	char sBuffer[CLS_CVAR_MAXLEN], cvar[CLS_CVAR_MAXLEN];
	bool hasMin, hasMax;
	float min, max;
	CLSAction action=CLSA_Kick;
	GetCmdArg(1, cvar, sizeof(cvar));
	if (!strlen(cvar))
	{
		PrintToServer("Unreadable cvar");
		return Plugin_Handled;
	}
	GetCmdArg(2, sBuffer, sizeof(sBuffer));
	hasMin = view_as<bool>(StringToInt(sBuffer));
	GetCmdArg(3, sBuffer, sizeof(sBuffer));
	min = StringToFloat(sBuffer);
	if (args >= 5)
	{
		GetCmdArg(4, sBuffer, sizeof(sBuffer));
		hasMax = view_as<bool>(StringToInt(sBuffer));
		GetCmdArg(5, sBuffer, sizeof(sBuffer));
		max = StringToFloat(sBuffer);
	}
	if (args >= 6)
	{
		GetCmdArg(6, sBuffer, sizeof(sBuffer));
		action = view_as<CLSAction>(StringToInt(sBuffer));
	}
	_AddClientCvar(cvar, hasMin, min, hasMax, max, action);	
	return Plugin_Handled;
}

public Action _ResetTracking_Cmd(int args)
{
	if (ClientSettingsCheckTimer != INVALID_HANDLE)
	{
		KillTimer(ClientSettingsCheckTimer);
		ClientSettingsCheckTimer = INVALID_HANDLE;
	}
	ClearAllSettings();
	PrintToServer("Client CVar Tracking Information Reset!");
	return Plugin_Handled;
}

public Action _StartClientChecking_Cmd(int args)
{
	if (ClientSettingsCheckTimer == INVALID_HANDLE) ClientSettingsCheckTimer = CreateTimer(5.0, _CheckClientSettings_Timer, _, TIMER_REPEAT);
	else PrintToServer("无法启动插件跟踪或已开始跟踪");
}

public Action _CheckClientSettings_Timer(Handle timer)
{
	EnforceAllCliSettings();
	return Plugin_Continue;
}


//Stock
void AdjustRates(int client)
{
	float newLerpTime = GetLerpTime(client);
	if (LerpTime[client] == -1.0)
	{
		LerpTime[client] = newLerpTime;
	}
	else
	{
		if (LerpTime[client] != newLerpTime && !IsClientInKickQueue(client))
		{
			KickClient(client, "当前服务器禁止在游戏中修改 cl_interp 值!");
			LerpTime[client] = -1.0;
		}
	}
}

float GetLerpTime(int client)
{
	char buffer[64];
	if (!GetClientInfo(client, "cl_interp", buffer, sizeof(buffer))) buffer = "";
	float flLerpAmount = StringToFloat(buffer);	
	return flLerpAmount;
}

void _AddClientCvar(const char[] cvar, bool hasMin, float min, bool hasMax, float max, CLSAction action)
{
	if (ClientSettingsCheckTimer != INVALID_HANDLE)
	{
		PrintToServer("在比赛进行中无法追踪新的Cvar");
		return;
	}
	if (!(hasMin || hasMax))
	{
		LogError("[lgofnoc] ClientSettings: Client CVar %s 没有MAX或MIN指定", cvar);
		return;
	}
	if (hasMin && hasMax && max < min)
	{
		LogError("[lgofnoc] ClientSettings: Client CVar %s 指定的最大 < 最小 (%f < %f)", cvar, max, min);
		return;
	}
	if (strlen(cvar) >= CLS_CVAR_MAXLEN)
	{
		LogError("[lgofnoc] ClientSettings: CVar 指定的 (%s) 大于最大 cvar 长度 (%d)", cvar, CLS_CVAR_MAXLEN);
		return;
	}
	
	CLSEntry newEntry;
	for (int i = 0; i < GetArraySize(ClientSettingsArray); i++)
	{
		ClientSettingsArray.GetArray(i, newEntry, sizeof(newEntry));
		if (StrEqual(newEntry.CLSE_cvar, cvar, false))
		{
			LogError("[lgofnoc] ClientSettings: 尝试跟踪已经被跟踪的 CVar %s.", cvar);
			return;
		}
	}
	newEntry.CLSE_hasMin = hasMin;
	newEntry.CLSE_min = min;
	newEntry.CLSE_hasMax = hasMax;
	newEntry.CLSE_max = max;
	newEntry.CLSE_action = view_as<CLSAction>(action);
	strcopy(newEntry.CLSE_cvar, CLS_CVAR_MAXLEN, cvar);
	ClientSettingsArray.PushArray(newEntry, sizeof(newEntry)); 
}

void EnforceAllCliSettings()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			CLSEntry clsetting;
			for (int i = 0; i < GetArraySize(ClientSettingsArray); i++)
			{
				ClientSettingsArray.GetArray(i, clsetting, sizeof(clsetting));
				QueryClientConVar(client, clsetting.CLSE_cvar, _EnforceCliSettings_QueryReply, i);
			}
		}
	}
}

public int _EnforceCliSettings_QueryReply(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	if (!IsClientConnected(client) || !IsClientInGame(client) || IsClientInKickQueue(client)) return; // Client disconnected or got kicked already
	if (result)
	{
		LogToFile(path, "[lgofnoc] ClientSettings: Couldn't retrieve cvar %s from %L, kicked from server", cvarName, client);
		KickClient(client, "CVar '%s' protected or missing! Hax?", cvarName);
		return;
	}
	float fCvarVal = StringToFloat(cvarValue);
	int clsetting_index = value;
	CLSEntry clsetting;
	ClientSettingsArray.GetArray(clsetting_index, clsetting, sizeof(clsetting));
	
	if ((clsetting.CLSE_hasMin && fCvarVal < clsetting.CLSE_min) || (clsetting.CLSE_hasMax && fCvarVal > clsetting.CLSE_max))
	{
		switch (clsetting.CLSE_action)
		{
			case CLSA_Kick:
			{
				LogToFile(path, "[lgofnoc] ClientSettings: Kicking %L for bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
				PrintToChatAll("\x01[\x05lgofnoc\x01] Kicking \x04%L \x01非法的客户端值为 \x04%s \x01(\x04%f\x01) !!!", client, cvarName, fCvarVal);
				char kickMessage[256] = "非法的客户端值 ";
				Format(kickMessage, sizeof(kickMessage), "%s%s (%.2f)", kickMessage, cvarName, fCvarVal);
				if (clsetting.CLSE_hasMin)
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting.CLSE_min);
				if (clsetting.CLSE_hasMax)
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting.CLSE_max);
				KickClient(client, "%s", kickMessage);
			}
			case CLSA_Log:
			{
				LogToFile(path, "[lgofnoc] ClientSettings: Client %L has a bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
			}
		}
	}
	
}

void ClearAllSettings()
{
	ClientSettingsArray.Clear();
}

bool L4D2Util_IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

bool IsValidAndInGame(int client)
{
	return L4D2Util_IsValidClient(client) && IsClientInGame(client);
}

bool IsSurvivor(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == 2);
}

bool IsValidSurvivor(int client)
{
	return (L4D2Util_IsValidClient(client) && IsSurvivor(client));
}

bool IsInfectedGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}
