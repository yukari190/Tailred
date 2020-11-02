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
#include <nativevotes>
#include <readyup>
#define REQUIRE_PLUGIN

#define VANILLA_COOP_SI_LIMIT 2
#define NUM_TYPES_INFECTED 6

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

ConVar hSpawnTimeMin, hSpawnTimeMax;
Handle g_h8SIVote;
char Spawns[NUM_TYPES_INFECTED][16] = {"smoker", "boomer", "hunter", "spitter", "jockey", "charger"};
int SpawnCounts[NUM_TYPES_INFECTED], SpawnerDelayCount, g_iTimeLOS[MAXPLAYERS+1], g_iClass[MAXPLAYERS+1], 
  hSpawnLimits[NUM_TYPES_INFECTED], iGameMode, iSpawnTimeMin, iSpawnTimeMax;
bool g_bReadyUpAvailable, g_bIsRoundActive, g_bIsSpawnerActive, g_bDelaying, g_b8Si;

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
  
public Plugin myinfo = 
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy, 趴趴酱",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	hSpawnTimeMin = CreateConVar("ss_time_min", "12", "受感染的最小自动产卵时间 (秒)", FCVAR_SS_ADDED, true, 1.0);
	hSpawnTimeMax = CreateConVar("ss_time_max", "15", "受感染的最大自动产卵时间 (秒)", FCVAR_SS_ADDED, true, 1.0);
	
	iSpawnTimeMin = GetConVarInt(hSpawnTimeMin);
	iSpawnTimeMax = GetConVarInt(hSpawnTimeMax);
	
	hSpawnTimeMin.AddChangeHook(ConVarChange);
	hSpawnTimeMax.AddChangeHook(ConVarChange);
	
	if (GetConVarInt(hSpawnTimeMin) > GetConVarInt(hSpawnTimeMax)) SetConVarInt(hSpawnTimeMin, GetConVarInt(hSpawnTimeMax));
	
	RegConsoleCmd("sm_8si", Vote8SI);
	
	SetConVarBool( FindConVar("director_spectate_specials"), true );
	SetConVarBool( FindConVar("director_no_specials"), true );
	SetConVarInt( FindConVar("z_safe_spawn_range"), 0 );
	SetConVarInt( FindConVar("z_spawn_safety_range"), 0 );
	SetConVarInt( FindConVar("z_finale_spawn_safety_range"), 0 );
	
	HookEvent("survival_round_start", OnSurvivalRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("player_spawn", PlayerSpawn_Event);
}

public void OnPluginEnd()
{
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") );
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_finale_spawn_safety_range") );
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSpawnTimeMin = hSpawnTimeMin.IntValue;
	iSpawnTimeMax = hSpawnTimeMax.IntValue;
}

public void OnAllPluginsLoaded()
{
	g_bReadyUpAvailable = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup")) g_bReadyUpAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup")) g_bReadyUpAvailable = true;
}

/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                                                    
***********************************************************************************************************************************************************************************/

public void OnMapStart()
{
	iGameMode = Gamemode();
}

public void OnRoundIsLive()
{
	RandomClass();
	g_bIsSpawnerActive = true;
	PrintSettings();
	
	SpawnerDelayCount = 0;
	g_bDelaying = false;
	g_bIsRoundActive = true;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!g_bReadyUpAvailable)
	{
		RandomClass();
		g_bIsSpawnerActive = true;
		PrintSettings();
		
		SpawnerDelayCount = 0;
		g_bDelaying = false;
		g_bIsRoundActive = true;
	}
	
	char gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if (iGameMode == GAMEMODE_VERSUS || iGameMode == GAMEMODE_SCAVENGE) SetFailState("Plugin does not support PvP modes");
	else if (iGameMode != GAMEMODE_SURVIVAL)  CreateTimer(1.0, SpawnInfectedAuto, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Continue;
}

