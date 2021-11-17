#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"
#define MODEL_WITCH "models/infected/witch.mdl"
#define MODEL_WITCHBRIDE "models/infected/witch_bride.mdl"

#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"
#define ADDRESS_NAME "NextBotCreatePlayerBot.jumptable"
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"

#define GAMEDATA "spawn_infected_nolimit"

#define DIRECTOR_CLASS "info_director"
#define BRIDE_WITCH_TARGETNAME "plugin_dzs_bride"

public Plugin myinfo = 
{
	name = "[L4D2] Direct Infected Spawn",
	author = "Shadowysn, ProdigySim (Major Windows Fix), Tordecybombo, breezy",
	description = "Spawn special infected without the director limits!",
	version = "1.2.1",
	url = ""
};

Handle 
	hCreateSmoker = null,
	hCreateBoomer = null,
	hCreateHunter = null,
	hCreateSpitter = null,
	hCreateJockey = null,
	hCreateCharger = null,
	hCreateTank = null,
	hInfectedAttackSurvivorTeam = null;

ConVar 
	hSpawnSearchHeight,
	hSpawnProximityMin,
	hSpawnProximityMax;

int 
	iSpawnSearchHeight,
	iSpawnProximityMin,
	iSpawnProximityMax;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("GridSpawn", _native_GridSpawn);
	CreateNative("TriggerSpawn", _native_TriggerSpawn);
	RegPluginLibrary("DirectInfectedSpawn");
	return APLRes_Success;
}

public any _native_GridSpawn(Handle plugin, int numParams)
{
	int desiredClass = GetNativeCell(1);
	int attempts = GetNativeCell(2);
	float pos[3];
	GridSpawn(desiredClass, attempts, pos);
	SetNativeArray(3, pos, 3);
}

public any _native_TriggerSpawn(Handle plugin, int numParams)
{
	int desiredClass = GetNativeCell(1);
	float pos[3];
	GetNativeArray(2, pos, 3);
	TriggerSpawn(desiredClass, pos);
}

public void OnPluginStart()
{
	hSpawnSearchHeight = CreateConVar( "ss_spawn_search_height", "350", "Attempts to find a valid spawn location will move down from this height relative to a survivor");
	hSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "最接近SI的可能是生还者", _, true, 1.0 );
	hSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "一个SI可以产卵到幸存者的最远的地方", _, true, float(hSpawnProximityMin.IntValue) );
	
	hSpawnSearchHeight.AddChangeHook(ConVarChange);
	hSpawnProximityMin.AddChangeHook(ConVarChange);
	hSpawnProximityMax.AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
	
	HookEvent("witch_harasser_set", witch_harasser_set, EventHookMode_Post);
	HookEvent("witch_killed", witch_killed, EventHookMode_Post);
	
	GetGamedata();
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSpawnSearchHeight = hSpawnSearchHeight.IntValue;
	iSpawnProximityMin = hSpawnProximityMin.IntValue;
	iSpawnProximityMax = hSpawnProximityMax.IntValue;
}

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}

public void OnMapStart()
{
	CheckandPrecacheModel(MODEL_SMOKER);
	CheckandPrecacheModel(MODEL_BOOMER);
	CheckandPrecacheModel(MODEL_HUNTER);
	CheckandPrecacheModel(MODEL_SPITTER);
	CheckandPrecacheModel(MODEL_JOCKEY);
	CheckandPrecacheModel(MODEL_CHARGER);
	CheckandPrecacheModel(MODEL_WITCHBRIDE);
	CheckandPrecacheModel(MODEL_TANK);
	CheckandPrecacheModel(MODEL_WITCH);
}

