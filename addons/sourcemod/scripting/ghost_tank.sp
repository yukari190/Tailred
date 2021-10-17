#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>

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
	hMobSpawnSizeMin,
	hMobSpawnSizeMax,
	hMobSpawnTimeMin,
	hMobSpawnTimeMax,
	hTankThrowAllowRange,
	hTankLotterySelectionTime,
	hEnabled,
	hRemoveEscapeTank,
	hDisableTankHordes;

bool 
	bFinaleVehicleIncoming,
	bHordesDisabled;

int g_iTankClient;

public void OnPluginStart()
{
	hMobSpawnSizeMin = FindConVar("z_mob_spawn_min_size");
	hMobSpawnSizeMax = FindConVar("z_mob_spawn_max_size");
	hMobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
	hMobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
	hTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
	hTankThrowAllowRange = FindConVar("tank_throw_allow_range");
	
    hEnabled	= CreateConVar("boss_tank", "1", "Tank can't be prelight, frozen and ghost until player takes over, punch fix, and no rock throw for AI tank while waiting for player");
    hRemoveEscapeTank = CreateConVar("remove_escape_tank", "1", "Remove tanks that spawn as the rescue vehicle is incoming on finales.");
    hDisableTankHordes = CreateConVar("disable_tank_hordes", "1", "Disable natural hordes while tanks are in play");
	
    HookEvent("player_incapacitated", PlayerIncap);
    HookEvent("finale_vehicle_incoming", FinaleVehicleIncoming);
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
    if(hRemoveEscapeTank.BoolValue && bFinaleVehicleIncoming)
        return Plugin_Handled;
    return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
    if(hEnabled.BoolValue) enterStasis = false;
    if(hRemoveEscapeTank.BoolValue && bFinaleVehicleIncoming) return Plugin_Handled;
    return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &amount)
{
    // quick fix. needs normalize_hordes 1
    if (bHordesDisabled)
    {
        int minsize = hMobSpawnSizeMin.IntValue, maxsize = hMobSpawnSizeMax.IntValue;
        if (amount < minsize || amount > maxsize)
        {
            return Plugin_Continue;
        }
        if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer))
        {
            return Plugin_Continue;
        }
        
        float duration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
        if (duration < hMobSpawnTimeMin.FloatValue || duration > hMobSpawnTimeMax.FloatValue)
        {
            return Plugin_Continue;
        }
        
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
}

public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
	// Workaround to make tank horde blocking always work
	// Makes the first horde always start 100s after survivors leave saferoom
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(hMobSpawnTimeMin.FloatValue, hMobSpawnTimeMax.FloatValue));
}

public void L4D2_OnRealRoundStart()
{
    bFinaleVehicleIncoming = false;
    EnableNaturalHordes();
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
    g_iTankClient = tankClient;
    
    if (hDisableTankHordes.BoolValue)
    {
        DisableNaturalHordes();
    }
    
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
    g_iTankClient = newTank;
}

public void L4D2_OnTankDeath(int tankClient, int attacker)
{
    if (bHordesDisabled)
    {
        EnableNaturalHordes();
    }
}

public void FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
    bFinaleVehicleIncoming = true;
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
    hTankThrowAllowRange.SetFloat(THROWRANGE);
    if (!IsValidEntity(g_iTankClient)) return;
    SetEntityMoveType(g_iTankClient, MOVETYPE_NONE);
    SetEntProp(g_iTankClient, Prop_Send, "m_isGhost",1);
}

void ResumeTank()
{
    hTankThrowAllowRange.RestoreDefault();
    if (!IsValidEntity(g_iTankClient)) return;
    SetEntityMoveType(g_iTankClient, MOVETYPE_CUSTOM);
    SetEntProp(g_iTankClient, Prop_Send, "m_isGhost", 0);
}

void DisableNaturalHordes()
{
    // 0x7fff = 16 bit signed max value. Over 9 hours.
    bHordesDisabled = true;
}

void EnableNaturalHordes()
{
    bHordesDisabled = false;
}

bool IsValidSurvivor(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return GetClientTeam(client) == 2;
}
