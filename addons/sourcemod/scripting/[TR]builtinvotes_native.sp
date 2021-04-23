#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <[TR]builtinvotes>
#include <[TR]l4d2library>

#define PLAYER_LIMIT 1

GlobalForward hFwdVoteResult;

public Plugin myinfo =
{
	name = "Builtinvotes Native",
	description = "",
	author = "Yukari190",
	version = "0.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	hFwdVoteResult = new GlobalForward("BuiltinVotes_VoteResult", ET_Ignore);
	CreateNative("BuiltinVotes_StartVote", Native_StartVote);
	CreateNative("BuiltinVotes_StartVoteAllTeam", Native_StartVoteAllTeam);
	RegPluginLibrary("builtinvotes_native");
	return APLRes_Success;
}

public int Native_StartVote(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int team = GetClientTeam(client);
	int len;
	GetNativeStringLength(2, len);
	len += 1;
	char[] sArgument = new char[len];
	GetNativeString(2, sArgument, len);
	
	if (L4D2_IsClientAdmin(client))
	{
		Call_StartForward(hFwdVoteResult);
		Call_Finish();
		return true;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "无法开始投票.");
		return false;
	}
	if (team <= 1)
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
			if (!IsClientInGame(i) || IsFakeClient(i) || GetClientTeam(i) != team) continue;
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

public int Native_StartVoteAllTeam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int len;
	GetNativeStringLength(2, len);
	len += 1;
	char[] sArgument = new char[len];
	GetNativeString(2, sArgument, len);
	
	if (L4D2_IsClientAdmin(client))
	{
		Call_StartForward(hFwdVoteResult);
		Call_Finish();
		return true;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "无法开始投票.");
		return false;
	}
	if (!L4D2_IsClientCaster(client) && GetClientTeam(client) <= 1)
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
			if (!IsClientInGame(i) || IsFakeClient(i) || (!L4D2_IsClientCaster(i) && GetClientTeam(i) <= 1)) continue;
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
				Call_StartForward(hFwdVoteResult);
				Call_Finish();
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}