void witch_harasser_set(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	PrintToServer("Bride startled");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

void witch_killed(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	//if (!event.GetBool("oneshot")) return;
	
	PrintToServer("Bride killed");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

int CheckForDirectorEnt()
{
	int result = FindEntityByClassname(-1, DIRECTOR_CLASS);
	if (!IsValidEntity(result) || result <= 0)
	{
		result = CreateEntityByName(DIRECTOR_CLASS);
		DispatchSpawn(result);
		ActivateEntity(result);
	}
	return result;
}


#define BOUNDINGBOX_INFLATION_OFFSET 0.5
#define PI 3.14159265359
#define UNINITIALISED_FLOAT -1.42424
#define NAV_MESH_HEIGHT 20.0
#define PITCH 0
#define YAW 1
#define ROLL 2
#define MAX_ANGLE 89.0
#define COORD_X 0
#define COORD_Y 1
#define COORD_Z 2
#define X_MIN 0
#define X_MAX 1
#define Y_MIN 2
#define Y_MAX 3
#define X_COORD 0
#define Y_COORD 1
#define Z_COORD 2

float spawnBounds[4]; // denoted by minimum and maximum X and Y coordinates

bool GridSpawn(int zombieClass, int attempts, float vecPos[3])
{
	UpdateSpawnBounds();
	
	for (int i = 0; i < attempts; i++)
	{
		float searchPos[3];
		float survivorPos[3];
		int closestSurvivor;
		
		// 'x' and 'y' for potential spawn point coordinates is selected with uniform RNG
		searchPos[COORD_X] = GetRandomFloat(spawnBounds[X_MIN], spawnBounds[X_MAX]);
		searchPos[COORD_Y] = GetRandomFloat(spawnBounds[Y_MIN], spawnBounds[Y_MAX]);
		// 'z' for potential spawn point coordinate is taken from just above the height of nearest survivor
		closestSurvivor = GetClosestSurvivor2D(searchPos[COORD_X], searchPos[COORD_Y]);
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		searchPos[COORD_Z] = survivorPos[COORD_Z] + float(iSpawnSearchHeight);
		
		// Search down the vertical column from the generated [x, y ,z] coordinate for a valid spawn position
		float direction[3];
		direction[PITCH] = MAX_ANGLE; // straight down
		direction[YAW] = 0.0;
		direction[ROLL] = 0.0;
		TR_TraceRay(searchPos, direction, MASK_ALL, RayType_Infinite);
		
		// found solid land below the [x, y, z] coordinate
		if (TR_DidHit())
		{
			float traceImpact[3];
			TR_GetEndPosition(traceImpact); 
			vecPos = traceImpact;
			vecPos[COORD_Z] += NAV_MESH_HEIGHT; // from testing I presume the SI cannot spawn on the floor itself
			
			if (IsValidSpawn(vecPos)/* && !PlayerVisibleTo(vecPos)*/)
			{
				return true;
			}
		} 
 	}

 	// Could not find an acceptable spawn position
	LogMessage("[SS] FAILED to find a valid GRID SPAWN position for SI Class '%d' after %d attempts", zombieClass, attempts); 
	return false;
}

void UpdateSpawnBounds()
{
	// Grid will have coords (min X, min Y), (min X, max Y), (max X, min Y), (max X, max Y)
	spawnBounds[X_MIN] = UNINITIALISED_FLOAT, spawnBounds[Y_MIN] = UNINITIALISED_FLOAT;
	spawnBounds[X_MAX] = UNINITIALISED_FLOAT, spawnBounds[Y_MAX] = UNINITIALISED_FLOAT;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		float pos[3];
		GetClientAbsOrigin(i, pos);
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

int GetClosestSurvivor2D(float x_coord, float y_coord) 
{
	float proximity = -1.0;
	int closestSurvivor = GetRandomSurvivor();
	if ( !IsValidClient2(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor2D(%f, %f) - Unable to find any survivors", x_coord, y_coord);
	}		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		float survivorPos[3];
		GetClientAbsOrigin( i, survivorPos );
		// Pythagoras
		float survivorDistance = SquareRoot( Pow(survivorPos[X_COORD] - x_coord, 2.0) + Pow(survivorPos[Y_COORD] - y_coord, 2.0) );
		if( survivorDistance < proximity || proximity == -1.0 ) {
			proximity = survivorDistance;
			closestSurvivor = i;
		}
	}
	return closestSurvivor;
}

float CheckMinCoord( float oldMin, float checkValue )
{
	if( checkValue < oldMin || oldMin == UNINITIALISED_FLOAT )
	{
		return checkValue;
	}
	else
	{
		return oldMin;
	}
}

float CheckMaxCoord( float oldMax, float checkValue )
{
	if( checkValue > oldMax || oldMax == UNINITIALISED_FLOAT )
	{
		return checkValue;
	}
	else
	{
		return oldMax;
	}
}

bool IsValidSpawn(const float spawnPos[3])
{
	bool is_valid = false;
	int flow_dist_survivors;
	if( IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, GetRandomSurvivor()) )
	{
		flow_dist_survivors = GetFlowDistToSurvivors(spawnPos);
		if ( HasSurvivorLOS(spawnPos) )
		{
			int survivor_proximity = GetSurvivorProximity(spawnPos);
			if ( survivor_proximity > iSpawnProximityMin && flow_dist_survivors < 900 )
			{
				is_valid = true;
			}
		}
		else
		{ // try to keep spawn flow distance to survivors low if they are spawning outside of LOS
			if ( flow_dist_survivors < 500 && flow_dist_survivors != -1 )
			{
				is_valid = true;
			}
		}
	}
	return is_valid;
}

bool IsOnValidMesh(const float position[3])
{
	float pos[3];
	pos[0] = position[0]; 
	pos[1] = position[1]; 
	pos[2] = position[2]; 
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null)
	{
		return true;
	}
	else
	{
		return false;
	}
}

bool IsPlayerStuck( const float pos[3], int client)
{
	bool isStuck = true;
	if( IsValidClient2(client) ) {
		float mins[3];
		float maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		
		// inflate the sizes just a little bit
		for( int i = 0; i < sizeof(mins); i++ )
		{
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}
		
		TR_TraceHullFilter(pos, pos, mins, maxs, MASK_ALL, TraceEntityFilterPlayer, client);
		isStuck = TR_DidHit();
	}
	return isStuck;
}

public bool TraceEntityFilterPlayer(int entity, int contentsMask)
{
    return entity <= 0 || entity > MaxClients;
}  

int GetFlowDistToSurvivors(const float pos[3])
{
	int spawnpoint_flow;
	int lowest_flow_dist = -1;
	
	spawnpoint_flow = GetFlow(pos);
	if ( spawnpoint_flow == -1)
	{
		return -1;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		float origin[3];
		int flow_dist;
		
		GetClientAbsOrigin(i, origin);
		flow_dist = GetFlow(origin);
		
		// have we found a new valid(i.e. != -1) lowest flow_dist
		if ( flow_dist != -1 && FloatCompare(FloatAbs(float(flow_dist) - float(spawnpoint_flow)), float(lowest_flow_dist)) ==  -1 ) {
			lowest_flow_dist = flow_dist;
		}
	}
	
	return lowest_flow_dist;
}

bool HasSurvivorLOS( const float pos[3] )
{
	bool hasLOS = false;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		float origin[3];
		GetClientAbsOrigin(i, origin);
		TR_TraceRay( pos, origin, MASK_ALL, RayType_EndPoint );
		if( !TR_DidHit() )
		{
			hasLOS = true;
			break;
		}	
	}
	return hasLOS;
}

