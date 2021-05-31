#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]navmesh>
#include <[LIB]l4d2library>
#include <[LIB]NavMesh_DirectInfectedSpawn>

#define DEBUG_WEIGHTS 0
#define DEBUG_SPAWNQUEUE 0
#define DEBUG_TIMERS 0
#define DEBUG_POSITIONER 0
#define PLUGIN_NAME "Special Spawner"

#define VANILLA_COOP_SI_LIMIT 2
#define NUM_TYPES_INFECTED 6

Handle hCvarReadyUpEnabled;
Handle hCvarConfigName;
Handle hCvarLineOfSightStarvationTime;
Handle hTimerHUD;

// SpawnPositioner module
ConVar hCvarSpawnPositionerMode;
Handle hCvarMaxSearchAttempts;
Handle hCvarSpawnSearchHeight;
Handle hCvarSpawnProximityMin;
Handle hCvarSpawnProximityMax;
Handle hCvarSpawnProximityFlowNoLOS;
Handle hCvarSpawnProximityFlowLOS; 

bool bShowSpawnerHUD[MAXPLAYERS];
float g_fTimeLOS[100000]; // not sure what the largest possible userid is


// array indices for Special Infected
#define SI_SMOKER		0
#define SI_BOOMER		1
#define SI_HUNTER		2
#define SI_SPITTER		3
#define SI_JOCKEY		4
#define SI_CHARGER		5

#define UNINITIALISED -1

// Settings upon load
Handle hSpawnSize;
ConVar hSILimit;
Handle hSpawnLimits[NUM_TYPES_INFECTED];
Handle hSpawnWeights[NUM_TYPES_INFECTED], hScaleWeights;
Handle hSILimitServerCap;

// Cache customised settings to re-apply after map changes
int SpawnSizeCache = UNINITIALISED;
int SILimitCache = UNINITIALISED;
int SpawnLimitsCache[NUM_TYPES_INFECTED] = { UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED };
int SpawnWeightsCache[NUM_TYPES_INFECTED] = { UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED, UNINITIALISED };


Handle hSpawnTimer;
ConVar hSpawnTimeMode;
ConVar hSpawnTimeMin;
ConVar hSpawnTimeMax;

Handle hCvarFrequencyBoomerAmbush;
Handle hTimerBoomer;

Handle hCvarIncapAllowance;

float SpawnTimes[MAXPLAYERS];
float IntervalEnds[NUM_TYPES_INFECTED];

int g_bHasSpawnTimerStarted = true;
int g_bHasBoomerTimerStarted = true;


#define PI 3.14159265359
#define UNINITIALISED_FLOAT -1.42424

#define BOUNDINGBOX_INFLATION_OFFSET 0.5
#define NAV_MESH_HEIGHT 20.0
#define DEBUG_DRAW_ELEVATION 100.0

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

#define INVALID_MESH 0
#define VALID_MESH 1
#define SPAWN_FAIL 2
#define WHITE 3
#define PURPLE 4

int g_AllSurvivors[MAXPLAYERS]; // MAXPLAYERS because who knows what survivor limit people may use
float spawnBounds[4]; // denoted by minimum and maximum X and Y coordinates

int laserCache;


// new Handle:hCvarSpawnAttemptInterval;

