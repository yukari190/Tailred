#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <[TR]l4d2library>
#include <[TR]builtinvotes_native>

KeyValues g_hModesKV;
char g_sCfg[32];
bool bVoteStart;

public void OnPluginStart()
{
	char sBuffer[128];
	GetGameFolderName(sBuffer, sizeof(sBuffer));
	g_hModesKV = new KeyValues("MatchModes");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/shared/matchmodes.txt");
	if (!FileToKeyValues(g_hModesKV, sBuffer)) LogError("[VM] 无法加载 matchmodes.txt!");
	
	RegConsoleCmd("sm_match", MatchRequest);
}

public void L4D2_OnRealRoundStart()
{
	bVoteStart = false;
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
		strcopy(g_sCfg, sizeof(g_sCfg), sInfo);
		Format(sBuffer, sizeof(sBuffer), "将配置更改为 '%s'?", sBuffer);
		bVoteStart = true;
		BuiltinVotes_StartVoteAllTeam(param1, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

public void BuiltinVotes_VoteResult()
{
	if (bVoteStart)
	{
		ServerCommand("sm_forcematch %s", g_sCfg);
	}
	bVoteStart = false;
}
