#include <colors>
#include <readyup>

#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define IS_VALID_CLIENT(%1)     (%1 > 0 && %1 <= MaxClients)
#define IS_INFECTED(%1)         (GetClientTeam(%1) == 3)
#define IS_VALID_INGAME(%1)     (IS_VALID_CLIENT(%1) && IsClientInGame(%1))
#define IS_VALID_INFECTED(%1)   (IS_VALID_INGAME(%1) && IS_INFECTED(%1))
#define IS_VALID_CASTER(%1)     (IS_VALID_INGAME(%1) && casterSystemAvailable && IsClientCaster(%1))

public Plugin myinfo = 
{
    name = "L4D2 Tank Control",
    author = "arti, Yukari190", //Add support sm1.11 - A1m`
    description = "Distributes the role of the tank evenly throughout the team",
    version = "0.0.18b",
    url = "https://github.com/alexberriman/l4d2-plugins/tree/master/l4d_tank_control"
};

enum L4D2Team
{
    L4D2Team_None = 0,
    L4D2Team_Spectator,
    L4D2Team_Survivor,
    L4D2Team_Infected
};

enum ZClass
{
    ZClass_Smoker = 1,
    ZClass_Boomer = 2,
    ZClass_Hunter = 3,
    ZClass_Spitter = 4,
    ZClass_Jockey = 5,
    ZClass_Charger = 6,
    ZClass_Witch = 7,
    ZClass_Tank = 8
};

ConVar
	hTankLotterySelectionTime,
	hTankPrint,
	hTankDebug;

ArrayList
	h_whosHadTank;

char
	queuedTankSteamId[64];

bool
	casterSystemAvailable;

public void OnAllPluginsLoaded()
{
	casterSystemAvailable = LibraryExists("caster_system");
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "caster_system")) casterSystemAvailable = true;
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "caster_system")) casterSystemAvailable = false;
}

public void OnPluginStart()
{
	hTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
	
	// Event hooks
	HookEvent("player_left_start_area", PlayerLeftStartArea_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
	HookEvent("tank_killed", TankKilled_Event, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
	
	// Initialise the tank arrays/data values
	h_whosHadTank = new ArrayList(ByteCountToCells(64));
	
	// Admin commands
	RegAdminCmd("sm_tankshuffle", TankShuffle_Cmd, ADMFLAG_SLAY, "Re-picks at random someone to become tank.");
	RegAdminCmd("sm_givetank", GiveTank_Cmd, ADMFLAG_SLAY, "Gives the tank to a selected player");
	
	// Register the boss commands
	RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank.");
	RegConsoleCmd("sm_boss", Tank_Cmd, "Shows who is becoming the tank.");
	RegConsoleCmd("sm_witch", Tank_Cmd, "Shows who is becoming the tank.");
	
	// Cvars
	hTankPrint = CreateConVar("tankcontrol_print_all", "0", "Who gets to see who 将成为 tank? (0 = Infected, 1 = Everyone)");
	hTankDebug = CreateConVar("tankcontrol_debug", "0", "Whether or not to debug to console");
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{
	// Reset the tank's frustration if need be
	if (! IsFakeClient(tank_index)) 
	{
		PrintHintText(tank_index, "控制权重新填充");
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (! IsClientInGame(i) || GetClientTeam(i) != 3)
				continue;
			if (tank_index == i) CPrintToChat(i, "{red}<{default}Tank 控制权{red}> {olive}控制权 {red}重新填充");
			else CPrintToChat(i, "{red}<{default}Tank 控制权{red}> {default}({green}%N{default}'s) {olive}控制权 {red}重新填充", tank_index);
		}
		
		SetTankFrustration(tank_index, 100);
		L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
		
		return Plugin_Handled;
	}
	
	if (L4D_IsMissionFinalMap()) return Plugin_Continue;
	
	if (! strcmp(queuedTankSteamId, ""))
		chooseTank(0);
	
	if (strcmp(queuedTankSteamId, "") != 0)
	{
		int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
		
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (! IsClientInGame(i) || GetClientTeam(i) != 3)
				continue;
			if (tankClientId == i) PrintHintText(i, "你将变为 TANK\n准备攻击生还者");
			else PrintHintText(i, "一只 TANK 正在靠近\n%N 将变为 Tank", tankClientId);
		}
		PushArrayString(h_whosHadTank, queuedTankSteamId);
		CreateTimer(hTankLotterySelectionTime.FloatValue + 0.1, TankTimer, tankClientId);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action TankTimer(Handle timer, any client)
{
	TakeTank(client);
	return Plugin_Stop;
}

void SetTankFrustration(int iTankClient, int iFrustration) {
    if (iFrustration < 0 || iFrustration > 100) {
        return;
    }
    
    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}

void TakeTank(int client)
{
    if (!IS_VALID_INFECTED(client)) return;
    
    int target = FindAliveTankClient();
    
    if (target == -1)
    {
        return;
    }
    else if (target == client)
    {
        return;
    }
    
    if (GetClientHealth(client) > 1 && !GetEntProp(client, Prop_Send, "m_isGhost", 1))
    {
        L4D_ReplaceWithBot(client);
    }
    L4D_ReplaceTank(target, client);
    
    L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
}

int FindAliveTankClient()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i) && IsPlayerAlive(i)) {
			return i;
		}
	}

	return -1;
}

