#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo =
{
	name = "Infected Flow Warp",
	author = "CanadaRox, A1m`",
	description = "Allows infected to warp to survivors based on their flow",
	version = "1.3",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

StringMap hNameToCharIDTrie;
bool bDelay[MAXPLAYERS+1];
int iLastTarget[MAXPLAYERS+1] = -1;

public void OnPluginStart()
{
	hNameToCharIDTrie = new StringMap();
	
	hNameToCharIDTrie.SetValue("bill", 0);
	hNameToCharIDTrie.SetValue("zoey", 1);
	hNameToCharIDTrie.SetValue("louis", 2);
	hNameToCharIDTrie.SetValue("francis", 3);
	
	hNameToCharIDTrie.SetValue("nick", 0);
	hNameToCharIDTrie.SetValue("rochelle", 1);
	hNameToCharIDTrie.SetValue("coach", 2);
	hNameToCharIDTrie.SetValue("ellis", 3);
	
	HookEvent("player_death",PlayerDeath_Event);
	
	RegConsoleCmd("sm_warpto", WarpTo_Cmd, "Warps to the specified survivor");
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!IsGhostInfected(client) || !(buttons & IN_RELOAD) || bDelay[client]) return Plugin_Continue;
	
	bDelay[client] = true;
	CreateTimer(0.25, ResetDelay, client);
	
	TeleportToClient(client, 0);
	return Plugin_Handled;
}

public Action ResetDelay(Handle timer, any client)
{
    bDelay[client] = false;
}

public Action PlayerDeath_Event(Event event, const char[] name, bool dB)
{
	iLastTarget[GetClientOfUserId(event.GetInt("userid"))] = -1;
}

public Action WarpTo_Cmd(int client, int args)
{
	if (!IsGhostInfected(client)) return Plugin_Handled;

	if (args == 0)
	{
		int fMaxFlowSurvivor = L4D_GetHighestFlowSurvivor(); //left4dhooks functional or left4downtown2 by A1m`
		if (!IsValidSurvivor(fMaxFlowSurvivor))
		{
			return Plugin_Handled;
		}
		
		TeleportToClient(client, fMaxFlowSurvivor);
		return Plugin_Handled;
	}

	char arg[12];
	GetCmdArg(1, arg, sizeof(arg));
	StripQuotes(arg);
	String_ToLower(arg, sizeof(arg));
	
	int characterID;
	if (GetTrieValue(hNameToCharIDTrie, arg, characterID))
	{
		int target = GetClientOfCharID(characterID);
		if (target > 0)
		{
			TeleportToClient(client, target);
		}
	}

	return Plugin_Handled;
}

void TeleportToClient(int client, int target)
{
	if (target <= 0)
	{
		target = FindNextSurvivor(client, iLastTarget[client]);
	}
	if (target == 0) return;
	
	// Prevent people from spawning and then warp to survivor
	SetEntProp(client,Prop_Send,"m_ghostSpawnState",256);
	
	float origin[3];
	GetClientAbsOrigin(target, origin);
	TeleportEntity(client, origin, NULL_VECTOR, NULL_VECTOR);
}

int FindNextSurvivor(int client, int charz)
{
	if (!IsAnySurvivorsAlive())
	{
		return 0;
	}
	
	bool havelooped = false;
	charz++;
	if (charz >= L4D2_GetSurvivorCount())
	{
		charz = 0;
	}
	
	for (int index = charz; index <= MaxClients; index++)
	{
		if (index >= L4D2_GetSurvivorCount())
		{
			if (havelooped)
			{
				break;
			}
			havelooped = true;
			index = 0;
		}
		
		if (L4D2_GetSurvivorOfIndex(index) == 0)
		{
			continue;
		}
		
		iLastTarget[client] = index;
		return L4D2_GetSurvivorOfIndex(index);
	}
	
	return 0;
}

bool IsAnySurvivorsAlive()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0) return true;
	}
	return false;
}

int GetClientOfCharID(int characterID)
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) return 0;
		if (GetEntProp(index, Prop_Send, "m_survivorCharacter") == characterID)
		{
			return index;
		}
	}
	return 0;
}

bool IsGhostInfected(int client)
{
	return (IsValidInfected(client) && IsPlayerAlive(client) && IsInfectedGhost(client));
}
