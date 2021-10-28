#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2util>

public Plugin myinfo = 
{
	name = "Disable Tank Hordes",
	author = "Confogl Team",
	description = "A competitive mod for L4D2",
	version = "2.2.4",
	url = "http://confogl.googlecode.com/"
};

ConVar
	hMobSpawnSizeMin,
	hMobSpawnSizeMax,
	hMobSpawnTimeMin,
	hMobSpawnTimeMax,
	hDisableTankHordes;
int
	iMobSpawnSizeMin,
	iMobSpawnSizeMax;
float
	fMobSpawnTimeMin,
	fMobSpawnTimeMax;

public void OnPluginStart()
{
	hMobSpawnSizeMin = FindConVar("z_mob_spawn_min_size");
	hMobSpawnSizeMax = FindConVar("z_mob_spawn_max_size");
	hMobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
	hMobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
	
	hMobSpawnSizeMin.AddChangeHook(ConVarChange);
	hMobSpawnSizeMax.AddChangeHook(ConVarChange);
	hMobSpawnTimeMin.AddChangeHook(ConVarChange);
	hMobSpawnTimeMax.AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
	
	hDisableTankHordes = CreateConVar("disable_tank_hordes", "1", "Disable natural hordes while tanks are in play", FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMobSpawnSizeMin = hMobSpawnSizeMin.IntValue;
	iMobSpawnSizeMax = hMobSpawnSizeMax.IntValue;
	fMobSpawnTimeMin = hMobSpawnTimeMin.FloatValue;
	fMobSpawnTimeMax = hMobSpawnTimeMax.FloatValue;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
}

public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(fMobSpawnTimeMin, fMobSpawnTimeMax));
}

public Action L4D_OnSpawnMob(int &amount)
{
    // quick fix. needs normalize_hordes 1
    if (hDisableTankHordes.BoolValue && FindAnyTank() != -1)
    {
        if (amount < iMobSpawnSizeMin || amount > iMobSpawnSizeMax)
        {
            return Plugin_Continue;
        }
        if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer))
        {
            return Plugin_Continue;
        }
        
        float duration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
        if (duration < fMobSpawnTimeMin || duration > fMobSpawnTimeMax)
        {
            return Plugin_Continue;
        }
        
        return Plugin_Handled;
    }
    return Plugin_Continue;
}
