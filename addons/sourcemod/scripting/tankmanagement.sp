#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <colors>

#define MAX_TANKS		2

const NUM_OF_SURVIVORS = 4;

int iTankCount = 0, BS_iTankCount[2], g_iQueuedThrow[MAXPLAYERS + 1];
float BS_fTankSpawn[MAX_TANKS][3];
char g_sMap[64], queuedTankSteamId[64];
bool g_bFinaleVehicleIncoming, BS_bFinaleStarted;
ArrayList h_whosHadTank, hTankProps, hTankPropsHit;

public Plugin myinfo = 
{
	name = "Tank Management Merge",
	author = "Mr. Zero, Jacob, Visor, CanadaRox, arti, Stabby, vintik",
	description = "",
	version = "1.0",
	url = ""
};

public void OnPluginStart()
{
	h_whosHadTank = new ArrayList(64);
	hTankProps = new ArrayList();
	hTankPropsHit = new ArrayList();
	
	RegConsoleCmd("sm_tank", Tank_Cmd, "Shows who is becoming the tank.");
	
	SetConVarBool(FindConVar("sv_tankpropfade"), false);
	
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_incoming", Event_FinaleVehicleIncoming, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	ResetConVar(FindConVar("sv_tankpropfade"));
	CloseHandle(hTankProps);
	CloseHandle(hTankPropsHit);
	CloseHandle(h_whosHadTank);
}

public void OnMapStart()
{
	PrecacheSound("ui/pickup_secret01.wav");
	BS_iTankCount[0] = 0;
	BS_iTankCount[1] = 0;
	GetCurrentMap(g_sMap, sizeof(g_sMap));
}

public void OnClientDisconnect(int client) 
{
    char tmpSteamId[64];
    if (client)
    {
        GetClientAuthId(client, AuthId_Steam3, tmpSteamId, sizeof(tmpSteamId));
        if (strcmp(queuedTankSteamId, tmpSteamId) == 0)
        {
            chooseTank();
            outputTankToAll();
        }
    }
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    chooseTank();
    outputTankToAll();
    return Plugin_Continue;
}

public void L4D2_OnRealRoundStart()
{
	iTankCount = 0;
	BS_bFinaleStarted = false;
	g_bFinaleVehicleIncoming = false;
	queuedTankSteamId = "";
	UnhookTankProps();
	ClearArray(hTankPropsHit);
	CreateTimer(10.0, newGame);
}

public Action newGame(Handle timer)
{
    int teamAScore = L4D2Direct_GetVSCampaignScore(0);
    int teamBScore = L4D2Direct_GetVSCampaignScore(1);
    if (teamAScore == 0 && teamBScore == 0) ClearArray(h_whosHadTank);
}

public void L4D2_OnRealRoundEnd()
{
	UnhookTankProps();
	ClearArray(hTankPropsHit);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
    char tmpSteamId[64];
    if (IsValidInGame(client) && oldteam == TEAM_INFECTED)
    {
        GetClientAuthId(client, AuthId_Steam3, tmpSteamId, sizeof(tmpSteamId));
        if (strcmp(queuedTankSteamId, tmpSteamId) == 0)
        {
            chooseTank();
            outputTankToAll();
        }
    }
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	if (!IsValidInGame(tankClient)) return;
	iTankCount++;
	EmitSoundToAll("ui/pickup_secret01.wav");
	CPrintToChatAll("{R}[{G}!{R}] {G}Tank{W} 已产生!");
	
	UnhookTankProps();
	ClearArray(hTankPropsHit);
       
	for (int i = 1; i <= GetMaxEntities(); i++)
	{
		if (IsTankProp(i))
		{
			SDKHook(i, SDKHook_OnTakeDamagePost, PropDamaged);
			PushArrayCell(hTankProps, i);
		}
	}
	
	if (!BS_bFinaleStarted && !StrEqual(g_sMap, "c5m5_bridge", false))
	{
		if (L4D2_GetMapValueInt("tank_z_fix")) FixZDistance(tankClient); // fix stuck tank spawns, ex c1m1
		if (BS_iTankCount[(!InSecondHalfOfRound() ? 0 : 1)] < MAX_TANKS)
		{
			if (!InSecondHalfOfRound())
			{
				GetClientAbsOrigin(tankClient, BS_fTankSpawn[BS_iTankCount[0]]);
				BS_iTankCount[0]++;
			}
			else if (BS_iTankCount[0] > BS_iTankCount[1])
			{
				TeleportEntity(tankClient, BS_fTankSpawn[BS_iTankCount[1]], NULL_VECTOR, NULL_VECTOR);
				BS_iTankCount[1]++;
			}
		}
	}
}

