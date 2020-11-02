#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <l4d2_hybrid_scoremod>
#define REQUIRE_PLUGIN

#define MIN_BOSS_VARIANCE (0.2)
#define MAXSPAWNS 8

#define FINALE_GAUNTLET_2 3
#define FINALE_CUSTOM_TANK 8
#define FINALE_GAUNTLET_BOSS 16
#define FINALE_GAUNTLET_ESCAPE 17

#define SKIP 0
#define FLOWANDSECONDONEVENT 1
#define FIRSTONEVENT 2

public Plugin myinfo =
{
	name = "Tank Spawner",
	author = "CanadaRox, ProdigySim, Jahze, Stabby, CircleSquared, Visor, Tabun, Breezy, Tordecybombo, 趴趴酱",
	version = "1.0",
	description = "控制每回合tank刷新"
};

Handle hFirstTankSpawningScheme, hSecondTankSpawningScheme, hStaticTankMaps;
ConVar hVsBossFlowMin, hVsBossFlowMax, hAllowTankSpawn;
float fCoopTankFlow, fCvarMinFlow, fCvarMaxFlow;
int tankCount, iGameMode, iTankPercent, iRoundPercent, iMapTankSpawnAttemptCount, spawnScheme;
bool bCoopTankSpawn, readyUpIsAvailable, hybridScoringAvailable, readyFooterAdded, bAllowTankSpawn;
char iCurrentMap[64];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("AddStringToReadyFooter");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
	hybridScoringAvailable = LibraryExists("l4d2_hybrid_scoremod");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
	else if (StrEqual(name, "l4d2_hybrid_scoremod")) hybridScoringAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
	else if (StrEqual(name, "l4d2_hybrid_scoremod")) hybridScoringAvailable = true;
}

public void OnPluginStart()
{
	hVsBossFlowMin = FindConVar("versus_boss_flow_min");
	hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	hAllowTankSpawn = CreateConVar("l4d2_allow_tank_spawn", "1");
	
	fCvarMinFlow = GetConVarFloat(hVsBossFlowMin);
	fCvarMaxFlow = GetConVarFloat(hVsBossFlowMax);
	bAllowTankSpawn = GetConVarBool(hAllowTankSpawn);
	
	hVsBossFlowMin.AddChangeHook(ConVarChange);
	hVsBossFlowMax.AddChangeHook(ConVarChange);
	hAllowTankSpawn.AddChangeHook(ConVarChange);
	
	hFirstTankSpawningScheme = CreateTrie();
	hSecondTankSpawningScheme = CreateTrie();
	hStaticTankMaps = CreateTrie();
	
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_cu", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_cur", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_current", Cmd_BossPercent, "Boss产生的百分比");
	
	RegServerCmd("tank_map_flow_and_second_event", SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event", SetMapSecondTankSpawningScheme);
	RegServerCmd("static_tank_map", StaticTank_Command);
	RegServerCmd("reset_static_maps", Reset_Command);
	
	RegAdminCmd("sm_settank", SetTank_Command, ADMFLAG_BAN);
	
	HookEvent("witch_spawn", OnWitchSpawn);
	
	if (Gamemode() == GAMEMODE_COOP) SetConVarBool(FindConVar("director_no_bosses"), true);
}

public void OnPluginEnd()
{
	ResetConVar(FindConVar("director_no_bosses"));
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fCvarMinFlow = hVsBossFlowMin.FloatValue;
	fCvarMaxFlow = hVsBossFlowMax.FloatValue;
	bAllowTankSpawn = hAllowTankSpawn.BoolValue;
}

public Action Cmd_BossPercent(int client, int args)
{
	CreateTimer(0.1, SaveBossFlows);
	int iTeam = GetClientTeam(client);
	if (iTeam == 1)
	{
		PrintBossPercents(client);
		return Plugin_Handled;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && GetClientTeam(i) == iTeam) PrintBossPercents(i);
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	iGameMode = Gamemode();
	GetCurrentMap(iCurrentMap, sizeof(iCurrentMap));
	
	bCoopTankSpawn = false;
	fCoopTankFlow = 0.0;
	iTankPercent = 0;
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (!bAllowTankSpawn) return Plugin_Handled;
	return Plugin_Continue;
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(8.0, ProcessTankSpawn);
	CreateTimer(0.5, AdjustBossFlow);
	readyFooterAdded = false;
	iMapTankSpawnAttemptCount = 0;
	
	if (!IsDKR())
	{
		CreateTimer(5.0, SaveBossFlows);
		CreateTimer(6.0, AddReadyFooter);
	}
}

public Action OnWitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (IsValidEntity(witch)) AcceptEntityInput(witch, "kill");
}

