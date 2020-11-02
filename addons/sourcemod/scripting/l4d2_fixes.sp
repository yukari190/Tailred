#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

ConVar hMobSpawnMinSize, hMobSpawnMaxSize, hMobSpawnIntervalMin, hMobSpawnIntervalMax;
bool bHordesDisabled;
int iMobSpawnMinSize, iMobSpawnMaxSize;
float fMobSpawnIntervalMin, fMobSpawnIntervalMax;

public Plugin myinfo =
{
	name = "L4D2 Merge Fixes",
	author = "Visor, Jacob, sheo, CanadaRox, Sir, step, Don, epilimic, Griffin, Tabun",
	description = "",
	version = "1.0",
	url = "Nope"
};

public void OnPluginStart()
{
	hMobSpawnMinSize = FindConVar("z_mob_spawn_min_size");
	hMobSpawnMaxSize = FindConVar("z_mob_spawn_max_size");
	hMobSpawnIntervalMin = FindConVar("z_mob_spawn_min_interval_normal");
	hMobSpawnIntervalMax = FindConVar("z_mob_spawn_max_interval_normal");
	
	iMobSpawnMinSize = GetConVarInt(hMobSpawnMinSize);
	iMobSpawnMaxSize = GetConVarInt(hMobSpawnMaxSize);
	fMobSpawnIntervalMin = GetConVarFloat(hMobSpawnIntervalMin);
	fMobSpawnIntervalMax = GetConVarFloat(hMobSpawnIntervalMax);
	
	hMobSpawnMinSize.AddChangeHook(ConVarChange);
	hMobSpawnMaxSize.AddChangeHook(ConVarChange);
	hMobSpawnIntervalMin.AddChangeHook(ConVarChange);
	hMobSpawnIntervalMax.AddChangeHook(ConVarChange);
	
	HookEvent("player_incapacitated", PlayerIncap);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMobSpawnMinSize = hMobSpawnMinSize.IntValue;
	iMobSpawnMaxSize = hMobSpawnMaxSize.IntValue;
	fMobSpawnIntervalMin = hMobSpawnIntervalMin.FloatValue;
	fMobSpawnIntervalMax = hMobSpawnIntervalMax.FloatValue;
}

public void L4D2_OnRealRoundStart()
{
	bHordesDisabled = false;
}

public void L4D2_OnTankDeath()
{
	bHordesDisabled = false;
}

public void L4D2_OnTankFirstSpawn()
{
	bHordesDisabled = true;
}

//L4DT
public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
	return Plugin_Continue;
}

public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(fMobSpawnIntervalMin, fMobSpawnIntervalMax));
}

public Action L4D_OnSpawnMob(int &amount)
{
	if(bHordesDisabled)
	{
		if (amount < iMobSpawnMinSize || amount > iMobSpawnMaxSize)
		{
			return Plugin_Continue;
		}
		if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer))
		{
			return Plugin_Continue;
		}
		float duration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
		if (duration < fMobSpawnIntervalMin || duration > fMobSpawnIntervalMax)
		{
			return Plugin_Continue;
		}
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action L4D_OnSpawnITMob(int &amount)
{
	amount = iMobSpawnMaxSize;
	return Plugin_Changed;
}

//Event
public Action PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	char weapon[16];	 
	event.GetString("weapon", weapon, 16);
	if (!IsValidInGame(victim)) return;
	
	if (StrEqual(weapon, "tank_claw", false))
	{
		SetEntProp(victim, Prop_Send, "m_isIncapacitated", 0);
		SetEntityHealth(victim, 1);
		CreateTimer(0.4, IncapTimer_Function, victim, TIMER_REPEAT);
	}
}

public Action IncapTimer_Function(Handle timer, any victim)
{
	if (!IsValidInGame(victim)) return Plugin_Stop;
	SetEntProp(victim, Prop_Send, "m_isIncapacitated", 1);
	SetEntityHealth(victim, 300);
	return Plugin_Stop;
}
