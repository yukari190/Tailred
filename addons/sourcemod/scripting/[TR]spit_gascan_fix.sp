#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <[LIB]l4d2library>

public Plugin myinfo =
{
	name = "Spiter GasCan Fix",
	description = "",
	author = "趴趴酱",
	version = "1.0",
	url = ""
};

float gascan_delay;

public void OnPluginStart()
{
	ConVar hGasCanSpitTime = FindConVar("gascan_spit_time");
	gascan_delay = GetConVarFloat(hGasCanSpitTime);
	hGasCanSpitTime.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	gascan_delay = convar.FloatValue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		if (StrEqual(classname, "weapon_gascan", false))
		  SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage);
	}
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (IsValidEntity(victim) && inflictor)
	{
		char sInflictor[64];
		GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor));
		if (GetEntProp(victim, Prop_Send, "m_glowColorOverride") != 16777215 && StrEqual(sInflictor, "insect_swarm", false))
		{
			CreateTimer(gascan_delay, timer_gascan, victim, TIMER_FLAG_NO_MAPCHANGE);
		}
	}
}

public Action timer_gascan(Handle timer, any victim)
{
	SDKHooks_TakeDamage(victim, 0, 0, 100.0, DMG_BURN);
}
