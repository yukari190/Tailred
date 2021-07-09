#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#include <[LIB]l4d2library>
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

#define PI 3.14159265359
#define UNINITIALISED_FLOAT -1.42424

#define NAV_MESH_HEIGHT 20.0

#define COORD_X 0
#define COORD_Y 1
#define COORD_Z 2
#define X_MIN 0
#define X_MAX 1
#define Y_MIN 2
#define Y_MAX 3

#define PITCH 0
#define YAW 1
#define ROLL 2
#define MAX_ANGLE 89.0

#define X_COORD 0
#define Y_COORD 1
#define Z_COORD 2

// Settings upon load
ConVar cvSpawnSize;
ConVar cvSILimit;
ConVar cvSpawnLimits[NUM_TYPES_INFECTED];
ConVar cvSpawnWeights[NUM_TYPES_INFECTED];
ConVar cvScaleWeights;
ConVar cvSpawnProximityMin;
ConVar cvSpawnProximityMax;
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
int iIncapAllowance;
int iSurvivorLimit;

int SpawnCounts[NUM_TYPES_INFECTED];

Handle hSpawnTimer;

float SpawnTimes[MAXPLAYERS];
float IntervalEnds[NUM_TYPES_INFECTED];

int g_bHasSpawnTimerStarted = true;

float spawnBounds[4]; // denoted by minimum and maximum X and Y coordinates

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
	
	HookEvent("player_death", OnPlayerDeath);
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

public void L4D_OnRoundEnd()
{
	EndSpawnTimer(true);
}

public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (IsBotInfected(player) && L4D2_GetInfectedClass(player) != L4D2Infected_Spitter)
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
	g_bHasSpawnTimerStarted = false; 
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	int numIncappedSurvivors = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
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
		//NavMeshSpawn(SpawnQueue);
		// for old spawn times, generate spawn locations one at a time
		for( int i = 0; i < MAXPLAYERS; i++ ) 
		{
			if( SpawnQueue[i] < 0 ) // end of spawn queue (does not always fill the whole array)
			{ 
				break;
			}
			AttemptSpawnAuto(view_as<L4D2_Infected>(SpawnQueue[i] + 1));
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
// Handles radial and grid spawning; Nav Mesh spawning is handled differently in SpawnQueue module and does not pass on to here.
void AttemptSpawnAuto(L4D2_Infected SIClass)
{
	if( CheckSurvivorsSeparated() )
	{
		RadialSpawn( SIClass, GetLeadSurvivor() );	
	}
	else
	{
		GridSpawn( SIClass );
	} 
}

/*
 * Reposition the SI to a point on the circumference of a circle [spawn_proximity] from a survivor; respects distance to all survivors
 * Always spawns SI at [ss_spawn_proximity_min] distance to survivors
 */
void RadialSpawn( L4D2_Infected SIClass, int survivorTarget ) {
	bool spawnSuccess = false;
	float survivorPos[3];
	float rayEnd[3];
	float spawnPos[3] = {-1.0, -1.0, -1.0};
	for( int i = 0; i < 500; i++ ) {		
		// Fire a ray at a random angle around the survivor
		GetClientAbsOrigin(survivorTarget, survivorPos); 
		float spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
		rayEnd[0] = survivorPos[0] + Sine(spawnSearchAngle) * iSpawnProximityMin;
		rayEnd[1] = survivorPos[1] + Cosine(spawnSearchAngle) * iSpawnProximityMin;
		rayEnd[2] = survivorPos[2] + 50;
		// Search down the vertical column from the ray's' endpoint for a valid spawn position
		float direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay( rayEnd, direction, MASK_ALL, RayType_Infinite );
		if( TR_DidHit() ) {
			float traceImpact[3];
			TR_GetEndPosition( traceImpact );
			spawnPos = traceImpact;
			spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			// Have to use the size of a survivor to estimate if SI will get stuck, 
			// as with recent update to this plugin, the SI do not get repositioned but are spawned directly into the decided position
			if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, L4D2_GetRandomSurvivor()) && GetSurvivorProximity(spawnPos) > iSpawnProximityMin ) {
				TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); 
				spawnSuccess = true;
				break;
			}
		}
	}
		
	// Could not find an acceptable spawn position
	if(!spawnSuccess) {
		LogMessage("[SS] FAILED to find a valid RADIAL SPAWN position for infected class '%d' after %d attempts", SIClass, 500 ); 
	}		
}

/*
 * Reposition the SI to a random point on a 2D grid around the survivors. 
 */
