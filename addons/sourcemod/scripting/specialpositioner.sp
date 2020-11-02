#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

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

float spawnGrid[4];
float iTankPos[3];
float iTankAng[3];

int g_iTimeLOS[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	PauseSi(tankClient, true);
	GetClientAbsOrigin(tankClient, iTankPos);
	GetClientAbsAngles(tankClient, iTankAng);
	CreateTimer(0.1, Timer_ActiveTank, tankClient, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ActiveTank(Handle timer, any client)
{
	float activePos[3];
	GetClientAbsOrigin(GetRandomSurvivor(), activePos);
	TeleportEntity(client, activePos, NULL_VECTOR, NULL_VECTOR);
	CreateTimer(0.8, Timer_ActiveTank2, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ActiveTank2(Handle timer, any client)
{
	TeleportEntity(client, iTankPos, iTankAng, NULL_VECTOR);
	PauseSi(client, false);
	CreateTimer(0.01, Timer_PositionSI, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsBotInfected(client)) return;
	g_iTimeLOS[client] = 0;
	int iClass = GetInfectedClass(client);
	if (iClass > 0 && iClass <= 6)
	{
		PauseSi(client, true);
		CreateTimer(0.01, Timer_PositionSI, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action Timer_PositionSI(Handle timer, any infectedBot)
{
	if (!IsBotInfected(infectedBot) || !IsPlayerAlive(infectedBot)) return Plugin_Stop;
	
	int iClass = GetInfectedClass(infectedBot);
	if (iClass == 8)
	{
		if (g_iTimeLOS[infectedBot] >= 200)
		{
			if (RepositionGrid(infectedBot, iClass))
			{
				PrintToChatAll("\x03%N\x01 失去目标, 传送到一个新的位置", infectedBot);
				return Plugin_Stop;
			}
			return Plugin_Continue;
		}
		if (GetEntProp(infectedBot, Prop_Send, "m_hasVisibleThreats")) g_iTimeLOS[infectedBot] = 0;
		else g_iTimeLOS[infectedBot]++;
	}
	else if (RepositionGrid(infectedBot, iClass))
	{
		PauseSi(infectedBot, false);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

bool RepositionGrid(int infectedBot, int class)
{
	float spawnPos[3];
	if (L4D_GetRandomPZSpawnPosition(GetRandomSurvivor(), class, 10, spawnPos))
	{
		TeleportEntity(infectedBot, spawnPos, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	else
	{
		UpdateSpawnGrid();
		float gridPos[3];
		gridPos[COORD_X] = GetRandomFloat(spawnGrid[X_MIN], spawnGrid[X_MAX]);
		gridPos[COORD_Y] = GetRandomFloat(spawnGrid[Y_MIN], spawnGrid[Y_MAX]);
		int closestSurvivor = GetClosestSurvivor2D(gridPos);
		float survivorPos[3];
		GetClientAbsOrigin(closestSurvivor, survivorPos);
		gridPos[COORD_Z] = survivorPos[COORD_Z] + 300.0;
		if(IsValidSurvivor(closestSurvivor) && IsPlayerAlive(closestSurvivor))
		{
			float direction[3];
			direction[PITCH] = MAX_ANGLE;
			direction[YAW] = 0.0;
			direction[ROLL] = 0.0;
			TR_TraceRay(gridPos, direction, MASK_ALL, RayType_Infinite);
			if(TR_DidHit())
			{
				float traceImpact[3];
				TR_GetEndPosition(traceImpact); 
				spawnPos = traceImpact;
				spawnPos[COORD_Z] += NAV_MESH_HEIGHT;
				if(IsOnValidMesh(spawnPos) && !IsPlayerStuck(spawnPos, infectedBot))
				{
					if(!HasSurvivorLOS(spawnPos) || GetSurvivorProximity(spawnPos) > 500)
					{
						TeleportEntity( infectedBot, spawnPos, NULL_VECTOR, NULL_VECTOR);
						return true;
					}
				}
			} 
		}
	}
	return false;
}

void UpdateSpawnGrid()
{
	spawnGrid[X_MIN] = UNINITIALISED_FLOAT, spawnGrid[Y_MIN] = UNINITIALISED_FLOAT;
	spawnGrid[X_MAX] = UNINITIALISED_FLOAT, spawnGrid[Y_MAX] = UNINITIALISED_FLOAT;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float pos[3];
			GetClientAbsOrigin(index, pos);
			spawnGrid[X_MIN] = CheckMinCoord( spawnGrid[X_MIN], pos[COORD_X] );
			spawnGrid[Y_MIN] = CheckMinCoord( spawnGrid[Y_MIN], pos[COORD_Y] );
			spawnGrid[X_MAX] = CheckMaxCoord( spawnGrid[X_MAX], pos[COORD_X] );
			spawnGrid[Y_MAX] = CheckMaxCoord( spawnGrid[Y_MAX], pos[COORD_Y] );
		}
	}
	float borderWidth = 650.0;
	spawnGrid[X_MIN] -= borderWidth;
	spawnGrid[Y_MIN] -= borderWidth;
	spawnGrid[X_MAX] += borderWidth;
	spawnGrid[Y_MAX] += borderWidth;
}

int GetClosestSurvivor2D(float gridPos[3])
{
	float proximity = UNINITIALISED_FLOAT;
	int closestSurvivor = -1;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float survivorPos[3];
			GetClientAbsOrigin(index, survivorPos);
			float survivorDistance = SquareRoot( Pow(survivorPos[COORD_X] - gridPos[COORD_X], 2.0) + Pow(survivorPos[COORD_Y] - gridPos[COORD_Y], 2.0) );
			if(survivorDistance < proximity || proximity == UNINITIALISED_FLOAT)
			{
				proximity = survivorDistance;
				closestSurvivor = index;
			}
		}
	}
	return closestSurvivor;
}

bool HasSurvivorLOS(float pos[3])
{
	bool hasLOS = false;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			float origin[3];
			GetClientAbsOrigin(index, origin);
			TR_TraceRay(pos, origin, MASK_ALL, RayType_EndPoint);
			if(!TR_DidHit())
			{
				hasLOS = true;
				break;
			}
		}	
	}
	return hasLOS;
}

float CheckMinCoord(float oldMin, float checkValue)
{
	if(checkValue < oldMin || oldMin == UNINITIALISED_FLOAT) return checkValue;
	else return oldMin;
}

float CheckMaxCoord(float oldMax, float checkValue)
{
	if(checkValue > oldMax || oldMax == UNINITIALISED_FLOAT) return checkValue;
	else return oldMax;
}

int GetSurvivorProximity(float referencePos[3], int specificSurvivor = -1)
{
	int targetSurvivor;
	float targetSurvivorPos[3];
	if(specificSurvivor > 0 && IsValidSurvivor(specificSurvivor)) targetSurvivor = specificSurvivor;
	else targetSurvivor = GetClosestSurvivor(referencePos);
	GetEntPropVector( targetSurvivor, Prop_Send, "m_vecOrigin", targetSurvivorPos );
	return RoundToNearest( GetVectorDistance(referencePos, targetSurvivorPos) );
}

int GetClosestSurvivor(float referencePos[3], int excludeSurvivor = -1)
{
	float survivorPos[3];
	int iClosestAbsDisplacement = -1; 
	int closestSurvivor = -1;		
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0 && index != excludeSurvivor)
		{
			GetClientAbsOrigin(index, survivorPos);
			int iAbsDisplacement = RoundToNearest(GetVectorDistance(referencePos, survivorPos));			
			if(iClosestAbsDisplacement < 0)
			{
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = index;
			} else if(iAbsDisplacement < iClosestAbsDisplacement)
			{
				iClosestAbsDisplacement = iAbsDisplacement;
				closestSurvivor = index;
			}			
		}
	}
	return closestSurvivor;
}

bool IsPlayerStuck(float pos[3], int client)
{
	bool isStuck = true;
	if(IsValidInGame(client))
	{
		float mins[3], maxs[3];		
		GetClientMins(client, mins);
		GetClientMaxs(client, maxs);
		for(int i = 0; i < sizeof(mins); i++)
		{
		    mins[i] -= 3;
		    maxs[i] += 3;
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

bool IsOnValidMesh(float pos[3])
{
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(pos);
	if (pNavArea != Address_Null) return true;
	else return false;
}

bool IsBotInfected(int client)
{
    if (IsValidInfected(client) && IsFakeClient(client)) return true;
    return false;
}

void PauseSi(int client, bool pause = false)
{
	if (pause)
	{
		if (IsTank(client)) SetConVarFloat(FindConVar("tank_throw_allow_range"), 99999999.0);
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	}
	else
	{
		if (IsTank(client)) ResetConVar(FindConVar("tank_throw_allow_range"));
		SetEntityMoveType(client, MOVETYPE_CUSTOM);
		SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
}

bool IsTank(int client)
{
	return (IsValidInfected(client) && GetInfectedClass(client) == ZC_TANK && IsPlayerAlive(client));
}
