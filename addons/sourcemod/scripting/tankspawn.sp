#pragma semicolon 1
//#pragma newdecls required

#include <sourcemod>
#include <dhooks>

#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

#define PLUGIN_VERSION "1.3b"

Handle g_hDetour;

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor, Forgetest, xoxo",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

static Handle:hTankClients;

static Handle:hFwdOnTankSpawn;
static Handle:hFwdOnTankPass;
static Handle:hFwdOnTankDeath;

new Handle:hTankDeathTimer[MAXPLAYERS+1];

static bool:bIsTankActive;

public APLRes:AskPluginLoad2(Handle:hPlugin, bool:bLateLoad, String:sError[], iErrMax) {
    hFwdOnTankSpawn = CreateGlobalForward("OnTankSpawn", ET_Ignore, Param_Cell);
    hFwdOnTankPass = CreateGlobalForward("OnTankPass", ET_Ignore, Param_Cell, Param_Cell);
    hFwdOnTankDeath = CreateGlobalForward("OnTankDeath", ET_Ignore, Param_Cell);


    return APLRes_Success;
}

public void OnPluginStart()
{
	Handle hGameData = LoadGameConfigFile(LEFT4FRAMEWORK_GAMEDATA);
	if (hGameData == null) {
		SetFailState("Missing gamedata \"%s\".", LEFT4FRAMEWORK_GAMEDATA);
	}
	
	g_hDetour = DHookCreateFromConf(hGameData, "SpawnTank");
	if (g_hDetour == null) {
		SetFailState("Failed to create detour \"SpawnTank\" from gamedata.");
	}
	
	if (!DHookEnableDetour(g_hDetour, true, OnSpawnTank)) {
		SetFailState("Failed to enable detour \"SpawnTank\".");
	}

	delete hGameData;
	
	hTankClients = CreateArray();
	
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath_Event);
}

public void OnPluginEnd()
{
	if (!DHookDisableDetour(g_hDetour, true, OnSpawnTank))
		SetFailState("Failed to disable detour \"SpawnTank\".");
}

public Action:RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	bIsTankActive = false;  
    ClearArray(hTankClients);
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (hTankDeathTimer[i] != INVALID_HANDLE)
		{
			KillTimer(hTankDeathTimer[i]);
			hTankDeathTimer[i] = INVALID_HANDLE;
		}
	}
}

public MRESReturn OnSpawnTank(Handle hReturn, Handle hParams)
{
	bool ret = DHookGetReturn(hReturn) != 0; // left4dhooks sets it 0 to disable tank spawns
	
	if (ret == true) {
		RequestFrame(OnNextFrame, 0);	// seems it occurs often that prints with wrong teamcolors
									// make a slight delay here to try fixing this
	}
	return MRES_Ignored;
}

public void OnNextFrame(any data)
{
	int iNumTanks = NumTanksInPlay();
	
    if (GetArraySize(hTankClients) < iNumTanks)
	{
		int tankClient = FindAliveTankClient();
		if (tankClient > 0)
		{
			bIsTankActive = true;
			AddTankToArray(tankClient);
			Call_StartForward(hFwdOnTankSpawn);
			Call_PushCell(tankClient);
			Call_Finish();
			
			PrintToChatAll("[TankSpawn] Tank(控制者: %N) 产生!", tankClient);
		}
    }
}

public Action:ItemPickup_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	Tanks_ItemPickup(event);
}

Tanks_ItemPickup(Handle:event)
{
	if (!bIsTankActive) return;
	
	decl String:item[64];
	GetEventString(event, "item", item, sizeof(item));
	
	if (StrEqual(item, "tank_claw"))
	{
		int iPrevTank = FindOldTankClient();
		if (iPrevTank <= 0) return;
		
		if (hTankDeathTimer[iPrevTank] != INVALID_HANDLE)
		{
			KillTimer(hTankDeathTimer[iPrevTank]);
			hTankDeathTimer[iPrevTank] = INVALID_HANDLE;
		}
		int iTankClient = GetClientOfUserId(GetEventInt(event, "userid"));
		
		RemoveTankFromArray(iPrevTank);
		if (iTankClient > 0 && !FindTankInArray(iTankClient)) AddTankToArray(iTankClient);
		
		Call_StartForward(hFwdOnTankPass);
		Call_PushCell(iPrevTank);
		Call_PushCell(iTankClient);
		Call_Finish();
		
		PrintToChatAll("[TankSpawn] Tank(旧控制者: %N | 新控制者: %N) 控制转换!", iPrevTank, iTankClient);
		
	}
}

public Action:PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	Tanks_PlayerDeath(event);
}

Tanks_PlayerDeath(Handle:event)
{
	if (!bIsTankActive) return;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	if (!FindTankInArray(client)) return;
	
	hTankDeathTimer[client] = CreateTimer(0.5, TankDeath_Timer, client);
}

public Action:TankDeath_Timer(Handle:timer, any iTankClient)
{
	RemoveTankFromArray(iTankClient);
	Call_StartForward(hFwdOnTankDeath);
	Call_PushCell(iTankClient);
	Call_Finish();
    
	if (hTankDeathTimer[iTankClient] != INVALID_HANDLE)
	{
		KillTimer(hTankDeathTimer[iTankClient]);
		hTankDeathTimer[iTankClient] = INVALID_HANDLE;
	}
	
	if (!NumTanksInPlay()) bIsTankActive = false;
	
	PrintToChatAll("[TankSpawn] Tank(控制者: %N) 死亡!", iTankClient);
}



void AddTankToArray(int client)
{
    PushArrayCell(hTankClients, client);
}

void RemoveTankFromArray(client) {
    for (new i = 0; i < GetArraySize(hTankClients); ++i) {
        if (GetArrayCell(hTankClients, i) == client) {
            RemoveFromArray(hTankClients, i);
        }
    }
}

bool FindTankInArray(client)
{
    for (new i = 0; i < GetArraySize(hTankClients); ++i) {
        if (GetArrayCell(hTankClients, i) == client) {
            return true;
        }       
    }
    
    return false;
}

int FindOldTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (FindTankInArray(i))
		{
			if (!IsTank(i) || !IsPlayerAlive(i))
			{
				return i;
			}
		}
	}

	return -1;
}

int NumTanksInPlay()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i)) {
			count++;
		}
	}
	
	return count;
}

int FindAliveTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i) && IsPlayerAlive(i))
		{
			if (!FindTankInArray(i))
			{
				return i;
			}
		}
	}

	return -1;
}

int FindTankClient(int iTankClient)
{
	int i = (iTankClient < 0) ? 1 : iTankClient + 1;
	
	for (; i <= MaxClients; i++) {
		if (IsTank(i)) {
			return i;
		}
	}

	return -1;
}

bool IsTank(int client)
{
	return (IsClientInGame(client)
		&& GetClientTeam(client) == 3
		&& GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}