public Action ProcessTankSpawn(Handle timer)
{
	spawnScheme = SKIP;
	tankCount = 0;
	
	bool dummy;
	if (GetTrieValue(hFirstTankSpawningScheme, iCurrentMap, dummy)) spawnScheme = FLOWANDSECONDONEVENT;
	if (GetTrieValue(hSecondTankSpawningScheme, iCurrentMap, dummy)) spawnScheme = FIRSTONEVENT;
	if ((GetConVarFloat(FindConVar("versus_tank_chance_finale")) > 0.0) && spawnScheme != SKIP) L4D2Direct_SetVSTankToSpawnThisRound(InSecondHalfOfRound(), (spawnScheme == FLOWANDSECONDONEVENT));
}

public Action SaveBossFlows(Handle timer)
{
	if (iGameMode == GAMEMODE_COOP)
	{
		if (GetCoopTankToSpawnThisRound()) iTankPercent = RoundToNearest(GetCoopTankFlowPercent() * 100.0);
		else iTankPercent = 0;
	}
	else if (iGameMode == GAMEMODE_VERSUS)
	{
		if (!InSecondHalfOfRound())
		{
			iRoundPercent = 1;
			
			iTankPercent = 0;
			if (L4D2Direct_GetVSTankToSpawnThisRound(0)) iTankPercent = RoundToNearest(GetTankFlow(0) * 100.0);
		}
		else
		{
			iRoundPercent = 2;
			if (iTankPercent != 0) iTankPercent = RoundToNearest(GetTankFlow(1) * 100.0);
		}
	}
}

public Action AddReadyFooter(Handle timer)
{
	if (readyFooterAdded) return Plugin_Continue;
	if (readyUpIsAvailable)
	{
		char readyString[68];
		if (iTankPercent) Format(readyString, sizeof(readyString), "Tank: %d%%", iTankPercent);
		else Format(readyString, sizeof(readyString), "Tank: None");

		AddStringToReadyFooter(readyString);
		readyFooterAdded = true;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

																				PER ROUND
																	
***********************************************************************************************************************************************************************************/
public void OnRoundIsLive()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i)) PrintBossPercents(i);
	}
	if (iGameMode == GAMEMODE_VERSUS) AnnounceSIClasses();
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!readyUpIsAvailable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientConnected(i) && IsClientInGame(i)) PrintBossPercents(i);
		}
		if (iGameMode == GAMEMODE_VERSUS) AnnounceSIClasses();
	}
	if (iGameMode == GAMEMODE_COOP)
	{
		if (GetCoopTankToSpawnThisRound()) CreateTimer(1.0, TankSpawnDelay, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	}
}

