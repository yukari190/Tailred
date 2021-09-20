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
	hSILimit,
	hSpawnLimits[NUM_TYPES_INFECTED],
	hSpawnWeights[NUM_TYPES_INFECTED],
	hScaleWeights,
	hSpawnTimeMode,
	hSpawnTimeMin,
	hSpawnTimeMax,
	hIncapAllowance,
	hSurvivorLimit;

Handle hSpawnTimer;

int 
	iSpawnLimits[NUM_TYPES_INFECTED],
	iSpawnWeights[NUM_TYPES_INFECTED],
	iSILimit,
	iSpawnSize,
	iSpawnTimeMode,
	iIncapAllowance,
	iSurvivorLimit,
	SpawnCounts[NUM_TYPES_INFECTED];

float 
	fSpawnTimeMin,
	fSpawnTimeMax,
	SpawnTimes[MAXPLAYERS],
	IntervalEnds[NUM_TYPES_INFECTED];

bool 
	g_bHasSpawnTimerStarted = true,
	bScaleWeights;

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
public void OnPluginStart()
{
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
	hSpawnTimeMode = CreateConVar("ss_time_mode", "1", "The spawn time mode [ 0 = RANDOMIZED | 1 = INCREMENTAL | 2 = DECREMENTAL ]", _, true, 0.0, true, 2.0);

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
	CloseHandle(hSpawnTimer);
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
	if (!L4D2_IsSurvival()) 
	{ // would otherwise cause spawns in survival before button is pressed
		g_bHasSpawnTimerStarted = false;
		StartSpawnTimer();
	}
}

public void L4D2_OnRealRoundEnd()
{
	EndSpawnTimer(true);
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
}

/***********************************************************************************************************************************************************************************

                                                                           START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

//special infected spawn timer based on time modes
void StartSpawnTimer()
{
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	float time;
	
	if( iSpawnTimeMode > 0 ) { //NOT randomization spawn time mode
		time = SpawnTimes[CountSpecialInfectedBots()]; //a spawn time based on the current amount of special infected
	} else { //randomization spawn time mode
		time = GetRandomFloat( fSpawnTimeMin, fSpawnTimeMax ); //a random spawn time between min and max inclusive
	}
	g_bHasSpawnTimerStarted = true;
	hSpawnTimer = CreateTimer( time, SpawnInfectedAuto, TIMER_FLAG_NO_MAPCHANGE );
}

/***********************************************************************************************************************************************************************************

                                                                       SPAWN TIMER
                                                                    
***********************************************************************************************************************************************************************************/

public Action SpawnInfectedAuto(Handle timer)
{
	if (IsInReady())
	{
		StartSpawnTimer();
		return Plugin_Handled;
	}
	g_bHasSpawnTimerStarted = false; 
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	int numIncappedSurvivors = 0;
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		if(IsIncapacitated(index) && !IsPinned(index))
		{
			numIncappedSurvivors++;			
		}
	}
	if( numIncappedSurvivors > 0 && numIncappedSurvivors != iSurvivorLimit )
	{ // grant grace period
		int gracePeriod = numIncappedSurvivors * iIncapAllowance;
		CreateTimer( float(gracePeriod), Timer_GracePeriod, _, TIMER_FLAG_NO_MAPCHANGE );
		CPrintToChatAll("{G}[{W}SS{G}]{W} {B}%d{W}s {G}grace period{W} was granted because of {B}%d{W} incapped survivor(s)", gracePeriod, numIncappedSurvivors);
	}
	else
	{ // spawn immediately
		GenerateAndExecuteSpawnQueue();
	}
	// Start timer for next spawn group
	StartSpawnTimer();
	return Plugin_Handled;
}

public Action Timer_GracePeriod(Handle timer)
{
	GenerateAndExecuteSpawnQueue();
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                        END TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

void EndSpawnTimer(bool bForce = false)
{
	if (g_bHasSpawnTimerStarted || bForce)
	{
		if (hSpawnTimer != null)
		{
			KillTimer(hSpawnTimer);
			hSpawnTimer = null;
		}
		g_bHasSpawnTimerStarted = false;
	}
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
			L4D2_Infected SIClass = view_as<L4D2_Infected>(SpawnQueue[i] + 1);
			float spawnPos[3];
			if (L4D_GetRandomPZSpawnPosition(L4D2_GetRandomSurvivor(), view_as<int>(SIClass), 20, spawnPos))
			{
				TriggerSpawn(SIClass, spawnPos); // all spawn conditions satisifed
			}
			else if (GridSpawn(SIClass, 100, spawnPos))
			{
				TriggerSpawn(SIClass, spawnPos); // all spawn conditions satisifed
			}
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
        if (IsBotInfected(i) && IsPlayerAlive(i))
		{
            count++;
        }
    }
    return count;
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

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsValidSurvivor(client))
	{
		// check if held by:
		if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = true; // smoker
		if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = true; // hunter
		if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = true; // charger carry
		if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = true; // charger pound
		if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

bool AnySurvivorAlive()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsClientInGame(index)) continue;
		if (IsPlayerAlive(index) && !IsIncapacitated(index))
		{
			return true;
		}
	}
	return false;
}