#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <l4d2lib>
#include <l4d2util>

#define ACTIVE_SECONDS 	120

#define MAX_SPECTATORS 	24
#define PLUGIN_VERSION 	"1.2"
#define STEAMID_LENGTH 	32

public Plugin myinfo =
{
    name = "Spectator stays spectator",
    author = "Die Teetasse",
    description = "Spectator will stay as spectators on mapchange.",
    version = PLUGIN_VERSION,
    url = ""
};

ConVar
	g_hMaxSurvivors,
	g_hMaxInfected;
int
	lastTimestamp = 0,
	spectatorCount = 0;
Handle
	spectatorTimer[MAX_SPECTATORS];
char
	spectatorSteamIds[MAX_SPECTATORS][STEAMID_LENGTH];

public void OnPluginStart()
{
    g_hMaxSurvivors = FindConVar("survivor_limit");
    g_hMaxInfected = FindConVar("z_max_player_zombies");
}

public void OnClientAuthorized(int client, const char[] auth)
{
    int currentTimestamp = GetTime();
    
    if ((currentTimestamp - lastTimestamp) > ACTIVE_SECONDS) return;
    
    if (strcmp(auth, "BOT") == 0) return;
    
    int index = Function_GetIndex(auth);
    if (index == -1) return;
    
    spectatorTimer[index] = CreateTimer(1.0, Timer_MoveToSpec, client, TIMER_REPEAT);
}

public Action Timer_MoveToSpec(Handle timer, int client)
{
    if (IsInTransition() || GetSeriousClientCount(true) == 0) return Plugin_Continue;
    
    if (!IsClientInGame(client)) return Plugin_Continue;
    
    char auth[STEAMID_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, auth, STEAMID_LENGTH);
    
    int index = Function_GetIndex(auth);
    
    if (index == -1) return Plugin_Stop;
    
    spectatorTimer[index] = INVALID_HANDLE;
    
    int team = GetClientTeam(client);
    if (team == 1)
    {
        CreateTimer(2.0, ReSpec, client);
        return Plugin_Stop;
    }
    
    char name[MAX_NAME_LENGTH];
    GetClientName(client, name, sizeof(name));
    
    ChangeClientTeam(client, 1);
    CreateTimer(2.0, ReSpec, client);
    //PrintToChatAll("[SM] Found %s in %s team. Moved him back to spec team.", name, (team == 2) ? "survivor" : "infected");
    
    return Plugin_Stop;
}

public Action ReSpec(Handle timer, int client)
{
    if (IsClientInGame(client) && GetClientTeam(client) == 1) FakeClientCommand(client, "say /spectate");
}

public void OnClientDisconnect(int client)
{
    char clientSteamId[STEAMID_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, clientSteamId, STEAMID_LENGTH);
    
    int index = Function_GetIndex(clientSteamId);
    
    if (index == -1) return;
    
    if (spectatorTimer[index] == INVALID_HANDLE) return;
    
    KillTimer(spectatorTimer[index]);
    spectatorTimer[index] = INVALID_HANDLE;
}

public void L4D2_OnRealRoundStart()
{
    CreateTimer(15.0, Check4Spec, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Check4Spec(Handle timer)
{
    if (GetRealClientCount() != (g_hMaxSurvivors.IntValue + g_hMaxInfected.IntValue)) return Plugin_Continue;
    
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsClientInGame(i) && GetClientTeam(i) == 1 && !IsClientSourceTV(i)) FakeClientCommand(i, "say /spectate");   
    }
    return Plugin_Stop;
}

public void L4D2_OnRealRoundEnd()
{
    spectatorCount = 0;
    
    for (int i = 0; i < MAX_SPECTATORS; i++)
    {
        spectatorSteamIds[i] = "";
        
        if (spectatorTimer[i] != INVALID_HANDLE)
        {
            KillTimer(spectatorTimer[i]);
            spectatorTimer[i] = INVALID_HANDLE;
        }
    }
    
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i)) continue;
        if (IsFakeClient(i)) continue;
        if (GetClientTeam(i) != 1) continue;
        if (IsClientSourceTV(i)) continue;
        
        GetClientAuthId(i, AuthId_Steam2, spectatorSteamIds[spectatorCount], STEAMID_LENGTH);
        spectatorCount++;
    }	
    
    lastTimestamp = GetTime();
}

int Function_GetIndex(const char[] clientSteamId)
{
    for (int i = 0; i < spectatorCount; i++)
    {
        if (StrEqual(spectatorSteamIds[i], clientSteamId)) return i;	
    }
    
    return -1;
}

int GetRealClientCount() 
{
    int clients = 0;
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) != 1) clients++;
    }
    return clients;
}