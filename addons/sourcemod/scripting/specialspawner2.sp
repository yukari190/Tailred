#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <l4d2lib>
#include <l4d2util>
#include <readyup>
#include <DirectInfectedSpawn>

#define NUM_TYPES_INFECTED 6

#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

public Plugin myinfo = 
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "2.0",
	url = ""
};

ConVar 
	hSpawnSize,
	hSSEnable,
	hSILimit,
	hSpawnLimits[NUM_TYPES_INFECTED],
	hSpawnWeights[NUM_TYPES_INFECTED],
	hScaleWeights,
	hSpawnTimeMode,
	hSpawnTimeMin,
	hSpawnTimeMax,
	hIncapAllowance,
	hSurvivorLimit;

Handle hSpawnTimer = null;

int 
	iSpawnLimits[NUM_TYPES_INFECTED],
	iSpawnWeights[NUM_TYPES_INFECTED],
	iSILimit,
	iSpawnSize,
	iSpawnTimeMode,
	iIncapAllowance,
	iSurvivorLimit,
	SpawnCounts[NUM_TYPES_INFECTED],
	gracePeriod;

float 
	fSpawnTimeMin,
	fSpawnTimeMax,
	SpawnTimes[MAXPLAYERS],
	IntervalEnds[NUM_TYPES_INFECTED],
	fInterval,
	g_fTimeLOS[100000]; // not sure what the largest possible userid is

bool bScaleWeights;

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
public void OnPluginStart()
{
	(hSSEnable = CreateConVar("ss_enable", "1", "")).AddChangeHook(ConVarChange_Enable);
	// Server SI max (marked FCVAR_CHEAT; admin only)
	// Spawn limits - this value is flattened to the above server SI Max cvar
	hSILimit = CreateConVar("ss_si_limit", "4", "The max amount of special infected at once", _, true, 1.0);
	hSpawnSize = CreateConVar("ss_spawn_size", "4", "The amount of special infected spawned at each spawn interval", _, true, 1.0);
	hSpawnLimits[SI_SMOKER]		= FindConVar("z_versus_smoker_limit");
	hSpawnLimits[SI_BOOMER]		= FindConVar("z_versus_boomer_limit");
	hSpawnLimits[SI_HUNTER]		= FindConVar("z_versus_hunter_limit");
	hSpawnLimits[SI_SPITTER]	= FindConVar("z_versus_spitter_limit");
	hSpawnLimits[SI_JOCKEY]		= FindConVar("z_versus_jockey_limit");
	hSpawnLimits[SI_CHARGER]	= FindConVar("z_versus_charger_limit");
	// Weights
	hSpawnWeights[SI_SMOKER]	= CreateConVar("ss_smoker_weight",	"50", "The weight for a smoker spawning", _, true, 0.0);
	hSpawnWeights[SI_BOOMER]	= CreateConVar("ss_boomer_weight",	"10", "The weight for a boomer spawning", _, true, 0.0);
	hSpawnWeights[SI_HUNTER]	= CreateConVar("ss_hunter_weight",	"100", "The weight for a hunter spawning", _, true, 0.0);
	hSpawnWeights[SI_SPITTER]	= CreateConVar("ss_spitter_weight", "100", "The weight for a spitter spawning", _, true, 0.0);
	hSpawnWeights[SI_JOCKEY]	= CreateConVar("ss_jockey_weight",	"100", "The weight for a jockey spawning", _, true, 0.0);
	hSpawnWeights[SI_CHARGER]	= CreateConVar("ss_charger_weight", "75", "The weight for a charger spawning", _, true, 0.0);
	hScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = OFF | 1 = ON ] Scale spawn weights with the limits of corresponding SI", _, true, 0.0, true, 1.0);
	// Timer
	hSpawnTimeMin = FindConVar("z_ghost_delay_min");
	hSpawnTimeMax = FindConVar("z_ghost_delay_max");
	hSpawnTimeMode = CreateConVar("ss_time_mode", "0", "The spawn time mode [ 0 = RANDOMIZED | 1 = INCREMENTAL | 2 = DECREMENTAL ]", _, true, 0.0, true, 2.0);

	// Grace period
	hIncapAllowance = CreateConVar( "ss_incap_allowance", "15", "Grace period(sec) per incapped survivor" );
	// sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	hSurvivorLimit = FindConVar("survivor_limit");
	
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		hSpawnLimits[i].AddChangeHook(ConVarChange);
		hSpawnWeights[i].AddChangeHook(ConVarChange);
	}
	hSILimit.AddChangeHook(ConVarChange);
	hSpawnSize.AddChangeHook(ConVarChange);
	hScaleWeights.AddChangeHook(ConVarChange);
	hSpawnTimeMin.AddChangeHook(ConVarChange);
	hSpawnTimeMax.AddChangeHook(ConVarChange);
	hSpawnTimeMode.AddChangeHook(ConVarChange);
	hIncapAllowance.AddChangeHook(ConVarChange);
	hSurvivorLimit.AddChangeHook(ConVarChange);
	ConVarChange(null, "", "");
	
	// 	Cvars
	FindConVar("director_spectate_specials").SetBool(true);
	FindConVar("director_no_specials").SetBool(true); // disable Director spawning specials naturally
	FindConVar("director_no_specials").AddChangeHook(DirectorNoSpecials_Change);
	FindConVar("z_safe_spawn_range").SetInt(0);
	FindConVar("z_spawn_safety_range").SetInt(0);
	FindConVar("z_discard_range").SetInt(1250); // discard zombies farther away than this	
	FindConVar("z_finale_spawn_safety_range").SetInt(0);
	
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", OnPlayerSpawn);
}