bool IsTank(int client)
{
	return (IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}




public void RoundStart_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    CreateTimer(10.0, newGame);
}

public Action newGame(Handle timer)
{
	int teamAScore = L4D2Direct_GetVSCampaignScore(0);
	int teamBScore = L4D2Direct_GetVSCampaignScore(1);

	// If it's a new game, reset the tank pool
	if (teamAScore == 0 && teamBScore == 0)
	{
		h_whosHadTank.Clear();
		queuedTankSteamId = "";
	}

	return Plugin_Stop;
}

public void RoundEnd_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    queuedTankSteamId = "";
}

public void PlayerLeftStartArea_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    chooseTank(0);
    outputTankToAll(0);
}

public void PlayerTeam_Event(Event hEvent, const char[] name, bool dontBroadcast)
{
	L4D2Team oldTeam = view_as<L4D2Team>(hEvent.GetInt("oldteam"));
	int client = GetClientOfUserId(hEvent.GetInt("userid"));
	char tmpSteamId[64];

	if (client && oldTeam == view_as<L4D2Team>(L4D2Team_Infected))
	{
		GetClientAuthId(client, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));
		if (strcmp(queuedTankSteamId, tmpSteamId) == 0)
		{
			RequestFrame(chooseTank, 0);
			RequestFrame(outputTankToAll, 0);
		}
	}
}

public void PlayerDeath_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    int zombieClass = 0;
    int victimId = hEvent.GetInt("userid");
    int victim = GetClientOfUserId(victimId);
    
    if (victimId && IsClientInGame(victim)) 
    {
        zombieClass = GetEntProp(victim, Prop_Send, "m_zombieClass");
        if (view_as<ZClass>(zombieClass) == ZClass_Tank) 
        {
            if (GetConVarBool(hTankDebug))
            {
                PrintToConsoleAll("[TC] Tank died(1), choosing a new tank");
            }
            chooseTank(0);
        }
    }
}

public void TankKilled_Event(Event hEvent, const char[] eName, bool dontBroadcast)
{
    if (GetConVarBool(hTankDebug))
    {
        PrintToConsoleAll("[TC] Tank died(2), choosing a new tank");
    }
    chooseTank(0);
}

public Action Tank_Cmd(int client, int args)
{
    if (L4D_IsMissionFinalMap()) return Plugin_Handled;
    
    if (!IsClientInGame(client)) 
      return Plugin_Handled;

    int tankClientId;
    char tankClientName[128];
    
    // Only output if we have a queued tank
    if (! strcmp(queuedTankSteamId, ""))
    {
        return Plugin_Handled;
    }
    
    tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        
        // If on infected, print to entire team
        if (view_as<L4D2Team>(GetClientTeam(client)) == L4D2Team_Infected || (casterSystemAvailable && IsClientCaster(client)))
        {
            if (client == tankClientId) CPrintToChat(client, "{red}<{default}Tank 选择{red}> {green}你 {default}将成为 {red}Tank{default}!");
            else CPrintToChat(client, "{red}<{default}Tank 选择{red}> {olive}%s {default}将成为 {red}Tank!", tankClientName);
        }
    }
    
    return Plugin_Handled;
}

public Action TankShuffle_Cmd(int client, int args)
{
    chooseTank(0);
    outputTankToAll(0);
    
    return Plugin_Handled;
}

public Action GiveTank_Cmd(int client, int args)
{    
    // Who are we targetting?
    char arg1[32];
    GetCmdArg(1, arg1, sizeof(arg1));
    
    // Try and find a matching player
    int target = FindTarget(client, arg1);
    if (target == -1)
    {
        return Plugin_Handled;
    }
    
    // Get the players name
    char name[MAX_NAME_LENGTH];
    GetClientName(target, name, sizeof(name));
    
    // Set the tank
    if (IsClientInGame(target) && ! IsFakeClient(target))
    {
        // Checking if on our desired team
        if (view_as<L4D2Team>(GetClientTeam(target)) != L4D2Team_Infected)
        {
            CPrintToChatAll("{olive}[SM] {default}%s not on infected. Unable to give tank", name);
            return Plugin_Handled;
        }
        
        char steamId[64];
        GetClientAuthId(target, AuthId_Steam2, steamId, sizeof(steamId));

        strcopy(queuedTankSteamId, sizeof(queuedTankSteamId), steamId);
        outputTankToAll(0);
    }
    
    return Plugin_Handled;
}

