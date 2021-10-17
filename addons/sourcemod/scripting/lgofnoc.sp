#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#undef REQUIRE_EXTENSIONS
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

#define CUSTOM_CFG_DIR "cfgogl"

#define MATCH_EXECCFG_ON "confogl.cfg"  //Execute this config file upon match mode starts and every map after that.
#define MATCH_EXECCFG_PLUGINS "generalfixes.cfg;server_plugins.cfg;sharedplugins.cfg;confogl_plugins.cfg"  //Execute this config file upon match mode starts. This will only get executed once and meant for plugins that needs to be loaded.
#define MATCH_EXECCFG_OFF "confogl_off.cfg"  //Execute this config file upon match mode ends.

#define MATCH_VOTE "configs/matchmodes/matchmodes.txt"

#define SV_TAG_SIZE 64

public Plugin myinfo = 
{
	name = "LGOFNOC Config Manager",
	author = "Confogl Team, Yukari190",
	description = "A competitive configuration management system for Source games",
	version = "1.4",
	url = ""
}

enum struct CVSEntry
{
	ConVar CVSE_cvar;
	char CVSE_oldval[SV_TAG_SIZE];
	char CVSE_newval[SV_TAG_SIZE];
}

ArrayList CvarSettingsArray;

ConVar hAllBotGame;

char 
	cfgPath[PLATFORM_MAX_PATH],
	customCfgPath[PLATFORM_MAX_PATH],
	matchName[32],
	map[64];

int DirSeparator;

bool 
	bTrackingStarted,
	bIsMatchModeLoaded;

KeyValues g_hModesKV = null;

bool IsHumansOnServer() { for (int i = 1; i <= MaxClients; i++) { if (IsClientConnected(i) && !IsFakeClient(i)) { return true; } } return false; }

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("LGO_BuildConfigPath", _native_BuildConfigPath);
	RegPluginLibrary("lgofnoc");
	return APLRes_Success;
}

public any _native_BuildConfigPath(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(3, len);
	char[] filename = new char[len+1];
	GetNativeString(3, filename, len+1);
	len = GetNativeCell(2);
	char[] buf = new char[len];
	if (customCfgPath[0])
	{
		Format(buf, len, "%s%s", customCfgPath, filename);
		if (!FileExists(buf))
		{
			LogError("[Lgofnoc] Custom config not available: %s", buf);
		}
	}
	SetNativeString(1, buf, len);
}

public void OnPluginStart()
{
	BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "../../cfg/");
	DirSeparator = cfgPath[strlen(cfgPath)-1];
	
	char sBuffer[128];
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), MATCH_VOTE);
	if (!FileToKeyValues(g_hModesKV, sBuffer))
	{
		delete g_hModesKV;
		LogError("[LGO] 找不到 matchmodes.txt!");
	}
	
	hAllBotGame = FindConVar("sb_all_bot_game");
	RegAdminCmd("sm_forcematch", ForceMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config. Will unload a previous config if one is loaded");
	RegAdminCmd("sm_softmatch", SoftMatchCmd, ADMFLAG_CONFIG, "Loads matchmode on a given config only if no match is currently running.");
	RegServerCmd("lgo_loadplugin", LgoLoadPluginCmd);
	RegServerCmd("lgo_start", LgoStartCmd);
	
	CvarSettingsArray = new ArrayList(sizeof(CVSEntry));
	RegServerCmd("lgo_addcvar", CVS_AddCvar_Cmd, "Add a ConVar to be set by Lgofnoc");
	RegServerCmd("confogl_addcvar", CVS_AddCvar_Cmd, "Add a ConVar to be set by Confogl");
	RegServerCmd("lgo_setcvars", CVS_SetCvars_Cmd, "Starts enforcing ConVars that have been added.");
	RegServerCmd("confogl_setcvars", CVS_SetCvars_Cmd, "Starts enforcing ConVars that have been added.");
	RegServerCmd("lgo_resetcvars", CVS_ResetCvars_Cmd, "Resets enforced ConVars.  Cannot be used during a match!");
	RegServerCmd("confogl_resetcvars", CVS_ResetCvars_Cmd, "Resets enforced ConVars.  Cannot be used during a match!");
	
	RegConsoleCmd("sm_match", MatchRequest);
}

public void OnPluginEnd()
{
	ClearAllCvarSettings();
	delete CvarSettingsArray;
	
	SetConVarInt(hAllBotGame, 0);
	ServerCommand("sm plugins load_unlock");
	ServerCommand("sm plugins refresh");
	ServerCommand("changelevel %s", map);
}

public void OnMapStart()
{
	GetCurrentMap(map, sizeof(map));
}

public void OnConfigsExecuted()
{
	if (bTrackingStarted) SetEnforcedCvars();
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client)) return;
	CreateTimer(60.0, MatchResetTimer);
}

public Action MatchResetTimer(Handle timer)
{
	if (!bIsMatchModeLoaded) return;
	if (!IsHumansOnServer())
	{
		PrintToServer("[UL] 没有人想在这台服务器上玩. :(");
		MatchMode_Unload(true, true);
	}
}