char Spawns[NUM_TYPES_INFECTED][16] = {"smoker", "boomer", "hunter", "spitter", "jockey", "charger"};
int SpawnCounts[NUM_TYPES_INFECTED];

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

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax) 
{ 
	// L4D2 check
	char mod[32];
	GetGameFolderName(mod, sizeof(mod));
	if( !StrEqual(mod, "left4dead2", false) )
	{
		return APLRes_Failure;
	}
	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load modules
	// Server SI max (marked FCVAR_CHEAT; admin only)
	hSILimitServerCap = CreateConVar("ss_server_si_limit", "12", "The max amount of special infected at once", FCVAR_CHEAT, true, 1.0);
	// Spawn limits - this value is flattened to the above server SI Max cvar
	hSILimit = CreateConVar("ss_si_limit", "8", "The max amount of special infected at once", _, true, 1.0, true, float(GetConVarInt(hSILimitServerCap)) );
	hSILimit.AddChangeHook(CalculateSpawnTimes);
	hSpawnSize = CreateConVar("ss_spawn_size", "4", "The amount of special infected spawned at each spawn interval", _, true, 1.0, true, float(GetConVarInt(hSILimitServerCap)) );
	hSpawnLimits[SI_SMOKER]		= CreateConVar("ss_smoker_limit",	"1", "The max amount of smokers present at once", _, true, 0.0, true, 14.0);
	hSpawnLimits[SI_BOOMER]		= CreateConVar("ss_boomer_limit",	"1", "The max amount of boomers present at once", _, true, 0.0, true, 14.0);
	hSpawnLimits[SI_HUNTER]		= CreateConVar("ss_hunter_limit",	"2", "The max amount of hunters present at once", _, true, 0.0, true, 14.0);
	hSpawnLimits[SI_SPITTER]	= CreateConVar("ss_spitter_limit",	"1", "The max amount of spitters present at once", _, true, 0.0, true, 14.0);
	hSpawnLimits[SI_JOCKEY]		= CreateConVar("ss_jockey_limit",	"2", "The max amount of jockeys present at once", _, true, 0.0, true, 14.0);
	hSpawnLimits[SI_CHARGER]	= CreateConVar("ss_charger_limit",	"1", "The max amount of chargers present at once", _, true, 0.0, true, 14.0);
	// Weights
	hSpawnWeights[SI_SMOKER]	= CreateConVar("ss_smoker_weight",	"50", "The weight for a smoker spawning", _, true, 0.0);
	hSpawnWeights[SI_BOOMER]	= CreateConVar("ss_boomer_weight",	"10", "The weight for a boomer spawning", _, true, 0.0);
	hSpawnWeights[SI_HUNTER]	= CreateConVar("ss_hunter_weight",	"100", "The weight for a hunter spawning", _, true, 0.0);
	hSpawnWeights[SI_SPITTER]	= CreateConVar("ss_spitter_weight", "100", "The weight for a spitter spawning", _, true, 0.0);
	hSpawnWeights[SI_JOCKEY]	= CreateConVar("ss_jockey_weight",	"100", "The weight for a jockey spawning", _, true, 0.0);
	hSpawnWeights[SI_CHARGER]	= CreateConVar("ss_charger_weight", "75", "The weight for a charger spawning", _, true, 0.0);
	hScaleWeights = CreateConVar("ss_scale_weights", "1",	"[ 0 = OFF | 1 = ON ] Scale spawn weights with the limits of corresponding SI", _, true, 0.0, true, 1.0);
	
	
	// Timer
	hSpawnTimeMin = CreateConVar("ss_time_min", "12.0", "The minimum auto spawn time (seconds) for infected", _, true, 0.0);
	hSpawnTimeMax = CreateConVar("ss_time_max", "15.0", "The maximum auto spawn time (seconds) for infected", _, true, 1.0);
	hSpawnTimeMode = CreateConVar("ss_time_mode", "1", "The spawn time mode [ 0 = RANDOMIZED | 1 = INCREMENTAL | 2 = DECREMENTAL ]", _, true, 0.0, true, 2.0);
	hCvarFrequencyBoomerAmbush = CreateConVar("ss_boomer_frequency", "7.0", "Roughly how often to attempt to ambush survivors with a boomer", _);
	hSpawnTimeMin.AddChangeHook(CalculateSpawnTimes);
	hSpawnTimeMax.AddChangeHook(CalculateSpawnTimes);
	hSpawnTimeMode.AddChangeHook(CalculateSpawnTimes);
	// Grace period
	hCvarIncapAllowance = CreateConVar( "ss_incap_allowance", "7", "Grace period(sec) per incapped survivor" );
	// sets SpawnTimeMin, SpawnTimeMax, and SpawnTimes[]
	SetSpawnTimes(); 
	
	
	/*
	 * Bibliography
	 * - Epilimic's witch spawner code
	 * - "Player-Teleport by Dr. HyperKiLLeR" (sm_gotoRevA.smx)
	 * Thanks to Newteee for his repositioning algorithm
	 */
	hCvarSpawnPositionerMode = CreateConVar( "ss_spawnpositioner_mode", "3", "[ 0 = disabled, 1 = Radial Reposition only, 2 = Grid Reposition with Radial fallback, 3 = nav mesh spawning ]" );
	hCvarSpawnPositionerMode.AddChangeHook(SpawnPositionerMode);
	hCvarMaxSearchAttempts = CreateConVar( "ss_spawn_max_search_attempts", "500", "Max attempts to make per SI spawn to find an acceptable location to which to relocate them" );
	hCvarSpawnSearchHeight = CreateConVar( "ss_spawn_search_height", "50", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hCvarSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "Closest an SI may spawn to a survivor", _, true, 1.0 );
	hCvarSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "Furthest an SI may spawn to a survivor", _, true, float(GetConVarInt(hCvarSpawnProximityMin)) );
	// N.B. the hCvarSpawnProximityFlow___ cvars are not a lower and upper bound;
	hCvarSpawnProximityFlowNoLOS = CreateConVar( "ss_spawn_proximity_flow_dist_no_LOS", "500", 
									"Closest spawns by flow distance; considered when there is no LOS on survivors" );
	hCvarSpawnProximityFlowLOS = CreateConVar( "ss_spawn_proximity_flow_dist_LOS", "900", 
									"Farthest spawns by flow distance; bounded by lowest straight line distance to survivor team" );
	
	
	
	// Compatibility with server_namer.smx
	hCvarReadyUpEnabled = CreateConVar("l4d_ready_enabled", "1", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	hCvarConfigName = CreateConVar("l4d_ready_cfg_name", "Hard Coop", "This cvar from readyup.smx is required by server_namer.smx, but is duplicated here to avoid use of readyup.smx");
	SetConVarFlags( hCvarReadyUpEnabled, FCVAR_CHEAT ); SetConVarFlags( hCvarConfigName, FCVAR_CHEAT ); // get rid of 'symbol is assigned a value that is never used' compiler warnings
	// 	Cvars
	SetConVarBool( FindConVar("director_spectate_specials"), true );
	SetConVarBool( FindConVar("director_no_specials"), true ); // disable Director spawning specials naturally
	SetConVarInt( FindConVar("z_safe_spawn_range"), 0 );
	SetConVarInt( FindConVar("z_spawn_safety_range"), 0 );
	//SetConVarInt( FindConVar("z_spawn_range"), 750 ); // default 1500 (potentially very far from survivors) is remedied if SpawnPositioner module is active 
	SetConVarInt( FindConVar("z_discard_range"), 1250 ); // discard zombies farther away than this	
	// Adjust game difficulty
	FindConVar("survivor_limit").AddChangeHook(ConVarChange_SurvivorLimit);
	// Faster spawns
	HookEvent("player_death", OnPlayerDeath, EventHookMode_PostNoCopy);
	// LOS tracking
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_PostNoCopy);
	hCvarLineOfSightStarvationTime = CreateConVar( "ss_los_starvation_time", "7.5", "SI will be slayed after being denied LOS to survivor team for this amount of time" );
	// Customisation commands
	RegConsoleCmd("sm_weight", Cmd_SetWeight, "设置SI类的衍生权重");
	RegConsoleCmd("sm_limit", Cmd_SetLimit, "Set individual, total and simultaneous SI spawn limits");
	RegConsoleCmd("sm_timer", Cmd_SetTimer, "Set a variable or constant spawn time (seconds)");
	RegConsoleCmd("sm_spawnmode", Cmd_SpawnMode, "[ 0 = vanilla spawning, 1 = radial spawning, 2 = grid spawning, 3 = nav mesh spawning ]");
	RegConsoleCmd("sm_spawnproximity", Cmd_SpawnProximity, "Set the minimum and maximum spawn distance");
	// Admin commands
	RegAdminCmd("sm_resetspawns", Cmd_ResetSpawns, ADMFLAG_RCON, "Reset by slaying all special infected and restarting the timer");
	RegAdminCmd("sm_forcetimer", Cmd_StartSpawnTimerManually, ADMFLAG_RCON, "Manually start the spawn timer");
}

public void OnPluginEnd()
{
	ResetConVar( FindConVar("director_spectate_specials") );
	ResetConVar( FindConVar("director_no_specials") ); // Disable Director spawning specials naturally
	ResetConVar( FindConVar("z_safe_spawn_range") );
	ResetConVar( FindConVar("z_spawn_safety_range") );
	ResetConVar( FindConVar("z_spawn_range") );
	ResetConVar( FindConVar("z_discard_range") );
	
	CloseHandle(hTimerHUD);
	hTimerHUD = INVALID_HANDLE;
	CloseHandle(hSpawnTimer);
	ResetConVar( FindConVar("z_spawn_range") );
}

