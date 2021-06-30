#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]DirectInfectedSpawn>
#include <[LIB]l4d2library>
#include <[LIB]navmesh>

ConVar cvSpawnProximityMin;
ConVar cvSpawnProximityMax;
ConVar cvRearSpawnMaxTrailingDistance;

int iSpawnProximityMin;
int iSpawnProximityMax;
float fRearSpawnMaxTrailingDistance;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("NavMeshSpawn", _native_NavMeshSpawn);
	return APLRes_Success;
}

public void OnPluginStart()
{
	cvSpawnProximityMin = CreateConVar( "ss_spawn_proximity_min", "500", "最接近SI的可能是生还者", _, true, 1.0 );
	cvSpawnProximityMax = CreateConVar( "ss_spawn_proximity_max", "650", "一个SI可以产卵到幸存者的最远的地方", _, true, float(cvSpawnProximityMin.IntValue) );
	cvRearSpawnMaxTrailingDistance = CreateConVar("ss2_rearspawn_max_trailing_distance", "150", "Limit set on ", _, true, 0.0);
	
	cvSpawnProximityMin.AddChangeHook(ConVarChange);
	cvSpawnProximityMax.AddChangeHook(ConVarChange);
	cvRearSpawnMaxTrailingDistance.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSpawnProximityMin = cvSpawnProximityMin.IntValue;
	iSpawnProximityMax = cvSpawnProximityMax.IntValue;
	fRearSpawnMaxTrailingDistance = cvRearSpawnMaxTrailingDistance.FloatValue;
}

public int _native_NavMeshSpawn(Handle plugin, int numParams)
{
	int SpawnQueue[MAXPLAYERS];
	GetNativeArray(1, SpawnQueue, MAXPLAYERS);
	NavMeshSpawn(SpawnQueue);
}

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