void GridSpawn( L4D2_Infected SIClass ) {
	
	UpdateSpawnBounds();
	
	for( int i = 0; i < 500; i++ ) {
		float searchPos[3];
		float survivorPos[3];
		int closestSurvivor;
		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		searchPos[COORD_X] = GetRandomFloat(spawnBounds[X_MIN], spawnBounds[X_MAX]);
		searchPos[COORD_Y] = GetRandomFloat(spawnBounds[Y_MIN], spawnBounds[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from just above the height of nearest survivor
		closestSurvivor = GetClosestSurvivor2D(searchPos[COORD_X], searchPos[COORD_Y]);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		searchPos[COORD_Z] = survivorPos[COORD_Z] + float( 50 );
		
		// Search down the vertical column from the generated [x, y ,z] coordinate for a valid spawn position
		float direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay( searchPos, direction, MASK_ALL, RayType_Infinite );
		
		// found solid land below the [x, y, z] coordinate
		if( TR_DidHit() ) { 
			float traceImpact[3];
			float spawnPos[3];
			TR_GetEndPosition( traceImpact ); 
			spawnPos = traceImpact;
			spawnPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			
			if ( IsValidSpawn(spawnPos) ) {
				TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); // all spawn conditions satisifed
				return;
				
			}
		} 
 	}
 	// Could not find an acceptable spawn position
	LogMessage("[SS] FAILED to find a valid GRID SPAWN position for SI Class '%d' after %d attempts", SIClass, 500 ); 
	return;
}

/* Determine if the lead survivor is too far ahead of the rear survivor, using the [spawn_proximity] cvar 
 * @return: a random survivor or a survivor that is rushing too far ahead in front
 */
bool CheckSurvivorsSeparated() {
	// Lead survivor position
	int leadSurvivor = GetLeadSurvivor();
	float leadSurvivorPos[3];
	if( L4D2_IsSurvivor(leadSurvivor) ) {
		GetClientAbsOrigin( leadSurvivor, leadSurvivorPos );
	}
	// Rear survivor position
	int rearSurvivor = GetRearSurvivor();
	float rearSurvivorPos[3];
	if( L4D2_IsSurvivor(rearSurvivor) ) {
		GetClientAbsOrigin( rearSurvivor, rearSurvivorPos );
	}
	// Is the leading player too far ahead?
	if( GetVectorDistance( leadSurvivorPos, rearSurvivorPos ) > float(2 * iSpawnProximityMax) ) {
		return true;
	} else {
		return false;
	}
}

int GetLeadSurvivor() {
	// Find the farthest flow held by a survivor
	float farthestFlow = -1.0;
	int leadSurvivor = -1;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		
		float origin[3];
		GetClientAbsOrigin(index, origin);
		Address pNavArea = L4D2Direct_GetTerrorNavArea(origin);
		if( pNavArea != Address_Null ) {
			float tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
			if( tmp_flow > farthestFlow || farthestFlow == -1.0 ) {
				farthestFlow = tmp_flow;
				leadSurvivor = index;
			}
		}
	}
	return leadSurvivor;
}

bool IsOnValidMesh(const float position[3]) {
	float pos[3];
	pos[0] = position[0]; 
	pos[1] = position[1]; 
	pos[2] = position[2]; 
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) { 
		return true;
	} else {
		return false;
	}
}

void UpdateSpawnBounds() {
	// Grid will have coords (min X, min Y), (min X, max Y), (max X, min Y), (max X, max Y)
	spawnBounds[X_MIN] = UNINITIALISED_FLOAT, spawnBounds[Y_MIN] = UNINITIALISED_FLOAT;
	spawnBounds[X_MAX] = UNINITIALISED_FLOAT, spawnBounds[Y_MAX] = UNINITIALISED_FLOAT;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		float pos[3];
		GetClientAbsOrigin(index, pos);
		// Check min
		spawnBounds[X_MIN] = CheckMinCoord( spawnBounds[X_MIN], pos[COORD_X] );
		spawnBounds[Y_MIN] = CheckMinCoord( spawnBounds[Y_MIN], pos[COORD_Y] );
		// Check max
		spawnBounds[X_MAX] = CheckMaxCoord( spawnBounds[X_MAX], pos[COORD_X] );
		spawnBounds[Y_MAX] = CheckMaxCoord( spawnBounds[Y_MAX], pos[COORD_Y] );
	}
	// Extend a border around grid
	float borderWidth = float( iSpawnProximityMax );
	spawnBounds[X_MIN] -= borderWidth;
	spawnBounds[Y_MIN] -= borderWidth;
	spawnBounds[X_MAX] += borderWidth;
	spawnBounds[Y_MAX] += borderWidth;
}

