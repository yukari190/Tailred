#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

enum NetVarsStruct
{
	mincmdrate = 0,
	maxcmdrate,
	minupdaterate,
	maxupdaterate,
	minrate,
	maxrate
};

Handle g_hSlotsVote;
ConVar rate, sv_minrate, sv_maxrate, sv_minupdaterate, sv_maxupdaterate, sv_mincmdrate, 
  sv_maxcmdrate, sv_client_min_interp_ratio, sv_client_max_interp_ratio, nb_update_frequency, 
  net_splitpacket_maxrate, net_splitrate, fps_max, hMaxPlayers, hVisibleMaxPlayers, hSurvivorLimit, 
  hMaxPlayerZombies;
int iSurvivorLimit, iMaxPlayerZombies, iSlot;
char netvars[6][2];

public Plugin myinfo =
{
	name = "Server Function",
	description = "",
	author = "",
	version = "1.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	hMaxPlayers = FindConVar("sv_maxplayers");
	hVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	
	hSurvivorLimit = FindConVar("survivor_limit");
	hMaxPlayerZombies = FindConVar("z_max_player_zombies");
	
	iSurvivorLimit = GetConVarInt(hSurvivorLimit);
	iMaxPlayerZombies = GetConVarInt(hMaxPlayerZombies);
	
	hSurvivorLimit.AddChangeHook(ConVarChange_MaxPlayers);
	hMaxPlayerZombies.AddChangeHook(ConVarChange_MaxPlayers);
	
	rate = FindConVar("rate");
	sv_minrate = FindConVar("sv_minrate");
	sv_maxrate = FindConVar("sv_maxrate");
	sv_minupdaterate = FindConVar("sv_minupdaterate");
	sv_maxupdaterate = FindConVar("sv_maxupdaterate");
	sv_mincmdrate = FindConVar("sv_mincmdrate");
	sv_maxcmdrate = FindConVar("sv_maxcmdrate");
	sv_client_min_interp_ratio = FindConVar("sv_client_min_interp_ratio");
	sv_client_max_interp_ratio = FindConVar("sv_client_max_interp_ratio");
	nb_update_frequency = FindConVar("nb_update_frequency");
	net_splitpacket_maxrate = FindConVar("net_splitpacket_maxrate");
	net_splitrate = FindConVar("net_splitrate");
	fps_max = FindConVar("fps_max");
	
	SetConVarInt(rate, 100000);
	SetConVarInt(sv_minrate, 60000); // Minimum value of rate.
	SetConVarInt(sv_maxrate, 60000); // Maximum Value of rate.
	SetConVarInt(sv_minupdaterate, 30); // Minimum Value of cl_updaterate.
	SetConVarInt(sv_maxupdaterate, 60); // Maximum Value of cl_updaterate.
	SetConVarInt(sv_mincmdrate, 30); // Minimum value of cl_cmdrate.
	SetConVarInt(sv_maxcmdrate, 60); // Maximum value of cl_cmdrate.
	SetConVarInt(sv_client_min_interp_ratio, 1); // Minimum value of cl_interp_ratio.
	SetConVarInt(sv_client_max_interp_ratio, 1); // Maximum value of cl_interp_ratio.
	SetConVarInt(nb_update_frequency, 0); // The lower the value, the more often common infected and witches get updated (Pathing, and state), very CPU Intensive. (0.1 is default)
	SetConVarInt(net_splitpacket_maxrate, 50000); // 网络调整。
	SetConVarInt(net_splitrate, 2);
	SetConVarInt(fps_max, 0); // 强制CPU为服务器提供的最大FPS数量。
	
	rate.AddChangeHook(ConVarChange);
	sv_minrate.AddChangeHook(ConVarChange);
	sv_maxrate.AddChangeHook(ConVarChange);
	sv_minupdaterate.AddChangeHook(ConVarChange);
	sv_maxupdaterate.AddChangeHook(ConVarChange);
	sv_mincmdrate.AddChangeHook(ConVarChange);
	sv_maxcmdrate.AddChangeHook(ConVarChange);
	sv_client_min_interp_ratio.AddChangeHook(ConVarChange);
	sv_client_max_interp_ratio.AddChangeHook(ConVarChange);
	nb_update_frequency.AddChangeHook(ConVarChange);
	net_splitpacket_maxrate.AddChangeHook(ConVarChange);
	net_splitrate.AddChangeHook(ConVarChange);
	fps_max.AddChangeHook(ConVarChange_FpsMax);
	
	RegConsoleCmd("sm_spectate", Command_Spectate);
	RegConsoleCmd("sm_spec", Command_Spectate);
	RegConsoleCmd("sm_s", Command_Spectate);
	RegConsoleCmd("sm_join", Command_JoinSurvivor);
	RegConsoleCmd("sm_j", Command_JoinSurvivor);
	RegConsoleCmd("sm_slots", SlotsRequest);
	RegConsoleCmd("sm_fixbots", FixBots);
	
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(TeamSay_Callback, "say_team");
	
	HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);
	HookEvent("player_changename", Event_NameChange, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	HookEvent("revive_success", EventReviveSuccess);
}

