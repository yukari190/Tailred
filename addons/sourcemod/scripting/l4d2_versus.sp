#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <weapons>
#include <colors>
#undef REQUIRE_PLUGIN
#include <pause>
#include <readyup>
#define REQUIRE_PLUGIN

#define CALL_OPCODE 0xE8


int L4D2_SI_Victim_Slots[10] =
{
    -1,
    13300,    // Smoker
    -1,
    16024,    // Hunter
    -1,
    16144,    // Jockey
    15992,    // Charger
    -1,
    -1,
    -1
};

Handle z_max_player_zombies;
Handle z_hunter_limit;
Handle z_boomer_limit;
Handle z_smoker_limit;
Handle z_jockey_limit;
Handle z_charger_limit;
Handle z_spitter_limit;
Handle g_hSpitterLimit;
Handle hAllTalk;
Handle hFirstRoundCars;
Handle hSecondRoundCars;
Handle g_hRockThrowRange;
ConVar hDirectorTankLotterySelectionTime;

int g_iSpitterLimit;
int lastHumanTank;
int iLastTarget[MAXPLAYERS+1] = -1;

float iCurRange;

bool IsInCharge[MAXPLAYERS + 1];
bool g_bIsTankInPlay;
bool bDelay[MAXPLAYERS+1];
bool bActivated;
bool bPatched;
bool FS_bIsFinale;

public Plugin myinfo =
{
	name = "l4d2 merge fixvs",
	author = "ProdigySim, Visor, CanadaRox",
	description = "",
	version = "1.0",
	url = ""
}

public void OnPluginStart()
{
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	z_hunter_limit = FindConVar("z_hunter_limit");
	z_boomer_limit = FindConVar("z_boomer_limit");
	z_smoker_limit = FindConVar("z_smoker_limit");
	z_jockey_limit = FindConVar("z_jockey_limit");
	z_charger_limit = FindConVar("z_charger_limit");
	z_spitter_limit = FindConVar("z_spitter_limit");
	g_hRockThrowRange = FindConVar("tank_throw_allow_range");
	hDirectorTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
	hAllTalk = FindConVar("sv_alltalk");
    hFirstRoundCars = CreateArray(128);
    hSecondRoundCars = CreateArray(128);
	
	HookConVarChange(z_hunter_limit, Hunter_Limit_ValueChanged);
	HookConVarChange(z_boomer_limit, Infected_Limit_ValueChanged);
	HookConVarChange(z_smoker_limit, Infected_Limit_ValueChanged);
	HookConVarChange(z_jockey_limit, Infected_Limit_ValueChanged);
	HookConVarChange(z_charger_limit, Infected_Limit_ValueChanged);
	HookConVarChange(z_spitter_limit, Infected_Limit_ValueChanged);
	HookConVarChange(hAllTalk, Changed_AllTalk);
	
	g_hSpitterLimit = FindConVar("z_versus_spitter_limit");
	HookConVarChange(g_hSpitterLimit, Cvar_SpitterLimit);
	g_iSpitterLimit = GetConVarInt(g_hSpitterLimit);
	
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
	HookEvent("tank_frustrated", OnTankFrustrated);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_death", Event_OnPlayerDeath);
	HookEvent("player_bot_replace", PlayerBotReplace);
	HookEvent("charger_charge_start", Event_ChargeStart);
	HookEvent("charger_charge_end", Event_ChargeEnd);
	HookEvent("finale_vehicle_leaving", FinaleEnd_Event, EventHookMode_PostNoCopy);
	
	L4D2Weapons_Init();
}

public void OnPluginEnd()
{
	ModifyEntity("trigger_hurt_ghost", "Enable");
	ResetConVar(z_hunter_limit);
	ResetConVar(z_boomer_limit);
	ResetConVar(z_smoker_limit);
	ResetConVar(z_jockey_limit);
	ResetConVar(z_charger_limit);
	ResetConVar(z_spitter_limit);
	if (g_iSpitterLimit > 0) SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
}

public int Hunter_Limit_ValueChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarInt(z_max_player_zombies) == 4) SetConVarInt(convar, 2);
	else if (GetConVarInt(z_max_player_zombies) == 1) SetConVarInt(convar, 1);
}

public int Infected_Limit_ValueChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (GetConVarInt(z_max_player_zombies) == 4) SetConVarInt(convar, 1);
	else if (GetConVarInt(z_max_player_zombies) == 1) SetConVarInt(convar, 0);
}