int GetSurvivorProximity( const float rp[3])
{
	
	int targetSurvivor;
	float targetSurvivorPos[3];
	float referencePos[3]; // non constant var
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	
	targetSurvivor = GetClosestSurvivor( referencePos );
	
	GetClientAbsOrigin( targetSurvivor, targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}

int GetClosestSurvivor( float referencePos[3], int excludeSurvivor = -1 )
{
	float survivorPos[3];
	int closestSurvivor = GetRandomSurvivor();	
	if ( !IsValidClient2(closestSurvivor) ) 
	{
		LogError("GetClosestSurvivor([%f, %f, %f], %d) = invalid client %d", referencePos[0], referencePos[1], referencePos[2], excludeSurvivor, closestSurvivor);
		return -1;
	}
	GetClientAbsOrigin( closestSurvivor, survivorPos );
	int iClosestAbsDisplacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
		if (i == excludeSurvivor) continue;
		GetClientAbsOrigin( i, survivorPos );
		int displacement = RoundToNearest( GetVectorDistance(referencePos, survivorPos) );			
		if( displacement < iClosestAbsDisplacement || iClosestAbsDisplacement < 0 ) { 
			iClosestAbsDisplacement = displacement;
			closestSurvivor = i;
		}
	}
	return closestSurvivor;
}