public void ConVarChange_MaxPlayers(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSurvivorLimit = hSurvivorLimit.IntValue;
	iMaxPlayerZombies = hMaxPlayerZombies.IntValue;
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(rate, 100000);
	SetConVarInt(sv_minrate, 60000);
	SetConVarInt(sv_maxrate, 60000);
	SetConVarInt(sv_minupdaterate, 30);
	SetConVarInt(sv_maxupdaterate, 60);
	SetConVarInt(sv_mincmdrate, 30);
	SetConVarInt(sv_maxcmdrate, 60);
	SetConVarInt(sv_client_min_interp_ratio, 1);
	SetConVarInt(sv_client_max_interp_ratio, 1);
	SetConVarInt(nb_update_frequency, 0);
	SetConVarInt(net_splitpacket_maxrate, 50000);
	SetConVarInt(net_splitrate, 2);
}

public void ConVarChange_FpsMax(ConVar convar, const char[] oldValue, const char[] newValue) { SetConVarInt(fps_max, 0); }

public void OnConfigsExecuted()
{
    GetConVarString(sv_mincmdrate, netvars[mincmdrate], sizeof(netvars));
    GetConVarString(sv_maxcmdrate, netvars[maxcmdrate], sizeof(netvars));
    GetConVarString(sv_minupdaterate, netvars[minupdaterate], sizeof(netvars));
    GetConVarString(sv_maxupdaterate, netvars[maxupdaterate], sizeof(netvars));
    GetConVarString(sv_minrate, netvars[minrate], sizeof(netvars));
    GetConVarString(sv_maxrate, netvars[maxrate], sizeof(netvars));
}

public void OnClientSettingsChanged(int client)
{
	if (IsValidInGame(client) && !IsFakeClient(client)) AdjustRates(client);
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidInGame(client) && !IsFakeClient(client) && GetClientCount(true) < MaxClients)
	{
		char rawmsg[301];
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 加入游戏.", 1, rawmsg);
		CPrintToChatAll("%s", rawmsg);
	}
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	if (IsValidSpectator(client) && impulse == 100)
	{
		SetEntProp(client, Prop_Send, "m_bNightVisionOn", (GetEntProp(client, Prop_Send, "m_bNightVisionOn") == 0) ? 1 : 0);
	}
	return Plugin_Continue;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client) || IsFakeClient(client)) return;
	SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	CreateTimer(1.0, TimerAdjustRates, client);
}

public Action TimerAdjustRates(Handle timer, any client)
{
	AdjustRates(client);
}

//Event
public Action Event_ServerConVar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}

public Action Event_NameChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (IsValidSpectator(client)) return Plugin_Handled;
    return Plugin_Continue;
}

public Action EventReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetBool("lastlife"))
	{
		int target = GetClientOfUserId(event.GetInt("subject"));
		if (!IsValidInGame(target)) return;
		PrintHintTextToAll("%N 黑白了!", target);
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidInGame(client) && !IsFakeClient(client))
	{
		char rawmsg[301], reason[65];
		event.GetString("reason", reason, sizeof(reason));
		ReplaceString(reason, sizeof(reason), "\n", " ");
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 断开连接. {O}原因: {W}%s", 1, rawmsg, reason);
		CPrintToChatAll("%s", rawmsg);
	}
}

// Command
public Action Say_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    if (sayWord[0] == '!' || sayWord[0] == '/') return Plugin_Handled;
    return Plugin_Continue; 
}

public Action TeamSay_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    if (sayWord[0] == '!' || sayWord[0] == '/') return Plugin_Handled;
    else if (!IsValidSpectator(client))
    {
        char sChat[256];
        GetCmdArgString(sChat, sizeof(sChat));
        StripQuotes(sChat);
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsConnectedAndInGame(i) && GetClientTeam(i) == TEAM_SPECTATOR)
            {
                CPrintToChat(i, "{W}%s%N {W}: %s", IsValidSurvivor(client) ? "(生还者) {B}" : "(感染者) {R}", client, sChat);
            }
        }
    }
    return Plugin_Continue;
}


