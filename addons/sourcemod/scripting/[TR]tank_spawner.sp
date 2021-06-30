#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#include <[LIB]l4d2library>
#include <[LIB]builtinvotes_native>
#undef REQUIRE_PLUGIN
#include <[LIB]readyup>
//#include <l4d2_hybrid_scoremod>
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
	author = "CanadaRox, ProdigySim, Jahze, Stabby, CircleSquared, Visor, Tabun, Breezy, Tordecybombo, Yukari190",
	version = "1.0",
	description = "控制每回合tank刷新"
};

StringMap hFirstTankSpawningScheme, hSecondTankSpawningScheme, hStaticTankMaps;
ConVar hVsBossChanceFinale, hVsBossFlowMin, hVsBossFlowMax, hAllowTankSpawn;
float fVsBossChanceFinale;
int tankCount, iTankPercent, iRoundPercent, spawnScheme, g_iTankFlow, iCvarMinFlow, iCvarMaxFlow;
bool readyUpIsAvailable, hybridScoringAvailable, readyFooterAdded, bAllowTankSpawn, bVoteStart, bIsRemix, bValidSpawn[101];
char sCurrentMap[64];

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("AddStringToReadyFooter");
	
	CreateNative("IsStaticTankMap", Native_IsStaticTankMap); 				// Used for other plugins to check if the current map contains a static tank spawn
	CreateNative("IsDarkCarniRemix", Native_IsDarkCarniRemix); 				// Used for other plugins to check if the current map is Dark Carnival: Remix (It tends to break things when it comes to bosses)
	RegPluginLibrary("tank_spawner");
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
	hVsBossChanceFinale = FindConVar("versus_tank_chance_finale");
	hVsBossFlowMin = FindConVar("versus_boss_flow_min");
	hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	hAllowTankSpawn = CreateConVar("l4d2_allow_tank_spawn", "1");
	
	hVsBossChanceFinale.AddChangeHook(ConVarChange);
	hVsBossFlowMin.AddChangeHook(ConVarChange);
	hVsBossFlowMax.AddChangeHook(ConVarChange);
	hAllowTankSpawn.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	hFirstTankSpawningScheme = new StringMap();
	hSecondTankSpawningScheme = new StringMap();
	hStaticTankMaps = new StringMap();
	
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_cu", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_cur", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_current", Cmd_BossPercent, "Boss产生的百分比");
	
	RegServerCmd("tank_map_flow_and_second_event", SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event", SetMapSecondTankSpawningScheme);
	RegServerCmd("static_tank_map", StaticTank_Command);
	RegServerCmd("reset_static_maps", Reset_Command);
	
	RegConsoleCmd("sm_settank", SetTank_Command);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fVsBossChanceFinale = hVsBossChanceFinale.FloatValue;
	iCvarMinFlow = RoundFloat(hVsBossFlowMin.FloatValue * 100);
	iCvarMaxFlow = RoundFloat(hVsBossFlowMax.FloatValue * 100);
	bAllowTankSpawn = hAllowTankSpawn.BoolValue;
}

public int Native_IsStaticTankMap(Handle plugin, int numParams)
{
	return IsStaticTankMap();
}

public int Native_IsDarkCarniRemix(Handle plugin, int numParams)
{
	return bIsRemix;
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
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
		  PrintBossPercents(i);
	}
	return Plugin_Handled;
}

public void OnMapStart()
{
	GetCurrentMapLower(sCurrentMap, sizeof(sCurrentMap));
	bIsRemix = IsDKR();
	iTankPercent = 0;
	spawnScheme = SKIP;
	bool dummy;
	if (GetTrieValue(hFirstTankSpawningScheme, sCurrentMap, dummy))
	{
		spawnScheme = FLOWANDSECONDONEVENT;
	}
	if (GetTrieValue(hSecondTankSpawningScheme, sCurrentMap, dummy))
	{
		spawnScheme = FIRSTONEVENT;
	}
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (!bAllowTankSpawn) return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	return Plugin_Handled;
}

public Action L4D_OnSpawnWitchBride(const float vector[3], const float qangle[3])
{
    return Plugin_Handled;
}

public void L4D_OnRoundStart()
{
	CreateTimer(1.0, AdjustBossFlow);
	readyFooterAdded = false;
	bVoteStart = false;
	tankCount = 0;
	
	if (!bIsRemix)
	{
		CreateTimer(5.0, SaveBossFlows);
		CreateTimer(6.0, AddReadyFooter);
	}
}

public Action SaveBossFlows(Handle timer)
{
	if (!L4D2_IsSecondRound())
	{
		iRoundPercent = 1;
		if (L4D2_GetTankToSpawn())
		{
			iTankPercent = L4D2_GetTankFlowPercent();
		}
	}
	else
	{
		iRoundPercent = 2;
	}
}

public Action AddReadyFooter(Handle timer)
{
	if (readyFooterAdded) return Plugin_Continue;
	if (readyUpIsAvailable)
	{
		char readyString[68];
		if (L4D2_GetTankToSpawn()) Format(readyString, sizeof(readyString), "Tank: %d%%", iTankPercent);
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
		if (IsClientInGame(i))
		  PrintBossPercents(i);
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!readyUpIsAvailable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			  PrintBossPercents(i);
		}
	}
}