public Action OnSurvivalRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(1.0, SpawnInfectedAuto, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void L4D2_OnRealRoundEnd()
{
	g_bIsRoundActive = false;
	g_bIsSpawnerActive = false;
	g_bDelaying = false;
	SpawnerDelayCount = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsConnectedAndInGame(i) && GetClientTeam(i) != TEAM_SURVIVOR && IsFakeClient(i))
		{
			if (IsPlayerAlive(i)) ForcePlayerSuicide(i);
			else CreateTimer(1.0, Timer_KickBot, i);
		}
	}
}

public Action Vote8SI(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (IsClientAdmin(client))
	{
		g_b8Si = !g_b8Si;
		PrintToChat(client, "\x03%s\x018特感模式", g_b8Si == true ? "开启" : "关闭");
		char map[64];
		GetCurrentMap(map, sizeof(map));
		ForceChangeLevel(map, "");
		return Plugin_Handled;
	}
	if (StartVote(client))
	{
		FakeClientCommand(client, "Vote Yes");
	}
	return Plugin_Handled;
}

bool StartVote(int client)
{
	if (GetClientTeam(client) == 1)
	{
		PrintToChat(client, "观众不允许投票.");
		return false;
	}
	if (NativeVotes_IsNewVoteAllowed())
	{
		int iNumPlayers = 0, iPlayers[MAXPLAYERS+1];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsConnectedAndInGame(i) || IsFakeClient(i) || GetClientTeam(i) == 1) continue;
			
			iPlayers[iNumPlayers++] = i;
		}
		char sBuffer[64];
		g_h8SIVote = NativeVotes_Create(Vote8SIHandler, NativeVotesType_Custom_YesNo);
		Format(sBuffer, sizeof(sBuffer), "x01是否 \x03%s\x01 8特感模式", g_b8Si == true ? "关闭" : "开启");
		NativeVotes_SetDetails(g_h8SIVote, sBuffer);
		NativeVotes_SetInitiator(g_h8SIVote, client);
		NativeVotes_Display(g_h8SIVote, iPlayers, iNumPlayers, 20);
		return true;
	}
	PrintToChat(client, "现在无法开始投票.");
	return false;
}

public int Vote8SIHandler(Handle vote, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select: PrintToChatAll("玩家 %N 已投票", param1);

		case MenuAction_VoteCancel:
		{
			if(param1 == VoteCancel_NoVotes) NativeVotes_DisplayFail(vote, NativeVotesFail_NotEnoughVotes);
			else NativeVotes_DisplayFail(vote, NativeVotesFail_Generic);
		}

		case MenuAction_VoteEnd:
		{
			if(param1 == NATIVEVOTES_VOTE_NO)
			{
				NativeVotes_DisplayFail(vote, NativeVotesFail_Loses);
			}
			else if (vote == g_h8SIVote)
			{
				g_b8Si = !g_b8Si;
				char sBuffer[64];
				Format(sBuffer, sizeof(sBuffer), "\x03%s\x018特感模式", g_b8Si == true ? "开启" : "关闭");
				NativeVotes_DisplayPass(vote, sBuffer);
				char map[64];
				GetCurrentMap(map, sizeof(map));
				ForceChangeLevel(map, "");
			}
		}

		case MenuAction_End:
		{
			g_h8SIVote = INVALID_HANDLE;
			NativeVotes_Close(vote);
		}
	}
}

/***********************************************************************************************************************************************************************************

                                                 					LOS STARVATION
                                                                    
***********************************************************************************************************************************************************************************/

