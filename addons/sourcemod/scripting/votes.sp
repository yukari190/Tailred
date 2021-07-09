#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <[LIB]builtinvotes>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#include <[LIB]l4d2library>
#include <[LIB]readyup>

#define PLAYER_LIMIT 1

enum VoteType
{
	VoteType_None,
	VoteType_SetMaxPlayers,
	VoteType_RestoreHealth,
	VoteType_ChangeMap,
	VoteType_KickSpec,
	VoteType_Match,
	VoteType_SetTank
};

KeyValues g_hInfoKV;
KeyValues g_hModesKV;
char TargetMap_Code[128];
char mapname[64];
char g_sCfg[32];
int iSlot;
int g_iTankFlow;
VoteType iVoteType;

native void SetTankPercent(int percent);

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("SetTankPercent");
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sBuffer[128];
	g_hInfoKV = new KeyValues("MapLists");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/shared/maplists.txt");
	if (!FileToKeyValues(g_hInfoKV, sBuffer)) LogMessage("找不到 <maplists.txt>.");
	
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/shared/matchmodes.txt");
	if (!FileToKeyValues(g_hModesKV, sBuffer)) LogError("[VM] 无法加载 matchmodes.txt!");
	
	RegConsoleCmd("sm_match", MatchRequest);
	RegConsoleCmd("sm_slots", SlotsRequest);
	RegConsoleCmd("sm_rhp", Command_RestoreHealth);
	RegConsoleCmd("sm_vcm", ChangeMaps);
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	RegConsoleCmd("sm_settank", SetTank_Command);
	
	HookEvent("finale_win", FinaleWin_Event, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
}

public Action FinaleWin_Event(Event event, const char[] name, bool dontBroadcast)
{
	CheckMapForChange();
}

int CheckMapForChange()
{
	char sInfo[64];
	KvRewind(g_hInfoKV);
	if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
	{
		do
		{
			KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
			if (StrContains(mapname, sInfo[3], false) != -1)
			{
				KvGetString(g_hInfoKV, "nextmap", TargetMap_Code, sizeof(TargetMap_Code));
				CreateTimer(L4D2_IsVersus() ? 6.0 : 3.0, ChangeLevel);
				break;
			}
		}
		while (KvGotoNextKey(g_hInfoKV));
	}
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!L4D2_IsValidClient(client) || IsFakeClient(client)) return;
	CreateTimer(10.0, UL_PlayerDisconnectTimer);
}

public Action UL_PlayerDisconnectTimer(Handle timer)
{
	if (!IsHumansOnServer())
	{
		char sInfo[64];
		KvRewind(g_hInfoKV);
		if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
		{
			do
			{
				KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
				if (StrContains(mapname, sInfo[3], false) != -1)
				{
					strcopy(TargetMap_Code, sizeof(TargetMap_Code), sInfo);
					CreateTimer(0.1, ChangeLevel);
					break;
				}
			}
			while (KvGotoNextKey(g_hInfoKV));
		}
	}
}

public void OnMapStart()
{
	GetCurrentMap(mapname, sizeof(mapname));
}

public void L4D_OnRoundEnd()
{
	if (L4D2_IsVersus() && L4D_IsMissionFinalMap() && L4D2_IsSecondRound())
	{
		CheckMapForChange();
	}
}