public void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
	if (IsValidInGame(newTank) && !IsFakeClient(newTank))
	{
		bool hidemessage = false;
		char buffer[3];
		if (GetClientInfo(newTank, "rs_hidemessage", buffer, sizeof(buffer))) hidemessage = view_as<bool>(StringToInt(buffer));
		if (!hidemessage)
		{
			CPrintToChat(newTank, "{B}[{W}Tank 岩石选择器{B}]");
			CPrintToChat(newTank, "{G}Reload {W}= {B}双手举过头顶");
			CPrintToChat(newTank, "{G}Use {W}= {B}低抛");
			CPrintToChat(newTank, "{G}M2 {W}= {B}单手举过头顶");
		}
	}
}

public void PropDamaged(int victim, int attacker, int inflictor, float damage, int damageType)
{
    if ((IsValidInfected(attacker) && GetInfectedClass(attacker) == ZC_TANK) || FindValueInArray(hTankPropsHit, inflictor) != -1)
	{
        if (FindValueInArray(hTankPropsHit, victim) == -1) PushArrayCell(hTankPropsHit, victim);
    }
}

//tank_limit
public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	BS_bFinaleStarted = true;
}

public void L4D2_OnTankDeath(int tankClient)
{
	int tankId = GetClientUserId(tankClient);
	if (tankId && IsValidInGame(tankClient))  chooseTank();
	
	if (FindTank() == -1)
	{
		UnhookTankProps();
		CreateTimer(4.5, FadeTankProps);
	}
}

public Action FadeTankProps(Handle timer)
{
    for (int i = 0; i < GetArraySize(hTankPropsHit); i++)
	{
        if (IsValidEdict(GetArrayCell(hTankPropsHit, i))) AcceptEntityInput(GetArrayCell(hTankPropsHit, i), "kill");
    }
    ClearArray(hTankPropsHit);
}

public Action Event_FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
	g_bFinaleVehicleIncoming = true;
}


// ////////////////////////////////////////////////////////
// Command
// ////////////////////////////////////////////////////////
public Action Tank_Cmd(int client, int args)
{
    int tankClientId;
    char tankClientName[128];
    
    if (! strcmp(queuedTankSteamId, "")) return Plugin_Handled;
    
    tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        if (GetClientTeam(client) == TEAM_INFECTED)
        {
            for (int i = 1; i <= MaxClients; i++)
            {
                if (IsClientConnected(i) && IsClientInGame(i) && ! IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED) CPrintToChat(i, "{O}%s {W}将成为 tank!", tankClientName);
            }
        }
        else CPrintToChat(client, "{O}%s {W}将成为 tank!", tankClientName);
    }
    return Plugin_Handled;
}

// ////////////////////////////////////////////////////////
// Private functions
// ////////////////////////////////////////////////////////

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) != 3
	|| GetEntProp(client, Prop_Send, "m_zombieClass") != 8) return Plugin_Continue;
	
	if (buttons & IN_RELOAD)
	{
		g_iQueuedThrow[client] = 3; //two hand overhand
		buttons |= IN_ATTACK2;
	}
	else if (buttons & IN_USE)
	{
		g_iQueuedThrow[client] = 2; //underhand
		buttons |= IN_ATTACK2;
	}
	else
	{
		g_iQueuedThrow[client] = 1; //one hand overhand
	}
	return Plugin_Continue;
}