public Action FixBots(int client, int args)
{
	CreateTimer(0.1, FillBots);
	return Plugin_Handled;
}

public Action FillBots(Handle timer)
{
	if (GetTeamClientCount(TEAM_SURVIVOR) < iSurvivorLimit) 
	{
		ServerCommand("sb_add");
		CreateTimer(0.1, FillBots);
	}
}

public Action Command_Spectate(int client, int args)
{
	if (!IsValidInGame(client)) return Plugin_Handled;
	if (GetClientTeam(client) == TEAM_SURVIVOR)
	{
		ChangeClientTeamEx(client, TEAM_SPECTATOR, true);
		PrintToChatAll("\x01玩家 \x03%N\x01 表示要去趴会_(:зゝ∠)_", client);
	}
	else if (GetClientTeam(client) == TEAM_INFECTED)
	{
		if (GetInfectedClass(client) != ZC_TANK)
		{
			ForcePlayerSuicide(client);
		}
		ChangeClientTeamEx(client, TEAM_SPECTATOR, true);
		PrintToChatAll("\x01玩家 \x03%N\x01 表示要去趴会_(:зゝ∠)_", client);
	}
	else if (GetClientTeam(client) == TEAM_SPECTATOR)
	{
		ChangeClientTeamEx(client, TEAM_INFECTED, true);
		CreateTimer(0.1, RespecDelay_Timer, client);
	}
	return Plugin_Handled;
}

public Action RespecDelay_Timer(Handle timer, any client)
{
	ChangeClientTeamEx(client, TEAM_SPECTATOR, true);
}

public Action Command_JoinSurvivor(int client, int args)
{
	if (!IsValidInGame(client)) return Plugin_Handled;
	ChangeClientTeamEx(client, TEAM_SURVIVOR, false);
	return Plugin_Handled;
}

public Action SlotsRequest(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	iSlot = StringToInt(buffer);
	if (iSlot < 0 || iSlot > 24)
	{
		PrintToServer("[Slots]有效范围 0 - 24");
		CPrintToChatAll("{B}[{W}Slots{B}] {W}有效范围 0 - 24");
		return Plugin_Handled;
	}
	if (!IsValidInGame(client) || IsClientAdmin(client)) SetMaxPlayers(iSlot);
	else if (StartVote(client, buffer)) FakeClientCommand(client, "Vote Yes");
	return Plugin_Handled;
}

//Vote Start
bool StartVote(int client, char[] sbuff)
{
	if (!NativeVotes_IsNewVoteAllowed())
	{
		PrintToChat(client, "[NativeVotes] 现在不能发起投票！");
		return false;
	}
	int iNumPlayers = 0, iPlayers[MAXPLAYERS+1];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsConnectedAndInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1) continue;
		iPlayers[iNumPlayers++] = i;
	}
	char sBuffer[64];
	g_hSlotsVote = NativeVotes_Create(VoteResultHandler, NativeVotesType_Custom_YesNo);
	Format(sBuffer, sizeof(sBuffer), "将人数设置为 '%s'?", sbuff);
	NativeVotes_SetDetails(g_hSlotsVote, sBuffer);
	NativeVotes_SetInitiator(g_hSlotsVote, client);
	NativeVotes_Display(g_hSlotsVote, iPlayers, iNumPlayers, 20);
	return true;
}

public int VoteResultHandler(Handle vote, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select: PrintToChatAll("玩家 %N 已投票", param1);

		case MenuAction_VoteCancel:
		{
			if (param1 == VoteCancel_NoVotes) NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			else NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
		}

		case MenuAction_VoteEnd:
		{
			if (param1 == NATIVEVOTES_VOTE_NO) NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			else if (vote == g_hSlotsVote)
			{
				NativeVotes_DisplayPass(vote, "正在修改人数...");
				SetMaxPlayers(iSlot);
			}
		}

		case MenuAction_End:
		{
			g_hSlotsVote = INVALID_HANDLE;
			NativeVotes_Close(vote);
		}
	}
}

