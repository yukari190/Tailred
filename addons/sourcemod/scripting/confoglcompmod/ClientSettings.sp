#define CLS_CVAR_MAXLEN	64
#define CLIENT_CHECK_INTERVAL 5.0
#define CLS_LOGFILE "logs/cls_logfile.txt"

enum CLSAction
{
	CLSA_Spec = 0,
	CLSA_Kick,
	CLSA_Log
};

#if SOURCEMOD_V_MINOR > 9
enum struct CLSEntry
{
	bool CLSE_hasMin;
	float CLSE_min;
	bool CLSE_hasMax;
	float CLSE_max;
	CLSAction CLSE_action;
	char CLSE_cvar[CLS_CVAR_MAXLEN];
}
#else
enum CLSEntry
{
	bool:CLSE_hasMin,
	Float:CLSE_min,
	bool:CLSE_hasMax,
	Float:CLSE_max,
	CLSAction:CLSE_action,
	String:CLSE_cvar[CLS_CVAR_MAXLEN]
};
#endif

Handle
	ClientSettingsCheckTimer = null;
ArrayList
	ClientSettingsArray;
char
	path[PLATFORM_MAX_PATH];
bool
	bIsMapActive;

public void CLS_OnModuleStart()
{
	BuildPath(Path_SM, path, PLATFORM_MAX_PATH, CLS_LOGFILE);
	
#if SOURCEMOD_V_MINOR > 9
	ClientSettingsArray = new ArrayList(sizeof(CLSEntry));
#else
	ClientSettingsArray = new ArrayList(view_as<int>(CLSEntry));
#endif
	RegConsoleCmd("confogl_clientsettings", _ClientSettings_Cmd, "List Client settings enforced by confogl");
	/* Using Server Cmd instead of admin because these shouldn't really be changed on the fly */
	RegServerCmd("confogl_trackclientcvar", _TrackClientCvar_Cmd, "Add a Client CVar to be tracked and enforced by confogl");
	RegServerCmd("confogl_resetclientcvars", _ResetTracking_Cmd, "Remove all tracked client cvars. Cannot be called during matchmode");
	RegServerCmd("confogl_startclientchecking", _StartClientChecking_Cmd, "Start checking and enforcing client cvars tracked by this plugin");
}

public Action _ClientSettings_Cmd(int client, int args)
{
	int clscount = ClientSettingsArray.Length;
	ReplyToCommand(client, "[Confogl] Tracked Client CVars (Total %d)", clscount);
#if SOURCEMOD_V_MINOR > 9
	for (int i = 0; i < clscount; i++)
	{
		CLSEntry clsetting;
		char message[256], shortbuf[64];
		GetArrayArray(ClientSettingsArray, i, clsetting);
		Format(message, sizeof(message), "[Confogl] Client CVar: %s ", clsetting.CLSE_cvar);
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
			case CLSA_Spec:
			{
				StrCat(message, sizeof(message), "Action: Spec");
			}
			case CLSA_Kick:
			{
				StrCat(message, sizeof(message), "Action: Kick");
			}
			case CLSA_Log:
			{
				StrCat(message, sizeof(message), "Action: Log");
			}
		}
		ReplyToCommand(client, message);
	}
#else
	for (int i = 0; i < clscount; i++)
	{
		int clsetting[CLSEntry];
		char message[256], shortbuf[64];
		GetArrayArray(ClientSettingsArray, i, clsetting[0]);
		Format(message, sizeof(message), "[Confogl] Client CVar: %s ", clsetting[CLSE_cvar]);
		if (clsetting[CLSE_hasMin])
		{
			Format(shortbuf, sizeof(shortbuf), "Min: %f ", clsetting[CLSE_min]);
			StrCat(message, sizeof(message), shortbuf);
		}
		if (clsetting[CLSE_hasMax])
		{
			Format(shortbuf, sizeof(shortbuf), "Max: %f ", clsetting[CLSE_max]);
			StrCat(message, sizeof(message), shortbuf);
		}
		switch (clsetting[CLSE_action])
		{
			case CLSA_Spec:
			{
				StrCat(message, sizeof(message), "Action: Spec");
			}
			case CLSA_Kick:
			{
				StrCat(message, sizeof(message), "Action: Kick");
			}
			case CLSA_Log:
			{
				StrCat(message, sizeof(message), "Action: Log");
			}
		}
		ReplyToCommand(client, message);
	}
#endif
	return Plugin_Handled;
}

public Action _TrackClientCvar_Cmd(int args)
{
	if (args < 3 || args == 4)
	{
		PrintToServer("Usage: confogl_trackclientcvar <cvar> <hasMin> <min> [<hasMax> <max> [<action>]]");
		return Plugin_Handled;
	}
	char sBuffer[CLS_CVAR_MAXLEN], cvar[CLS_CVAR_MAXLEN];
	bool hasMin, hasMax;
	float min, max;
	CLSAction action = CLSA_Spec;
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
	if(ClientSettingsCheckTimer != null)
	{
		PrintToServer("Can't reset tracking in the middle of a match");
		return Plugin_Handled;
	}
	ClearAllSettings();
	PrintToServer("Client CVar Tracking Information Reset!");
	return Plugin_Handled;
}