public void chooseTank(any data)
{
    // Create our pool of players to choose from
    ArrayList infectedPool = new ArrayList(ByteCountToCells(64));
    addTeamSteamIdsToArray(infectedPool, L4D2Team_Infected);
    
    // If there is nobody on the infected team, return (otherwise we'd be stuck trying to select forever)
    if (GetArraySize(infectedPool) == 0)
    {
        delete infectedPool;
        return;
    }

    // Remove players who've already had tank from the pool.
    removeTanksFromPool(infectedPool, h_whosHadTank);
    
    // If the infected pool is empty, remove infected players from pool
    if (GetArraySize(infectedPool) == 0) // (when nobody on infected ,error)
    {
        ArrayList infectedTeam = new ArrayList(ByteCountToCells(64));
        addTeamSteamIdsToArray(infectedTeam, L4D2Team_Infected);
        if (GetArraySize(infectedTeam) > 1)
        {
            removeTanksFromPool(h_whosHadTank, infectedTeam);
            chooseTank(0);
        }
        else
        {
            queuedTankSteamId = "";
        }
        
        delete infectedTeam;
        delete infectedPool;
        return;
    }
    
    // Select a random person to become tank
    int rndIndex = GetRandomInt(0, GetArraySize(infectedPool) - 1);
    GetArrayString(infectedPool, rndIndex, queuedTankSteamId, sizeof(queuedTankSteamId));
    delete infectedPool;
}

public void outputTankToAll(any data)
{
    if (L4D_IsMissionFinalMap()) return;
    
    char tankClientName[MAX_NAME_LENGTH];
    int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        if (GetConVarBool(hTankPrint))
        {
            CPrintToChatAll("{red}<{default}Tank 选择{red}> {olive}%s {default}将成为 {red}Tank!", tankClientName);
        }
        else
        {
            for (int i = 1; i <= MaxClients; i++) 
            {
                if (!IS_VALID_INFECTED(i) && !IS_VALID_CASTER(i))
                continue;

                if (tankClientId == i) CPrintToChat(i, "{red}<{default}Tank 选择{red}> {green}你 {default}将成为 {red}Tank{default}!");
                else CPrintToChat(i, "{red}<{default}Tank 选择{red}> {olive}%s {default}将成为 {red}Tank!", tankClientName);
            }
        }
    }
}

stock void PrintToInfected(const char[] Message, any ... )
{
    char sPrint[256];
    VFormat(sPrint, sizeof(sPrint), Message, 2);

    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IS_VALID_INFECTED(i) && !IS_VALID_CASTER(i)) 
        { 
            continue; 
        }

        CPrintToChat(i, "{default}%s", sPrint);
    }
}

public void addTeamSteamIdsToArray(ArrayList steamIds, L4D2Team team)
{
    char steamId[64];

    for (int i = 1; i <= MaxClients; i++)
    {
        // Basic check
        if (IsClientInGame(i) && ! IsFakeClient(i))
        {
            // Checking if on our desired team
            if (view_as<L4D2Team>(GetClientTeam(i)) != team)
                continue;
        
            GetClientAuthId(i, AuthId_Steam2, steamId, sizeof(steamId));
            PushArrayString(steamIds, steamId);
        }
    }
}
 
public void removeTanksFromPool(ArrayList steamIdTankPool, ArrayList tanks)
{
    int index;
    char steamId[64];
    
    int ArraySize = GetArraySize(tanks);
    for (int i = 0; i < ArraySize; i++)
    {
        GetArrayString(tanks, i, steamId, sizeof(steamId));
        index = FindStringInArray(steamIdTankPool, steamId);
        
        if (index != -1)
        {
            RemoveFromArray(steamIdTankPool, index);
        }
    }
}

public int getInfectedPlayerBySteamId(const char[] steamId) 
{
    char tmpSteamId[64];
   
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientInGame(i) || GetClientTeam(i) != 3)
            continue;
        
        GetClientAuthId(i, AuthId_Steam2, tmpSteamId, sizeof(tmpSteamId));     
        
        if (strcmp(steamId, tmpSteamId) == 0)
            return i;
    }
    
    return -1;
}