int GetFlow(const float o[3])
{
	float origin[3]; //non constant var
	origin[0] = o[0];
	origin[1] = o[1];
	origin[2] = o[2];
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(origin);
	if (pNavArea != Address_Null)
	{
		return RoundToNearest(L4D2Direct_GetTerrorNavAreaFlow(pNavArea));
	}
	else
	{
		return -1;
	}
}







void TriggerSpawn(int desiredClass, float[3] pos)
{
	int kick = KickDeadInfectedBots();
	if (kick <= 0) // spawn immediately without delay
    {
   		CreateInfectedWithParams(desiredClass, pos);
	}
	else
	{ // spawn on short delay
		DataPack data = CreateDataPack();
		data.WriteCell(view_as<int>(desiredClass));
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		CreateTimer(0.01, Timer_CreateInfected, data);
	}	
}

Action Timer_CreateInfected(Handle timer, DataPack data)
{
	data.Reset();
	int desiredClass = data.ReadCell(); 
	float pos0 = data.ReadFloat();
	float pos1 = data.ReadFloat();
	float pos2 = data.ReadFloat();
	if (data != null)
	{ CloseHandle(data); }
	float pos[3];pos[0]=pos0;pos[1]=pos1;pos[2]=pos2;
	CreateInfectedWithParams(desiredClass, pos);
	
	return Plugin_Stop;
}

void CreateInfectedWithParams(int desiredClass, float[3] pos)
{
	int spawnedClient = -1;
	switch (desiredClass)
	{
		case (L4D2Infected_Smoker):
		{
			spawnedClient = CreateInfected("smoker", pos);
		}
		case (L4D2Infected_Boomer):
		{
			spawnedClient = CreateInfected("boomer", pos);
		}
		case (L4D2Infected_Hunter):
		{
			spawnedClient = CreateInfected("hunter", pos);
		}
		case (L4D2Infected_Spitter):
		{
			spawnedClient = CreateInfected("spitter", pos);
		}
		case (L4D2Infected_Jockey):
		{
			spawnedClient = CreateInfected("jockey", pos);
		}
		case (L4D2Infected_Charger):
		{
			spawnedClient = CreateInfected("charger", pos);
		}
		case (L4D2Infected_Witch):
		{
			spawnedClient = CreateInfected("witch", pos);
		}
		case (L4D2Infected_Tank):
		{
			spawnedClient = CreateInfected("tank", pos);
		}
		default:
		{
			LogError("Spawn function was passed invalid class number %d", view_as<int>(desiredClass));
		}		
	}
	if (!IsValidEntity(spawnedClient))
	{
		LogError("[ DirectInfectedSpawn ] - Failed to spawn SI class %d at position [%f, %f, %f]", view_as<int>(desiredClass), pos[0], pos[1], pos[2]);
	}
}

