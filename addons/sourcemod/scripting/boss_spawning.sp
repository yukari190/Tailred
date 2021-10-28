#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

#define MAX_TANKS		5
#define MAX_WITCHES	5

public Plugin myinfo = 
{
	name = "Boss Spawning",
	author = "Confogl Team",
	description = "A competitive mod for L4D2",
	version = "2.2.4",
	url = "http://confogl.googlecode.com/"
};

bool 
	bEnabled = true,
	bDeleteWitches = false,
	bFinaleStarted = false;

int 
	iTankCount[2],
	iWitchCount[2];

float 
	fTankSpawn[MAX_TANKS][3],
	fWitchSpawn[MAX_WITCHES][2][3];

char
	sMap[64];

public void OnPluginStart()
{
	ConVar hEnabled;
	(hEnabled = CreateConVar("lock_boss_spawns", "1", "Enables forcing same coordinates for tank and witch spawns", CVAR_FLAGS, true, 0.0, true, 1.0)).AddChangeHook(ConVarChange);
	bEnabled = hEnabled.BoolValue;
	
	HookEvent("witch_spawn", WitchSpawn);
	HookEvent("finale_start", FinaleStart, EventHookMode_PostNoCopy);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bEnabled = convar.BoolValue;
}

public void OnMapStart()
{
	bFinaleStarted = false;
	iTankCount[0] = 0;
	iTankCount[1] = 0;
	iWitchCount[0] = 0;
	iWitchCount[1] = 0;
	
	GetCurrentMap(sMap, sizeof(sMap));
}

public void L4D2_OnRealRoundEnd()
{
	bFinaleStarted = false;
	if (StrEqual(sMap, "c6m1_riverbank"))
	{
		bDeleteWitches = false;
	}
	else
	{
		bDeleteWitches = true;
		CreateTimer(5.0, WitchTimerReset);
	}
}

public Action WitchTimerReset(Handle timer)
{
	bDeleteWitches = false;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	if (!bEnabled) return;
	// Don't touch tanks on finale events
	if (bFinaleStarted) return;
	// Don't track tank spawns on c5m5 or tank can spawn behind other team.
	if (StrEqual(sMap, "c5m5_bridge")) return; 
	
	if (L4D2_GetMapValueInt("tank_z_fix")) FixZDistance(tankClient); // fix stuck tank spawns, ex c1m1
	
	// If we reach MAX_TANKS, we don't have any room to store their locations
	if (iTankCount[InSecondHalfOfRound()] >= MAX_TANKS) return;
	
	if (!InSecondHalfOfRound())
	{
		GetClientAbsOrigin(tankClient, fTankSpawn[iTankCount[0]]);
		iTankCount[0]++;
	}
	else if (iTankCount[0] > iTankCount[1])
	{
		TeleportEntity(tankClient, fTankSpawn[iTankCount[1]], NULL_VECTOR, NULL_VECTOR);
		iTankCount[1]++;
	}
}

public void WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!bEnabled) return;
	
	int iWitch = event.GetInt("witchid");
	
	if (bDeleteWitches)
	{
		// Used to delete round2 extra witches, which spawn on round start instead of by flow
		AcceptEntityInput(iWitch, "Kill");
		return;
	}
	
	// Can't track more witches if our witch array is full
	if (iWitchCount[InSecondHalfOfRound()] >= MAX_WITCHES) return;
	
	if (!InSecondHalfOfRound())
	{
		// If it's the first round, track our witch.
		GetEntPropVector(iWitch, Prop_Send, "m_vecOrigin", fWitchSpawn[iWitchCount[0]][0]);
		GetEntPropVector(iWitch, Prop_Send, "m_angRotation", fWitchSpawn[iWitchCount[0]][1]);
		iWitchCount[0]++;
	}
	else if (iWitchCount[0] > iWitchCount[1])
	{
		// Until we have found the same number of witches as from round1, teleport them to round1 locations
		TeleportEntity(iWitch, fWitchSpawn[iWitchCount[1]][0], fWitchSpawn[iWitchCount[1]][1], NULL_VECTOR);
		iWitchCount[1]++;
	}
}

public void FinaleStart(Event event, const char[] name, bool dontBroadcast)
{
	bFinaleStarted = true;
}

void FixZDistance(int iTankClient)
{
	float TankLocation[3], TempSurvivorLocation[3];
	int index;
	
	GetClientAbsOrigin(iTankClient, TankLocation);
	
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		float distance = L4D2_GetMapValueFloat("max_tank_z", 99999999999999.9);
		index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0 && IsValidEntity(index))
		{
			GetClientAbsOrigin(index, TempSurvivorLocation);
			
			if (FloatAbs(TempSurvivorLocation[2] - TankLocation[2]) > distance)
			{
				float WarpToLocation[3];
				L4D2_GetMapValueVector("tank_warpto", WarpToLocation);
				if (!GetVectorLength(WarpToLocation, true))
				{
					LogMessage("[BS] tank_warpto missing from mapinfo.txt");
					return;
				}
				TeleportEntity(iTankClient, WarpToLocation, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}
