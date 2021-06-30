#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#include <[LIB]l4d2library>
#include <[LIB]readyup>

public Plugin myinfo =
{
	name = "Versus Merge",
	author = "ProdigySim, Visor, CanadaRox",
	description = "",
	version = "1.0",
	url = ""
}

ArrayList hFirstRoundCars;
ArrayList hSecondRoundCars;

ConVar g_hSpitterLimit;
ConVar hSpitterLimit;

int g_iSpitterLimit;
int lastHumanTank;
int iLastTarget[MAXPLAYERS+1] = -1;

bool IsInCharge[MAXPLAYERS + 1];
bool g_bIsTankInPlay;
bool bDelay[MAXPLAYERS+1];
bool bActivated;
bool bPatched;
bool FS_bIsFinale;

public void OnPluginStart()
{
    hFirstRoundCars = new ArrayList(128);
    hSecondRoundCars = new ArrayList(128);
	
	g_hSpitterLimit = FindConVar("z_versus_spitter_limit");
	hSpitterLimit = FindConVar("z_spitter_limit");
	g_hSpitterLimit.AddChangeHook(Cvar_SpitterLimit);
	g_iSpitterLimit = g_hSpitterLimit.IntValue;
	
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
	HookEvent("tank_frustrated", OnTankFrustrated);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_bot_replace", PlayerBotReplace);
	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);
	HookEvent("finale_vehicle_leaving", FinaleEnd_Event, EventHookMode_PostNoCopy);
}

public void OnPluginEnd()
{
	ResetConVar(g_hSpitterLimit);
}

public int Cvar_SpitterLimit(Handle convar, const char[] oldValue, const char[] newValue)
{
    if (g_bIsTankInPlay) return;
    g_iSpitterLimit = StringToInt(newValue);
}

public void L4D_OnEnterGhostState(int client)
{
    SetEntityHealth(client, GetEntProp(client, Prop_Send, "m_iMaxHealth"));
}