public void CalculateSpawnTimes(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int iSILimit =  GetConVarInt(hSILimit);
	float fSpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	float fSpawnTimeMax = GetConVarFloat(hSpawnTimeMax);
	if( iSILimit > 1 && GetConVarInt(hSpawnTimeMode) > 0 ) {
		float unit = ( (fSpawnTimeMax - fSpawnTimeMin) / (iSILimit - 1) );
		switch( GetConVarInt(hSpawnTimeMode) ) {
			case 1: { // incremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMin;
				for( int i = 1; i < MAXPLAYERS; i++ ) {
					if( i < iSILimit ) {
						SpawnTimes[i] = SpawnTimes[i-1] + unit;
					} else {
						SpawnTimes[i] = fSpawnTimeMax;
					}
				}
			}
			case 2: { // decremental spawn time mode			
				SpawnTimes[0] = fSpawnTimeMax;
				for( int i = 1; i < MAXPLAYERS; i++ ) {
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
	
		#if DEBUG_TIMERS
			for (int i = 1; i < NUM_TYPES_INFECTED; i++) {
				LogMessage("%d : %.5f s", i, SpawnTimes[i]);
			}
		#endif
}



public void ConVarChange_SurvivorLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	// Do stuff	
}

public void SpawnPositionerMode(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if( GetConVarBool(hCvarSpawnPositionerMode) ) {
		ResetConVar( FindConVar("z_spawn_range") ); // default value is 1500
	} else {
		SetConVarInt( FindConVar("z_spawn_range"), 1000 ); // spawn SI closer as they are not being repositioned; no second chances for failed spawns
	}
}

/***********************************************************************************************************************************************************************************

                                                 					PER ROUND
                                  SS_SpawnTimers -> SS_SpawnQueue + SS_SpawnQuantities -> SS_SpawnPositioner -> SS_DirectInfectedSpawn
                                                                    
***********************************************************************************************************************************************************************************/

public void OnConfigsExecuted() {	
	// Load customised cvar values to override any .cfg values
	LoadCacheSpawnLimits();
	LoadCacheSpawnWeights(); 
	hTimerHUD = CreateTimer( 0.1, Timer_DrawSpawnerHUD, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client) { 
	// Disable for PvP modes
	char gameMode[16];
	GetConVarString(FindConVar("mp_gamemode"), gameMode, sizeof(gameMode));
	if( StrContains(gameMode, "versus", false) != -1 || StrContains(gameMode, "scavenge", false) != -1 )
	{
		SetFailState("Plugin does not support PvP modes");
	} 
	else if ( StrContains(gameMode, "survival", false) == -1 ) 
	{ // would otherwise cause spawns in survival before button is pressed
		g_bHasSpawnTimerStarted = false;
		StartSpawnTimer();
		StartBoomerTimer();
	}
	// Print instruction readout to survivors
	for ( int i = 0; i <= MAXPLAYERS; ++i )
	{
		if ( L4D2_IsSurvivor(i) && IsClientInGame(i) )
		{
			PrintHintText(i, "To show commands - hold both the USE ITEM and RELOAD keys");
		}
	}
}

public void L4D2_OnRealRoundEnd()
{
	EndSpawnTimer();
	EndBoomerTimer();
}


// Kick infected bots promptly after death to allow quicker infected respawn
public Action OnPlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("userid"));
	if( IsBotInfected(player) ) {
		CreateTimer(1.0, Timer_KickBot, player);
	}
}

/***********************************************************************************************************************************************************************************

                                                 					LOS STARVATION
                                                                    
***********************************************************************************************************************************************************************************/

// Slay infected if they have not had LOS to survivors for a defined (hCvarLineOfSightStarvationTime/ss_los_starvation_time) period
public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if( IsBotInfected(client) && !IsTank(client) && userid >= 0 ) {
		g_fTimeLOS[userid] = 0.0;
		// Checking LOS
		CreateTimer( 0.5, Timer_StarvationLOS, userid, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE );
	}
}

public Action Timer_StarvationLOS( Handle timer, any userid ) {
	int client = GetClientOfUserId( userid );
	// increment tracked LOS time
	if( IsBotInfected(client) && IsPlayerAlive(client) ) {
		if( GetEntProp(client, Prop_Send, "m_hasVisibleThreats") ) {
			g_fTimeLOS[userid] = 0.0;
		} else {
			g_fTimeLOS[userid] += 0.5; 
		}
		// If an SI has not seen the survivors for a while, clone them closer to survivors
		if( g_fTimeLOS[userid] > GetConVarFloat(hCvarLineOfSightStarvationTime) ) { 
			switch ( GetConVarInt(FindConVar("ss_spawnpositioner_mode")) ) {
				case 1: {
					RadialSpawn(L4D2_GetInfectedClass(client), GetLeadSurvivor());
					ForcePlayerSuicide(client);
				}
				case 2: {
					GridSpawn(L4D2_GetInfectedClass(client)); 
					ForcePlayerSuicide(client);
				}
				default: {
				}
			}
			return Plugin_Stop;
		}
	} else {
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                           SPAWN TIMER AND CUSTOMISATION CMDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action Cmd_SetLimit(int client, int args) {
	if( !L4D2_IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if (args == 2) {
		// Read in the SI class
		char sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));
		// Read in limit value 
		char sLimitValue[32];     
		GetCmdArg(2, sLimitValue, sizeof(sLimitValue));
		int iLimitValue = StringToInt(sLimitValue);    
		// Must be valid limit value		
		if( iLimitValue < 0 ) {
			L4D2_CPrintToChat(client, "{blue}[{default}SS{blue}]{default} {olive}Limit value{default} must be >= {blue}0");
		} else {
			// Apply limit value to appropriate class
			if( StrEqual(sTargetClass, "all", false) ) {
				for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnLimitsCache[i] = iLimitValue;
				}
				L4D2_CPrintToChatAll( "{blue}[{default}SS{blue}]{default} All SI limits have been set to {blue}%d", iLimitValue );
			} else if( StrEqual(sTargetClass, "max", false) ) {  // Max specials
				SILimitCache = iLimitValue;
				L4D2_CPrintToChatAll("{blue}[{default}SS{blue}]{default} {olive}Max{default} SI limit set to {blue}%i", iLimitValue);		           
			} else if( StrEqual(sTargetClass, "group", false) || StrEqual(sTargetClass, "wave", false) ) {
				SpawnSizeCache = iLimitValue;
				L4D2_CPrintToChatAll("{blue}[{default}SS{blue}]{default} {olive}Group{default} size of SI waves set to {blue}%i", iLimitValue);
			} else {
				for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(Spawns[i], sTargetClass, false) ) {
						SpawnLimitsCache[i] = iLimitValue;
						L4D2_CPrintToChatAll("{blue}[{default}SS{blue}]{default} -> {olive}%s{default} limit set to {blue}%i", sTargetClass, iLimitValue);
					}
				}
			}
		}	 
	} else {  // Invalid command syntax
		L4D2_CPrintToChat(client, "!limit/sm_limit {blue}<class> {olive}<limit>");
		L4D2_CPrintToChat(client, "<class> [ {olive}all | {blue}max | {olive}group/wave{default} | smoker | boomer | hunter | spitter | jockey | charger ]");
		L4D2_CPrintToChat(client, "<limit> [ >= {blue}0{default} ]");
	}
	// Load cache into appropriate cvars
	LoadCacheSpawnLimits(); 
	return Plugin_Handled;  
}