void ClearAllSettings()
{
	ClientSettingsArray.Clear();
}

public Action _StartClientChecking_Cmd(int args)
{
	_StartTracking();
}

void _StartTracking()
{
	if (ClientSettingsCheckTimer == null)
	{
		ClientSettingsCheckTimer = CreateTimer(CLIENT_CHECK_INTERVAL, _CheckClientSettings_Timer, _, TIMER_REPEAT);
	}
	else
	{
		PrintToServer("Can't start plugin tracking or tracking already started");
	}
}

public Action _CheckClientSettings_Timer(Handle timer)
{
	if (!bIsMapActive) return Plugin_Continue;
	EnforceAllCliSettings();
	return Plugin_Continue;
}

void EnforceAllCliSettings()
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if(IsClientInGame(client) && !IsFakeClient(client))
		{
			EnforceCliSettings(client);
		}
	}
}

void EnforceCliSettings(int client)
{
#if SOURCEMOD_V_MINOR > 9
	CLSEntry clsetting;
	for (int i = 0; i < ClientSettingsArray.Length; i++)
	{
		GetArrayArray(ClientSettingsArray, i, clsetting);
		QueryClientConVar(client, clsetting.CLSE_cvar, _EnforceCliSettings_QueryReply, i);
	}
#else
	int clsetting[CLSEntry];
	for (int i = 0; i < ClientSettingsArray.Length; i++)
	{
		GetArrayArray(ClientSettingsArray, i, clsetting[0]);
		QueryClientConVar(client, clsetting[CLSE_cvar], _EnforceCliSettings_QueryReply, i);
	}
#endif
}

public void _EnforceCliSettings_QueryReply(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any value)
{
	if (!IsClientConnected(client) || !IsClientInGame(client) || IsClientInKickQueue(client))
	{
		// Client disconnected or got kicked already
		return;
	}
	if (result)
	{
		LogToFile(path, "[Confogl] ClientSettings: 无法从 %L 检索 cvar %s, 已从服务器踢出", client, cvarName);
		KickClient(client, "CVar '%s' 受保护或丢失! 作弊?", cvarName);
		return;
	}
	float fCvarVal = StringToFloat(cvarValue);
	int clsetting_index = value;
	
#if SOURCEMOD_V_MINOR > 9
	CLSEntry clsetting;
	GetArrayArray(ClientSettingsArray, clsetting_index, clsetting);
	
	if ((clsetting.CLSE_hasMin && fCvarVal < clsetting.CLSE_min) || (clsetting.CLSE_hasMax && fCvarVal > clsetting.CLSE_max))
	{
		switch (clsetting.CLSE_action)
		{
			case CLSA_Spec:
			{
				LogToFile(path, "[Confogl] ClientSettings: Specing %L for bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
				CPrintToChatAll("{blue}[{default}Confogl{blue}] {olive}%L {default} 因 {green}%s {blue}({default}%f{blue}) {default}的非法值而旁观", client, cvarName, fCvarVal);
				char kickMessage[256] = "Illegal Client Value for ";
				Format(kickMessage, sizeof(kickMessage), "%s%s (%.2f)", kickMessage, cvarName, fCvarVal);
				if (clsetting.CLSE_hasMin)
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting.CLSE_min);
				if (clsetting.CLSE_hasMax)
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting.CLSE_max);
				ChangeClientTeam(client, 1);
				PrintToChat(client, "%s", kickMessage);
			}
			case CLSA_Kick:
			{
				LogToFile(path, "[Confogl] ClientSettings: Kicking %L for bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
				CPrintToChatAll("{blue}[{default}Confogl{blue}] {olive}%L {default} 因 {green}%s {blue}({default}%f{blue}) {default}的非法值而被踢", client, cvarName, fCvarVal);
				char kickMessage[256] = "Illegal Client Value for ";
				Format(kickMessage, sizeof(kickMessage), "%s%s (%.2f)", kickMessage, cvarName, fCvarVal);
				if (clsetting.CLSE_hasMin)
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting.CLSE_min);
				if (clsetting.CLSE_hasMax)
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting.CLSE_max);
				KickClient(client, "%s", kickMessage);
			}
			case CLSA_Log:
			{
				LogToFile(path, "[Confogl] ClientSettings: Client %L has a bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting.CLSE_hasMin, clsetting.CLSE_min, clsetting.CLSE_hasMax, clsetting.CLSE_max);
			}
		}
	}
