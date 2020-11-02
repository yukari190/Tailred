ConVar sb_all_bot_game;

bool IsMatchModeInProgress;
bool MM_bIsPluginsLoaded;

ArrayList aReservedPlugins;

void MM_OnModuleStart()
{
	// Reserved Plugins
	aReservedPlugins = new ArrayList(PLATFORM_MAX_PATH);
	
	sb_all_bot_game = FindConVar("sb_all_bot_game");
	RegAdminCmd("sm_forcematch", ForceMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config. Will unload a previous config if one is loaded");
	RegAdminCmd("sm_fm", ForceMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config. Will unload a previous config if one is loaded");
	RegAdminCmd("sm_softmatch", SoftMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config only if no match is currently running.");
	RegAdminCmd("sm_resetmatch", ResetMatchCmd, ADMFLAG_CONFIG, "Unloads matchmode if it is currently running");
	RegServerCmd("lgofnoc_loadplugin", LgoLoadPluginCmd);
	RegServerCmd("lgofnoc_loadedplugins", LgoLoadedPluginsCmd);
	
	char sBuffer[PLATFORM_MAX_PATH];
	GetPluginFilename(INVALID_HANDLE, sBuffer, sizeof(sBuffer));
	PushArrayString(aReservedPlugins, sBuffer);
}

void MM_OnModuleEnd()
{
	SetConVarInt(sb_all_bot_game, 0);
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins refresh");
}

int MM_PlayerDisconnect()
{
	CreateTimer(60.0, MM_MatchResetTimer);
}

public Action MM_MatchResetTimer(Handle timer)
{
    if (!IsMatchModeInProgress) return;
	if (!IsHumansOnServer())
	{
		PrintToServer("[UL] 没有人想在这台服务器上玩. :(");
		MatchMode_Unload(true, true);
	}
}

// Load a plugin from plugins/ or plugins/optional
public Action LgoLoadPluginCmd(int args)
{
	char plugin[PLATFORM_MAX_PATH], path[PLATFORM_MAX_PATH];
	GetCmdArg(1, plugin, sizeof(plugin));
	BuildPath(Path_SM, path, sizeof(path), "plugins/%s", plugin);
	
	if (FileExists(path))
	{
		ServerCommand("sm plugins load %s", plugin);
		return Plugin_Handled;
	}
	BuildPath(Path_SM, path, sizeof(path), "plugins/optional/%s", plugin);
	if (FileExists(path))
	{
		ServerCommand("sm plugins load optional/%s", plugin);
		return Plugin_Handled;
	}
	
	PrintToServer("Load Failed: Plugin %s not found in plugins/ or plugins/optional/", plugin);
	return Plugin_Handled;
}

public Action LgoLoadedPluginsCmd(int args)
{
	if (IsMatchModeInProgress) {return Plugin_Handled;}
	MM_bIsPluginsLoaded = true;
	MatchMode_Load();
	return Plugin_Handled;
}

public Action ResetMatchCmd(int client, int args)
{
	if (!IsMatchModeInProgress) {return Plugin_Handled;}
	MatchMode_Unload(true, true);
	return Plugin_Handled;
}

public Action SoftMatchCmd(int client, int args)
{
	if (IsMatchModeInProgress) {return Plugin_Handled;}
	
	if (args < 1)
	{
		SetCustomCfg("");
		ReplyToCommand(client, "Must specify a config to use.");
		return Plugin_Handled;
	}
	
	ServerCommand("sm plugins load_unlock");
	UnloadAllPlugins(false);
	
	char configbuf[64];
	GetCmdArg(1, configbuf, sizeof(configbuf));
	RM_UpdateCfgOn(configbuf);
	MatchMode_Load();
	return Plugin_Handled;
}

public Action ForceMatchCmd(int client, int args)
{
	if (!IsMatchModeInProgress)
	{
		SoftMatchCmd(client, args);
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		SetCustomCfg("");
		ReplyToCommand(client, "Must specify a config to use.");
		return Plugin_Handled;
	}
	
	MatchMode_Unload(false, false);
	
	char configbuf[64];
	GetCmdArg(1, configbuf, sizeof(configbuf));
	RM_UpdateCfgOn(configbuf);
	
	CreateTimer(5.0, TimerMMload);
	
	return Plugin_Handled;
}

public Action TimerMMload(Handle timer)
{
	MatchMode_Load();
}

int RM_UpdateCfgOn(const char[] cfgfile)
{
	if (SetCustomCfg(cfgfile)) PrintToChatAll("\x01[\x05Lgofnoc\x01] Using \"\x04%s\x01\" config.", cfgfile);
	else PrintToChatAll("\x01[\x05Lgofnoc\x01] Config \"\x04%s\x01\" not found, using default config!", cfgfile);
}

int MatchMode_Load()
{
	SetConVarInt(sb_all_bot_game, 1);
	if (!MM_bIsPluginsLoaded)
	{
		ServerCommand("sm plugins load_unlock");
		ExecuteConfigCfg("generalfixes.cfg");
		ExecuteConfigCfg("sharedplugins.cfg");
		ExecuteConfigCfg("lgofnoc_plugins.cfg");
		return;
	}
	
	ServerCommand("sm plugins load_lock");
	IsPluginEnabled(true,true);

	ExecuteConfigCfg("lgofnoc_once.cfg");
	
	if (IsMatchModeInProgress) return;
	
	IsMatchModeInProgress = true;
	
	PrintToChatAll("\x01[\x05Lgofnoc\x01] Match mode loaded!");
	
	RestartMapCountdown(5.0);
	PrintToChatAll("\x01[\x05Lgofnoc\x01] Map will restart in 5 seconds!");
}

int MatchMode_Unload(bool reloadmyself = false, bool restartMap = true)
{
	IsMatchModeInProgress = false;
	IsPluginEnabled(true,false);
	MM_bIsPluginsLoaded = false;
	
	ExecuteConfigCfg("lgofnoc_off.cfg");
	
	ServerCommand("sm plugins load_unlock");
	UnloadAllPlugins(reloadmyself);
	
	if (restartMap) RestartMapCountdown(5.0);
	
	PrintToChatAll("Lgofnoc Matchmode unloaded.");
}

// Unload all plugins except one
stock int UnloadAllPlugins(bool reloadmyself = false)
{
	Handle plugit = GetPluginIterator();
	Handle myself = GetMyHandle();
	Handle plugin;
	char namebuf[64];
	char myselfbuf[64];
	GetPluginFilename(myself, myselfbuf, sizeof(myselfbuf));
	
	while (MorePlugins(plugit))
	{
		plugin = ReadPlugin(plugit);
		GetPluginFilename(plugin, namebuf, sizeof(namebuf));
		
		// Prevent double pushing.
		if (FindStringInArray(aReservedPlugins, namebuf) == -1)
			PushArrayString(aReservedPlugins, namebuf);
	}
	CloseHandle(plugit);
	CloseHandle(myself);
	CloseHandle(plugin);
	
	for (int iSize = GetArraySize(aReservedPlugins); iSize > 0; iSize--)
	{
		char sReserved[PLATFORM_MAX_PATH];
		GetArrayString(aReservedPlugins, iSize - 1, sReserved, sizeof(sReserved)); // -1 because of how arrays work. :)
		if (!reloadmyself)
		{
			if (!StrEqual(sReserved, myselfbuf, false)) ServerCommand("sm plugins unload %s", sReserved);
		}
		else
		{
			ServerCommand("sm plugins unload %s", sReserved);
		}
	}
}

int RestartMapCountdown(float time)
{
	CreateTimer(time, RestartMapCallback);
}

public Action RestartMapCallback(Handle timer)
{
	char map[64];
	GetCurrentMap(map, sizeof(map));
	ForceChangeLevel(map, "Restarting Map for Lgofnoc");
}
