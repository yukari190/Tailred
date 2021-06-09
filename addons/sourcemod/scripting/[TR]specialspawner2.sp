#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>
#include <[LIB]navmesh>
#include <[LIB]DirectInfectedSpawn>

#define BOUNDINGBOX_INFLATION_OFFSET 0.5

#define NUM_TYPES_INFECTED 6

// array indices for Special Infected
#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

// Settings upon load
ConVar cvSpawnSize;
ConVar cvSILimit;
ConVar cvSpawnLimits[NUM_TYPES_INFECTED];
ConVar cvSpawnWeights[NUM_TYPES_INFECTED];
ConVar cvScaleWeights;
ConVar cvSpawnProximityMin;
ConVar cvSpawnProximityMax;
ConVar cvRearSpawnMaxTrailingDistance;
ConVar cvSpawnTimeMode;
ConVar cvSpawnTimeMin;
ConVar cvSpawnTimeMax;
ConVar cvIncapAllowance;
ConVar cvSurvivorLimit;

int iSpawnLimits[NUM_TYPES_INFECTED];
int iSpawnWeights[NUM_TYPES_INFECTED];
int iSILimit;
int iSpawnSize;
bool bScaleWeights;
float fSpawnTimeMin;
float fSpawnTimeMax;
int iSpawnTimeMode;
int iSpawnProximityMin;
int iSpawnProximityMax;
float fRearSpawnMaxTrailingDistance;
int iIncapAllowance;
int iSurvivorLimit;

int SpawnCounts[NUM_TYPES_INFECTED];

Handle hSpawnTimer;

float SpawnTimes[MAXPLAYERS];
float IntervalEnds[NUM_TYPES_INFECTED];

int g_bHasSpawnTimerStarted = true;

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
  
public Plugin myinfo = 
{
	name = "Special Spawner",
	author = "Tordecybombo, breezy",
	description = "Provides customisable special infected spawing beyond vanilla coop limits",
	version = "2.0",
	url = ""
};

public void OnPluginStart()
{
	// Server SI max (marked FCVAR_CHEAT; admin only)
	// Spawn limits - this value is flattened to the above server SI Max cvar
	cvSILimit = CreateConVar("ss_si_limit", "4", "The max amount of special infected at once", _, true, 1.0);
	cvSpawnSize = CreateConVar("ss_spawn_size", "4", "The amount of special infected spawned at each spawn interval", _, true, 1.0);
	cvSpawnLimits[SI_SMOKER]		= CreateConVar("ss_smoker_limit",	"1", "The max amount of smokers present at once", _, true, 0.0, true, 14.0);
	cvSpawnLimits[SI_BOOMER]		= CreateConVar("ss_boomer_limit",	"1", "The max amount of boomers present at once", _, true, 0.0, true, 14.0);
	cvSpawnLimits[SI_HUNTER]		= CreateConVar("ss_hunter_limit",	"2", "The max amount of hunters present at once", _, true, 0.0, true, 14.0);
	cvSpawnLimits[SI_SPITTER]	= CreateConVar("ss_spitter_limit",	"1", "The max amount of spitters present at once", _, true, 0.0, true, 14.0);
	cvSpawnLimits[SI_JOCKEY]		= CreateConVar("ss_jockey_limit",	"2", "The max amount of jockeys present at once", _, true, 0.0, true, 14.0);
	cvSpawnLimits[SI_CHARGER]	= CreateConVar("ss_charger_limit",	"1", "The max amount of chargers present at once", _, true, 0.0, true, 14.0);
	// Weights
	cvSpawnWeights[SI_SMOKER]	= CreateConVar("ss_smoker_weight",	"50", "The weight for a smoker spawning", _, true, 0.0);
	cvSpawnWeights[SI_BOOMER]	= CreateConVar("ss_boomer_weight",	"10", "The weight for a boomer spawning", _, true, 0.0);
	cvSpawnWeights[SI_HUNTER]	= CreateConVar("ss_hunter_weight",	"100", "The weight for a hunter spawning", _, true, 0.0);
	cvSpawnWeights[SI_SPITTER]	= CreateConVar("ss_spitter_weight", "100", "The weight for a spitter spawning", _, true, 0.0);
	cvSpawnWeights[SI_JOCKEY]	= CreateConVar("ss_jockey_weight",	"100", "The weight for a jockey spawning", _, true, 0.0);
	cvSpawnWeights[SI_CHARGER]	= CreateConVar("ss_charger_weight", "75", "The weight for a charger spawning", _, true, 0.0);
	cvScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = OFF | 1 = ON ] Scale spawn weights with the limits of corresponding SI", _, true, 0.0, true, 1.0);
	// Timer
	cvSpawnTimeMin = CreateConVar("ss_time_min", "18.0", "The minimum auto spawn time (seconds) for infected", _, true, 1.0);
	cvSpawnTimeMax = CreateConVar("ss_time_max", "22.0", "The maximum auto spawn time (seconds) for infected", _, true, cvSpawnTimeMin.FloatValue);
	cvSpawnTimeMode = CreateConVar("ss_time_mode", "1", "The spawn time mode [ 0 = RANDOMIZED | 1 = INCREMENTAL | 2 = DECREMENTAL ]", _, true, 0.0, true, 2.0);
	/*
	/	CNavArea IDs appear to move into the six digits, whereas the CNavArea area indices move into the four digits
	*/
	cvSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "最接近SI的可能是生还者", _, true, 1.0 );
	cvSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "一个SI可以产卵到幸存者的最远的地方", _, true, float(cvSpawnProximityMin.IntValue) );
	cvRearSpawnMaxTrailingDistance = CreateConVar("ss2_rearspawn_max_trailing_distance", "150", "Limit set on ", _, true, 0.0);
	// Grace period
	cvIncapAllowance = CreateConVar( "ss_incap_allowance", "15", "Grace period(sec) per incapped survivor" );
	// sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	cvSurvivorLimit = FindConVar("survivor_limit");
	
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		cvSpawnLimits[i].AddChangeHook(ConVarChange);
		cvSpawnWeights[i].AddChangeHook(ConVarChange);
	}
	cvSILimit.AddChangeHook(ConVarChange);
	cvSpawnSize.AddChangeHook(ConVarChange);
	cvScaleWeights.AddChangeHook(ConVarChange);
	cvSpawnTimeMin.AddChangeHook(ConVarChange);
	cvSpawnTimeMax.AddChangeHook(ConVarChange);
	cvSpawnTimeMode.AddChangeHook(ConVarChange);
	cvSpawnProximityMin.AddChangeHook(ConVarChange);
	cvSpawnProximityMax.AddChangeHook(ConVarChange);
	cvRearSpawnMaxTrailingDistance.AddChangeHook(ConVarChange);
	cvIncapAllowance.AddChangeHook(ConVarChange);
	cvSurvivorLimit.AddChangeHook(ConVarChange);
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	// 	Cvars
	SetConVarBool( FindConVar("director_spectate_specials"), true );
	SetConVarBool( FindConVar("director_no_specials"), true ); // disable Director spawning specials naturally
	SetConVarInt( FindConVar("z_safe_spawn_range"), 0 );
	SetConVarInt( FindConVar("z_spawn_safety_range"), 0 );
	SetConVarInt( FindConVar("z_discard_range"), 1250 ); // discard zombies farther away than this	
	SetConVarInt( FindConVar("z_finale_spawn_safety_range"), 0 );
}