public Action PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("userid"));
	if (IsBotInfected(bot)) CreateTimer(1.0, Timer_KickBot, bot);
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsBotInfected(client)) return;
	g_iTimeLOS[client] = 0;
	g_iClass[client] = GetInfectedClass(client);
	if (g_iClass[client] < 1 || g_iClass[client] > 6) return;

	CreateTimer(1.0, Timer_StarvationLOS, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_StarvationLOS(Handle timer, any client)
{
	if (IsBotInfected(client) && IsPlayerAlive(client))
	{
		if (g_iTimeLOS[client] > 15)
		{
			if (g_iClass[client] == GetInfectedClass(client)) ForcePlayerSuicide(client);
			return Plugin_Stop;
		}
		if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || GetInfectedVictim(client)) g_iTimeLOS[client] = 0;
		else g_iTimeLOS[client]++;
	}
	else return Plugin_Stop;
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                                           START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

public Action SpawnInfectedAuto(Handle timer)
{
	if (!g_bIsRoundActive) return Plugin_Stop;
	
	if (g_bIsSpawnerActive)
	{
		g_bIsSpawnerActive = false;
		SpawnWave();
		g_bDelaying = false;
	}
	else
	{
		if (!g_bDelaying)
		{
			if (CountSpecialInfectedNoTankBots() == 0) SpawnerDelayCount++;
			else SpawnerDelayCount = 0;
			
			if (SpawnerDelayCount >= GetRandomInt(iSpawnTimeMin, iSpawnTimeMax))
			{
				g_bDelaying = true;
				SpawnerDelayCount = 0;
				RandomClass();
				g_bIsSpawnerActive = true;
			}
		}
	}
	return Plugin_Continue;
}

void SpawnWave()
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		SpawnCounts[i] = 0;
	}
	
	SpawnClassPopulation(ZC_SMOKER);
	SpawnClassPopulation(ZC_BOOMER);
	SpawnClassPopulation(ZC_HUNTER);
	SpawnClassPopulation(ZC_SPITTER);
	SpawnClassPopulation(ZC_JOCKEY);
	SpawnClassPopulation(ZC_CHARGER);
}

void SpawnClassPopulation(int targetClass)
{
	CreateTimer(0.5, Timer_SpawnSpecialInfected, targetClass, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_SpawnSpecialInfected(Handle timer, any targetClass)
{
	bool hasSpawnedClassPopulation = (SpawnCounts[targetClass - 1] >= hSpawnLimits[targetClass - 1] ? true : false);
	
	if (hasSpawnedClassPopulation)
	{
		return Plugin_Stop;
	}
	else
	{
		SpawnCounts[targetClass - 1]++;
		CreateTimer(0.5, Timer_SpawnSpecialInfected2, targetClass, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Continue;
	}
}

public Action Timer_SpawnSpecialInfected2(Handle timer, any targetClass)
{
	if (IsClassLimitReached(targetClass))
	{
		return Plugin_Stop;
	}
	else
	{
		AttemptSpawnAuto(targetClass - 1);
		return Plugin_Continue;
	}
}


/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

bool IsClassLimitReached(int targetClass)
{
	int iClassLimit = hSpawnLimits[targetClass - 1];
	int iClassCount = CountSpecialInfectedClass(targetClass);
	return iClassCount < iClassLimit ? false : true;
}

int CountSpecialInfectedClass(int targetClass)
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
	{
        if (IsConnectedAndInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsFakeClient(i) && IsPlayerAlive(i) && !IsClientInKickQueue(i))
		{
            int playerClass = GetEntProp(i, Prop_Send, "m_zombieClass");
            if (playerClass == targetClass)
			{
                count++;
            }
        }
    }
    return count;
}

int CountSpecialInfectedNoTankBots()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
	{
        if (IsConnectedAndInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsFakeClient(i) && IsPlayerAlive(i))
		{
			int zClass = GetInfectedClass(i);
			if ((zClass > 0) && (zClass < 7))
			{
				count++;
			}
        }
    }
    return count;
}

void AttemptSpawnAuto(int classIndex)
{
	char zombieClassName[16];
	zombieClassName = Spawns[classIndex];
	if (CountSpecialInfectedBots() >= VANILLA_COOP_SI_LIMIT)
	{
	    char sBotName[32];
	    Format(sBotName, sizeof(sBotName), "Dummy %s", zombieClassName);
	    int bot = CreateFakeClient(sBotName); 
	    if (bot != 0)
		{
	        ChangeClientTeam(bot, 3);
	        CreateTimer(0.1, Timer_KickBot, bot, TIMER_FLAG_NO_MAPCHANGE);
	    }
	}
	CheatCommand("z_spawn", zombieClassName);
	//L4D2_SpawnSpecial(classIndex+1, vecPos, vecAng);
}

int CountSpecialInfectedBots()
{
    int count = 0;
    for (int i = 1; i <= MaxClients; i++)
	{
        if (IsConnectedAndInGame(i) && GetClientTeam(i) == TEAM_INFECTED && IsFakeClient(i) && IsPlayerAlive(i))
		{
            count++;
        }
    }
    return count;
}

void PrintSettings()
{
	if (g_b8Si) return;
	
    int iSpawns = 0;
    int iSpawnClass[NUM_TYPES_INFECTED+1];
    
    for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		if (hSpawnLimits[i] > 0)
		{
			iSpawnClass[iSpawns] = i+1;
			iSpawns++;
		}
    }
	
	PrintToSurvivors(
		"\x01Special Infected: \x04%s\x01, \x04%s\x01, \x04%s\x01, \x04%s\x01.",
		L4D2_InfectedNames[iSpawnClass[0]],
		L4D2_InfectedNames[iSpawnClass[1]],
		L4D2_InfectedNames[iSpawnClass[2]],
		L4D2_InfectedNames[iSpawnClass[3]]
	);
}