public Action TankSpawnDelay(Handle timer)
{
	if (GetBossProximity() >= GetCoopTankFlowPercent())
	{
		CreateTimer(0.5, Timer_SpawnTank, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action Timer_SpawnTank(Handle timer)
{
	if(IsTankInPlay()) return Plugin_Stop;
	else if(iMapTankSpawnAttemptCount >= 10)
	{
		PrintToChatAll("[CB] Failed to find a spawn for tank in maximum allowed attempts"); 
		return Plugin_Stop;
	}
	else
	{
		CheatCommand("z_spawn_old", "tank", "auto");
		/*float spawnPos[3];
		if (L4D_GetRandomPZSpawnPosition(GetRandomSurvivor(), ZC_TANK, 5, spawnPos))
		{
			L4D2_SpawnTank(spawnPos, {0.0, 0.0, 0.0});
		}*/
		++iMapTankSpawnAttemptCount;
		return Plugin_Continue;
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/
void AnnounceSIClasses()
{
    int iSpawns = 0;
    int iSpawnClass[MAXSPAWNS+1];
    
    for (int i = 1; i <= MaxClients && iSpawns < MAXSPAWNS; i++)
	{
        if (!IsConnectedAndInGame(i) || GetClientTeam(i) != TEAM_INFECTED || !IsPlayerAlive(i)) continue;

        iSpawnClass[iSpawns] = GetEntProp(i, Prop_Send, "m_zombieClass");
        iSpawns++;
    }
	
    switch (iSpawns)
	{
        case 4: 
		{
            PrintToSurvivors(
                    "\x01Special Infected: \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01.",
                    L4D2_InfectedNames[iSpawnClass[0]],
                    L4D2_InfectedNames[iSpawnClass[1]],
                    L4D2_InfectedNames[iSpawnClass[2]],
                    L4D2_InfectedNames[iSpawnClass[3]]
                );
        }
        case 3: 
		{
            PrintToSurvivors(
                    "\x01Special Infected: \x04%s\x01, \x04%s\x01, \x04%s\x01.",
                    L4D2_InfectedNames[iSpawnClass[0]],
                    L4D2_InfectedNames[iSpawnClass[1]],
                    L4D2_InfectedNames[iSpawnClass[2]]
                );
        }
        case 2: 
		{
            PrintToSurvivors(
                    "\x01Special Infected: \x04%s\x01, \x04%s\x01.",
                    L4D2_InfectedNames[iSpawnClass[0]],
                    L4D2_InfectedNames[iSpawnClass[1]]
                );
        }
        case 1: 
		{
            PrintToSurvivors(
                    "\x01Special Infected: \x04%s\x01.",
                    L4D2_InfectedNames[iSpawnClass[0]]
                );
        }
    }
}

void PrintBossPercents(int client)
{
	int boss_proximity = RoundToNearest(GetBossProximity() * 100.0);
	if (iGameMode == GAMEMODE_COOP) CPrintToChat(client, "{W}当前: {O}%d%%", boss_proximity);
	else if (iGameMode == GAMEMODE_VERSUS) 
	{
		CPrintToChat(client, "{W}当前: R{O}#%d{W}, {O}%d%%", iRoundPercent, boss_proximity);
		if (hybridScoringAvailable) ClientCommand(client, "sm_bonus");
	}
	
	if (bAllowTankSpawn)
	{
		if (iTankPercent != 0) CPrintToChat(client, "{R}Tank{W}:  [ {G}%d%%{W} ]", iTankPercent);
		else CPrintToChat(client, "{R}Tank{W}:  [ {G}--%%{W} ]");
	}
}

public Action AdjustBossFlow(Handle timer)
{
	L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	
	if ((iGameMode == GAMEMODE_COOP && GetCoopTankFlowPercent() > 0.0) || (iGameMode == GAMEMODE_VERSUS && InSecondHalfOfRound())) return;
	
	char dummy;
	float fTankFlow = -1.0;
	
	if (bAllowTankSpawn && !GetTrieValue(hStaticTankMaps, iCurrentMap, dummy))
	{
		float fMinBanFlow = L4D2_GetMapValueInt("tank_ban_flow_min", -1) / 100.0;
		float fMaxBanFlow = L4D2_GetMapValueInt("tank_ban_flow_max", -1) / 100.0;
		float fBanRange = fMaxBanFlow - fMinBanFlow;
		if (fMinBanFlow > 0 && fMinBanFlow < fCvarMinFlow)
		{
			fBanRange -= (fCvarMinFlow - fMinBanFlow);
		}
		
		fTankFlow = GetRandomFloat(fCvarMinFlow, fCvarMaxFlow - fBanRange);
		if (fTankFlow > fMinBanFlow) fTankFlow += fBanRange;
		
		if (iGameMode == GAMEMODE_COOP)
		{
			SetCoopTankToSpawnThisRound(true);
			SetCoopTankFlowPercent(fTankFlow);
		}
		else if (iGameMode == GAMEMODE_VERSUS)
		{
			L4D2Direct_SetVSTankToSpawnThisRound(0, true);
			L4D2Direct_SetVSTankToSpawnThisRound(1, true);
			L4D2Direct_SetVSTankFlowPercent(0, fTankFlow);
			L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
		}
	}
	else
	{
		if (iGameMode == GAMEMODE_COOP) SetCoopTankToSpawnThisRound(false);
		else if (iGameMode == GAMEMODE_VERSUS)
		{
			L4D2Direct_SetVSTankToSpawnThisRound(0, false);
			L4D2Direct_SetVSTankToSpawnThisRound(1, false);
		}
	}
}

//Command
public Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hFirstTankSpawningScheme, mapname, true);
}

public Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hSecondTankSpawningScheme, mapname, true);
}

public Action StaticTank_Command(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hStaticTankMaps, mapname, true);
}