//l4dt_forwards
public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if ((iTankCount >= (L4D_IsMissionFinalMap() ? 2 : 1) || g_bFinaleVehicleIncoming)) return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	enterStasis=false;
	if (g_bFinaleVehicleIncoming) return Plugin_Handled;
	if (!IsFakeClient(tank_index)) 
	{
		PrintHintText(tank_index, "开始第二次控制权");
		for (int i = 1; i <= MaxClients; i++) 
		{
			if (!IsConnectedAndInGame(i) || !IsInfected(i)) continue;
			CPrintToChat(i, "[Tank Control] {O}(%N) {G}开始第二次控制权!", tank_index);
		}
		SetTankFrustration(tank_index, 100);
		L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
		return Plugin_Handled;
	}
	if (!strcmp(queuedTankSteamId, "")) chooseTank();
	if (strcmp(queuedTankSteamId, "") != 0)
	{
		setTankTickets(queuedTankSteamId, 20000);
		PushArrayString(h_whosHadTank, queuedTankSteamId);
	}
	return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	
	if (sequence > 48 && g_iQueuedThrow[client])
	{
		sequence = g_iQueuedThrow[client] + 48;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public void chooseTank()
{
    ArrayList infectedPool = teamSteamIds(TEAM_INFECTED);
    if (GetArraySize(infectedPool) == 0) return;
    infectedPool = removeTanksFromPool(infectedPool, h_whosHadTank);
    if (GetArraySize(infectedPool) == 0)
    {
        Handle infectedTeam = teamSteamIds(TEAM_INFECTED);
        if (GetArraySize(infectedTeam) > 1)
        {
            h_whosHadTank = removeTanksFromPool(h_whosHadTank, teamSteamIds(TEAM_INFECTED));
            chooseTank();
        }
        else queuedTankSteamId = "";
        return;
    }
    int rndIndex = GetRandomInt(0, GetArraySize(infectedPool) - 1);
    GetArrayString(infectedPool, rndIndex, queuedTankSteamId, sizeof(queuedTankSteamId));
}

public void setTankTickets(const char[] steamId, const int tickets)
{
    int tankClientId = getInfectedPlayerBySteamId(steamId);
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
        {
            L4D2Direct_SetTankTickets(i, (i == tankClientId) ? tickets : 0);
        }
    }
}

public void outputTankToAll()
{
    char tankClientName[128];
    int tankClientId = getInfectedPlayerBySteamId(queuedTankSteamId);
    if (tankClientId != -1)
    {
        GetClientName(tankClientId, tankClientName, sizeof(tankClientName));
        CPrintToChatAll("{O}%s {W}将成为 tank!", tankClientName);
    }
}

public ArrayList teamSteamIds(int team)
{
    ArrayList steamIds = new ArrayList(64);
    char steamId[64];
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
        {
            if (GetClientTeam(i) != team) continue;
            GetClientAuthId(i, AuthId_Steam3, steamId, sizeof(steamId));
            PushArrayString(steamIds, steamId);
        }
    }
    return steamIds;
}

public ArrayList removeTanksFromPool(ArrayList steamIdTankPool, Handle tanks)
{
    int index;
    char steamId[64];
    for (int i = 0; i < GetArraySize(tanks); i++)
    {
        GetArrayString(tanks, i, steamId, sizeof(steamId));
        index = FindStringInArray(steamIdTankPool, steamId);
        if (index != -1) RemoveFromArray(steamIdTankPool, index);
    }
    return steamIdTankPool;
}

public int getInfectedPlayerBySteamId(const char[] steamId) 
{
    char tmpSteamId[64];
    for (int i = 1; i <= MaxClients; i++) 
    {
        if (!IsClientConnected(i) || GetClientTeam(i) != TEAM_INFECTED) continue;
        GetClientAuthId(i, AuthId_Steam3, tmpSteamId, sizeof(tmpSteamId));     
        if (StrEqual(steamId, tmpSteamId)) return i;
    }
    return -1;
}

stock void FixZDistance(int client)
{
	float TankLocation[3], TempSurvivorLocation[3];
	int index;
	GetClientAbsOrigin(client, TankLocation);
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		float distance = L4D2_GetMapValueFloat("max_tank_z", 99999999999999.9);
		index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
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
				TeleportEntity(client, WarpToLocation, NULL_VECTOR, NULL_VECTOR);
			}
		}
	}
}

stock bool IsTankProp(int iEntity)
{
    if (!IsValidEdict(iEntity)) return false;
    char className[64];
    GetEdictClassname(iEntity, className, sizeof(className));
    if (StrEqual(className, "prop_physics", false))
	{
        if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) return true;
    }
    else if (StrEqual(className, "prop_car_alarm", false)) return true;
    return false;
}

stock void UnhookTankProps()
{
    for (int i = 0; i < GetArraySize(hTankProps); i++) SDKUnhook(GetArrayCell(hTankProps, i), SDKHook_OnTakeDamagePost, PropDamaged);
    ClearArray(hTankProps);
}
