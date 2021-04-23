#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define SV_TAG_SIZE 64

public Plugin myinfo = 
{
	name = "LGOFNOC Config Manager",
	author = "Confogl Team",
	description = "A competitive configuration management system for Source games",
	version = "1.3",
	url = ""
}

enum struct CVSEntry
{
	ConVar CVSE_cvar;
	char CVSE_oldval[SV_TAG_SIZE];
	char CVSE_newval[SV_TAG_SIZE];
}

ArrayList CvarSettingsArray;
bool bTrackingStarted;

static const char customCfgDir[12] = "lgofnoc";
static char configsPath[PLATFORM_MAX_PATH];
static char cfgPath[PLATFORM_MAX_PATH];
static char cfgPath2[PLATFORM_MAX_PATH];
static char customCfgPath[PLATFORM_MAX_PATH];
static int DirSeparator;

ConVar sb_all_bot_game;

bool IsMatchModeInProgress;
bool bIsPluginsLoaded;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	RegPluginLibrary(customCfgDir);
	return APLRes_Success;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, configsPath, sizeof(configsPath), "configs/lgofnoc/");
	BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "../../cfg/");
	BuildPath(Path_SM, cfgPath2, sizeof(cfgPath2), "../../cfg/lgofnoc/shared/");
	DirSeparator = cfgPath[strlen(cfgPath)-1];
	
	sb_all_bot_game = FindConVar("sb_all_bot_game");
	RegAdminCmd("sm_forcematch", ForceMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config. Will unload a previous config if one is loaded");
	RegAdminCmd("sm_softmatch", SoftMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config only if no match is currently running.");
	RegServerCmd("lgofnoc_loadplugin", LgoLoadPluginCmd);
	RegServerCmd("lgofnoc_loadedplugins", LgoLoadedPluginsCmd);
	
	CvarSettingsArray = new ArrayList(sizeof(CVSEntry));
	RegServerCmd("lgofnoc_addcvar", CVS_AddCvar_Cmd, "Add a ConVar to be set by Lgofnoc");
	RegServerCmd("lgofnoc_setcvars", CVS_SetCvars_Cmd, "Starts enforcing ConVars that have been added.");
	RegServerCmd("lgofnoc_resetcvars", CVS_ResetCvars_Cmd, "Resets enforced ConVars.  Cannot be used during a match!");
	
	HookEvent("player_disconnect", PlayerDisconnect_Event);
}

public void OnPluginEnd()
{
	ClearAllCvarSettings();
	delete CvarSettingsArray;
	
	SetConVarInt(sb_all_bot_game, 0);
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins refresh");
}

public void OnConfigsExecuted()
{
	if (bTrackingStarted) SetEnforcedCvars();
}

/* Events */
public Action PlayerDisconnect_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidEntity(client) || !IsClientInGame(client) || IsFakeClient(client)) return;
	CreateTimer(60.0, MatchResetTimer);
}

public Action MatchResetTimer(Handle timer)
{
    if (!IsMatchModeInProgress) return;
	if (!IsHumansOnServer())
	{
		PrintToServer("[UL] 没有人想在这台服务器上玩. :(");
		MatchMode_Unload(true, true);
	}
}

// Commands
public Action CVS_SetCvars_Cmd(int args)
{
	if (IsPluginEnabled())
	{
		if (bTrackingStarted)
		{
			PrintToServer("Tracking has already been started");
			return;
		}
		SetEnforcedCvars();
		bTrackingStarted = true;
	}
}