public void ConVarChange_Enable(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (hSSEnable.BoolValue)
	{
		StartSpawnTimer();
	}
	else
	{
		EndSpawnTimer();
	}
}

public void DirectorNoSpecials_Change(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.SetBool(true);
}

public void OnPluginEnd()
{
	FindConVar("director_spectate_specials").RestoreDefault();
	FindConVar("director_no_specials").RestoreDefault(); // Disable Director spawning specials naturally
	FindConVar("z_safe_spawn_range").RestoreDefault();
	FindConVar("z_spawn_safety_range").RestoreDefault();
	FindConVar("z_discard_range").RestoreDefault();
	FindConVar("z_finale_spawn_safety_range").RestoreDefault();
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		iSpawnLimits[i] = hSpawnLimits[i].IntValue;
		iSpawnWeights[i] = hSpawnWeights[i].IntValue;
	}
	iSILimit = hSILimit.IntValue;
	iSpawnSize = hSpawnSize.IntValue;
	bScaleWeights = hScaleWeights.BoolValue;
	fSpawnTimeMin = hSpawnTimeMin.FloatValue;
	fSpawnTimeMax = hSpawnTimeMax.FloatValue;
	iSpawnTimeMode = hSpawnTimeMode.IntValue;
	iIncapAllowance = hIncapAllowance.IntValue;
	iSurvivorLimit = hSurvivorLimit.IntValue;
	CalculateSpawnTimes();
}
/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                  SS_SpawnTimers -> SS_SpawnQueue + SS_SpawnQuantities -> SS_SpawnPositioner -> SS_DirectInfectedSpawn
                                                                    
***********************************************************************************************************************************************************************************/

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (	!IsValidInfected(client) || !IsFakeClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;

	if (!AnySurvivorAlive() || IsInReady())
	{
		ForcePlayerSuicide(client);
	}
	return Plugin_Continue;
}
public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!L4D_IsSurvivalMode())
	{ // would otherwise cause spawns in survival before button is pressed
		StartSpawnTimer();
	}
}

public void L4D2_OnRealRoundEnd()
{
	EndSpawnTimer();
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (IsBotInfected(player) && GetInfectedClass(player) != L4D2Infected_Spitter)
	{
		CreateTimer(1.0, Timer_KickBot, player);
	}
}

public Action Timer_KickBot(Handle timer, any client)
{
	if (IsClientConnected(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client);
	}
	return Plugin_Stop;
}