bool IsBotInfected(int client)
{
    if (IsValidInfected(client) && IsFakeClient(client)) return true;
    return false;
}

void RandomClass()
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		hSpawnLimits[i] = 0;
	}
	
	if (g_b8Si)
	{
		switch(GetRandomInt(0, 2)) {
			case 0: {
				hSpawnLimits[SI_SMOKER] = 2;
				hSpawnLimits[SI_BOOMER] = 1;
				hSpawnLimits[SI_HUNTER] = 2;
				hSpawnLimits[SI_SPITTER] = 1;
				hSpawnLimits[SI_JOCKEY] = 1;
				hSpawnLimits[SI_CHARGER] = 1;
			} case 1: {
				hSpawnLimits[SI_SMOKER] = 1;
				hSpawnLimits[SI_BOOMER] = 1;
				hSpawnLimits[SI_HUNTER] = 2;
				hSpawnLimits[SI_SPITTER] = 1;
				hSpawnLimits[SI_JOCKEY] = 2;
				hSpawnLimits[SI_CHARGER] = 1;
			} case 2: {
				hSpawnLimits[SI_SMOKER] = 1;
				hSpawnLimits[SI_BOOMER] = 1;
				hSpawnLimits[SI_HUNTER] = 2;
				hSpawnLimits[SI_SPITTER] = 1;
				hSpawnLimits[SI_JOCKEY] = 1;
				hSpawnLimits[SI_CHARGER] = 2;
			}
		}

		
		return;
	}
	
	switch(GetRandomInt(0, 27)) {
		case 0: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		}
		case 1: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 2: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 0;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 3: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 4: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 5: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 6: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 0;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 7: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 8: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 9: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 0;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 10: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 0;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 11: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 0;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 12: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 13: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 14: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 1;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 15: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 16: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 17: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 18: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 19: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 20: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 21: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 22: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 1;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 23: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 0;
		} case 24: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 1;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 25: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 26: {
			hSpawnLimits[SI_SMOKER] = 0;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 1;
			hSpawnLimits[SI_CHARGER] = 1;
		} case 27: {
			hSpawnLimits[SI_SMOKER] = 1;
			hSpawnLimits[SI_BOOMER] = 0;
			hSpawnLimits[SI_HUNTER] = 2;
			hSpawnLimits[SI_SPITTER] = 0;
			hSpawnLimits[SI_JOCKEY] = 0;
			hSpawnLimits[SI_CHARGER] = 1;
		} 
	}
}
