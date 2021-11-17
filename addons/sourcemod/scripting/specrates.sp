#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define RATE_MULTIPLIER 1000
#define FREQUENCY_DIVIDEND 1.4
#define SPLITPACKET_MULTIPLIER 500

public Plugin myinfo =
{
    name = "Server Rates + Lightweight Spectating",
    author = "Visor, Yukari190",
    description = "Forces low rates on spectators",
    version = "1.2.1b",
    url = "https://github.com/yukari190/Tailred"
};

enum
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
};

bool
	readyUpIsAvailable;

ConVar
	sv_mincmdrate,
	sv_maxcmdrate,
	sv_minupdaterate,
	sv_maxupdaterate,
	sv_minrate,
	sv_maxrate,
	nb_update_frequency,
	net_splitpacket_maxrate;

char
	netvars[6][8];

float
	fLastAdjusted[MAXPLAYERS + 1];

public void OnAllPluginsLoaded()
{
    readyUpIsAvailable = LibraryExists("caster_system");
}

public void OnLibraryRemoved(const char[] name)
{
    if (strcmp(name, "caster_system") == 0)
    {
        readyUpIsAvailable = false;
    }
}

public void OnLibraryAdded(const char[] name)
{
    if (strcmp(name, "caster_system") == 0)
    {
        readyUpIsAvailable = true;
    }
}

public void OnPluginStart()
{
	sv_mincmdrate = FindConVar("sv_mincmdrate");
	sv_maxcmdrate = FindConVar("sv_maxcmdrate");
	sv_minupdaterate = FindConVar("sv_minupdaterate");
	sv_maxupdaterate = FindConVar("sv_maxupdaterate");
	sv_minrate = FindConVar("sv_minrate");
	sv_maxrate = FindConVar("sv_maxrate");
	nb_update_frequency = FindConVar("nb_update_frequency");
	net_splitpacket_maxrate = FindConVar("net_splitpacket_maxrate");
	
	HookEvent("player_team", OnTeamChange);
}

public void OnPluginEnd()
{
    sv_minupdaterate.SetString(netvars[2]);
    sv_mincmdrate.SetString(netvars[0]);
}

public void OnConfigsExecuted()
{
	int iTickrate = RoundToNearest(1.0 / GetTickInterval());
	
	sv_minrate.SetInt(iTickrate * RATE_MULTIPLIER);
	sv_maxrate.SetInt(iTickrate * RATE_MULTIPLIER);
	sv_minupdaterate.SetInt(iTickrate);
	sv_maxupdaterate.SetInt(iTickrate);
	sv_mincmdrate.SetInt(iTickrate);
	sv_maxcmdrate.SetInt(iTickrate);
	nb_update_frequency.SetFloat(FREQUENCY_DIVIDEND / float(iTickrate));
	net_splitpacket_maxrate.SetInt(iTickrate * SPLITPACKET_MULTIPLIER);
	
	sv_mincmdrate.GetString(netvars[0], 8);
	sv_maxcmdrate.GetString(netvars[1], 8);
	sv_minupdaterate.GetString(netvars[2], 8);
	sv_maxupdaterate.GetString(netvars[3], 8);
	sv_minrate.GetString(netvars[4], 8);
	sv_maxrate.GetString(netvars[5], 8);
	
	sv_minupdaterate.SetInt(30);
	sv_mincmdrate.SetInt(30);
}

public void OnClientPutInServer(int client)
{
    fLastAdjusted[client] = 0.0;
}

public void OnTeamChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    CreateTimer(10.0, TimerAdjustRates, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action TimerAdjustRates(Handle timer, any client)
{
    AdjustRates(client);
    return Plugin_Stop;
}

public void OnClientSettingsChanged(int client) 
{
    AdjustRates(client);
}

void AdjustRates(int client)
{
    if (!IsValidClient(client))
        return;

    if (fLastAdjusted[client] < GetEngineTime() - 1.0)
    {
        fLastAdjusted[client] = GetEngineTime();

        int team = GetClientTeam(client);
        if (team == L4D2Team_Survivor || team == L4D2Team_Infected || (readyUpIsAvailable && IsClientCaster(client)))
        {
            ResetRates(client);
        }
        else if (team == L4D2Team_Spectator)
        {
            SetSpectatorRates(client);
        }
    }
}

void SetSpectatorRates(int client)
{
    sv_mincmdrate.ReplicateToClient(client, "30");
    sv_maxcmdrate.ReplicateToClient(client, "30");
    sv_minupdaterate.ReplicateToClient(client, "30");
    sv_maxupdaterate.ReplicateToClient(client, "30");
    sv_minrate.ReplicateToClient(client, "10000");
    sv_maxrate.ReplicateToClient(client, "10000");

    SetClientInfo(client, "cl_updaterate", "30");
    SetClientInfo(client, "cl_cmdrate", "30");
}

void ResetRates(int client)
{
    sv_mincmdrate.ReplicateToClient(client, netvars[0]);
    sv_maxcmdrate.ReplicateToClient(client, netvars[1]);
    sv_minupdaterate.ReplicateToClient(client, netvars[2]);
    sv_maxupdaterate.ReplicateToClient(client, netvars[3]);
    sv_minrate.ReplicateToClient(client, netvars[4]);
    sv_maxrate.ReplicateToClient(client, netvars[5]);

    SetClientInfo(client, "cl_updaterate", netvars[3]);
    SetClientInfo(client, "cl_cmdrate", netvars[1]);
}

bool IsValidClient(int client)
{
    return client > 0 && client <= MaxClients && IsClientInGame(client) && !IsFakeClient(client);
}