/***********************************************************************************************************************************************************************************

																				UTILITY
																	
***********************************************************************************************************************************************************************************/
void PrintBossPercents(int client)
{
	int boss_proximity = L4D2_GetHighestSurvivorFlow();
	CPrintToChat(client, "{W}当前: R{O}#%d{W}, {O}%d%%", iRoundPercent, boss_proximity);
	if (hybridScoringAvailable) ClientCommand(client, "sm_bonus");
	
	if (bAllowTankSpawn)
	{
		if (L4D2_GetTankToSpawn()) CPrintToChat(client, "{R}Tank{W}:  [ {G}%d%%{W} ]", iTankPercent);
		else CPrintToChat(client, "{R}Tank{W}:  [ {G}--%%{W} ]");
	}
}

public Action AdjustBossFlow(Handle timer)
{
	if (L4D2_IsSecondRound()) return;
	L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
	L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	
	//char dummy;
	//float fTankFlow = -1.0;
	
	if (bAllowTankSpawn && !IsStaticTankMap())
	{
		int iMinBanFlow = L4D_GetMapValueInt("tank_ban_flow_min", -1);
		int iMaxBanFlow = L4D_GetMapValueInt("tank_ban_flow_max", -1);
		/*int iBanRange = iMaxBanFlow - iMinBanFlow;
		if (iMinBanFlow > 0 && iMinBanFlow < iCvarMinFlow)
		{
			iBanRange -= (iCvarMinFlow - iMinBanFlow);
		}
		fTankFlow = GetRandomFloat(iCvarMinFlow, iCvarMaxFlow - iBanRange);
		if (fTankFlow > iMinBanFlow) fTankFlow += iBanRange;*/
		
        int iValidSpawnTotal = 0;
        for (int i = 0; i <= 100; i++)
		{
            bValidSpawn[i] = (iCvarMinFlow <= i && i <= iCvarMaxFlow) && !(iMinBanFlow <= i && i <= iMaxBanFlow);
            if (bValidSpawn[i]) iValidSpawnTotal++;
        }

        if (iValidSpawnTotal == 0)
		{
            SetTankPercent(0);
        }
        else
		{
            int n = Math_GetRandomInt(1, iValidSpawnTotal);

            for (int iTankFlow = 0; iTankFlow <= 100; iTankFlow++)
			{
                if (bValidSpawn[iTankFlow])
				{
                    n--;
                    if (n == 0)
					{
						SetTankPercent(iTankFlow);
                        break;
                    }
                }
            }
        }
		
		if (fVsBossChanceFinale > 0.0 && spawnScheme != SKIP)
		{
			L4D2_SetTankToSpawn(spawnScheme == FLOWANDSECONDONEVENT);
		}
	}
	else
	{
		SetTankPercent(0);
	}
}


//Command
public Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	hFirstTankSpawningScheme.SetValue(mapname, true);
}

public Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	hSecondTankSpawningScheme.SetValue(mapname, true);
}

public Action StaticTank_Command(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	hStaticTankMaps.SetValue(mapname, true);
}

public Action Reset_Command(int args)
{
	ClearTrie(hStaticTankMaps);
}

public Action SetTank_Command(int client, int args)
{
	char buffer[8];
	GetCmdArg(1, buffer, sizeof(buffer));
	g_iTankFlow = StringToInt(buffer);
	Format(buffer, sizeof(buffer), "将Tank刷新点更改为 %s ?", buffer);
	bVoteStart = BuiltinVotes_StartVoteAllTeam(client, buffer);
}

public void BuiltinVotes_VoteResult()
{
	if (bVoteStart)
	{
		SetTankPercent(g_iTankFlow);
		iTankPercent = L4D2_GetTankFlowPercent();
		PrintToChatAll("Tank刷新地点更改为 %d%%", iTankPercent);
	}
	bVoteStart = false;
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

bool IsDKR()
{
	if (StrEqual(sCurrentMap, "dkr_m1_motel", false) || StrEqual(sCurrentMap, "dkr_m2_carnival", false) || 
		StrEqual(sCurrentMap, "dkr_m3_tunneloflove", false) || StrEqual(sCurrentMap, "dkr_m4_ferris", false) || 
		StrEqual(sCurrentMap, "dkr_m5_stadium", false)) return true;
	return false;
}

public bool IsStaticTankMap()
{
	bool tempValue;
	if (hStaticTankMaps.GetValue(sCurrentMap, tempValue)) return true;
	else return false;
}

public void SetTankPercent(int percent)
{
	float p_newPercent;
	p_newPercent = float(percent);

	if (p_newPercent == 0.0)
	{
		L4D2_SetTankFlowPercent(0.0);
		L4D2_SetTankToSpawn(false);
	}
	else if (p_newPercent == 100.0)
	{
		L4D2_SetTankFlowPercent(1.0);
		L4D2_SetTankToSpawn(true);
	}
	else
	{
		p_newPercent = (p_newPercent/100);
		L4D2_SetTankFlowPercent(p_newPercent);
		L4D2_SetTankToSpawn(true);
	}
}

#define SIZE_OF_INT         2147483647 // without 0
int Math_GetRandomInt(int min, int max)
{
    int random = GetURandomInt();

    if (random == 0) {
        random++;
    }

    return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

stock void StrToLower(char[] arg)
{
    for (int i = 0; i < strlen(arg); i++)
	{
        arg[i] = CharToLower(arg[i]);
    }
}

stock int GetCurrentMapLower(char[] buffer, int buflen)
{
    int iBytesWritten = GetCurrentMap(buffer, buflen);
    StrToLower(buffer);
    return iBytesWritten;
}