public void OnPluginEnd()
{
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_discard_range") );
	ResetConVar( FindConVar("z_finale_spawn_safety_range") );
	CloseHandle(hSpawnTimer);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 0; i < NUM_TYPES_INFECTED; i++)
	{
		iSpawnLimits[i] = cvSpawnLimits[i].IntValue;
		iSpawnWeights[i] = cvSpawnWeights[i].IntValue;
	}
	iSILimit = cvSILimit.IntValue;
	iSpawnSize = cvSpawnSize.IntValue;
	bScaleWeights = cvScaleWeights.BoolValue;
	fSpawnTimeMin = cvSpawnTimeMin.FloatValue;
	fSpawnTimeMax = cvSpawnTimeMax.FloatValue;
	iSpawnTimeMode = cvSpawnTimeMode.IntValue;
	iSpawnProximityMin = cvSpawnProximityMin.IntValue;
	iSpawnProximityMax = cvSpawnProximityMax.IntValue;
	fRearSpawnMaxTrailingDistance = cvRearSpawnMaxTrailingDistance.FloatValue;
	iIncapAllowance = cvIncapAllowance.IntValue;
	iSurvivorLimit = cvSurvivorLimit.IntValue;
	CalculateSpawnTimes();
}
/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                  SS_SpawnTimers -> SS_SpawnQueue + SS_SpawnQuantities -> SS_SpawnPositioner -> SS_DirectInfectedSpawn
                                                                    
***********************************************************************************************************************************************************************************/

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	// Disable for PvP modes
	if(L4D2_IsVersus() || L4D2_IsScavenge())
	{ SetFailState("Plugin does not support PvP modes"); } 
	else if (!L4D2_IsSurvival()) 
	{ // would otherwise cause spawns in survival before button is pressed
		g_bHasSpawnTimerStarted = false;
		StartSpawnTimer();
	}
}