bool IsPlayerStuck( const float pos[3], int client) {
	bool isStuck = true;
	if( L4D2_IsValidClient(client) ) {
		float mins[3];
		float maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		
		// inflate the sizes just a little bit
		for( int i = 0; i < sizeof(mins); i++ ) {
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}
		
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}  

// filter out players, since we can't get stuck on them
public bool TraceEntityFilterPlayer(int entity, int contentsMask) {
    return entity <= 0 || entity > MaxClients;
}  

int GetSurvivorProximity( const float rp[3], int specificSurvivor = -1 ) {
	
	int targetSurvivor;
	float targetSurvivorPos[3];
	float referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	
	if( specificSurvivor > 0 && L4D2_IsSurvivor(specificSurvivor) ) { // specified survivor
		targetSurvivor = specificSurvivor;		
	} else { // closest survivor		
		targetSurvivor = GetClosestSurvivor( referencePos );
	}
	
	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}

int GetClosestSurvivor2D(float x_coord, float y_coord) 
{
	float proximity = -1.0;
	int closestSurvivor = L4D2_GetRandomSurvivor();
	if ( !L4D2_IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor2D(%f, %f) - Unable to find any survivors", x_coord, y_coord);
	}		
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int j = L4D_GetSurvivorOfIndex(i);
		if (j == 0 || !IsPlayerAlive(j)) continue;
		float survivorPos[3];
		GetClientAbsOrigin( j, survivorPos );
		// Pythagoras
		float survivorDistance = SquareRoot( Pow(survivorPos[X_COORD] - x_coord, 2.0) + Pow(survivorPos[Y_COORD] - y_coord, 2.0) );
		if( survivorDistance < proximity || proximity == -1.0 ) {
			proximity = survivorDistance;
			closestSurvivor = j;
		}
	}
	return closestSurvivor;
}

bool IsValidSpawn(const float spawnPos[3]) {
	bool is_valid = false;
	int flow_dist_survivors;
	if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, L4D2_GetRandomSurvivor()) ) {
		flow_dist_survivors = GetFlowDistToSurvivors(spawnPos);
		if ( HasSurvivorLOS(spawnPos) ) {
			int survivor_proximity = GetSurvivorProximity(spawnPos);
			if ( survivor_proximity > iSpawnProximityMin && flow_dist_survivors < 900 ) { 
				is_valid = true;
			}
		} else { // try to keep spawn flow distance to survivors low if they are spawning outside of LOS
			if ( flow_dist_survivors < 500 && flow_dist_survivors != -1 ) {
				is_valid = true;
			}
		}
	}
	return is_valid;
}

int GetRearSurvivor() {
	// Find the farthest flow held by a survivor
	float lowestFlow = -1.0;
	int rearSurvivor = -1;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int j = L4D_GetSurvivorOfIndex(i);
		if (j == 0 || !IsPlayerAlive(j)) continue;
		
		float origin[3];
		GetClientAbsOrigin(j, origin);
		Address pNavArea = L4D2Direct_GetTerrorNavArea(origin);
		if( pNavArea != Address_Null ) {
			float tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
			if( tmp_flow < lowestFlow || lowestFlow == -1.0 ) {
				lowestFlow = tmp_flow;
				rearSurvivor = j;
			}
		}
	}
	return rearSurvivor;
}

float CheckMinCoord( float oldMin, float checkValue ) {
	if( checkValue < oldMin || oldMin == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMin;
	}
}

float CheckMaxCoord( float oldMax, float checkValue ) {
	if( checkValue > oldMax || oldMax == UNINITIALISED_FLOAT ) {
		return checkValue;
	} else {
		return oldMax;
	}
}

int GetClosestSurvivor( float referencePos[3], int excludeSurvivor = -1 ) {
	float survivorPos[3];
	int closestSurvivor = L4D2_GetRandomSurvivor();	
	if ( !L4D2_IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor([%f, %f, %f], %d) = invalid client %d", referencePos[0], referencePos[1], referencePos[2], excludeSurvivor, closestSurvivor);
		return -1;
	}
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	int iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int client = L4D_GetSurvivorOfIndex(i);
		if (client == 0 || !IsPlayerAlive(client) || client == excludeSurvivor) continue;
		GetClientAbsOrigin( client, survivorPos );
		int displacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
		if( displacement < iClosestAbsDisplacement || iClosestAbsDisplacement < 0 ) { 
			iClosestAbsDisplacement = displacement;
			closestSurvivor = client;
		}
	}
	return closestSurvivor;
}

int GetFlowDistToSurvivors(const float pos[3]) {
	int spawnpoint_flow;
	int lowest_flow_dist = -1;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow == -1) {
		return -1;
	}
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int j = L4D_GetSurvivorOfIndex(i);
		if (j == 0 || !IsPlayerAlive(j)) continue;
		float origin[3];
		int flow_dist;
		
		GetClientAbsOrigin(j, origin);
		flow_dist = GetFlow(origin);
		
		// have we found a new valid(i.e. != -1) lowest flow_dist
		if ( flow_dist != -1 && FloatCompare(FloatAbs(float(flow_dist) - float(spawnpoint_flow)), float(lowest_flow_dist)) ==  -1 ) {
			lowest_flow_dist = flow_dist;
		}
	}
	
	return lowest_flow_dist;
}

bool HasSurvivorLOS( const float pos[3] ) {
	bool hasLOS = false;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int j = L4D_GetSurvivorOfIndex(i);
		if (j == 0 || !IsPlayerAlive(j)) continue;
		float origin[3];
		GetClientAbsOrigin(j, origin);
		TR_TraceRay( pos, origin, MASK_ALL, RayType_EndPoint );
		if( !TR_DidHit() ) {
			hasLOS = true;
			break;
		}	
	}
	return hasLOS;
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