#else
	int clsetting[CLSEntry];
	GetArrayArray(ClientSettingsArray, clsetting_index, clsetting[0]);
	
	if((clsetting[CLSE_hasMin] && fCvarVal < clsetting[CLSE_min]) || (clsetting[CLSE_hasMax] && fCvarVal > clsetting[CLSE_max]))
	{
		switch (clsetting[CLSE_action])
		{
			case CLSA_Spec:
			{
				LogToFile(path, "[Confogl] ClientSettings: Specing %L for bad %s value (%f). Min: %d %f Max: %d %f", \
				client, cvarName, fCvarVal, clsetting[CLSE_hasMin], clsetting[CLSE_min], clsetting[CLSE_hasMax], clsetting[CLSE_max]);
				CPrintToChatAll("{blue}[{default}Confogl{blue}] {olive}%L {default} 因 {green}%s {blue}({default}%f{blue}) {default}的非法值而旁观", client, cvarName, fCvarVal);
				char kickMessage[256] = "Illegal Client Value for ";
				Format(kickMessage, sizeof(kickMessage), "%s%s (%.2f)", kickMessage, cvarName, fCvarVal);
				if (clsetting[CLSE_hasMin])
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting[CLSE_min]);
				if (clsetting[CLSE_hasMax])
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting[CLSE_max]);
				ChangeClientTeam(client, 1);
				PrintToChat(client, "%s", kickMessage);
			}
			case CLSA_Kick:
			{
				LogToFile(path, "[Confogl] ClientSettings: Kicking %L for bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting[CLSE_hasMin], clsetting[CLSE_min], clsetting[CLSE_hasMax], clsetting[CLSE_max]);
				CPrintToChatAll("{blue}[{default}Confogl{blue}] {olive}%L {default} was kicked for having an illegal value for {green}%s {blue}({default}%f{blue})", client, cvarName, fCvarVal);
				char kickMessage[256] = "Illegal Client Value for ";
				Format(kickMessage, sizeof(kickMessage), "%s%s (%.2f)", kickMessage, cvarName, fCvarVal);
				if (clsetting[CLSE_hasMin])
					Format(kickMessage, sizeof(kickMessage), "%s, Min %.2f", kickMessage, clsetting[CLSE_min]);
				if (clsetting[CLSE_hasMax])
					Format(kickMessage, sizeof(kickMessage), "%s, Max %.2f", kickMessage, clsetting[CLSE_max]);
				KickClient(client, "%s", kickMessage);
			}
			case CLSA_Log:
			{
				LogToFile(path, "[Confogl] ClientSettings: Client %L has a bad %s value (%f). Min: %d %f Max: %d %f", \
					client, cvarName, fCvarVal, clsetting[CLSE_hasMin], clsetting[CLSE_min], clsetting[CLSE_hasMax], clsetting[CLSE_max]);
			}
		}
	}
#endif
}

void _AddClientCvar(const char[] cvar, bool hasMin, float min, bool hasMax, float max, CLSAction action)
{
	if (ClientSettingsCheckTimer != null)
	{
		PrintToServer("Can't track new cvars in the middle of a match");
		return;
	}
	if (!(hasMin || hasMax))
	{
		LogError("[Confogl] ClientSettings: Client CVar %s specified without max or min", cvar);
		return;
	}
	if (hasMin && hasMax && max < min)
	{
		LogError("[Confogl] ClientSettings: Client CVar %s specified max < min (%f < %f)", cvar, max, min);
		return;
	}
	if (strlen(cvar) >= CLS_CVAR_MAXLEN)
	{
		LogError("[Confogl] ClientSettings: CVar Specified (%s) is longer than max cvar length (%d)", cvar, CLS_CVAR_MAXLEN);
		return;
	}
	
#if SOURCEMOD_V_MINOR > 9
	CLSEntry newEntry;
	for (int i = 0; i < ClientSettingsArray.Length; i++)
	{
		GetArrayArray(ClientSettingsArray, i, newEntry);
		if (StrEqual(newEntry.CLSE_cvar, cvar, false))
		{
			LogError("[Confogl] ClientSettings: Attempt to track CVar %s, which is already being tracked.", cvar);
			return;
		}
	}
		
	newEntry.CLSE_hasMin = hasMin;
	newEntry.CLSE_min = min;
	newEntry.CLSE_hasMax = hasMax;
	newEntry.CLSE_max = max;
	newEntry.CLSE_action = action;
	strcopy(newEntry.CLSE_cvar, CLS_CVAR_MAXLEN, cvar);
	
	PushArrayArray(ClientSettingsArray, newEntry);
#else
	int newEntry[CLSEntry];
	for (int i = 0; i < ClientSettingsArray.Length; i++)
	{
		GetArrayArray(ClientSettingsArray, i, newEntry[0]);
		if (StrEqual(newEntry[CLSE_cvar], cvar, false))
		{
			LogError("[Confogl] ClientSettings: Attempt to track CVar %s, which is already being tracked.", cvar);
			return;
		}
	}
		
	newEntry[CLSE_hasMin] = hasMin;
	newEntry[CLSE_min] = min;
	newEntry[CLSE_hasMax] = hasMax;
	newEntry[CLSE_max] = max;
	newEntry[CLSE_action] = action;
	strcopy(newEntry[CLSE_cvar], CLS_CVAR_MAXLEN, cvar);
	
	PushArrayArray(ClientSettingsArray, newEntry[0]);
#endif
}