public Action Cmd_SetWeight(int client, int args) {
	if( !L4D2_IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		char arg[16];
		GetCmdArg(1, arg, sizeof(arg));	
		if( StrEqual(arg, "reset", false) ) {
			ResetWeights();
			ReplyToCommand(client, "{blue}[{default}SS{blue}]{default} Spawn weights reset to default values");
		} 
	} else if( args == 2 ) {
		// Read in the SI class
		char sTargetClass[32];
		GetCmdArg(1, sTargetClass, sizeof(sTargetClass));

		// Read in limit value 
		char sWeightPercent[32];     
		GetCmdArg(2, sWeightPercent, sizeof(sWeightPercent));
		int iWeightPercent = StringToInt(sWeightPercent);      
		if( iWeightPercent < 0 || iWeightPercent > 100 ) {
			L4D2_CPrintToChat( client, "0 <= weight value <= 100") ;
			return Plugin_Handled;
		} else { //presets for spawning special infected i only
			if( StrEqual(sTargetClass, "all", false) ) {
				for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					SpawnWeightsCache[i] = iWeightPercent;			
				}	
				L4D2_CPrintToChat(client, "{blue}[{default}SS{blue}]{default} All {olive}spawn weights{olive} set to {blue}%d", iWeightPercent );	
			} else {
				for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
					if( StrEqual(sTargetClass, Spawns[i], false) ) {
						SpawnWeightsCache[i] =  iWeightPercent;
						L4D2_CPrintToChat(client, "{blue}[{default}SS{blue}]{default} -> {olive}%s{default} weight set to {blue}%d", Spawns[i], iWeightPercent);
					}
				}	
			}
			
		}
	} else {
		L4D2_CPrintToChat( client, "!weight/sm_weight {blue}<class> {olive}<value>" );
		L4D2_CPrintToChat( client, "<class> [ {blue}reset | {olive}all{default} | smoker | boomer | hunter | spitter | jockey | charger ] " );	
		L4D2_CPrintToChat( client, "{olive}value{default} [ >= {blue}0{blue} ] " );	
	}
	LoadCacheSpawnWeights();
	return Plugin_Handled;
}

public Action Cmd_SetTimer(int client, int args) {
	if( !L4D2_IsSurvivor(client) && !IsGenericAdmin(client) ) {
		PrintToChat(client, "You do not have access to this command");
		return Plugin_Handled;
	} 
	
	if( args == 1 ) {
		float time;
		char arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		if (time < 0.0) { 
			time = 1.0; // don't want a constant spawn time of 0s
		}
		SetConVarFloat( hSpawnTimeMin, time );
		SetConVarFloat( hSpawnTimeMax, time );
		SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
		PrintToChat(client, "{blue}[{default}SS{blue}]{default} Spawn timer set to constant {blue}%.3f{default} seconds", time);
	} else if( args == 2 ) {
		float min, max;
		char arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hSpawnTimeMin, min );
			SetConVarFloat( hSpawnTimeMax, max );
			SetSpawnTimes(); //refresh times since hooked event from SetConVarFloat is temporarily disabled
			L4D2_CPrintToChat(client, "{blue}[{default}SS{blue}]{default} Spawn timer will be between {blue}%.3f{default} and {blue}%.3f{default} seconds", min, max );
		} else {
			ReplyToCommand(client, "Max(>= 1.0) spawn time must greater than min(>= 0.0) spawn time");
		}
	} else {
		ReplyToCommand(client, "timer <constant> || timer <min><max>");
	}
	return Plugin_Handled;
}

public Action Cmd_SpawnMode( int client, int args ) {
	if( !L4D2_IsSurvivor(client) && !IsGenericAdmin(client) ) {
		ReplyToCommand( client, "You do not have access to this command" );	
	}
	// Switch to appropriate mode
	bool isValidParams = false;
	if( args == 1 ) {
		char arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		int mode = StringToInt(arg);
		if( mode >= 0 && mode <= 2 ) {
			SetConVarInt( hCvarSpawnPositionerMode, mode );
			char spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
			L4D2_CPrintToChat( client, "{blue}[{default}SS{blue}]{default} {blue}%s{default} spawn mode activated", spawnModes[mode] );
			isValidParams = true;
		}
	} 
	// Correct command usage
	if( !isValidParams ) {
		char spawnModes[3][8] = { "Vanilla", "Radial", "Grid" };
		L4D2_CPrintToChat( client, "{blue}[{default}SS{blue}]{default} Current spawnmode: {blue}%s", spawnModes[GetConVarInt(hCvarSpawnPositionerMode)] );
		ReplyToCommand( client, "Usage: spawnmode <mode> [ 0 = vanilla spawning, 1 = radial repositioning, 2 = grid repositioning ]" );
	}
}

public Action Cmd_SpawnProximity(int client, int args) {	
	if( args == 2 ) {
		float min, max;
		char arg[8];
		GetCmdArg( 1, arg, sizeof(arg) );
		min = StringToFloat(arg);
		GetCmdArg( 2, arg, sizeof(arg) );
		max = StringToFloat(arg);
		if( min > 0.0 && max > 1.0 && max > min ) {
			SetConVarFloat( hCvarSpawnProximityMin, min );
			SetConVarFloat( hCvarSpawnProximityMax, max );
			L4D2_CPrintToChat(client, "{blue}[{default}SS{blue}]{default} Spawn proximity set between {blue}%.3f{default} and {blue}%.3f{default} units", min, max );
		} else {
			ReplyToCommand(client, "Max(>= 1.0) spawn proximity must greater than min(>= 0.0) spawn proximity");
		}
	} else {
		ReplyToCommand(client, "spawnproximity <min> <max>");
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         ADMIN COMMANDS
                                                                    
***********************************************************************************************************************************************************************************/

public Action Cmd_ResetSpawns(int client, int args) {	
	for( int i = 0; i < MAXPLAYERS; i++ ) {
		if( IsBotInfected(i) ) {
			ForcePlayerSuicide(i);
		}
	}	
	StartCustomSpawnTimer(SpawnTimes[0]);
	ReplyToCommand( client, "Slayed all special infected. Spawn timer restarted. Next potential spawn in %.3f seconds.", GetConVarFloat(hSpawnTimeMin) );
	return Plugin_Handled;
}

public Action Cmd_StartSpawnTimerManually(int client, int args) {
	if( args < 1 ) {
		StartSpawnTimer();
		ReplyToCommand(client, "Spawn timer started manually.");
	} else {
		float time = 1.0;
		char arg[8];
		GetCmdArg(1, arg, sizeof(arg));
		time = StringToFloat(arg);
		
		if (time < 0.0) {
			time = 1.0;
		}
		
		StartCustomSpawnTimer(time);
		ReplyToCommand(client, "Spawn timer started manually. Next potential spawn in %.3f seconds.", time);
	}
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                         SPAWNER HUD
                                                                    
***********************************************************************************************************************************************************************************/

public Action OnPlayerRunCmd( int client, int &buttons ) {
	if( L4D2_IsValidClient(client) && !IsFakeClient(client) && buttons & IN_USE && buttons & IN_RELOAD ) {
		bShowSpawnerHUD[client] = true;
	} else {
		bShowSpawnerHUD[client] = false;
	}
} 

public Action Timer_DrawSpawnerHUD( Handle timer ) {
	Handle spawnerHUD = CreatePanel();
	FillHeaderInfo(spawnerHUD);
	FillSpecialInfectedInfo(spawnerHUD);
	FillTimerInfo(spawnerHUD);
	// Send to survivors
	for( int i = 1; i <= MAXPLAYERS; i++ ) {
		if( L4D2_IsValidClient(i) && !IsFakeClient(i) && bShowSpawnerHUD[i] ) {
			SendPanelToClient( spawnerHUD, i, DummySpawnerHUDHandler, 3 ); 
		}
	}
	CloseHandle(spawnerHUD);
	return Plugin_Continue;
}

void FillHeaderInfo(Handle spawnerHUD) {
	SetPanelTitle(spawnerHUD, "--------- SPAWNER HUD ---------");
	DrawPanelText(spawnerHUD, " \n");
}

void FillSpecialInfectedInfo(Handle spawnerHUD) {
	// Potential SI
	char SILimit[32];
	Format( SILimit, sizeof(SILimit), "SI max -> %d / %d (Cap: %d)", CountSpecialInfectedBots(), GetConVarInt(hSILimit), GetConVarInt(hSILimitServerCap) );
	DrawPanelText(spawnerHUD, SILimit);
	// Simultaneous spawn limit
	char simultaneousSpawnLimit[32];
	Format( simultaneousSpawnLimit, sizeof(simultaneousSpawnLimit), "Group spawn size -> %d", GetConVarInt(hSpawnSize) );
	DrawPanelText(spawnerHUD, simultaneousSpawnLimit);
	DrawPanelText(spawnerHUD, " \n");
	// Individual class weights and limits
	char classCustomisationInfo[NUM_TYPES_INFECTED][64];
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		Format( 
			classCustomisationInfo[i],
			128, 
			"%s | weight: %d | limit: %d/%d ",
			Spawns[i], GetConVarInt(hSpawnWeights[i]), CountSIClass(i + 1), GetConVarInt(hSpawnLimits[i])
		);
		DrawPanelText(spawnerHUD, classCustomisationInfo[i]);
	}
	DrawPanelText(spawnerHUD, " \n");
}

void FillTimerInfo(Handle spawnerHUD) {
	// Section heading
	DrawPanelText(spawnerHUD, "Timer:");
	// Min spawn time
	char timerMin[32];
	Format( timerMin, sizeof(timerMin), "Min: %f", GetConVarFloat(hSpawnTimeMin) );
	DrawPanelText(spawnerHUD, timerMin);
	// Max spawn time
	char timerMax[32];
	Format( timerMax, sizeof(timerMax), "Max: %f", GetConVarFloat(hSpawnTimeMax) );
	DrawPanelText(spawnerHUD, timerMax);
}

public int DummySpawnerHUDHandler(Handle hMenu, MenuAction action, int param1, int param2) {}

int CountSIClass( int targetClass ) {
	int iClassSpawnVolume;
	for( int i = 1; i <= MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) && L4D2_GetInfectedClass(i) == view_as<L4D2_Infected>(targetClass) ) {
			iClassSpawnVolume++;
		}
	}	
	return iClassSpawnVolume;
}











