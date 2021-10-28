#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define UNRESERVE_VERSION "2.0.1"

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

#define UNRESERVE_DEBUG 0
#define UNRESERVE_DEBUG_LOG 0

#define L4D_MAXHUMANS_LOBBY_VERSUS 8
#define L4D_MAXHUMANS_LOBBY_OTHER 4

public Plugin myinfo =
{
	name = "L4D 1/2 Remove Lobby Reservation",
	author = "Downtown1, Anime4000, Yukari190",
	description = "Removes lobby reservation when server is full",
	version = UNRESERVE_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=87759"
}

ConVar
	hAllowLobby,
	hHostingLobby,
	hUnreserve;
bool
	g_bUnreserved,
	isMapActive;

public void OnPluginStart()
{
	hAllowLobby = FindConVar("sv_allow_lobby_connect_only");
	hHostingLobby = FindConVar("sv_hosting_lobby");
	
	HookEvent("player_disconnect", OnPlayerDisconnect);
	RegAdminCmd("sm_unreserve", Command_Unreserve, ADMFLAG_BAN, "sm_unreserve - manually force removes the lobby reservation");

	hUnreserve = CreateConVar("sv_allow_lobby", "1", "Automatically unreserve server after a full lobby joins", CVAR_FLAGS, true, 0.0, true, 1.0);
	hUnreserve.AddChangeHook(CvarChange);
	CreateConVar("l4d_unreserve_version", UNRESERVE_VERSION, "Version of the Lobby Unreserve plugin.", CVAR_FLAGS);
}

public void CvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!hUnreserve.BoolValue)
	{
		if (!g_bUnreserved)
		{
			g_bUnreserved = true;
			LobbyUnreserve(true);
		}
	}
	else
	{
		if (!IsServerLobbyFull())
		{
			LobbyUnreserve(false);
			g_bUnreserved = false;
		}
	}
}

public void OnMapStart()
{
	if (!hUnreserve.BoolValue)
	{
		if (!g_bUnreserved)
		{
			g_bUnreserved = true;
			LobbyUnreserve(true);
		}
	}
	isMapActive = true;
}

public void OnMapEnd()
{
	isMapActive = false;
}

public void OnClientPostAdminCheck(int client)
{
	if (!isMapActive || !IsValidAndInGame(client) || IsFakeClient(client)) return;
	
	//DebugPrintToAll("Client put in server %N", client);

	if (hUnreserve.BoolValue)
	{
		if (!g_bUnreserved && IsServerLobbyFull())
		{
			if (hHostingLobby.IntValue > 0)
			{
				LogMessage("[UL] A full lobby has connected, automatically unreserving the server.");
				g_bUnreserved = true;
				LobbyUnreserve(true);
			}
		}
	}
}

//OnClientDisconnect will fired when changing map, issued by gH0sTy at http://docs.sourcemod.net/api/index.php?fastload=show&id=390&
public void OnPlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (client == 0)
		return;

	if (IsFakeClient(client))
		return;
	
	if (!RealClientsInServer(client))
	{
		PrintToServer("[UL] No human want to play in this server. :(");
		if (hUnreserve.BoolValue)
			LobbyUnreserve(false);
		g_bUnreserved = false;
	}
}

public Action Command_Unreserve(int client, int args)
{
	if (g_bUnreserved)
	{
		ReplyToCommand(client, "[UL] Server has already been unreserved.");
	}
	else
	{
		g_bUnreserved = true;
		ReplyToCommand(client, "[UL] Lobby reservation has been removed.");
		LobbyUnreserve(true);
	}

	return Plugin_Handled;
}

/*void DebugPrintToAll(const char[] format, any ...)
{
	#if UNRESERVE_DEBUG	|| UNRESERVE_DEBUG_LOG
	char buffer[192];

	VFormat(buffer, sizeof(buffer), format, 2);

	#if UNRESERVE_DEBUG
	PrintToChatAll("[UNRESERVE] %s", buffer);
	PrintToConsole(0, "[UNRESERVE] %s", buffer);
	#endif

	LogMessage("%s", buffer);
	#else
	//suppress "format" never used warning
	if (format[0])
		return;
	else
		return;
	#endif
}*/

bool IsServerLobbyFull()
{
	int humans = GetHumanCount();
	
	//DebugPrintToAll("IsServerLobbyFull : humans = %d, gamemode = %d", humans, L4D_GetGameModeType());

	if (L4D_IsVersusMode() || L4D2_IsScavengeMode())
	{
		return humans >= L4D_MAXHUMANS_LOBBY_VERSUS;
	}

	return humans >= L4D_MAXHUMANS_LOBBY_OTHER;
}

int GetHumanCount()
{
	int humans = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
			humans++;
	}
	return humans;
}

void LobbyUnreserve(bool e)
{
	if (!e)
	{
		hAllowLobby.SetBool(true);
	}
	else
	{
		L4D_LobbyUnreserve();
		hAllowLobby.SetBool(false);
	}
}

//No need check client in game, issue when client left and server empty, then got client still connecting.
bool RealClientsInServer(int client)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (i != client)
		{
			if (IsClientConnected(i) && !IsFakeClient(i))
				return true;
		}
	}
	return false;
}

bool IsValidAndInGame(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