public void L4D2_OnRealRoundEnd()
{
	EndSpawnTimer(true);
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
	g_bHasSpawnTimerStarted = false; 
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	int numIncappedSurvivors = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		if(L4D2_IsPlayerIncap(index) && !IsPinned(index))
		{
			numIncappedSurvivors++;			
		}
	}
	if( numIncappedSurvivors > 0 && numIncappedSurvivors != iSurvivorLimit )
	{ // grant grace period
		int gracePeriod = numIncappedSurvivors * iIncapAllowance;
		CreateTimer( float(gracePeriod), Timer_GracePeriod, _, TIMER_FLAG_NO_MAPCHANGE );
		L4D2_CPrintToChatAll("{G}[{W}SS{G}]{W} {B}%d{W}s {G}grace period{W} was granted because of {B}%d{W} incapped survivor(s)", gracePeriod, numIncappedSurvivors);
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
	if( g_bHasSpawnTimerStarted || bForce ) {
		if( hSpawnTimer != INVALID_HANDLE ) {
			CloseHandle(hSpawnTimer);
			hSpawnTimer = INVALID_HANDLE;
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
		// Execute the spawn queue
		NavMeshSpawn(SpawnQueue);
	}
}

void SITypeCount()
{ //Count the number of each SI ingame
	for (int i = 0; i < NUM_TYPES_INFECTED; i++) {
		SpawnCounts[i] = 0;
	}
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) ) { 
			switch( L4D2_GetInfectedClass(i) )
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


/***********************************************************************************************************************************************************************************

                                                 								AUTOMATIC SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/
 /* 
	 * TODO: 
	 * - spawns are appearing in clustered locationsl, ook into reducing spawn condition check strictness
	 */
void NavMeshSpawn ( const int SpawnQueue[MAXPLAYERS] )
{
	int rearSurvivorFlow = GetRearSurvivorFlow(); // The rear survivor's flow distance is required to prevent spawns later spawning too far behind
	ArrayList ProximateSpawns;
	ProximateSpawns = new ArrayList();
	
	/*
	 * Collate all spawn areas near survivors
	 */
	int countFoundSpawnAreas = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int thisClient = L4D2_GetSurvivorOfIndex(i);
		if (thisClient == 0 || !IsPlayerAlive(thisClient)) continue;
		float posThisSurvivor[3]; // Need this survivor's coordinates to start search
		char nameThisSurvivor[32]; 
		GetClientName(thisClient, nameThisSurvivor, sizeof(nameThisSurvivor)); 
		if ( GetClientAbsOrigin(thisClient, posThisSurvivor) )
		{
			CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); // Identify closest navmesh tile from their coordinates
			if ( areaThisSurvivor != INVALID_NAV_AREA )
			{
				ArrayStack hereProximates = new ArrayStack(); // Get nearby navmesh tiles
				NavMesh_CollectSurroundingAreas(hereProximates, areaThisSurvivor); 
				while ( !hereProximates.Empty )
				{
					CNavArea area = INVALID_NAV_AREA; // for each discovered tile, check we have not seen it before 
					PopStackCell(hereProximates, area); 
					if ( area != INVALID_NAV_AREA && ProximateSpawns.FindValue(area) == -1 )
					{
						float posArea[3];
						int indexArea = view_as<int>(NavMesh_FindAreaByID(view_as<int>(area.ID)));
						if ( NavMeshArea_GetCenter(indexArea, posArea) ) // returns true if successful
						{
							int flowThisArea = GetFlow(posArea);
							if ( flowThisArea >= 0 ) // TODO: checking for flow distance invalidates potential spawn areas with no flow distance attached, not sure of ramifications
							{
								if ( (rearSurvivorFlow - flowThisArea) < fRearSpawnMaxTrailingDistance )
								{
									++countFoundSpawnAreas;
									if ( CheckSpawnConditions(area) ) // check each tile meets our spawn conditions
									{
										ProximateSpawns.Push(indexArea); // save this tile
									} 
								}
							}
						}
						else
						{
							PrintToServer("NavMeshSpawn(): Failed to find center position for spawn area of ID: %d; unable to calculate flow distance from rear survivor", indexArea);
						}
						
					} 
				}
				delete hereProximates;
			}
			else 
			{
				PrintToServer("NavMeshSpawn(): No CNavArea found near %s required to search for proximate spawn areas", nameThisSurvivor);
			}
		} 
		else 
		{
			PrintToServer("NavMeshSpawn(): Unable to obtain coordinates for survivor %s", nameThisSurvivor);
		}
	}
	PrintToServer("NavMeshSpawn(): Found %d spawns near survivors, of which %d met spawn conditions", countFoundSpawnAreas, ProximateSpawns.Length);
	
	// Spawn all SI in queue
	if ( ProximateSpawns.Length > 0 ) {	
		for( int i = 0; i < MAXPLAYERS; i++ ) 
		{
			if( SpawnQueue[i] < 0 ) // end of spawn queue (does not always fill the whole array)
			{ 
				break;
			}
			else
			{
				int spawnIndex = GetRandomInt(0, ProximateSpawns.Length - 1);	
				int indexRandomSpawn = ProximateSpawns.Get(spawnIndex);
				float posRandomSpawn[3]; 
				if ( NavMeshArea_GetCenter(indexRandomSpawn, posRandomSpawn) ) // returns true if successful
				{
					TriggerSpawn( view_as<L4D2_Infected>(SpawnQueue[i] + 1), posRandomSpawn, NULL_VECTOR);
				}
				else
				{
					PrintToServer("NavMeshSpawn(): Failed to spawn at NavMesh index %d; cannot determine mesh center coordinates", indexRandomSpawn);
				}	
			}
		}
	}
	else 
	{
		LogError("NavMeshSpawn(): Failed to find any proximate spawns");
	} 
	delete ProximateSpawns;
}