//Utility
void AdjustRates(int client)
{
	if (GetClientTeam(client) <= 1)
	{
		SendConVarValue(client, sv_mincmdrate, "30");
		SendConVarValue(client, sv_maxcmdrate, "30");
		SendConVarValue(client, sv_minupdaterate, "30");
		SendConVarValue(client, sv_maxupdaterate, "30");
		SendConVarValue(client, sv_minrate, "10000");
		SendConVarValue(client, sv_maxrate, "10000");
		SetClientInfo(client, "cl_updaterate", "30");
		SetClientInfo(client, "cl_cmdrate", "30");
		SetClientInfo(client, "rate", "10000");
	}
	else
	{
		SendConVarValue(client, sv_mincmdrate, netvars[mincmdrate]);
		SendConVarValue(client, sv_maxcmdrate, netvars[maxcmdrate]);
		SendConVarValue(client, sv_minupdaterate, netvars[minupdaterate]);
		SendConVarValue(client, sv_maxupdaterate, netvars[maxupdaterate]);
		SendConVarValue(client, sv_minrate, netvars[minrate]);
		SendConVarValue(client, sv_maxrate, netvars[maxrate]);
		SetClientInfo(client, "cl_updaterate", netvars[maxupdaterate]);
		SetClientInfo(client, "cl_cmdrate", netvars[maxcmdrate]);
		SetClientInfo(client, "rate", netvars[maxrate]);
	}
}

bool IsLanIP(char src[16])
{
	char ip4[4][4];
	int ipnum;
	if (ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		if ((ipnum >= 655360 && ipnum < 655360+65535) || (ipnum >= 11276288 && ipnum < 11276288+4095) || (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			return true;
		}
	}
	return false;
}

void PrintFormattedMessageToAll(char rawmsg[301], int client)
{
	char steamid[256], ip[16], country[46];
	bool bIsLanIp;
	
	GetClientAuthId(client, AuthId_Steam3, steamid, sizeof(steamid));
	GetClientIP(client, ip, sizeof(ip)); 
	bIsLanIp = IsLanIP(ip);
	if (!GeoipCountry(ip, country, sizeof(country)))
	{
		if (bIsLanIp) Format(country, sizeof(country), "%s", "局域网", LANG_SERVER);
		else Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	}
	if (StrEqual(country, "")) Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	if (StrContains(country, "United", false) != -1 || StrContains(country, "Republic", false) != -1 || 
	StrContains(country, "Federation", false) != -1 || StrContains(country, "Island", false) != -1 || 
	StrContains(country, "Netherlands", false) != -1 || StrContains(country, "Isle", false) != -1 || 
	StrContains(country, "Bahamas", false) != -1 || StrContains(country, "Maldives", false) != -1 || 
	StrContains(country, "Philippines", false) != -1 || 
	StrContains(country, "Vatican", false) != -1) Format(country, sizeof(country), "The %s", country);
	
	Format(rawmsg, sizeof(rawmsg), "%s {O}%N {G}%s{W} ({O}%s{W}), ", IsClientAdmin(client) ? "管理员" : "玩家", 
	client, steamid, country);
}

void SetMaxPlayers(int amount)
{
	SetConVarInt(hMaxPlayers, amount);
	SetConVarInt(hVisibleMaxPlayers, amount);
	PrintToServer("[Slots]服务器人数设置为 %i", amount);
	CPrintToChatAll("{B}[{W}Slots{B}]{W}服务器人数设置为 {B}%i", amount);
}

bool ChangeClientTeamEx(int client, int team, bool force = false)
{
	if (GetClientTeam(client) == team) return true;
	else if (!force && GetTeamHumanCount(team) >= GetTeamMaxHumans(team))
	{
		PrintToChat(client, "您选择的团队已经满了.");
		return false;
	}
	if (team != TEAM_SURVIVOR)
	{
		ChangeClientTeam(client, team);
		return true;
	}
	else
	{
		int bot = FindSurvivorBot();
		if (bot > 0)
		{
			ClientCheatCommand(client, "sb_takecontrol");
			if (!IsValidSurvivor(client)) ClientCheatCommand(client, "jointeam 2");
			return true;
		}
	}
	return false;
}

int FindSurvivorBot()
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0 && IsFakeClient(index)) return index;
	}
	return -1;
}

int GetTeamHumanCount(int team)
{
	int humans = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsConnectedAndInGame(client) && !IsFakeClient(client) && GetClientTeam(client) == team) humans++;
	}
	return humans;
}

int GetTeamMaxHumans(int team)
{
	if (team == TEAM_SURVIVOR) return iSurvivorLimit;
	else if (team == TEAM_INFECTED) return iMaxPlayerZombies;
	return MaxClients;
}