// Commands
public Action MatchRequest(int client, int args)
{
	if (g_hModesKV == null || !client) return Plugin_Handled;
	char sInfo[64], sBuffer[64];
	KvRewind(g_hModesKV);
	if (KvJumpToKey(g_hModesKV, sInfo) && KvGotoFirstSubKey(g_hModesKV))
	{
		Handle hMenu = CreateMenu(ConfigsMenuHandler);
		SetMenuTitle(hMenu, "选择 Match 模式:");
		do
		{
			KvGetSectionName(g_hModesKV, sInfo, sizeof(sInfo));
			KvGetString(g_hModesKV, "name", sBuffer, sizeof(sBuffer));
			AddMenuItem(hMenu, sInfo, sBuffer);
		} while (KvGotoNextKey(g_hModesKV));
		DisplayMenu(hMenu, client, 20);
	}
	return Plugin_Handled;
}

public int ConfigsMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[64], sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		strcopy(matchName, sizeof(matchName), sInfo);
		Format(sBuffer, sizeof(sBuffer), "将配置更改为 '%s'?", sBuffer);
		StartVote(param1, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

public Action CVS_SetCvars_Cmd(int args)
{
	if (bIsMatchModeLoaded)
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
		PrintToServer("Usage: confogl_addcvar <cvar> <newValue>");
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
	if (newCvar == null)
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
	if (bIsMatchModeLoaded)
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
	
	BuildPath(Path_SM, path, sizeof(path), "plugins/optional/LGO/%s", plugin);
	if (FileExists(path))
	{
		ServerCommand("sm plugins load optional/LGO/%s", plugin);
		return Plugin_Handled;
	}
	
	PrintToServer("Load Failed: Plugin %s not found in plugins/ or plugins/optional/", plugin);
	return Plugin_Handled;
}

public Action LgoStartCmd(int args)
{
	if (bIsMatchModeLoaded) {return Plugin_Handled;}
	MatchMode_Load(true);
	return Plugin_Handled;
}

public Action SoftMatchCmd(int client, int args)
{
	if (bIsMatchModeLoaded) {return Plugin_Handled;}
	
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
	if (!bIsMatchModeLoaded)
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
	if (!strlen(cfgname)) return;
	
	Format(customCfgPath, sizeof(customCfgPath), "%s%s%c%s", cfgPath, CUSTOM_CFG_DIR, DirSeparator, cfgname);
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

int MatchMode_Load(bool LgoStart = false)
{
	if (bIsMatchModeLoaded) return;
	
	SetConVarInt(hAllBotGame, 1);
	if (!LgoStart)
	{
		ServerCommand("sm plugins load_unlock");
		char sPieces[32][256];
		int iNumPieces = ExplodeString(MATCH_EXECCFG_PLUGINS, ";", sPieces, sizeof(sPieces), sizeof(sPieces[]));
		for(int i = 0; i < iNumPieces; i++)
		{
			ExecuteConfigCfg(sPieces[i]);
		}
		return;
	}
	ServerCommand("sm plugins load_lock");
	
	bIsMatchModeLoaded = true;

	ExecuteConfigCfg(MATCH_EXECCFG_ON);
	
	PrintToChatAll("\x01[\x05Lgofnoc\x01] Match mode loaded!");
	
	RestartMapCountdown(5.0);
	PrintToChatAll("\x01[\x05Lgofnoc\x01] Map will restart in 5 seconds!");
}

int MatchMode_Unload(bool unloadmyself = false, bool restartMap = true)
{
	bIsMatchModeLoaded = false;
	
	ExecuteConfigCfg(MATCH_EXECCFG_OFF);
	
	ServerCommand("sm plugins load_unlock");
	UnloadAllPlugins(unloadmyself);
	
	if (restartMap) RestartMapCountdown(5.0);
	
	PrintToChatAll("Lgofnoc Matchmode unloaded.");
}

// Unload all plugins except one
// 参考了 Sir 的 Predictable Plugin Unloader 插件
stock int UnloadAllPlugins(bool unloadmyself = false)
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
		if (!unloadmyself)
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

void RestartMapCountdown(float time)
{
	CreateTimer(time, RestartMapCallback);
}

public Action RestartMapCallback(Handle timer)
{
	ForceChangeLevel(map, "Restarting Map for Lgofnoc");
}


bool StartVote(int client, char[] sArgument)
{
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "[Lgofnoc] 无法开始投票.");
		return false;
	}
	if (GetClientTeam(client) <= 1)
	{
		PrintToChat(client, "[Lgofnoc] 观众不允许投票.");
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) <= 1) continue;
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < 1)
		{
			PrintToChat(client, "[Lgofnoc] 没有足够的玩家无法开始投票.");
			return false;
		}
		Handle hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hVote, sArgument);
		SetBuiltinVoteInitiator(hVote, client);
		SetBuiltinVoteResultCallback(hVote, VoteResultHandler);
		DisplayBuiltinVote(hVote, iPlayers, iNumPlayers, 30);
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	PrintToChat(client, "[Lgofnoc] 现在无法开始投票.");
	return false;
}

public int VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public int VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, " ");
				ServerCommand("sm_forcematch %s", matchName);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}
