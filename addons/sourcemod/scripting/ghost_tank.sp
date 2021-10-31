#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

public Plugin myinfo = 
{
	name = "Ghost Tank",
	author = "Confogl Team",
	description = "A competitive mod for L4D2",
	version = "2.2.4",
	url = "http://confogl.googlecode.com/"
};

static const float THROWRANGE = 99999999.0;
static const int INCAPHEALTH = 300;

ConVar
	hTankThrowAllowRange,
	hTankLotterySelectionTime,
	hEnabled,
	hRemoveEscapeTank,
	hMaxTank;

bool 
	bFinaleVehicleIncoming,
	bIsFinale;

int
	iTankClient,
	iTankCount;

public void OnPluginStart()
{
	hTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
	hTankThrowAllowRange = FindConVar("tank_throw_allow_range");
	
    hEnabled	= CreateConVar("boss_tank", "1", "Tank can't be prelight, frozen and ghost until player takes over, punch fix, and no rock throw for AI tank while waiting for player", CVAR_FLAGS, true, 0.0, true, 1.0);
    hRemoveEscapeTank = CreateConVar("remove_escape_tank", "1", "Remove tanks that spawn as the rescue vehicle is incoming on finales.", CVAR_FLAGS, true, 0.0, true, 1.0);
	//hMaxTank = CreateConVar("tank_limit", "1", "", CVAR_FLAGS, true, 0.0);
	
    HookEvent("player_incapacitated", PlayerIncap);
    HookEvent("finale_vehicle_incoming", FinaleVehicleIncoming, EventHookMode_PostNoCopy);
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
    if(hRemoveEscapeTank.BoolValue && bFinaleVehicleIncoming)
        return Plugin_Handled;
	/*int iMaxTank = hMaxTank.IntValue;
	if (iMaxTank > 0 && iTankCount >= iMaxTank && (!L4D_IsMissionFinalMap() || bIsFinale))
		return Plugin_Handled;
	iTankCount += 1;*/
    return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
    if(hEnabled.BoolValue) enterStasis = false;
    if(hRemoveEscapeTank.BoolValue && bFinaleVehicleIncoming) return Plugin_Handled;
    return Plugin_Continue;
}

public void L4D2_OnRealRoundStart()
{
    bFinaleVehicleIncoming = false;
	bIsFinale = false;
	iTankCount = 0;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
    iTankClient = tankClient;
    
    if (!hEnabled.BoolValue) return;
    
    if (IsFakeClient(tankClient))
    {
        PauseTank();
        CreateTimer(hTankLotterySelectionTime.FloatValue, ResumeTankTimer);
    }
}

public Action ResumeTankTimer(Handle timer)
{
    ResumeTank();
}

public void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
    iTankClient = newTank;
}

public void FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
    bFinaleVehicleIncoming = true;
}

public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	bIsFinale = true;
}

public void PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    if(!hEnabled.BoolValue) return;
    
    char weapon[16];
    GetEventString(event, "weapon", weapon, 16);
    
    if (!StrEqual(weapon, "tank_claw")) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidSurvivor(client)) return;
    
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
    SetEntityHealth(client, 1);
    CreateTimer(0.4, IncapTimer, client);
}

public Action IncapTimer(Handle timer, any client)
{
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
    SetEntityHealth(client, INCAPHEALTH);
}

void PauseTank()
{
    hTankThrowAllowRange.FloatValue = THROWRANGE;
    if (!IsValidEntity(iTankClient)) return;
    SetEntityMoveType(iTankClient, MOVETYPE_NONE);
    SetEntProp(iTankClient, Prop_Send, "m_isGhost",1);
}

void ResumeTank()
{
    hTankThrowAllowRange.RestoreDefault();
    if (!IsValidEntity(iTankClient)) return;
    SetEntityMoveType(iTankClient, MOVETYPE_CUSTOM);
    SetEntProp(iTankClient, Prop_Send, "m_isGhost", 0);
}

bool IsValidSurvivor(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return GetClientTeam(client) == 2;
}