public void OnRoundIsLive()
{
	AnnounceSIClasses();
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Continue;
	
	if (!bDelay[client] && L4D2_IsInfected(client) && IsPlayerAlive(client) && L4D2_IsInfectedGhost(client))
	{
		if (buttons & IN_RELOAD)
		{
			bDelay[client] = true;
			CreateTimer(0.25, ResetDelay, client);
			
			WarpToSurvivor(client, 0);
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action ResetDelay(Handle timer, any client)
{
    bDelay[client] = false;
}

public void OnMapStart()
{
    hFirstRoundCars.Clear();
    hSecondRoundCars.Clear();
	
	bActivated = false;
	bPatched = false;
}

public void L4D_OnRoundStart()
{
	FS_bIsFinale = false;
	g_bIsTankInPlay = false;
	if (g_iSpitterLimit > 0)
	{
		SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
		SetConVarInt(hSpitterLimit, g_iSpitterLimit);
	}
	
	CreateTimer(1.2, RoundStartDelay_Timer);
}

public Action RoundStartDelay_Timer(Handle timer)
{
	if (!L4D2_IsSecondRound() || bActivated)
	{
		int iEntity = -1;
		char sTargetName[128];
		while ((iEntity = FindEntityByClassname(iEntity, "logic_relay")) != -1)
		{
			GetEntityName(iEntity, sTargetName, sizeof(sTargetName));
			if (StrContains(sTargetName, "-relay_caralarm_off", false) == -1) continue;
			HookSingleEntityOutput(iEntity, "OnTrigger", CarAlarmLogicRelayTriggered);
		}
	}
}

public void CarAlarmLogicRelayTriggered(const char[] output, int caller, int activator, float delay)
{
    char sTargetName[128];
    GetEntityName(caller, sTargetName, sizeof(sTargetName));
    
    if (IsValidEntity(activator))
	{
        char sClassName[128];
        GetEntityClassname(activator, sClassName, sizeof(sClassName));
        if (StrEqual(sClassName, "prop_car_alarm", false)) return;
    }
        
    if (!L4D2_IsSecondRound())
	{
        bActivated = true;
        hFirstRoundCars.PushString(sTargetName);
    }
    else
	{
        hSecondRoundCars.PushString(sTargetName);
        if (!bPatched)
		{
            CreateTimer(1.0, PatchAlarmedCars);
            bPatched = true;
        }
    }
}

public Action PatchAlarmedCars(Handle timer)
{
    char sEntName[128];
    for (int i = 0; i < GetArraySize(hFirstRoundCars); i++)
	{
        hFirstRoundCars.GetString(i, sEntName, sizeof(sEntName));
        if (hSecondRoundCars.FindString(sEntName) == -1) DisableCar(sEntName);
    }
    
    for (int i = 0; i < GetArraySize(hSecondRoundCars); i++)
	{
        hSecondRoundCars.GetString(i, sEntName, sizeof(sEntName));
        if (hFirstRoundCars.FindString(sEntName) == -1) EnableCar(sEntName);
    }
}


public void L4D_OnRoundEnd()
{
	FS_bIsFinale = false;
	g_bIsTankInPlay = false;
	if (g_iSpitterLimit > 0)
	{
		SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
		SetConVarInt(hSpitterLimit, g_iSpitterLimit);
	}
}

public void L4D_OnTankSpawn(int tankClient)
{
	g_bIsTankInPlay = true;
	SetConVarInt(g_hSpitterLimit, 0);
	SetConVarInt(hSpitterLimit, 0);
}

public void L4D_OnTankDeath()
{
	g_bIsTankInPlay = false;
	if (g_iSpitterLimit > 0)
	{
		SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
		SetConVarInt(hSpitterLimit, g_iSpitterLimit);
	}
}

public Action L4D2_OnJoinInfected(int client)
{
	SDKHook(client, SDKHook_PreThinkPost, HookCallback);
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwayInfected(int client)
{
	SDKUnhook(client, SDKHook_PreThinkPost, HookCallback);
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action HookCallback(int client)
{
	if (!FS_bIsFinale || !L4D2_IsInfected(client) || !L4D2_IsInfectedGhost(client)) return;
	if (GetEntProp(client, Prop_Send, "m_ghostSpawnState") == 256)
	{
		if (!TooClose(client)) SetEntProp(client, Prop_Send, "m_ghostSpawnState", 0);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
    if (!attacker || weapon < 1 || !IsTank(victim) || IsFakeClient(victim)) return Plugin_Continue;
	if (IsMelee(weapon)) UTIL_ScreenFade(victim, 1, 150, 0, 128, 0, 0, 128);
    return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//Event
public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	FS_bIsFinale = true;
}

public Action OnTankFrustrated(Event event, const char[] name, bool dontBroadcast)
{
	int tank = GetClientOfUserId(event.GetInt("userid"));
	if (!IsFakeClient(tank))
	{
		lastHumanTank = tank;
		CreateTimer(0.1, CheckForAITank, _, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action CheckForAITank(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && L4D2_IsInfected(i) && L4D2_GetInfectedClass(i) == L4D2Infected_Tank && IsFakeClient(i))
		{
			if (L4D2_IsInfected(lastHumanTank)) ForcePlayerSuicide(lastHumanTank);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public Action PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	int botid = event.GetInt("bot");
	int bot = GetClientOfUserId(botid);
	if (L4D2_IsValidClient(bot) && L4D2_IsInfected(bot) && IsFakeClient(bot)) CreateTimer(10.0, KillBot, bot);
	
	if (IsInCharge[client])
	{
		SetEntityFlags(bot, GetEntityFlags(bot) | FL_FROZEN); //New method, by dcx2
		IsInCharge[client] = false;
	}
	
	if (L4D2_IsInfected(bot) && L4D2_GetInfectedClass(bot) == L4D2Infected_Tank)
	{
		PrintToChatAll("[AI Tank] Tank控制权丢失, 启用代打模式!");
	}
}

public Action KillBot(Handle timer, any bot)
{
    if (L4D2_IsValidClient(bot) && L4D2_IsInfected(bot) && IsFakeClient(bot) && L4D2_GetInfectedVictim(bot) != -1)
	  ForcePlayerSuicide(bot);
}

public Action Event_ChargeStart(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = true;
}

public Action Event_ChargeEnd(Event event, const char[] name, bool dontBroadcast)
{
    IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	IsInCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action Event_OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	IsInCharge[client] = false;
	iLastTarget[client] = -1;
}

public Action FinaleEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < 4; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		if (L4D2_IsPlayerIncap(index)) ForcePlayerSuicide(index);
	}
}

//Utility
void AnnounceSIClasses()
{
    int iSpawns;
    L4D2_Infected iSpawnClass[4];
    
    for (int i = 1; i <= MaxClients && iSpawns < 4; i++) {
        if (!L4D2_IsValidClient(i) || !L4D2_IsInfected(i)) continue;

        iSpawnClass[iSpawns] = L4D2_GetInfectedClass(i);
        iSpawns++;
    }

	char sBuffer[4][16];
	L4D2_GetInfectedClassName(iSpawnClass[0], sBuffer[0], 16);
	L4D2_GetInfectedClassName(iSpawnClass[1], sBuffer[1], 16);
	L4D2_GetInfectedClassName(iSpawnClass[2], sBuffer[2], 16);
	L4D2_GetInfectedClassName(iSpawnClass[3], sBuffer[3], 16);
	
    switch (iSpawns) {
        case 4: {
            PrintToSurvivors(
                    "{default}Special Infected: {red}%s{default}, {red}%s{default}, {red}%s{default}, {red}%s{default}.",
                    sBuffer[0],
                    sBuffer[1],
                    sBuffer[2],
                    sBuffer[3]
                );
        }
        case 3: {
            PrintToSurvivors(
                    "{default}Special Infected: {red}%s{default}, {red}%s{default}, {red}%s{default}.",
                    sBuffer[0],
                    sBuffer[1],
                    sBuffer[2]
                );
        }
        case 2: {
            PrintToSurvivors(
                    "{default}Special Infected: {red}%s{default}, {red}%s{default}.",
                    sBuffer[0],
                    sBuffer[1]
                );
        }
        case 1: {
            PrintToSurvivors(
                    "{default}Special Infected: {red}%s{default}.",
                    sBuffer[0]
                );
        }
    }
}

void PrintToSurvivors(const char[] Message, any ... )
{
    char sPrint[256];
    VFormat(sPrint, sizeof(sPrint), Message, 2);

	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
        CPrintToChat(index, "%s", sPrint);
    }
}

void WarpToSurvivor(int client, int index)
{
    int target;
    if(index <= 0) target = FindNextSurvivor(client, iLastTarget[client]);
    else if(index <= 4) target = L4D2_GetSurvivorOfIndex(index - 1);
    else return;
    
    if (target == 0) return;
    SetEntProp(client,Prop_Send,"m_ghostSpawnState",256);
    
    float position[3], anglestarget[3];
    GetClientAbsOrigin(target, position);
    GetClientAbsAngles(target, anglestarget);
    TeleportEntity(client, position, anglestarget, NULL_VECTOR);
    return;
}

int FindNextSurvivor(int client, int index)
{
    if (!IsAnySurvivorsAlive()) return 0;
    bool havelooped = false;
    index++;
    if (index >= NUM_OF_SURVIVORS) index = 0;
    
    for (int i = index; i < MaxClients; i++)
    {
        if (i >= NUM_OF_SURVIVORS)
        {
            if (havelooped) break;
            havelooped = true;
            i = 0;
        }
        int x = L4D2_GetSurvivorOfIndex(i);
        if (x == 0 || !IsPlayerAlive(x)) continue;
        
        iLastTarget[client] = i;
        return x;
    }
    return 0;
}

bool IsAnySurvivorsAlive()
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0 && IsPlayerAlive(index)) return true;
	}
	return false;
}

void DisableCar(const char[] sName)
{
    TriggerCarRelay(sName, false);
}

void EnableCar(const char[] sName)
{
    TriggerCarRelay(sName, true);
}

void TriggerCarRelay(const char[] sName, bool bOn)
{
    char sCarName[128];
    int iEntity;
    if (!(SplitString(sName, "-", sCarName, sizeof(sCarName)) != -1)) return;
    StrCat(sCarName, sizeof(sCarName), "-relay_caralarm_");
    if (bOn) StrCat(sCarName, sizeof(sCarName), "on");
    else StrCat(sCarName, sizeof(sCarName), "off");
    iEntity = FindEntityByName(sCarName, "logic_relay");
    if (iEntity != -1) AcceptEntityInput(iEntity, "Trigger");
}

int FindEntityByName(const char[] sName, const char[] sClassName)
{
    int iEntity = -1;
    char sEntName[128];
    while ((iEntity = FindEntityByClassname(iEntity, sClassName)) != -1)
	{
        if (!IsValidEntity(iEntity)) continue;
        GetEntityName(iEntity, sEntName, sizeof(sEntName));
        if (StrEqual(sEntName, sName)) return iEntity;
    }
    return -1;
}

bool TooClose(int client)
{
	float fInfLocation[3], fSurvLocation[3], fVector[3];
	GetClientAbsOrigin(client, fInfLocation);
	
	for (int i = 0; i < 4; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		GetClientAbsOrigin(index, fSurvLocation);
		MakeVectorFromPoints(fInfLocation, fSurvLocation, fVector);
		if (GetVectorLength(fVector) <= 150) return true;
	}
	return false;
}

void UTIL_ScreenFade(int client, int duration, int time, int flags, int r, int g, int b, int a)
{
    int clients[1];
	Handle bf;
    clients[0] = client;

    bf = StartMessage("Fade", clients, 1);
    BfWriteShort(bf, duration);
    BfWriteShort(bf, time);
    BfWriteShort(bf, flags);
    BfWriteByte(bf, r);
    BfWriteByte(bf, g);
    BfWriteByte(bf, b);
    BfWriteByte(bf, a);
    EndMessage();
}

bool IsTank(int client)
{
	return L4D2_IsValidClient(client) && L4D2_IsInfected(client) && L4D2_GetInfectedClass(client) == L4D2Infected_Tank && IsPlayerAlive(client);
}

bool IsMelee(int entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		char strClassName[64];
		GetEdictClassname(entity, strClassName, sizeof(strClassName));
		return StrContains(strClassName, "melee", false) != -1;
	}
	return false;
}

void GetEntityName(int iEntity, char[] sTargetName, int iSize)
{
    GetEntPropString(iEntity, Prop_Data, "m_iName", sTargetName, iSize);
}