/***********************************************************************************************************************************************************************************

                                     								DETERMINE POSITION
                                                                    
***********************************************************************************************************************************************************************************/

// Handles radial and grid spawning; Nav Mesh spawning is handled differently in SpawnQueue module and does not pass on to here.
void AttemptSpawnAuto(L4D2_Infected SIClass)
{
	if( CheckSurvivorsSeparated() )
	{
		RadialSpawn( SIClass, GetLeadSurvivor() );	
	}
	else if( GetConVarInt(hCvarSpawnPositionerMode) == 2 ) 
	{
		GridSpawn( SIClass );
	} 
	else 
	{ 
		RadialSpawn( SIClass, L4D2_GetRandomSurvivor() );
	}
}

/***********************************************************************************************************************************************************************************

                                             					GRID POSITIONING SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a random point on a 2D grid around the survivors. 
 */
void GridSpawn( L4D2_Infected SIClass ) {
	
	UpdateSpawnBounds();
	
	for( int i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) {
		float searchPos[3];
		float survivorPos[3];
		int closestSurvivor;
		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		searchPos[COORD_X] = GetRandomFloat(spawnBounds[X_MIN], spawnBounds[X_MAX]);
		searchPos[COORD_Y] = GetRandomFloat(spawnBounds[Y_MIN], spawnBounds[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from just above the height of nearest survivor
		closestSurvivor = GetClosestSurvivor2D(searchPos[COORD_X], searchPos[COORD_Y]);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		searchPos[COORD_Z] = survivorPos[COORD_Z] + float( GetConVarInt(hCvarSpawnSearchHeight) );
		
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
			
					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						PrintToChatAll("[SS] SI Class %d GRID SPAWN, %d dist, ( %d attempts)", SIClass, RoundFloat(GetFlowDistToSurvivors(spawnPos)), i + 1);
						searchPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( searchPos, spawnPos, VALID_MESH );
					#endif
				NMDIS_TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); // all spawn conditions satisifed
				return;
				
			} else {

					#if DEBUG_POSITIONER
						DrawSpawnGrid();
						searchPos[COORD_Z] = DEBUG_DRAW_ELEVATION;
						DrawBeam( searchPos, spawnPos, INVALID_MESH );
					#endif
					
			}
		} 
 	}
 	// Could not find an acceptable spawn position
	LogMessage("[SS] FAILED to find a valid GRID SPAWN position for SI Class '%d' after %d attempts", SIClass, GetConVarInt(hCvarMaxSearchAttempts) ); 
	return;
 }
 
bool IsValidSpawn(const float spawnPos[3]) {
	bool is_valid = false;
	int flow_dist_survivors;
	if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, L4D2_GetRandomSurvivor()) ) {
		flow_dist_survivors = GetFlowDistToSurvivors(spawnPos);
		if ( HasSurvivorLOS(spawnPos) ) {
			int survivor_proximity = GetSurvivorProximity(spawnPos);
			if ( survivor_proximity > GetConVarInt(hCvarSpawnProximityMin) && flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowLOS) ) { 
				is_valid = true;
			}
		} else { // try to keep spawn flow distance to survivors low if they are spawning outside of LOS
			if ( flow_dist_survivors < GetConVarInt(hCvarSpawnProximityFlowNoLOS) && flow_dist_survivors != -1 ) {
					
					#if DEBUG_POSITIONER
						PrintToChatAll("flow dist %d < cvar %d", flow_dist_survivors, GetConVarInt(hCvarSpawnProximityFlowNoLOS));
					#endif
				
				is_valid = true;
			}
		}
	}
	return is_valid;
}

void UpdateSpawnBounds() {
	// Grid will have coords (min X, min Y), (min X, max Y), (max X, min Y), (max X, max Y)
	spawnBounds[X_MIN] = UNINITIALISED_FLOAT, spawnBounds[Y_MIN] = UNINITIALISED_FLOAT;
	spawnBounds[X_MAX] = UNINITIALISED_FLOAT, spawnBounds[Y_MAX] = UNINITIALISED_FLOAT;
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && IsPlayerAlive(i) ) {
			float pos[3];
			GetClientAbsOrigin(i, pos);
			// Check min
			spawnBounds[X_MIN] = CheckMinCoord( spawnBounds[X_MIN], pos[COORD_X] );
			spawnBounds[Y_MIN] = CheckMinCoord( spawnBounds[Y_MIN], pos[COORD_Y] );
			// Check max
			spawnBounds[X_MAX] = CheckMaxCoord( spawnBounds[X_MAX], pos[COORD_X] );
			spawnBounds[Y_MAX] = CheckMaxCoord( spawnBounds[Y_MAX], pos[COORD_Y] );
		}
	}
	// Extend a border around grid
	float borderWidth = float( GetConVarInt(hCvarSpawnProximityMax) );
	spawnBounds[X_MIN] -= borderWidth;
	spawnBounds[Y_MIN] -= borderWidth;
	spawnBounds[X_MAX] += borderWidth;
	spawnBounds[Y_MAX] += borderWidth;
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

