#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_EXTENSIONS
#include <builtinvotes>
#define REQUIRE_EXTENSIONS

#define TEAM_INFECTED 3
#define Z_TANK 8

ConVar
	g_hKillOnCrash = null;

public Plugin myinfo = 
{
	name = "AI Tank Gank",
	author = "Stabby",
	version = "0.3",
	description = "Kills tanks on pass to AI."
};

public void OnPluginStart()
{
	g_hKillOnCrash = CreateConVar( \
		"tankgank_killoncrash", \
		"0", \
		"If 0, tank will not be killed if the player that controlled it crashes.", \
		_, true,  0.0, true, 1.0 \
	);
	
	HookEvent("player_bot_replace", OnTankGoneAi);
	
	RegConsoleCmd("sm_killai", Killai_Cmd);
}

public Action Killai_Cmd(int client, int args)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED) return Plugin_Handled;
	if (FindAliveTankClient() == -1)
	{
		PrintToChat(client, "没有AI坦克");
		return Plugin_Handled;
	}
	StartVote(client);
	return Plugin_Handled;
}

public void OnTankGoneAi(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int iNewTank = GetClientOfUserId(hEvent.GetInt("bot"));
	
	if (GetClientTeam(iNewTank) == TEAM_INFECTED && GetEntProp(iNewTank, Prop_Send, "m_zombieClass") == Z_TANK)
	{
		if (!g_hKillOnCrash.BoolValue)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && !IsFakeClient(i))
				{
					PrintToChat(i, "输入 [sm_killai(控制台) | /killai(聊天框)] 命令可以投票处死AI坦克.");
				}
			}
			return;
		}
		
		CreateTimer(1.0, Timed_CheckAndKill, iNewTank, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timed_CheckAndKill(Handle hTimer, any iNewTank)
{
	if (IsFakeClient(iNewTank) && IsPlayerAlive(iNewTank))
	{
		ForcePlayerSuicide(iNewTank);
	}

	return Plugin_Stop;
}

bool StartVote(int client)
{
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "无法开始投票.");
		return false;
	}
	if (GetClientTeam(client) != TEAM_INFECTED)
	{
		PrintToChat(client, "特感才能投票.");
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != TEAM_INFECTED) continue;
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < 1)
		{
			PrintToChat(client, "没有足够的玩家无法开始投票.");
			return false;
		}
		Handle hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hVote, "是否处死 AI 坦克");
		SetBuiltinVoteInitiator(hVote, client);
		SetBuiltinVoteResultCallback(hVote, VoteResultHandler);
		DisplayBuiltinVote(hVote, iPlayers, iNumPlayers, 30);
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	PrintToChat(client, "现在无法开始投票.");
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
				CreateTimer(1.0, Timed_CheckAndKill, FindAliveTankClient(), TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

stock int FindAliveTankClient()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i) && IsPlayerAlive(i) && IsFakeClient(i)) {
			return i;
		}
	}

	return -1;
}

stock bool IsTank(int client)
{
	return (IsClientInGame(client)
		&& GetClientTeam(client) == TEAM_INFECTED
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == Z_TANK);
}
