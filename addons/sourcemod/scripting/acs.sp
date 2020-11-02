#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

#define NUMBER_OF_CAMPAIGNS 14
#define NUMBER_OF_LEN 32

Handle g_ChangeMapsVote, g_hInfoKV, MapDataPack_MapCode[33], MapDataPack_MapName[33];
int iGameMode;
char g_strCampaignFirstMap[NUMBER_OF_CAMPAIGNS][NUMBER_OF_LEN];		//Array of maps to switch to
char g_strCampaignLastMap[NUMBER_OF_CAMPAIGNS][NUMBER_OF_LEN];		//Array of maps to switch from
char mapname[64];
char TargetMap_Code[128];
char TargetMap_Name[128];

public Plugin myinfo =
{
	name = "Automatic Campaign Switcher (ACS)",
	description = "",
	author = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	g_hInfoKV = CreateKeyValues("MapLists");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/maplists.txt");
	if (!FileToKeyValues(g_hInfoKV, sBuffer)) LogMessage("找不到 <%s>.", "configs/maplists.txt");
	
	InitMapList();
	RegConsoleCmd("sm_vcm", ChangeMaps);
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("finale_win", FinaleWin_Event, EventHookMode_PostNoCopy);
}

public void OnMapStart()
{
	iGameMode = Gamemode();
	GetCurrentMap(mapname, sizeof(mapname));
}

public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidInGame(client) || IsFakeClient(client)) return;
	CreateTimer(10.0, UL_PlayerDisconnectTimer);
}

public Action UL_PlayerDisconnectTimer(Handle timer)
{
	if (!IsHumansOnServer())
	{
		CreateTimer(0.1, Timer_ChangeCampaign, GetFirstChapterMap());
	}
}

public void L4D2_OnRealRoundEnd()
{
	if (L4D_IsMissionFinalMap() && InSecondHalfOfRound()) CheckMapForChange();
}

public Action FinaleWin_Event(Event event, const char[] name, bool dontBroadcast)
{
	CheckMapForChange();
}