stock void DrawSpawnGrid() {
	float xMin = spawnGrid[X_MIN];
	float xMax = spawnGrid[X_MAX];
	float yMin = spawnGrid[Y_MIN];
	float yMax = spawnGrid[Y_MAX];
	float z = DEBUG_DRAW_ELEVATION;
	float bottomLeft[3]; 
	bottomLeft[0] = xMin;
	bottomLeft[1] = yMin;
	bottomLeft[2] = z;
	float topLeft[3];
	topLeft[0] = xMin;
	topLeft[1] = yMax;
	topLeft[2] = z;
	float topRight[3];
	topRight[0] = xMax;
	topRight[1] = yMax;
	float bottomRight[3]; 
	bottomRight[0] = xMax;
	bottomRight[1] = yMin;
	bottomLeft[2] = z;
	topRight[2] = z;
	DrawBeam( bottomLeft, topLeft, PURPLE );  
	DrawBeam( topLeft, topRight, PURPLE ); 
	DrawBeam( topRight, bottomRight, PURPLE );  
	DrawBeam( bottomRight, bottomLeft, PURPLE );  
}

/***********************************************************************************************************************************************************************************

                                             					RADIAL POSITIONING SYSTEM
                                                                    
***********************************************************************************************************************************************************************************/

/*
 * Reposition the SI to a point on the circumference of a circle [spawn_proximity] from a survivor; respects distance to all survivors
 * Always spawns SI at [ss_spawn_proximity_min] distance to survivors
 */
void RadialSpawn( L4D2_Infected SIClass, int survivorTarget ) {
	bool spawnSuccess = false;
	float survivorPos[3];
	float rayEnd[3];
	float spawnPos[3] = {-1.0, -1.0, -1.0};
	for( int i = 0; i < GetConVarInt(hCvarMaxSearchAttempts); i++ ) {		
		// Fire a ray at a random angle around the survivor
		GetClientAbsOrigin(survivorTarget, survivorPos); 
		float spawnSearchAngle = GetRandomFloat(0.0, 2.0 * PI);
		rayEnd[0] = survivorPos[0] + Sine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
		rayEnd[1] = survivorPos[1] + Cosine(spawnSearchAngle) * GetConVarInt(hCvarSpawnProximityMin);
		rayEnd[2] = survivorPos[2] + GetConVarInt(hCvarSpawnSearchHeight);
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
			if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, L4D2_GetRandomSurvivor()) && GetSurvivorProximity(spawnPos) > GetConVarInt(hCvarSpawnProximityMin) ) {
						
					#if DEBUG_POSITIONER
						LogMessage("[SS] ( %d attempts ) Found a valid RADIAL SPAWN position for SI Class '%d'", i, SIClass);
						DrawBeam( survivorPos, rayEnd, VALID_MESH );
						DrawBeam( rayEnd, spawnPos, VALID_MESH ); 
					#endif
						
				NMDIS_TriggerSpawn(SIClass, spawnPos, NULL_VECTOR); 
				spawnSuccess = true;
				break;
					
			} else {
			
					#if DEBUG_POSITIONER
						DrawBeam( survivorPos, rayEnd, INVALID_MESH );
						DrawBeam( rayEnd, spawnPos, WHITE ); 
					#endif
					
			}
		}
	}
		
	// Could not find an acceptable spawn position
	if(!spawnSuccess) {
		LogMessage("[SS] FAILED to find a valid RADIAL SPAWN position for infected class '%d' after %d attempts", SIClass, GetConVarInt(hCvarMaxSearchAttempts) ); 
	}		
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
	if( GetVectorDistance( leadSurvivorPos, rearSurvivorPos ) > float(2 * GetConVarInt(hCvarSpawnProximityMax)) ) {
		return true;
	} else {
		return false;
	}
}

/***********************************************************************************************************************************************************************************

                                                                      UTILITY	
                                                                    
***********************************************************************************************************************************************************************************/
	
stock bool HasSurvivorLOS( const float pos[3] ) {
	bool hasLOS = false;
	for( int i = 1; i < MaxClients; ++i ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && IsPlayerAlive(i) ) {
			float origin[3];
			GetClientAbsOrigin(i, origin);
			TR_TraceRay( pos, origin, MASK_ALL, RayType_EndPoint );
			if( !TR_DidHit() ) {
				hasLOS = true;
				break;
			}
		}	
	}
	return hasLOS;
}

int GetLeadSurvivor() {
	// Find the farthest flow held by a survivor
	float farthestFlow = -1.0;
	int leadSurvivor = -1;
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && IsPlayerAlive(i) ) {
			float origin[3];
			GetClientAbsOrigin(i, origin);
			Address pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				float tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow > farthestFlow || farthestFlow == -1.0 ) {
					farthestFlow = tmp_flow;
					leadSurvivor = i;
				}
			}
		}
	}
	return leadSurvivor;
}

int GetRearSurvivor() {
	// Find the farthest flow held by a survivor
	float lowestFlow = -1.0;
	int rearSurvivor = -1;
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && IsPlayerAlive(i) ) {
			float origin[3];
			GetClientAbsOrigin(i, origin);
			Address pNavArea = L4D2Direct_GetTerrorNavArea(origin);
			if( pNavArea != Address_Null ) {
				float tmp_flow = L4D2Direct_GetTerrorNavAreaFlow(pNavArea);
				if( tmp_flow < lowestFlow || lowestFlow == -1.0 ) {
					lowestFlow = tmp_flow;
					rearSurvivor = i;
				}
			}
		}
	}
	return rearSurvivor;
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

/** @return: the last array index of g_AllSurvivors holding a valid survivor */
stock int CacheSurvivors() {
	int j = 0;
	for( int i = 0; i < MAXPLAYERS; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) ) {
		    g_AllSurvivors[j] = i;
		    j++;
		}
	}
	return (j - 1);
}

