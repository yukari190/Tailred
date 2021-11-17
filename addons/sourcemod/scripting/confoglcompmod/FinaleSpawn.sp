#define STATE_SPAWNREADY 0
#define STATE_TOOCLOSE 256
#define SPAWN_RANGE 150

ConVar
	FS_hEnabled;

bool
	FS_bIsFinale,
	FS_bEnabled = true;

public void FS_OnModuleStart()
{
	FS_hEnabled = CreateConVarEx("reduce_finalespawnrange", "1", "Adjust the spawn range on finales for infected, to normal spawning range");
	FS_hEnabled.AddChangeHook(FS_ConVarChange);
	FS_bEnabled = FS_hEnabled.BoolValue;
	
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
}

public void FS_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	FS_bEnabled = FS_hEnabled.BoolValue;
}

public void FS_RoundStart()
{
	FS_bIsFinale = false;
}

public void FS_FinaleStart()
{
	FS_bIsFinale = true;
}

public Action PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");
	if (!IsValidClient(client)) return;
	
	if (team == 3)
	{
		SDKHook(client, SDKHook_PreThinkPost, HookCallback);
	}
	else if (oldteam == 3)
	{
		SDKUnhook(client, SDKHook_PreThinkPost, HookCallback);
	}
}

public void HookCallback(int client)
{
	if (!FS_bEnabled) return;
	if (!FS_bIsFinale) return;
	if (GetClientTeam(client) != TEAM_INFECTED) return;
	if (GetEntProp(client,Prop_Send,"m_isGhost") != 1) return;
	
	if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") == STATE_TOOCLOSE)
	{
		if (!TooClose(client))
		{
			SetEntProp(client, Prop_Send, "m_ghostSpawnState", STATE_SPAWNREADY);
		}
	}
}

bool TooClose(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 0; i < 4; i++)
	{
		int index = GetSurvivorIndex(i);
		if (index == 0) continue;
		if (!IsPlayerAlive(index)) continue;
		GetClientAbsOrigin(index, fSurvLocation);
		
		MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		
		if (GetVectorLength(fVector) <= SPAWN_RANGE) return true;
	}
	return false;
}