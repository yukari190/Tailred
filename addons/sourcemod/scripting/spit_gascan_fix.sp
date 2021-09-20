#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo =
{
	name = "Spiter GasCan Fix",
	description = "",
	author = "Yukari190",
	version = "1.2",
	url = ""
};

float fInterval;
float fOverkill[2048];

public void OnPluginStart()
{
	ConVar hGasCanSpitTime = FindConVar("gascan_spit_time");
	fInterval = GetConVarFloat(hGasCanSpitTime);
	hGasCanSpitTime.AddChangeHook(ConVarChange);
	HookEvent("player_use", OnPlayerUse, EventHookMode_Post);
}

public void ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	fInterval = convar.FloatValue;
}

public Action OnPlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	fOverkill[event.GetInt("targetid")] = 0.0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		if (StrContains(classname, "gascan", false) != -1)
		{
			fOverkill[entity] = 0.0;
			SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}

public Action OnTakeDamage(int entity, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (!IsGasCan(entity)) return Plugin_Continue;
	
	if (IsInsectSwarm(inflictor))
	{
		if (fOverkill[entity] == 0.0)
		{
			fOverkill[entity] = GetGameTime() + fInterval;
		}
		
		if (fOverkill[entity] - GetGameTime() <= 0.0)
		{
			SDKHooks_TakeDamage(entity, inflictor, inflictor, 100.0, DMG_BURN);
			fOverkill[entity] = 0.0;
		}
	}
	return Plugin_Continue;
}

bool IsInsectSwarm(int iEntity)
{
	if (iEntity < 1 || !IsValidEntity(iEntity)) return false;

	char sClassName[64];
	GetEntityClassname(iEntity, sClassName, sizeof(sClassName));
	return (strcmp(sClassName, "insect_swarm") == 0);
}

bool IsGasCan(int entity)
{
	if (entity < 1 || !IsValidEntity(entity)) return false;
	return GetEntProp(entity, Prop_Send, "m_glowColorOverride") != 16777215;
}