stock bool IsOnValidMesh(const float position[3]) {
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

stock void DrawBeam( float startPos[3], float endPos[3], int spawnResult ) {
	laserCache = PrecacheModel("materials/sprites/laserbeam.vmt");
	int Color[5][4]; 
	Color[VALID_MESH] = {0, 255, 0, 75}; // green
	Color[INVALID_MESH] = {255, 0, 0, 75}; // red
	Color[SPAWN_FAIL] = {255, 140, 0, 75}; // orange
	Color[WHITE] = {255, 255, 255, 75}; // white
	Color[PURPLE] = {128, 0, 128, 75}; // purple
	float beamDuration = 5.0;
	TE_SetupBeamPoints(startPos, endPos, laserCache, 0, 1, 1, beamDuration, 5.0, 5.0, 4, 0.0, Color[spawnResult], 0);
	int iSurvivors[MaxClients];
	int iNumSurvivors = 0;
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && !IsFakeClient(i) ) {
			iSurvivors[iNumSurvivors] = i;
			iNumSurvivors++;
		}
	}
	TE_Send( iSurvivors, iNumSurvivors ); 
}





/***********************************************************************************************************************************************************************************

                                                                       LIMIT/WEIGHT UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

void LoadCacheSpawnLimits() { // If cached values exist, apply them
	if( SILimitCache != UNINITIALISED ) SetConVarInt( hSILimit, SILimitCache );
	if( SpawnSizeCache != UNINITIALISED ) SetConVarInt( hSpawnSize, SpawnSizeCache );
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {		
		if( SpawnLimitsCache[i] != UNINITIALISED ) {
			SetConVarInt( hSpawnLimits[i], SpawnLimitsCache[i] );
		}
	}
}

void LoadCacheSpawnWeights() { // if cached values exist, apply them
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {		
		if( SpawnWeightsCache[i] != UNINITIALISED ) {
			SetConVarInt( hSpawnWeights[i], SpawnWeightsCache[i] );
		}
	}
}

void ResetWeights() {
	for (int i = 0; i < NUM_TYPES_INFECTED; i++) {
		ResetConVar(hSpawnWeights[i]);
	}
}








void GenerateAndExecuteSpawnQueue() {
	if( CountSpecialInfectedBots() < GetConVarInt(hSILimit) ) { // spawn when infected count hasn't reached limit
		int size;
		int numAllowedSI = GetConVarInt(hSILimit) - CountSpecialInfectedBots();
		if( GetConVarInt(hSpawnSize) > numAllowedSI ) { // prevent amount of special infected from exceeding SILimit
			size = numAllowedSI;
		} else {
			size = GetConVarInt(hSpawnSize);
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
		if ( GetConVarInt(hCvarSpawnPositionerMode) == 3 ) 
		{
			NMDIS_NavMeshSpawn(SpawnQueue);
		}
		else 
		{ // for old spawn times, generate spawn locations one at a time
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
}

void SITypeCount() { //Count the number of each SI ingame
	for (int i = 0; i < NUM_TYPES_INFECTED; i++) {
		SpawnCounts[i] = 0;
	}
	for( int i = 1; i < MaxClients; i++ ) {
		if( IsBotInfected(i) && IsPlayerAlive(i) ) { 
			switch( L4D2_GetInfectedClass(i) ) { //detect SI type
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

int GenerateIndex() {	
	int TotalSpawnWeight, StandardizedSpawnWeight;
	
	// temporary spawn weights factoring in SI spawn limits
	int TempSpawnWeights[NUM_TYPES_INFECTED];
	for( int i = 0; i < NUM_TYPES_INFECTED; i++ ) {
		if( SpawnCounts[i] < GetConVarInt(hSpawnLimits[i]) ) {
			if( GetConVarBool(hScaleWeights) ) {
				TempSpawnWeights[i] = ( GetConVarInt(hSpawnLimits[i]) - SpawnCounts[i] ) * GetConVarInt(hSpawnWeights[i]);
			} else {
				TempSpawnWeights[i] = GetConVarInt(hSpawnWeights[i]);
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

                                                                           START TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

//never directly set hSpawnTimer, use this function for custom spawn times
void StartCustomSpawnTimer(float time) {
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	g_bHasSpawnTimerStarted = true;
	hSpawnTimer = CreateTimer( time, SpawnInfectedAuto, TIMER_FLAG_NO_MAPCHANGE );
}

//special infected spawn timer based on time modes
void StartSpawnTimer() {
	//prevent multiple timer instances
	EndSpawnTimer();
	//only start spawn timer if plugin is enabled
	float time;
	
	if( GetConVarInt(hSpawnTimeMode) > 0 ) { //NOT randomization spawn time mode
		time = SpawnTimes[CountSpecialInfectedBots()]; //a spawn time based on the current amount of special infected
	} else { //randomization spawn time mode
		time = GetRandomFloat( GetConVarFloat(hSpawnTimeMin), GetConVarFloat(hSpawnTimeMax) ); //a random spawn time between min and max inclusive
	}
	g_bHasSpawnTimerStarted = true;
	hSpawnTimer = CreateTimer( time, SpawnInfectedAuto, TIMER_FLAG_NO_MAPCHANGE );
	
		#if DEBUG_TIMERS
			PrintToChatAll("[SS] New spawn timer | Mode: %d | SI: %d | Next: %.3f s", GetConVarInt(hSpawnTimeMode), CountSpecialInfectedBots(), time);
		#endif
}

void StartBoomerTimer() {
	EndBoomerTimer();
	g_bHasBoomerTimerStarted = true;	
	float avgFrequency = GetConVarFloat(hCvarFrequencyBoomerAmbush);
	hTimerBoomer = CreateTimer( GetRandomFloat(avgFrequency, avgFrequency + 2.0), Timer_BoomerAmbush, TIMER_FLAG_NO_MAPCHANGE );
	
		#if DEBUG_TIMERS
			PrintToChatAll("[SS] Boomer timer started");
		#endif
}

/***********************************************************************************************************************************************************************************

                                                                       SPAWN TIMER
                                                                    
***********************************************************************************************************************************************************************************/

public Action SpawnInfectedAuto(Handle timer) {
	g_bHasSpawnTimerStarted = false; 
	// Grant grace period before allowing a wave to spawn if there are incapacitated survivors
	int numIncappedSurvivors = 0;
	for (int i = 1; i <= MaxClients; i++ ) {
		if( IsClientInGame(i) && L4D2_IsSurvivor(i) && L4D2_IsPlayerIncap(i) && !IsPinned(i) ) {
			numIncappedSurvivors++;			
		}
	}
	if( numIncappedSurvivors > 0 && numIncappedSurvivors != GetConVarInt(FindConVar("survivor_limit")) ) { // grant grace period
		int gracePeriod = numIncappedSurvivors * GetConVarInt(hCvarIncapAllowance);
		CreateTimer( float(gracePeriod), Timer_GracePeriod, _, TIMER_FLAG_NO_MAPCHANGE );
		L4D2_CPrintToChatAll("{olive}[{default}SS{olive}]{default} {blue}%d{default}s {olive}grace period{default} was granted because of {blue}%d{default} incapped survivor(s)", gracePeriod, numIncappedSurvivors);
	} else { // spawn immediately
		GenerateAndExecuteSpawnQueue();
	}
	// Start timer for next spawn group
	StartSpawnTimer();
	return Plugin_Handled;
}

public Action Timer_BoomerAmbush(Handle timer) {
	g_bHasBoomerTimerStarted = false;
	// Spawn_NavMesh(L4D2Infected_Boomer); // rewriting spawn function
	StartBoomerTimer();	
}

