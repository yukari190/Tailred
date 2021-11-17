#define MAX_TANKS		5
#define MAX_WITCHES	5

ConVar
	BS_hEnabled;

bool
	BS_bEnabled = true,
	BS_bIsFirstRound = true,
	BS_bDeleteWitches = false,
	BS_bFinaleStarted = false,
	BS_bExpectTankSpawn = false;

int
	BS_iTankCount[2],
	BS_iWitchCount[2];

float
	BS_fTankSpawn[MAX_TANKS][3],
	BS_fWitchSpawn[MAX_WITCHES][2][3];

char
	BS_sMap[64];

public void BS_OnModuleStart()
{
	BS_hEnabled = CreateConVarEx("lock_boss_spawns", "1", "Enables forcing same coordinates for tank and witch spawns");
	BS_hEnabled.AddChangeHook(BS_ConVarChange);
	
	BS_bEnabled = BS_hEnabled.BoolValue;
	
	HookEvent("witch_spawn", BS_WitchSpawn);
}

public void BS_OnMapStart()
{
	BS_bIsFirstRound = true;
	BS_bFinaleStarted = false;
	BS_bExpectTankSpawn = false;
	BS_iTankCount[0] = 0;
	BS_iTankCount[1] = 0;
	BS_iWitchCount[0] = 0;
	BS_iWitchCount[1] = 0;
	
	GetCurrentMap(BS_sMap, sizeof(BS_sMap));
}

public void BS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	BS_bEnabled = BS_hEnabled.BoolValue;
}

public void BS_WitchSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!BS_bEnabled) return;
	
	int iWitch = event.GetInt("witchid");
	
	if (BS_bDeleteWitches)
	{
		KillEntity(iWitch);
		return;
	}
	
	if (BS_iWitchCount[!BS_bIsFirstRound] >= MAX_WITCHES) return;
	
	if (BS_bIsFirstRound)
	{
		GetEntPropVector(iWitch, Prop_Send, "m_vecOrigin", BS_fWitchSpawn[BS_iWitchCount[0]][0]);
		GetEntPropVector(iWitch, Prop_Send, "m_angRotation", BS_fWitchSpawn[BS_iWitchCount[0]][1]);
		BS_iWitchCount[0]++;
	}
	else if (BS_iWitchCount[0] > BS_iWitchCount[1])
	{
		TeleportEntity(iWitch, BS_fWitchSpawn[BS_iWitchCount[1]][0], BS_fWitchSpawn[BS_iWitchCount[1]][1], NULL_VECTOR);
		BS_iWitchCount[1]++;
	}
}

Action BS_OnTankSpawn_Forward()
{
	if(BS_bEnabled)
		BS_bExpectTankSpawn = true;
	return Plugin_Continue;
}

public void BS_TankSpawn(Event event)
{
	if (!BS_bEnabled) return;
	
	if (BS_bFinaleStarted) return;
	
	if(!BS_bExpectTankSpawn) return;
	BS_bExpectTankSpawn = false;
	
	if(StrEqual(BS_sMap, "c5m5_bridge")) return; 
	
	int iTankClient = GetClientOfUserId(event.GetInt("userid"));
	
	if (L4D2_GetMapValueInt("tank_z_fix")) FixZDistance(iTankClient); // fix stuck tank spawns, ex c1m1
	
	if (BS_iTankCount[!BS_bIsFirstRound] >= MAX_TANKS) return;
	
	if (BS_bIsFirstRound)
	{
		GetClientAbsOrigin(iTankClient, BS_fTankSpawn[BS_iTankCount[0]]);
		BS_iTankCount[0]++;
	}
	else if (BS_iTankCount[0] > BS_iTankCount[1])
	{
		TeleportEntity(iTankClient, BS_fTankSpawn[BS_iTankCount[1]], NULL_VECTOR, NULL_VECTOR);
		BS_iTankCount[1]++;
	}
}

public void BS_RoundEnd()
{
	BS_bIsFirstRound = false;
	BS_bFinaleStarted = false;
	if(StrEqual(BS_sMap, "c6m1_riverbank")) {
		BS_bDeleteWitches = false;
	} else {
		BS_bDeleteWitches = true;
		CreateTimer(5.0, BS_WitchTimerReset);
	}
}

public void BS_FinaleStart()
{
	BS_bFinaleStarted = true;
}

public Action BS_WitchTimerReset(Handle timer)
{
	BS_bDeleteWitches = false;
	
	return Plugin_Stop;
}

void FixZDistance(int iTankClient)
{
	float TankLocation[3], TempSurvivorLocation[3];
	
	GetClientAbsOrigin(iTankClient, TankLocation);
	float distance = L4D2_GetMapValueFloat("max_tank_z", 99999999999999.9);
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = GetSurvivorIndex(i);
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
