#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2util_stocks>
#undef REQUIRE_PLUGIN
#include <nativevotes>
#define REQUIRE_PLUGIN

Handle g_hMatchVote = INVALID_HANDLE;
Handle g_hResetMatchVote = INVALID_HANDLE;
Handle g_hModesKV = INVALID_HANDLE;
char g_sCfg[32];

public void OnPluginStart()
{
	char sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_hModesKV = CreateKeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/matchmodes.txt");
	if (!FileToKeyValues(g_hModesKV, sBuffer)) LogMessage("[VM] 无法加载 matchmodes.txt!");
	
	RegConsoleCmd("sm_match", MatchRequest);
	RegConsoleCmd("sm_rmatch", MatchReset);
}

public Action MatchRequest(int client, int args)
{
	if (g_hModesKV == INVALID_HANDLE) return Plugin_Handled;
	
	if (args > 0)
	{
		char sCfg[64], sBuffer[256];
		GetCmdArg(1, sCfg, sizeof(sCfg));
		BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/%s", sCfg);
		if (DirExists(sBuffer))
		{
			FindConfigName(sCfg, sBuffer, sizeof(sBuffer));
			strcopy(g_sCfg, sizeof(g_sCfg), sCfg);
			if (!IsValidInGame(client) || IsClientAdmin(client)) ServerCommand("sm_forcematch %s", g_sCfg);
			else StartMatchVote(client, sBuffer);
			return Plugin_Handled;
		}
	}
	if (IsValidInGame(client)) MatchModeMenu(client);
	return Plugin_Handled;
}

bool FindConfigName(const char[] cfg, char[] name, int maxlength)
{
	KvRewind(g_hModesKV);
	if (KvGotoFirstSubKey(g_hModesKV))
	{
		do
		{
			if (KvJumpToKey(g_hModesKV, cfg))
			{
				KvGetString(g_hModesKV, "name", name, maxlength);
				return true;
			}
		} while (KvGotoNextKey(g_hModesKV));
	}
	return false;
}

int MatchModeMenu(int client)
{
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
}

public int ConfigsMenuHandler(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		char sInfo[64], sBuffer[64];
		GetMenuItem(menu, param2, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		StartMatchVote(param1, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

int StartMatchVote(int client, const char[] cfgname)
{
	if (!NativeVotes_IsNewVoteAllowed())
	{
		PrintToChat(client, "[Lgofnoc] 现在无法开始 Match 投票.");
		return;
	}
	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "将配置更改为 '%s'?", cfgname);
	g_hMatchVote = NativeVotes_Create(VoteResultHandler, NativeVotesType_Custom_YesNo);
	NativeVotes_SetDetails(g_hMatchVote, sBuffer);
	NativeVotes_SetInitiator(g_hMatchVote, client);
	NativeVotes_DisplayToAll(g_hMatchVote, 20);
	FakeClientCommand(client, "Vote Yes");
}

public int VoteResultHandler(Handle vote, MenuAction action, int param1, int param2)
{
	switch (action)
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
			else if (vote == g_hMatchVote)
			{
				NativeVotes_DisplayPass(vote, "lgofnoc 正在加载...");
				ServerCommand("sm_forcematch %s", g_sCfg);					
			}
			else if (vote == g_hResetMatchVote)
			{
				NativeVotes_DisplayPass(vote, "lgofnoc 正在卸载...");
				ServerCommand("sm_resetmatch");
			}
		}

		case MenuAction_End:
		{
			g_hMatchVote = INVALID_HANDLE;
			g_hResetMatchVote = INVALID_HANDLE;
			NativeVotes_Close(vote);
		}
	}
}

public Action MatchReset(int client, int args)
{
	if (!client || g_hModesKV == INVALID_HANDLE) return Plugin_Handled;
	if (!IsValidInGame(client) || IsClientAdmin(client)) ServerCommand("sm_resetmatch");
	else StartResetMatchVote(client);
	return Plugin_Handled;
}

int StartResetMatchVote(int client)
{
	if (!NativeVotes_IsNewVoteAllowed())
	{
		PrintToChat(client, "[Lgofnoc] 现在无法启动 Resetmatch 投票.");
		return;
	}
	g_hResetMatchVote = NativeVotes_Create(VoteResultHandler, NativeVotesType_Custom_YesNo);
	NativeVotes_SetDetails(g_hResetMatchVote, "关闭 lgofnoc?");
	NativeVotes_SetInitiator(g_hResetMatchVote, client);
	NativeVotes_DisplayToAll(g_hResetMatchVote, 20);
	FakeClientCommand(client, "Vote Yes");
	return;
}