int CreateInfected(const char[] zomb, float[3] pos)
{
	int bot = -1;
	
	if (StrEqual(zomb, "witch", false) || StrEqual(zomb, "witch_bride", false))
	{
		int witch = CreateEntityByName("witch");
		TeleportEntity(witch, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(witch);
		ActivateEntity(witch);
		if (StrEqual(zomb, "witch_bride", false))
		{
			SetEntityModel(witch, MODEL_WITCHBRIDE);
			DispatchKeyValue(witch, "targetname", BRIDE_WITCH_TARGETNAME);
		}
		return witch;
	}
	else if (StrEqual(zomb, "smoker", false))
	{
		bot = SDKCall(hCreateSmoker, "Smoker");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_SMOKER);
	}
	else if (StrEqual(zomb, "boomer", false))
	{
		bot = SDKCall(hCreateBoomer, "Boomer");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_BOOMER);
	}
	else if (StrEqual(zomb, "hunter", false))
	{
		bot = SDKCall(hCreateHunter, "Hunter");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_HUNTER);
	}
	else if (StrEqual(zomb, "spitter", false))
	{
		bot = SDKCall(hCreateSpitter, "Spitter");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_SPITTER);
	}
	else if (StrEqual(zomb, "jockey", false))
	{
		bot = SDKCall(hCreateJockey, "Jockey");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_JOCKEY);
	}
	else if (StrEqual(zomb, "charger", false))
	{
		bot = SDKCall(hCreateCharger, "Charger");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_CHARGER);
	}
	else if (StrEqual(zomb, "tank", false))
	{
		bot = SDKCall(hCreateTank, "Tank");
		if (IsValidClient2(bot)) SetEntityModel(bot, MODEL_TANK);
	}
	else
	{
		int infected = CreateEntityByName("infected");
		TeleportEntity(infected, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchSpawn(infected);
		ActivateEntity(infected);
		if (hInfectedAttackSurvivorTeam != null && StrContains(zomb, "chase", false) > -1)
		{ CreateTimer(0.4, Timer_Chase, infected); }
		return infected;
	}
	
	if (IsValidClient2(bot))
	{
		ChangeClientTeam(bot, 3);
		//SDKCall(hRoundRespawn, bot);
		SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(bot, Prop_Send, "movetype", 2);
		SetEntProp(bot, Prop_Send, "deadflag", 0);
		SetEntProp(bot, Prop_Send, "m_lifeState", 0);
		//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
		SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(bot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(bot);
		ActivateEntity(bot);
		
		DataPack data = CreateDataPack();
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		data.WriteCell(bot);
		RequestFrame(RequestFrame_SetPos, data);
	}
	
	return bot;
}

Action Timer_Chase(Handle timer, int infected)
{
	if (!IsValidEntity(infected)) return Plugin_Stop;
	char class[64];
	GetEntityClassname(infected, class, sizeof(class));
	if (!StrEqual(class, "infected", false)) return Plugin_Stop;
	
	SDKCall(hInfectedAttackSurvivorTeam, infected);
	
	return Plugin_Stop;
}

void RequestFrame_SetPos(DataPack data)
{
	data.Reset();
	float pos0 = data.ReadFloat();
	float pos1 = data.ReadFloat();
	float pos2 = data.ReadFloat();
	int bot = data.ReadCell();
	if (data != null)
	{ CloseHandle(data); }
	
	float pos[3];pos[0]=pos0;pos[1]=pos1;pos[2]=pos2;
	
	TeleportEntity(bot, pos, NULL_VECTOR, NULL_VECTOR);
}

int KickDeadInfectedBots()
{
	int kicked_Bots = 0;
	for (int loopclient = 1; loopclient <= MaxClients; loopclient++)
	{
		if (!IsValidClient2(loopclient)) continue;
		if (!IsInfected(loopclient) || !IsFakeClient(loopclient) || IsPlayerAlive(loopclient)) continue;
		KickClient(loopclient);
		kicked_Bots += 1;
	}
	if (kicked_Bots > 0)
	{ PrintToServer("Kicked %i bots.", kicked_Bots); }
	return kicked_Bots;
}

void GetGamedata()
{
	Handle hConf = null;
	hConf = LoadGameConfigFile(GAMEDATA); // For some reason this doesn't return null even for invalid files, so check they exist first.
	if (hConf == null)
	{ SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }
	
	Address replaceWithBot = GameConfGetAddress(hConf, ADDRESS_NAME);
	if (replaceWithBot == Address_Null || LoadFromAddress(replaceWithBot, NumberType_Int8) != 0x68)
	{ SetFailState("Cannot initialize NextBotCreatePlayerBot.jumptable SDKCall, address lookup failed."); return; }
	
	StringMap hInfectedFuncs = new StringMap();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.
	
	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++)
	{
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = replaceWithBot + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		hInfectedFuncs.SetValue(siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }
	
	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
	
	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
	
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam);
	hInfectedAttackSurvivorTeam = EndPrepSDKCall();
	if (hInfectedAttackSurvivorTeam == null)
	{ PrintToServer("WARNING: Cannot initialize %s SDKCall, signature is broken. Chase infected spawn is disabled.", NAME_InfectedAttackSurvivorTeam); }
	
	delete hConf;
}

Handle PrepCreateBotCallFromAddress(StringMap hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!hSiFuncTrie.GetValue(siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();	
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength)
{
	int i = 0;
	while(i < maxlength)
	{
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0)
		{
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

bool IsValidClient2(int client, bool replaycheck = true)
{
	if (client <= 0 || client > MaxClients) return false;
	if (!IsClientInGame(client)) return false;
	//if (GetEntProp(client, Prop_Send, "m_bIsCoaching")) return false;
	if (replaycheck)
	{
		if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	}
	return true;
}

/*bool RealValidEntity(int entity)
{ return (entity > 0 && IsValidEntity(entity)); }*/