public Action MatchRequest(int client, int args)
{
	if (g_hModesKV == INVALID_HANDLE || !L4D2_IsValidClient(client)) return Plugin_Handled;
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
		iVoteType = VoteType_Match;
		strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		Format(sBuffer, sizeof(sBuffer), "将配置更改为 '%s'?", sBuffer);
		BuiltinVotes_StartVoteAllTeam(param1, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
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
	if (!L4D2_IsValidClient(client)) L4D2_SetMaxPlayers(iSlot);
	else
	{
		iVoteType = VoteType_SetMaxPlayers;
		Format(buffer, sizeof(buffer), "将人数设置为 '%s'?");
		BuiltinVotes_StartVoteAllTeam(client, buffer);
	}
	return Plugin_Handled;
}

public Action Command_RestoreHealth(int client, int args)
{
	if (!client) return Plugin_Handled;
	iVoteType = VoteType_RestoreHealth;
	BuiltinVotes_StartVoteAllTeam(client, "是否恢复生还者生命值?");
	return Plugin_Handled;
}

public Action ChangeMaps(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (g_hInfoKV == INVALID_HANDLE)
	{
		LogError("[NativeVotes] 初始化投票失败, 找不到 <%s>.", "configs/maplists.txt");
		return Plugin_Handled;
	}
	
	char sInfo[64], map_name[64];
	KvRewind(g_hInfoKV);
	if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
	{
		Handle hMenu = CreateMenu(Start_Menu);
		SetMenuTitle(hMenu, "请选择地图:");
		do
		{
			KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
			if (IsMapValid(sInfo))
			{
				KvGetString(g_hInfoKV, "name", map_name, sizeof(map_name));
				AddMenuItem(hMenu, sInfo, map_name);
			}
		}
		while (KvGotoNextKey(g_hInfoKV));
		SetMenuExitBackButton(hMenu, true);
		SetMenuExitButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Start_Menu(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sInfo[64], sBuffer[64];
		GetMenuItem(menu, itemNum, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		strcopy(TargetMap_Code, sizeof(TargetMap_Code), sInfo);
		iVoteType = VoteType_ChangeMap;
		Format(sBuffer, sizeof(sBuffer), "将地图更改为 %s ?", sBuffer);
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

public Action KickSpecs_Cmd(int client, int args)
{
	if (L4D2_IsValidClient(client))
	{
		char sBuffer[64];
		iVoteType = VoteType_KickSpec;
		Format(sBuffer, sizeof(sBuffer), "踢非管理员和非强制性观众?");
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	return Plugin_Handled;
}

public Action SetTank_Command(int client, int args)
{
	char buffer[8];
	GetCmdArg(1, buffer, sizeof(buffer));
	g_iTankFlow = StringToInt(buffer);
	iVoteType = VoteType_SetTank;
	Format(buffer, sizeof(buffer), "将Tank刷新点更改为 %s ?", buffer);
	BuiltinVotes_StartVoteAllTeam(client, buffer);
}

public void BuiltinVotes_VoteResult()
{
	switch (iVoteType)
	{
		case VoteType_SetMaxPlayers: L4D2_SetMaxPlayers(iSlot);
		case VoteType_RestoreHealth: RestoreHealth();
		case VoteType_ChangeMap: CreateTimer(2.5, ChangeLevel);
		case VoteType_KickSpec:
		{
			for (int c=1; c<=MaxClients; c++)
			{
				if (IsClientInGame(c) && (GetClientTeam(c) == 1) && !IsClientCaster(c) && !L4D2_IsClientAdmin(c))
				{
					KickClient(c, "No Spectators, please!");
				}
			}
		}
		case VoteType_Match: ServerCommand("sm_forcematch %s", g_sCfg);
		case VoteType_SetTank:
		{
			SetTankPercent(g_iTankFlow);
			PrintToChatAll("Tank刷新地点更改为 %d%%", L4D2_GetTankFlowPercent());
		}
	}
	iVoteType = VoteType_None;
}


bool BuiltinVotes_StartVoteAllTeam(int client, char[] sArgument)
{
	if (L4D2_IsClientAdmin(client))
	{
		BuiltinVotes_VoteResult();
		return true;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "无法开始投票.");
		return false;
	}
	if (!IsClientCaster(client) && GetClientTeam(client) <= 1)
	{
		PrintToChat(client, "{B}[{W}SM{B}] {W}观众不允许投票.");
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (!IsClientCaster(i) && GetClientTeam(i) <= 1)) continue;
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < PLAYER_LIMIT)
		{
			PrintToChat(client, "{B}[{W}SM{B}] {W}没有足够的玩家无法开始投票.");
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
	PrintToChat(client, "{B}[{W}SM{B}] {W}现在无法开始投票.");
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
				DisplayBuiltinVotePass(vote, "");
				BuiltinVotes_VoteResult();
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

void RestoreHealth()
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		L4D2_RestoreHealth(index);
	}
}

public Action ChangeLevel(Handle timer)
{
	if (IsMapValid(TargetMap_Code)) ForceChangeLevel(TargetMap_Code, "");
	else ForceChangeLevel("c1m1_hotel", "");
}

bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}

void L4D2_SetMaxPlayers(int amount)
{
	SetConVarInt(FindConVar("sv_maxplayers"), amount);
	SetConVarInt(FindConVar("sv_visiblemaxplayers"), amount);
	PrintToServer("服务器人数设置为 %i", amount);
	PrintToChatAll("服务器人数设置为 %i", amount);
}

void L4D2_RestoreHealth(int client)
{
	L4D2_CheatCommand(client, "give", "health");
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
}

void L4D2_CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (!L4D2_IsValidClient(client))
		{
			int[] player = new int[MaxClients];
			int numplayer = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					player[numplayer] = i;
					numplayer++;
				}
			}
			client = player[GetRandomInt(0, numplayer - 1)];
		}
		if (L4D2_IsValidClient(client))
		{
		    int originalUserFlags = GetUserFlagBits(client);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(client, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(client, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(client, originalUserFlags);
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}