// Slay infected if they have not had LOS to survivors for a defined (hSpawnTimeMin/z_ghost_delay_min) period
public void OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = GetEventInt(event, "userid");
	int client = GetClientOfUserId(userid);
	if (IsBotInfected(client) && !IsTank(client) && userid >= 0)
	{
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer(0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_StarvationLOS(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	// increment tracked LOS time
	if (IsBotInfected(client) && IsPlayerAlive(client))
	{
		if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") || IsValidSurvivor(GetInfectedVictim(client)))
		{
			g_fTimeLOS[userid] = 0.0;
		}
		else
		{
			g_fTimeLOS[userid] += 0.5; 
		}
		// If an SI has not seen the survivors for a while, clone them closer to survivors
		if (g_fTimeLOS[userid] > hSpawnTimeMin.FloatValue)
		{

			int SIClass = GetInfectedClass(client);
			if (SIClass == L4D2Infected_Tank) return Plugin_Stop;
			
			ForcePlayerSuicide(client);
			return Plugin_Stop;
			
			/*float spawnPos[3];
			if (!L4D_GetRandomPZSpawnPosition(GetRandomSurvivor(), view_as<int>(SIClass), 20, spawnPos))
			{
				if (!GridSpawn(SIClass, 100, spawnPos))
				{
					ForcePlayerSuicide(client);
					return Plugin_Stop;
				}
			}
			g_fTimeLOS[userid] = 0.0;
			TeleportEntity(client, spawnPos, NULL_VECTOR, NULL_VECTOR);
			return Plugin_Continue;*/
		}
	}
	else
	{
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                                           START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

//special infected spawn timer based on time modes
void StartSpawnTimer()
{
	//prevent multiple timer instances
	EndSpawnTimer();
	if (!hSSEnable.BoolValue) return;

	fInterval = GetGameTime() + 1.0;
	hSpawnTimer = CreateTimer(1.0, SpawnInfectedAuto, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

/***********************************************************************************************************************************************************************************

                                                                       SPAWN TIMER
                                                                    
***********************************************************************************************************************************************************************************/

public Action SpawnInfectedAuto(Handle timer)
{
	if (IsInReady()) return Plugin_Continue;
	
	if (fInterval - GetGameTime() <= 0.0)
	{ // spawn immediately
		if (fInterval != 0.0)
		{
			GenerateAndExecuteSpawnQueue();
			fInterval = 0.0;
		}
		if (fInterval == 0.0 && !AnyInfectedBotsAlive())
		{
			fInterval = GetGameTime() + GetSpawnTime();
			gracePeriod = 0;
		}
	}
	
	int iIncappedCount = GetIncappedSurvivorsCount();
	if (gracePeriod == 0 && iIncappedCount > 0 && iIncappedCount != iSurvivorLimit)
	{ // grant grace period
		gracePeriod = iIncappedCount * iIncapAllowance;
		
		fInterval += float(gracePeriod);
		CPrintToChatAll("{G}[{W}SS{G}]{W} 因为{B}%d{W}个幸存者无法行动, 授予{B}%d{W}秒{G}宽限期.", iIncappedCount, gracePeriod);
	}
	//CPrintToChatAll("%.0f", (fInterval - GetGameTime() <= 0.0 ? 0.0 : fInterval - GetGameTime()));
	
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                                        END TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

void EndSpawnTimer()
{
	delete hSpawnTimer;
}

/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/
void CalculateSpawnTimes()
{
	if( iSILimit > 1 && iSpawnTimeMode > 0 ) {
		float unit = ( (fSpawnTimeMax - fSpawnTimeMin) / (iSILimit - 1) );
		switch( iSpawnTimeMode )
		{
			case 1:
			{ // incremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMin;
				for( int i = 1; i < MAXPLAYERS; i++ )
				{
					if( i < iSILimit ) {
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					} else {
						SpawnTimes[i] = fSpawnTimeMax;
					}
				}
			}
			case 2:
			{ // decremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMax;
				for( int i = 1; i < MAXPLAYERS; i++ )
				{
					if (i < iSILimit) {
						SpawnTimes[i] = SpawnTimes[i-1] - unit;
					} else {
						SpawnTimes[i] = fSpawnTimeMax;
					}
				}
			}
			//randomized spawn time mode does not use time tables
		}	
	} else { //constant spawn time for if SILimit is 1
		SpawnTimes[0] = fSpawnTimeMax;
	}
}



void GenerateAndExecuteSpawnQueue()
{
	if( CountSpecialInfectedBots() < iSILimit ) { // spawn when infected count hasn't reached limit
		int size;
		int numAllowedSI = iSILimit - CountSpecialInfectedBots();
		if( iSpawnSize > numAllowedSI ) { // prevent amount of special infected from exceeding SILimit
			size = numAllowedSI;
		} else {
			size = iSpawnSize;
		}
		
		// refresh current SI counts
		SITypeCount();
	
		// Initialise spawn queue
		int index;
		int SpawnQueue[MAXPLAYERS];
		for( int i = 0; i < MAXPLAYERS; i++ ) {
			SpawnQueue[i] = -1;
		}		
		// Generate the spawn queue
		for( int i = 0; i < size; i++ ) {
			index = GenerateIndex();
			if (index == -1) {
				break;
			}
			SpawnQueue[i] = index;
			SpawnCounts[index] += 1;
		}
		
		for( int i = 0; i < MAXPLAYERS; i++ ) 
		{
			if( SpawnQueue[i] < 0 ) // end of spawn queue (does not always fill the whole array)
			{ 
				break;
			}
			
			// Execute the spawn queue
			int SIClass = SpawnQueue[i] + 1;
			float spawnPos[3];
			if (!L4D_GetRandomPZSpawnPosition(GetRandomSurvivor(), view_as<int>(SIClass), 20, spawnPos))
			{
				if (!GridSpawn(SIClass, 100, spawnPos))
				{
					return;
				}
			}
			TriggerSpawn(SIClass, spawnPos); // all spawn conditions satisifed
		}
	}
}

void SITypeCount()
{ //Count the number of each SI ingame
	for (int i = 0; i < NUM_TYPES_INFECTED; i++) {
		SpawnCounts[i] = 0;
	}
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) ) { 
			switch( GetInfectedClass(i) )
			{ //detect SI type
				case (L4D2Infected_Smoker):
					SpawnCounts[view_as<int>(L4D2Infected_Smoker)]++; // array indices start 0, where L4D2Infected numbering starts from 1
				
				case (L4D2Infected_Boomer):
					SpawnCounts[view_as<int>(L4D2Infected_Boomer) - 1]++;
				
				case (L4D2Infected_Hunter):
					SpawnCounts[view_as<int>(L4D2Infected_Hunter) - 1]++;
					
				case (L4D2Infected_Spitter):
					SpawnCounts[view_as<int>(L4D2Infected_Spitter) - 1]++;
				
				case (L4D2Infected_Jockey):
					SpawnCounts[view_as<int>(L4D2Infected_Jockey) - 1]++;
				
				case (L4D2Infected_Charger):
					SpawnCounts[view_as<int>(L4D2Infected_Charger) - 1]++;
				
				default:
					break;
			}
		}
	}
}

int GenerateIndex()
{
	int TotalSpawnWeight, StandardizedSpawnWeight;
	
	// temporary spawn weights factoring in SI spawn limits
	int TempSpawnWeights[NUM_TYPES_INFECTED];
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		if( SpawnCounts[i] < iSpawnLimits[i] ) {
			if( bScaleWeights ) {
				TempSpawnWeights[i] = ( iSpawnLimits[i] - SpawnCounts[i] ) * iSpawnWeights[i];
			} else {
				TempSpawnWeights[i] = iSpawnWeights[i];
			}
		} else {
			TempSpawnWeights[i] = 0;
		}
		TotalSpawnWeight += TempSpawnWeights[i];
	}
	
	//calculate end intervals for each spawn
	float unit = 1.0/TotalSpawnWeight;
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		if (TempSpawnWeights[i] >= 0) {
			StandardizedSpawnWeight += TempSpawnWeights[i];
			IntervalEnds[i] = StandardizedSpawnWeight * unit;
		}
	}
	
	float random = GetRandomFloat( 0.0, 1.0 ); //selector r must be within the ith interval for i to be selected
	for (int i = 0; i < NUM_TYPES_INFECTED; i++) {
		//negative and 0 weights are ignored
		if( TempSpawnWeights[i] <= 0 ) continue;
		//r is not within the ith interval
		if( IntervalEnds[i] < random ) continue;
		//selected index i because r is within ith interval
		return i;
	}
	return -1; //no selection because all weights were negative or 0
}

int CountSpecialInfectedBots()
{
    int count = 0;
    for (int i = 1; i < MaxClients; i++)
	{
        if (IsInfected(i) && IsFakeClient(i) && IsPlayerAlive(i))
		{
            count++;
        }
    }
    return count;
}

bool AnyInfectedBotsAlive()
{
    for (int i = 1; i < MaxClients; i++)
	{
        if (IsInfected(i) && IsFakeClient(i) && IsPlayerAlive(i) && GetInfectedClass(i) != L4D2Infected_Tank)
		{
            return true;
        }
    }
    return false;
}

/**
 * @return: true if client is a special infected bot
 */
bool IsBotInfected(int client)
{
    if (IsValidInfected(client) && IsFakeClient(client))
	{
        return true;
    }
    return false; // otherwise
}

bool AnySurvivorAlive()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		if (!IsIncapacitated(i))
		{
			return true;
		}
	}
	return false;
}

float GetSpawnTime()
{
	//only start spawn timer if plugin is enabled
	float time;
	
	if( iSpawnTimeMode > 0 ) { //NOT randomization spawn time mode
		time = SpawnTimes[CountSpecialInfectedBots()]; //a spawn time based on the current amount of special infected
	} else { //randomization spawn time mode
		time = GetRandomFloat( fSpawnTimeMin, fSpawnTimeMax ); //a random spawn time between min and max inclusive
	}
	
	return time;
}

int GetIncappedSurvivorsCount()
{
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	int numIncappedSurvivors = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		if (IsIncapacitated(i) && !IsSurvivorAttacked(i))
		{
			numIncappedSurvivors++;			
		}
	}
	return numIncappedSurvivors;
}