public Action CVS_AddCvar_Cmd(int args)
{
	if (args != 2)
	{
		PrintToServer("Usage: lgofnoc_addcvar <cvar> <newValue>");
		return Plugin_Handled;
	}
	char cvar[SV_TAG_SIZE], newval[SV_TAG_SIZE];
	GetCmdArg(1, cvar, sizeof(cvar));
	GetCmdArg(2, newval, sizeof(newval));
	
	if (bTrackingStarted) return Plugin_Handled;
	if (strlen(cvar) >= SV_TAG_SIZE)
	{
		LogError("[Lgofnoc] CvarSettings: CVar Specified (%s) is longer than max cvar/value length (%d)", cvar, SV_TAG_SIZE);
		return Plugin_Handled;
	}
	if (strlen(newval) >= SV_TAG_SIZE)
	{
		LogError("[Lgofnoc] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", newval, SV_TAG_SIZE);
		return Plugin_Handled;
	}
	ConVar newCvar = FindConVar(cvar);
	if (newCvar == INVALID_HANDLE)
	{
		LogError("[Lgofnoc] CvarSettings: Could not find CVar specified (%s)", cvar);
		return Plugin_Handled;
	}
	CVSEntry newEntry;
	char cvarBuffer[SV_TAG_SIZE];
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, newEntry, sizeof(newEntry));
		GetConVarName(newEntry.CVSE_cvar, cvarBuffer, SV_TAG_SIZE);
		if (StrEqual(cvar, cvarBuffer, false))
		{
			LogError("[Lgofnoc] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", cvar);
			return Plugin_Handled;
		}
	}
	GetConVarString(newCvar, cvarBuffer, SV_TAG_SIZE);
	newEntry.CVSE_cvar = newCvar;
	strcopy(newEntry.CVSE_oldval, SV_TAG_SIZE, cvarBuffer);
	strcopy(newEntry.CVSE_newval, SV_TAG_SIZE, newval);
	newCvar.AddChangeHook(CVS_ConVarChange);
	CvarSettingsArray.PushArray(newEntry, sizeof(newEntry));
	return Plugin_Handled;
}

public Action CVS_ResetCvars_Cmd(int args)
{
	if (IsPluginEnabled())
	{
		PrintToServer("Can't reset tracking in the middle of a match");
		return Plugin_Handled;
	}
	ClearAllCvarSettings();
	PrintToServer("Server CVar Tracking Information Reset!");
	return Plugin_Handled;
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
	bIsPluginsLoaded = true;
	MatchMode_Load();
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
	SetCustomCfg(configbuf);
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
	SetCustomCfg(configbuf);
	
	CreateTimer(5.0, TimerMMload);
	
	return Plugin_Handled;
}

public Action TimerMMload(Handle timer)
{
	MatchMode_Load();
}


void SetCustomCfg(const char[] cfgname)
{
	if (!strlen(cfgname) || StrEqual(cfgname, "shared", false)) return;
	
	Format(customCfgPath, sizeof(customCfgPath), "%s%s%c%s", cfgPath, customCfgDir, DirSeparator, cfgname);
	if (!DirExists(customCfgPath))
	{
		LogError("[Configs] Custom config directory %s does not exist!", customCfgPath);
		// Revert customCfgPath
		customCfgPath[0]=0;
		return;
	}
	int thislen = strlen(customCfgPath);
	if (thislen+1 < sizeof(customCfgPath))
	{
		customCfgPath[thislen] = DirSeparator;
		customCfgPath[thislen+1] = 0;
	}
	else
	{
		LogError("[Configs] Custom config directory %s path too long!", customCfgPath);
		customCfgPath[0]=0;
	}
}

int ExecuteConfigCfg(const char[] sFileName)
{
	if (strlen(sFileName) == 0) return;
	char sFilePath[PLATFORM_MAX_PATH];
	if (customCfgPath[0])
	{
		Format(sFilePath, sizeof(sFilePath), "%s%s", customCfgPath, sFileName);
		if (FileExists(sFilePath))
		{
			ServerCommand("exec %s%s", customCfgPath[strlen(cfgPath)], sFileName);
			return;
		}
	}
	Format(sFilePath, sizeof(sFilePath), "%s%s", cfgPath, sFileName);
	
	if (FileExists(sFilePath)) ServerCommand("exec %s", sFileName);
	else LogError("[Configs] Could not execute server config \"%s\", file not found", sFilePath);
}