public int Cvar_SpitterLimit(Handle convar, const char[] oldValue, const char[] newValue)
{
    if (g_bIsTankInPlay) return;
    g_iSpitterLimit = StringToInt(newValue);
}

public int Changed_AllTalk(Handle convar, const char[] oldValue, const char[] newValue)
{
	switch (StringToInt(newValue))
	{
		case 0: CPrintToChatAll("{G}全体语音 {O}关闭");
		case 1: CPrintToChatAll("{G}全体语音 {O}开启");
	}
}

public void L4D_OnEnterGhostState(int client)
{
    int CurrentHealth = GetClientHealth(client);
    int MaxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
    if (CurrentHealth != MaxHealth) SetEntityHealth(client, MaxHealth);
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	ModifyEntity("trigger_hurt_ghost", "Enable");
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!IsValidInGame(client)) return Plugin_Continue;
	
	if (!bDelay[client] && GetClientTeam(client) == 3 && IsPlayerAlive(client) && IsInfectedGhost(client))
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
    ClearArray(hFirstRoundCars);
    ClearArray(hSecondRoundCars);
	
	bActivated = false;
	bPatched = false;
}

public void OnRoundIsLive()
{
	IsAllowAllTalk(false);
}

public void OnPause()
{
	IsAllowAllTalk(true);
}

public void OnUnpause()
{
	IsAllowAllTalk(false);
}

public void L4D2_OnRealRoundStart()
{
	ModifyEntity("trigger_hurt_ghost", "Disable");
	IsAllowAllTalk(true);
	
	if (GetConVarInt(z_max_player_zombies) == 4)
	{
		SetConVarInt(z_hunter_limit, 2);
		SetConVarInt(z_boomer_limit, 1);
		SetConVarInt(z_smoker_limit, 1);
		SetConVarInt(z_jockey_limit, 1);
		SetConVarInt(z_charger_limit, 1);
		SetConVarInt(z_spitter_limit, 1);
	}
	else if (GetConVarInt(z_max_player_zombies) == 1)
	{
		SetConVarInt(z_hunter_limit, 1);
		SetConVarInt(z_boomer_limit, 0);
		SetConVarInt(z_smoker_limit, 0);
		SetConVarInt(z_jockey_limit, 0);
		SetConVarInt(z_charger_limit, 0);
		SetConVarInt(z_spitter_limit, 0);
	}
	
	FS_bIsFinale = false;
	g_bIsTankInPlay = false;
	if (g_iSpitterLimit > 0) SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
	
	CreateTimer(1.2, RoundStartDelay_Timer);
}

public Action RoundStartDelay_Timer(Handle timer)
{
	if (L4D2_IsFirstRound() || bActivated)
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
        
    if (L4D2_IsFirstRound())
	{
        bActivated = true;
        PushArrayString(hFirstRoundCars, sTargetName);
    }
    else
	{
        PushArrayString(hSecondRoundCars, sTargetName);
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
        GetArrayString(hFirstRoundCars, i, sEntName, sizeof(sEntName));
        if (FindStringInArray(hSecondRoundCars, sEntName) == -1) DisableCar(sEntName);
    }
    
    for (int i = 0; i < GetArraySize(hSecondRoundCars); i++)
	{
        GetArrayString(hSecondRoundCars, i, sEntName, sizeof(sEntName));
        if (FindStringInArray(hFirstRoundCars, sEntName) == -1) EnableCar(sEntName);
    }
}


public void L4D2_OnRealRoundEnd()
{
	IsAllowAllTalk(true);
	FS_bIsFinale = false;
	g_bIsTankInPlay = false;
	if (g_iSpitterLimit > 0) SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
    g_bIsTankInPlay = true;
    SetConVarInt(g_hSpitterLimit, 0);
	if (IsFakeClient(tankClient))
	{
		iCurRange = GetConVarFloat(g_hRockThrowRange);
		SetConVarFloat(g_hRockThrowRange, 99999999.0);
		if (!IsValidEntity(tankClient)) return;
		SetEntityMoveType(tankClient, MOVETYPE_NONE);
		SetEntProp(tankClient, Prop_Send, "m_isGhost", 1, 1);
		CreateTimer(GetConVarFloat(hDirectorTankLotterySelectionTime), ResumeTankTimer, tankClient);
	}
}

public Action ResumeTankTimer(Handle timer, any tankClient)
{
	SetConVarFloat(g_hRockThrowRange, iCurRange);
	if (!IsValidEntity(tankClient)) return;
	SetEntityMoveType(tankClient, MOVETYPE_CUSTOM);
	SetEntProp(tankClient, Prop_Send, "m_isGhost", 0, 1);
}