public Action Reset_Command(int args)
{
	ClearTrie(hStaticTankMaps);
}

public Action SetTank_Command(int client, int args)
{
	char buffer[8];
	GetCmdArg(1, buffer, sizeof(buffer));
	float fTankFlow = StringToFloat(buffer);
	if (iGameMode == GAMEMODE_COOP) SetCoopTankFlowPercent(fTankFlow);
	else if (iGameMode == GAMEMODE_VERSUS)
	{
		L4D2Direct_SetVSTankFlowPercent(0, fTankFlow);
		L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
	}
	PrintToChatAll("Tank刷新地点更改为 %d%%", RoundToNearest(fTankFlow * 100));
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (StrEqual(key, "DisallowThreatType"))
	{
		retVal = 0;
		return Plugin_Handled;
	}
	
	if (StrEqual(key, "ProhibitBosses"))
	{
		retVal = 0;
		return Plugin_Handled;		
	}
	
	return Plugin_Continue;
}

public Action L4D_OnGetMissionVSBossSpawning(float &spawn_pos_min, float &spawn_pos_max, float &tank_chance, float &witch_chance)
{
	if (StrEqual(iCurrentMap, "c7m1_docks")/* || StrEqual(mapname, "c13m2_southpinestream")*/)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action L4D2_OnChangeFinaleStage(int &finaleType, const char[] arg) 
{
	if (spawnScheme != SKIP && (finaleType == FINALE_CUSTOM_TANK || finaleType == FINALE_GAUNTLET_BOSS || finaleType == FINALE_GAUNTLET_ESCAPE))
	{
		tankCount++;
		
		if ((spawnScheme == FLOWANDSECONDONEVENT && tankCount != 2) || 
		(spawnScheme == FIRSTONEVENT && tankCount != 1)) return Plugin_Handled;
	}
	return Plugin_Continue;
}


stock bool GetCoopTankToSpawnThisRound()
{
	return bCoopTankSpawn;
}

stock void SetCoopTankToSpawnThisRound(bool spawn = false)
{
	bCoopTankSpawn = spawn;
}

stock float GetCoopTankFlowPercent()
{
	return fCoopTankFlow;
}

stock void SetCoopTankFlowPercent(float fFlow)
{
	fCoopTankFlow = fFlow;
}

stock bool IsDKR()
{
	if (StrEqual(iCurrentMap, "dkr_m1_motel", false) || StrEqual(iCurrentMap, "dkr_m2_carnival", false) || 
		StrEqual(iCurrentMap, "dkr_m3_tunneloflove", false) || StrEqual(iCurrentMap, "dkr_m4_ferris", false) || 
		StrEqual(iCurrentMap, "dkr_m5_stadium", false)) return true;
	return false;
}