public Action Timer_GracePeriod(Handle timer) {
	GenerateAndExecuteSpawnQueue();
	return Plugin_Handled;
}

/***********************************************************************************************************************************************************************************

                                                                        END TIMERS
                                                                    
***********************************************************************************************************************************************************************************/

void EndSpawnTimer() {
	if( g_bHasSpawnTimerStarted ) {
		if( hSpawnTimer != INVALID_HANDLE ) {
			CloseHandle(hSpawnTimer);
			hSpawnTimer = INVALID_HANDLE;
		}
		g_bHasSpawnTimerStarted = false;
		
			#if DEBUG_TIMERS
				PrintToChatAll("[SS] Ending spawn timer.");
			#endif
		
	}
}

void EndBoomerTimer() {
	if ( g_bHasBoomerTimerStarted ) {
		if ( hTimerBoomer != INVALID_HANDLE ) {
			CloseHandle(hTimerBoomer);
			hTimerBoomer = INVALID_HANDLE;			
		}
		g_bHasBoomerTimerStarted = false;
		
			#if DEBUG_TIMERS
				PrintToChatAll("[SS] Ending boomer timer.");
			#endif
	}
}

/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

void SetSpawnTimes() {
	float fSpawnTimeMin = GetConVarFloat(hSpawnTimeMin);
	float fSpawnTimeMax = GetConVarFloat(hSpawnTimeMax);
	if( fSpawnTimeMin > fSpawnTimeMax ) { //SpawnTimeMin cannot be greater than SpawnTimeMax
		SetConVarFloat( hSpawnTimeMin, fSpawnTimeMax ); //set back to appropriate limit
	} else if( fSpawnTimeMax < fSpawnTimeMin ) { //SpawnTimeMax cannot be less than SpawnTimeMin
		SetConVarFloat(hSpawnTimeMax, fSpawnTimeMin ); //set back to appropriate limit
	} else {
		CalculateSpawnTimes(view_as<ConVar>(INVALID_HANDLE), "", ""); //must recalculate spawn time table to compensate for min change
	}
}






/**
 * @return: true if client is a special infected bot
 */
stock bool IsBotInfected(int client) {
    // Check the input is valid
    if (!L4D2_IsValidClient(client))return false;
    
    // Check if player is a bot on the infected team
    if (L4D2_IsInfected(client) && IsFakeClient(client)) {
        return true;
    }
    return false; // otherwise
}

/**
 *@return: true if client is a tank
 */
stock bool IsTank(int client) {
    return IsClientConnected(client)
        && view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected
        && L4D2_GetInfectedClass(client) == L4D2Infected_Tank;
}

stock bool IsGenericAdmin(int client) {
	return CheckCommandAccess(client, "generic_admin", ADMFLAG_GENERIC, false); 
}

// @return: the total special infected bots alive in the game
stock int CountSpecialInfectedBots() {
    int count = 0;
    for (int i = 1; i < MaxClients; i++) {
        if (IsBotInfected(i) && IsPlayerAlive(i)) {
            count++;
        }
    }
    return count;
}

stock bool IsPinned(int client) {
	bool bIsPinned = false;
	if (L4D2_IsSurvivor(client)) {
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
 * Returns the distance of the closest survivor or a specified survivor
 * @param referenceClient: the client from which to measure distance to survivor
 * @param specificSurvivor: the index of the survivor to be measured, -1 to search for distance to closest survivor
 * @return: the distance
 */
stock int GetSurvivorProximity( const float rp[3], int specificSurvivor = -1 ) {
	
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

/**
 * Returns the flow distance from given point to closest alive survivor. 
 * Returns -1.0 if either the given point or the survivors as a whole are not upon a valid nav mesh
 */
stock int GetFlowDistToSurvivors(const float pos[3]) {
	int spawnpoint_flow;
	int lowest_flow_dist = -1;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow == -1) {
		return -1;
	}
	
	for ( int j = 0; j < MaxClients; j++ ) {
		if ( IsClientInGame(j) && L4D2_IsSurvivor(j) && IsPlayerAlive(j) ) {
			float origin[3];
			int flow_dist;
			
			GetClientAbsOrigin(j, origin);
			flow_dist = GetFlow(origin);
			
			// have we found a new valid(i.e. != -1) lowest flow_dist
			if ( flow_dist != -1 && FloatCompare(FloatAbs(float(flow_dist) - float(spawnpoint_flow)), float(lowest_flow_dist)) ==  -1 ) {
				lowest_flow_dist = flow_dist;
			}
		}
	}
	
	return lowest_flow_dist;
}

/**
 * Finds the closest survivor excluding a given survivor 
 * @param referenceClient: compares survivor distances to this client
 * @param excludeSurvivor: ignores this survivor
 * @return: the entity index of the closest survivor
**/
stock int GetClosestSurvivor( float referencePos[3], int excludeSurvivor = -1 ) {
	float survivorPos[3];
	int closestSurvivor = L4D2_GetRandomSurvivor();	
	if ( !L4D2_IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor([%f, %f, %f], %d) = invalid client %d", referencePos[0], referencePos[1], referencePos[2], excludeSurvivor, closestSurvivor);
		return -1;
	}
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	int iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (int client = 1; client <= MAXPLAYERS; client++) {
		if( IsClientInGame(client) && L4D2_IsSurvivor(client) && IsPlayerAlive(client) && client != excludeSurvivor ) {
			GetClientAbsOrigin( client, survivorPos );
			int displacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
			if( displacement < iClosestAbsDisplacement || iClosestAbsDisplacement < 0 ) { 
				iClosestAbsDisplacement = displacement;
				closestSurvivor = client;
			}
		}
	}
	return closestSurvivor;
}

#define X_COORD 0
#define Y_COORD 1
#define Z_COORD 2
/**
 * Returns the distance of the closest survivor or a specified survivor to a 2D point on the horizontal plane
 * @param gridPos - from where we are measuring the distance to survivors
 * @return: the closest survivor on the horizontal 2D plane
 */
stock int GetClosestSurvivor2D(float x_coord, float y_coord) 
{
	float proximity = -1.0;
	int closestSurvivor = L4D2_GetRandomSurvivor();
	if ( !L4D2_IsValidClient(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor2D(%f, %f) - Unable to find any survivors", x_coord, y_coord);
	}		
	for( int j = 1; j <= MAXPLAYERS; j++ ) {
		if( IsClientInGame(j) && L4D2_IsSurvivor(j) && IsPlayerAlive(j) ) {
			float survivorPos[3];
			GetClientAbsOrigin( j, survivorPos );
			// Pythagoras
			float survivorDistance = SquareRoot( Pow(survivorPos[X_COORD] - x_coord, 2.0) + Pow(survivorPos[Y_COORD] - y_coord, 2.0) );
			if( survivorDistance < proximity || proximity == -1.0 ) {
				proximity = survivorDistance;
				closestSurvivor = j;
			}
		}
	}
	return closestSurvivor;
}