public void L4D2_OnTankDeath()
{
    g_bIsTankInPlay = false;
    if (g_iSpitterLimit > 0 && FindTank() == -1) SetConVarInt(g_hSpitterLimit, g_iSpitterLimit);
}

public void L4D2_OnPlayerHurtPost(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype)
{
	if (!CheckForTank(attacker, victim)) return;
	if (damage < 5) return;
	SetTankFrustration(attacker, 100);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client)) return;
	if (nowteam == 3 && oldteam != 3)
	{
		SDKHook(client, SDKHook_PreThinkPost, HookCallback);
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
	else if (nowteam != 3 && oldteam == 3)
	{
		SDKUnhook(client, SDKHook_PreThinkPost, HookCallback);
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action HookCallback(int client)
{
	if (!FS_bIsFinale || GetClientTeam(client) != 3 || GetEntProp(client,Prop_Send,"m_isGhost") != 1) return;
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
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED && GetInfectedClass(i) == ZC_TANK && IsFakeClient(i))
		{
			if (GetClientTeam(lastHumanTank) == TEAM_INFECTED) ForcePlayerSuicide(lastHumanTank);
			return Plugin_Handled;
		}
	}
	return Plugin_Handled;
}

public Action PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	int victimid = event.GetInt("userid");
	int victim = GetClientOfUserId(victimid);
	int Attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!CheckForTank(Attacker, victim)) return;
	SetTankFrustration(Attacker, 100);
}

public Action PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("player"));
	int botid = event.GetInt("bot");
	int bot = GetClientOfUserId(botid);
	if (bot && IsClientInGame(bot) && GetClientTeam(bot) == 3 && IsFakeClient(bot)) CreateTimer(10.0, KillBot, bot);
	
	if (IsInCharge[client])
	{
		SetEntityFlags(bot, GetEntityFlags(bot) | FL_FROZEN); //New method, by dcx2
		IsInCharge[client] = false;
	}
	
	if (GetClientTeam(bot) == 3 && GetInfectedClass(bot) == 8)
	{
		PrintToChatAll("[AI Tank] Tank控制权丢失, 启用代打模式!");
	}
}

public Action KillBot(Handle timer, any bot)
{
    if (bot && IsClientInGame(bot) && GetClientTeam(bot) == 3 && IsFakeClient(bot) && ShouldBeKicked(bot)) ForcePlayerSuicide(bot);
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
		if (IsPlayerIncap(index)) ForcePlayerSuicide(index);
	}
}

//Utility
bool CheckForTank(int Attacker, int Victim)
{
	if (!IsValidInGame(Victim) || !IsValidInGame(Attacker)) return false;
	if (GetClientTeam(Victim) != 2 || GetClientTeam(Attacker) != 3) return false;
	if (IsFakeClient(Attacker)) return false;
	if (GetEntProp(Attacker, Prop_Send, "m_zombieClass") != 8) return false;
	return true;
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
        
        if (L4D2_GetSurvivorOfIndex(i) == 0) continue;
        
        iLastTarget[client] = i;
        return L4D2_GetSurvivorOfIndex(i);
    }
    return 0;
}

bool IsAnySurvivorsAlive()
{
	for (int index = 0; index < NUM_OF_SURVIVORS; index++)
	{
		if (L4D2_GetSurvivorOfIndex(index)) return true;
	}
	return false;
}

bool ShouldBeKicked(int infected)
{
    Address pEntity = GetEntityAddress(infected);
    if (pEntity == Address_Null) return false;

    int zcOffset = L4D2_SI_Victim_Slots[GetEntProp(infected, Prop_Send, "m_zombieClass")];
    if (zcOffset == -1) return false;
    
    int hasTarget = LoadFromAddress(pEntity + view_as<Address>(zcOffset), NumberType_Int32);
    return hasTarget > 0 ? false : true;
}

void IsAllowAllTalk(bool e)
{
	SetConVarBool(hAllTalk, e);
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

void ModifyEntity(char[] className, char[] inputName)
{ 
    int iEntity;
    while ((iEntity = FindEntityByClassname(iEntity, className)) != -1)
    {
        if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) continue;
        AcceptEntityInput(iEntity, inputName);
    }
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
	if (IsValidInGame(client) && GetClientTeam(client) == 3 && GetInfectedClass(client) == ZC_TANK && IsPlayerAlive(client)) return true;
	return false;
}
