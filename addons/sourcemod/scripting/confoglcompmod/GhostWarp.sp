ConVar
	GW_hGhostWarp;
bool
	GW_bEnabled = true;
	GW_bDelay[MAXPLAYERS+1];
int
	GW_iLastTarget[MAXPLAYERS+1] = -1;

public void GW_OnModuleStart()
{
	GW_hGhostWarp = CreateConVarEx("ghost_warp", "1", "Sets whether infected ghosts can right click for warp to next survivor");
	
	HookConVarChange(GW_hGhostWarp, GW_ConVarChange);
	RegConsoleCmd("sm_warptosurvivor", GW_Cmd_WarpToSurvivor);
	
	GW_bEnabled = GW_hGhostWarp.BoolValue;
}

public void GW_ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	GW_bEnabled = GW_hGhostWarp.BoolValue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!GW_bEnabled || !(buttons & IN_RELOAD) || GW_bDelay[client]){return Plugin_Continue;}
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED || GetEntProp(client,Prop_Send,"m_isGhost") != 1){return Plugin_Continue;}
	
	GW_bDelay[client] = true;
	CreateTimer(0.25, GW_ResetDelay, client);
	
	GW_WarpToSurvivor(client, 0);
	
	return Plugin_Handled;
}

public Action GW_ResetDelay(Handle timer, any client)
{
	GW_bDelay[client] = false;
	
	return Plugin_Stop;
}

public void GW_PlayerDeath(Event event)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	GW_iLastTarget[client] = -1;
}

public Action GW_Cmd_WarpToSurvivor(int client, int args)
{
	if (!GW_bEnabled || args != 1 || !IsClientInGame(client) || GetClientTeam(client) != TEAM_INFECTED || GetEntProp(client,Prop_Send,"m_isGhost") != 1){return Plugin_Handled;}
	
	char buffer[2];
	GetCmdArg(1, buffer, 2);
	if(strlen(buffer) == 0){return Plugin_Handled;}
	int charz = (StringToInt(buffer));
	
	GW_WarpToSurvivor(client,charz);
	
	return Plugin_Handled;
}

void GW_WarpToSurvivor(int client, int charz)
{
	int target;
	
	if(charz <= 0)
	{
		target = GW_FindNextSurvivor(client,GW_iLastTarget[client]);
	}
	else if(charz <= 4)
	{
		target = GetSurvivorIndex(charz-1);
	}
	else
	{
		return;
	}
	
	if(target == 0){return;}
	
	// Prevent people from spawning and then warp to survivor
	SetEntProp(client,Prop_Send,"m_ghostSpawnState",256);
	
	float position[3], anglestarget[3];
	
	GetClientAbsOrigin(target, position);
	GetClientAbsAngles(target, anglestarget);
	TeleportEntity(client, position, anglestarget, NULL_VECTOR);
	
	return;
}

int GW_FindNextSurvivor(int client, int charz)
{
	if (!IsAnySurvivorsAlive())
	{
		return 0;
	}
	
	int havelooped = false;
	charz++;
	if (charz >= NUM_OF_SURVIVORS)
	{
		charz = 0;
	}
	
	for(int index = charz;index<=MaxClients;index++)
	{
		if (index >= NUM_OF_SURVIVORS)
		{
			if (havelooped)
			{
				break;
			}
			havelooped = true;
			index = 0;
		}
		
		if (GetSurvivorIndex(index) == 0)
		{
			continue;
		}
		
		GW_iLastTarget[client] = index;
		return GetSurvivorIndex(index);
	}
	
	return 0;
}