bool CheckSpawnConditions(CNavArea spawn)
{
	bool shouldSpawn = false;
	
	int shortestPath = -1; // Find shortest path cost to any member of the survivor team
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int thisClient = L4D2_GetSurvivorOfIndex(i);
		if (thisClient == 0 || !IsPlayerAlive(thisClient)) continue;
		float posThisSurvivor[3];			
		GetClientAbsOrigin(thisClient, posThisSurvivor);
		CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); 
		int indexAreaThisSurvivor = view_as<int>(NavMesh_FindAreaByID(view_as<int>(areaThisSurvivor.ID)));
		bool didBuildPath = NavMesh_BuildPath(spawn, areaThisSurvivor, posThisSurvivor, GauntletPathCost); 
		if ( didBuildPath )
		{
			// TODO: hoping the cost is for the path built in NavMesh_BuildPath
			int pathCost = NavMeshArea_GetTotalCost(indexAreaThisSurvivor); 
			if ( pathCost < shortestPath || shortestPath == -1 )
			{
				shortestPath = pathCost; // update the shortest path found to survivors from this position
			}
		}
	}
	// Return whether this shortest calculated path length is acceptable
	if ( shortestPath > iSpawnProximityMin && shortestPath < iSpawnProximityMax ) 
	{
		shouldSpawn = true;	
	}
	
	return shouldSpawn;	
}

int GauntletPathCost(CNavArea area, CNavArea from, CNavLadder ladder, any data)
{
	if (from == INVALID_NAV_AREA)
	{
		return 0;
	}
	else
	{
		int iDist = 0;
		if (ladder != INVALID_NAV_LADDER)
		{
			iDist = RoundFloat(ladder.Length * 10.0); // addding 10x multiplier to discourage spawn spots that require climbing
		}
		else
		{
			float flAreaCenter[3]; float flFromAreaCenter[3];
			area.GetCenter(flAreaCenter);
			from.GetCenter(flFromAreaCenter);
			
			iDist = RoundFloat(GetVectorDistance(flAreaCenter, flFromAreaCenter));
		}
		
		int iCost = iDist + from.CostSoFar;
		int iAreaFlags = area.Attributes;
		if (iAreaFlags & NAV_MESH_CROUCH) iCost += 20; // default += (20)
		if (iAreaFlags & NAV_MESH_JUMP) iCost += (50 * iDist); // default +=(5 * iDist)
		return iCost;
	}
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
    // Check the input is valid
    if (!L4D2_IsValidClient(client))return false;
    
    // Check if player is a bot on the infected team
    if (L4D2_IsInfected(client) && IsFakeClient(client))
	{
        return true;
    }
    return false; // otherwise
}

bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (L4D2_IsSurvivor(client))
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

/**
 * @return: the farthest flow distance currently held by a survivor
 */
int GetRearSurvivorFlow() 
{
	int lowestMapFlow = -1; // initialise to impossible value
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int thisClient = L4D2_GetSurvivorOfIndex(i);
		if (thisClient == 0 || !IsPlayerAlive(thisClient)) continue;
		float thisSurvivorsOrigin[3];
		char survivorName[32];
		GetClientName(thisClient, survivorName, sizeof(survivorName));
		if ( GetClientAbsOrigin(thisClient, thisSurvivorsOrigin) )
		{
			int thisFlow = GetFlow(thisSurvivorsOrigin);
			if ( thisFlow <= 0 )
			{
				PrintToServer("GetRearSurvivorFlow(): Survivor %s returning invalid flow %f", survivorName, thisFlow);
				continue;
			}
			if ( lowestMapFlow == -1 || thisFlow < lowestMapFlow )
			{
				lowestMapFlow = thisFlow;
			}
		}
		else
		{
			PrintToServer("GetRearSurvivorFlow(): Failed to find position for %s", survivorName);
		}
	}
	return lowestMapFlow;
}