int CheckMapForChange()
{
	for (int iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
	{
		if (StrEqual(mapname, g_strCampaignLastMap[iMapIndex]))
		{
			if (iMapIndex == NUMBER_OF_CAMPAIGNS - 1) iMapIndex = -1;
			CreateTimer(iGameMode == GAMEMODE_VERSUS ? 6.0 : 3.0, Timer_ChangeCampaign, iMapIndex + 1);
			return;
		}
	}
	CreateTimer(iGameMode == GAMEMODE_VERSUS ? 6.0 : 3.0, Timer_ChangeCampaign, 6);
}

public Action Timer_ChangeCampaign(Handle timer, any iCampaignIndex)
{
	ForceChangeLevel(g_strCampaignFirstMap[iCampaignIndex], "");
	return Plugin_Stop;
}

public Action ChangeMaps(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (g_hInfoKV == INVALID_HANDLE)
	{
		PrintToChat(client, "[NativeVotes] 初始化投票失败, 找不到 <%s>.", "configs/maplists.txt");
		return Plugin_Handled;
	}
	
	if (MapDataPack_MapCode[client] == INVALID_HANDLE) MapDataPack_MapCode[client] = CreateDataPack();
	else ResetPack(MapDataPack_MapCode[client], true);
	
	if (MapDataPack_MapName[client] == INVALID_HANDLE) MapDataPack_MapName[client] = CreateDataPack();
	else ResetPack(MapDataPack_MapName[client], true);
	
	
	int MaxCount = KvGetNum(g_hInfoKV, "max count", 0);
	Handle menu = CreateMenu(Start_Menu);
	SetMenuTitle(menu, "请选择投票地图");
	for (int i = 0; i <= MaxCount; i++)
	{
		char num[4];
		IntToString(i,num,sizeof(num));
		if (KvJumpToKey(g_hInfoKV, num))
		{
			char map_code[128];
			KvGetString(g_hInfoKV,"MapCode",map_code,sizeof(map_code));
			if (IsMapValid(map_code))
			{
				char map_name[128];
				KvGetString(g_hInfoKV,map_code,map_name,sizeof(map_name));
				WritePackString(MapDataPack_MapCode[client],map_code);
				WritePackString(MapDataPack_MapName[client],map_name);
				AddMenuItem(menu, "", map_name);
			}
			KvGoBack(g_hInfoKV);
		}
	}
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
	return Plugin_Handled;
}

public int Start_Menu(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{	
		SetConVarFloat(FindConVar("sm_vote_delay"), 10.0, true, false);
		
		ResetPack(MapDataPack_MapCode[client]);
		ResetPack(MapDataPack_MapName[client]);
		
		for (int i = 0; i <= itemNum; i++)
		{
			ReadPackString(MapDataPack_MapCode[client],TargetMap_Code,sizeof(TargetMap_Code));
			ReadPackString(MapDataPack_MapName[client],TargetMap_Name,sizeof(TargetMap_Name));
		}
		
		if (IsMapValid(TargetMap_Code)) StartNativeVote(client, TargetMap_Name);
		else ReplyToCommand(client, "This Map Invalid.");
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

bool StartNativeVote(int client, char[] sbuff)
{
	if (!NativeVotes_IsNewVoteAllowed())
	{
		PrintToChat(client, "[NativeVotes] 现在不能发起投票！");
		return false;
	}
	if (!TestVoteDelay(client)) return false;

	if (NativeVotes_IsNewVoteAllowed())
	{
		char VoteArgument[128];
		Format(VoteArgument,sizeof(VoteArgument),"将地图更改为 %s ?", sbuff);
		g_ChangeMapsVote = NativeVotes_Create(VoteResultHandler, NativeVotesType_Custom_YesNo);
		NativeVotes_SetResultCallback(g_ChangeMapsVote, CallBack_VoteResult);
		NativeVotes_SetDetails(g_ChangeMapsVote, VoteArgument);
		NativeVotes_SetInitiator(g_ChangeMapsVote, client);
		NativeVotes_DisplayToAll(g_ChangeMapsVote, 20);
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	PrintToChat(client, "现在无法开始投票.");
	return false;
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
		}

		case MenuAction_End:
		{
			g_ChangeMapsVote = INVALID_HANDLE;
			NativeVotes_Close(vote);
		}
	}
}

public int CallBack_VoteResult(Handle vote, int num_votes, int num_clients, const int[] client_indexes, const int[] client_votes, int num_items, const int[] item_indexes, const int[] item_votes)
{
	if (num_votes <= (num_clients / 2))
	{
		NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
		return;
	}

	int agreenumber = 0;
	for (int i = 0;i < num_items;++i)
	{
		if (item_indexes[i] == NATIVEVOTES_VOTE_YES) agreenumber = item_votes[i];
	}

	if ((float(agreenumber) / float(num_votes)) >= 0.75)
	{
		if (IsMapValid(TargetMap_Code))
		{
			char PassStr[64];
			Format(PassStr,sizeof(PassStr),"Changing Campaign...");
			NativeVotes_DisplayPass(vote, PassStr);
			CreateTimer(2.5, ChangeLevel);
		}
		else
		{
			NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
			PrintToChatAll("[NativeVotes] 这张地图是无效的.");
		}
	}
	else NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
}

public Action ChangeLevel(Handle timer)
{
	ForceChangeLevel(TargetMap_Code, "");
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	if (delay > 0)
 	{
 		if (delay > 30) PrintToChat(client, "[NativeVotes] 您必须再等 %i 分钟後才能发起新一轮投票", delay % 30);
 		else PrintToChat(client, "[NativeVotes] 您必须再等 %i 秒钟後才能发起新一轮投票", delay);
 		return false;
 	}
	return true;
}



bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}

int GetFirstChapterMap()
{
	if (StrContains(mapname, "c8m", false) != -1) return 0;
	else if (StrContains(mapname, "c9m", false) != -1) return 1;
	else if (StrContains(mapname, "c10m", false) != -1) return 2;
	else if (StrContains(mapname, "c11m", false) != -1) return 3;
	else if (StrContains(mapname, "c12m", false) != -1) return 4;
	else if (StrContains(mapname, "c7m", false) != -1) return 5;
	else if (StrContains(mapname, "c1m", false) != -1) return 6;
	else if (StrContains(mapname, "c6m", false) != -1) return 7;
	else if (StrContains(mapname, "c2m", false) != -1) return 8;
	else if (StrContains(mapname, "c3m", false) != -1) return 9;
	else if (StrContains(mapname, "c4m", false) != -1) return 10;
	else if (StrContains(mapname, "c5m", false) != -1) return 11;
	else if (StrContains(mapname, "c13m", false) != -1) return 12;
	else if (StrContains(mapname, "c14m", false) != -1) return 13;
	else return 6;
}

void InitMapList()
{
	Format(g_strCampaignFirstMap[0], NUMBER_OF_LEN, "c8m1_apartment");
	Format(g_strCampaignFirstMap[1], NUMBER_OF_LEN, "c9m1_alleys");
	Format(g_strCampaignFirstMap[2], NUMBER_OF_LEN, "c10m1_caves");
	Format(g_strCampaignFirstMap[3], NUMBER_OF_LEN, "c11m1_greenhouse");
	Format(g_strCampaignFirstMap[4], NUMBER_OF_LEN, "c12m1_hilltop");
	Format(g_strCampaignFirstMap[5], NUMBER_OF_LEN, "c7m1_docks");
	Format(g_strCampaignFirstMap[6], NUMBER_OF_LEN, "c1m1_hotel");
	Format(g_strCampaignFirstMap[7], NUMBER_OF_LEN, "c6m1_riverbank");
	Format(g_strCampaignFirstMap[8], NUMBER_OF_LEN, "c2m1_highway");
	Format(g_strCampaignFirstMap[9], NUMBER_OF_LEN, "c3m1_plankcountry");
	Format(g_strCampaignFirstMap[10], NUMBER_OF_LEN, "c4m1_milltown_a");
	Format(g_strCampaignFirstMap[11], NUMBER_OF_LEN, "c5m1_waterfront");
	Format(g_strCampaignFirstMap[12], NUMBER_OF_LEN, "c13m1_alpinecreek");
	Format(g_strCampaignFirstMap[13], NUMBER_OF_LEN, "c14m1_junkyard");
	
	Format(g_strCampaignLastMap[0], NUMBER_OF_LEN, "c8m5_rooftop");
	Format(g_strCampaignLastMap[1], NUMBER_OF_LEN, "c9m2_lots");
	Format(g_strCampaignLastMap[2], NUMBER_OF_LEN, "c10m5_houseboat");
	Format(g_strCampaignLastMap[3], NUMBER_OF_LEN, "c11m5_runway");
	Format(g_strCampaignLastMap[4], NUMBER_OF_LEN, "c12m5_cornfield");
	Format(g_strCampaignLastMap[5], NUMBER_OF_LEN, "c7m3_port");
	Format(g_strCampaignLastMap[6], NUMBER_OF_LEN, "c1m4_atrium");
	Format(g_strCampaignLastMap[7], NUMBER_OF_LEN, "c6m3_port");
	Format(g_strCampaignLastMap[8], NUMBER_OF_LEN, "c2m5_concert");
	Format(g_strCampaignLastMap[9], NUMBER_OF_LEN, "c3m4_plantation");
	Format(g_strCampaignLastMap[10], NUMBER_OF_LEN, "c4m5_milltown_escape");
	Format(g_strCampaignLastMap[11], NUMBER_OF_LEN, "c5m5_bridge");
	Format(g_strCampaignLastMap[12], NUMBER_OF_LEN, "c13m4_cutthroatcreek");
	Format(g_strCampaignLastMap[13], NUMBER_OF_LEN, "c14m2_lighthouse");
}