int ExecuteConfigSharedCfg(const char[] sFileName)
{
	if (strlen(sFileName) == 0) return;
	char sFilePath[PLATFORM_MAX_PATH];
	Format(sFilePath, sizeof(sFilePath), "%s%s", cfgPath2, sFileName);
	
	if (FileExists(sFilePath)) ServerCommand("exec %s%s", cfgPath2[strlen(cfgPath)], sFileName);
	else LogError("[Configs] Could not execute server config \"%s\", file not found", sFilePath);
}

int ClearAllCvarSettings()
{
	bTrackingStarted = false;
	CVSEntry cvsetting;
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, cvsetting, sizeof(cvsetting));
		UnhookConVarChange(cvsetting.CVSE_cvar, CVS_ConVarChange);
		SetConVarString(cvsetting.CVSE_cvar, cvsetting.CVSE_oldval);
	}
	ClearArray(CvarSettingsArray);
}

int SetEnforcedCvars()
{
	CVSEntry cvsetting;
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, cvsetting, sizeof(cvsetting));
		SetConVarString(cvsetting.CVSE_cvar, cvsetting.CVSE_newval);
	}
}

public int CVS_ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (bTrackingStarted)
	{
		char name[SV_TAG_SIZE];
		GetConVarName(convar, name, sizeof(name));
		PrintToChatAll("!!! [Lgofnoc] Tracked Server CVar \"%s\" changed from \"%s\" to \"%s\" !!!", name, oldValue, newValue);
	}
}

int MatchMode_Load()
{
	SetConVarInt(sb_all_bot_game, 1);
	if (!bIsPluginsLoaded)
	{
		ServerCommand("sm plugins load_unlock");
		ExecuteConfigSharedCfg("sharedplugins.cfg");
		ExecuteConfigCfg("lgofnoc_plugins.cfg");
		return;
	}
	
	ServerCommand("sm plugins load_lock");
	IsPluginEnabled(true,true);

	ExecuteConfigSharedCfg("sharedcvars.cfg");
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
	bIsPluginsLoaded = false;
	
	ExecuteConfigCfg("lgofnoc_off.cfg");
	
	ServerCommand("sm plugins load_unlock");
	UnloadAllPlugins(reloadmyself);
	
	if (restartMap) RestartMapCountdown(5.0);
	
	PrintToChatAll("Lgofnoc Matchmode unloaded.");
}

// Unload all plugins except one
// 参考了 Sir 的 Predictable Plugin Unloader 插件
stock int UnloadAllPlugins(bool reloadmyself = false)
{
	// Reserved Plugins
	ArrayList aReservedPlugins = new ArrayList(PLATFORM_MAX_PATH);
	Handle myself = GetMyHandle();
	char myselfbuf[64];
	GetPluginFilename(myself, myselfbuf, sizeof(myselfbuf));
	PushArrayString(aReservedPlugins, myselfbuf);
	delete myself;
	
	Handle plugit = GetPluginIterator();
	Handle plugin;
	char namebuf[64];
	
	while (MorePlugins(plugit))
	{
		plugin = ReadPlugin(plugit);
		GetPluginFilename(plugin, namebuf, sizeof(namebuf));
		
		// Prevent double pushing.
		if (!StrEqual(myselfbuf, namebuf, false))
			PushArrayString(aReservedPlugins, namebuf);
	}
	delete plugit;
	delete plugin;
	
	for (int iSize = GetArraySize(aReservedPlugins); iSize > 0; iSize--)
	{
		char sReserved[PLATFORM_MAX_PATH];
		GetArrayString(aReservedPlugins, iSize - 1, sReserved, sizeof(sReserved)); // -1 because of how arrays work. :)
		if (!reloadmyself)
		{
			if (!StrEqual(myselfbuf, sReserved, false)) ServerCommand("sm plugins unload %s", sReserved);
		}
		else
		{
			ServerCommand("sm plugins unload %s", sReserved);
		}
	}
	delete aReservedPlugins;
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

bool bIsPluginEnabled;

bool IsPluginEnabled(bool bSetStatus = false, bool bStatus = false)
{
	if (bSetStatus) bIsPluginEnabled = bStatus;
	return bIsPluginEnabled;
}

bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}
