int iSurvivorIndex[NUM_OF_SURVIVORS] = 0;

void SI_OnModuleStart()
{
	HookEvent("round_start"			, SI_BuildIndex_Event);
	HookEvent("round_end"			, SI_BuildIndex_Event);
	HookEvent("player_spawn"		, SI_BuildIndex_Event);
	HookEvent("player_disconnect"	, SI_BuildIndex_Event);
	HookEvent("player_death"		, SI_BuildIndex_Event);
	HookEvent("player_bot_replace"	, SI_BuildIndex_Event);
	HookEvent("bot_player_replace"	, SI_BuildIndex_Event);
	HookEvent("defibrillator_used"	, SI_BuildIndex_Event);
	HookEvent("player_team"			, SI_BuildIndexDelay_Event);
}

void SI_BuildIndex()
{
	if (!IsServerProcessing()){return;}
	
	int ifoundsurvivors = 0;
	int charz;
	
	// Make sure kicked survivors don't freak us out.
	for(int i = 0; i < NUM_OF_SURVIVORS;i++)
		iSurvivorIndex[i]=0;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (ifoundsurvivors == NUM_OF_SURVIVORS)
		{
			break;
		}
		
		if (!IsClientInGame(client) || GetClientTeam(client) != 2)
		{
			continue;
		}
		
		charz = GetEntProp(client,Prop_Send,"m_survivorCharacter");
		ifoundsurvivors++;
		
		if (charz > 3 || charz < 0)
		{
			continue;
		}
		
		iSurvivorIndex[charz] = 0;
		
		if (!IsPlayerAlive(client))
		{
			continue;
		}
		
		iSurvivorIndex[charz] = client;
	}
}

public void SI_BuildIndexDelay_Event(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.3, SI_BuildIndex_Timer);
}

public Action SI_BuildIndex_Timer(Handle timer)
{
	SI_BuildIndex();
	
	return Plugin_Stop;
}

public void SI_BuildIndex_Event(Event event, const char[] name, bool dontBroadcast)
{
	SI_BuildIndex();
}

int GetSurvivorIndex(int index)
{
	if (index < 0 || index > 3)
	{
		return 0;
	}
	
	return iSurvivorIndex[index];
}

bool IsAnySurvivorsAlive()
{
	for(int index = 0;index < NUM_OF_SURVIVORS; index++)
	{
		if (iSurvivorIndex[index]) return true;
	}
	return false;
}