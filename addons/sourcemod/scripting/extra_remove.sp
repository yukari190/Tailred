#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2lib>
#include <l4d2util>

#define CAN_GASCAN "models/props_junk/gascan001a.mdl"
#define CAN_PROPANE "models/props_junk/propanecanister001a.mdl"
#define CAN_OXYGEN "models/props_equipment/oxygentank01.mdl"
#define CAN_FIREWORKS "models/props_junk/explosive_box001.mdl"

public Plugin myinfo =
{
	name = "Extra Remove",
	description = "",
	author = "Yukari190",
	version = "1.0",
	url = ""
};

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.0, RoundStartDelay);
}

public Action RoundStartDelay(Handle hTimer)
{
	EntitySearch();
	
	return Plugin_Stop;
}

void EntitySearch()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (IsCheckItems(i))
		{
			KillEntity(i);
		}
	}
}

bool IsCheckItems(int entity)
{
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return false;
	char classname[64], targetname[64];
	GetEdictClassname(entity, classname, 64);
	GetEdictName(entity, targetname, 64);
	
	if (StrContains(targetname, "_locker", false) != -1) return true;
	else if (StrContains(classname, "laser_sight", false) != -1) return true;
	else if (StrContains(classname, "minigun", false) != -1) return true;
	else if (StrContains(classname, "fuel_barrel", false) != -1) return true;
	else if (StrContains(classname, "prop_physics", false) != -1)
	{
		char sModelName[128];
		GetEdictModelName(entity, sModelName, sizeof(sModelName));
		
		if (GetEntProp(entity, Prop_Send, "m_isCarryable"))
		{
			if (StrEqual(sModelName, CAN_GASCAN, false) && !IsCanGlow(entity)) return true;
			if (StrEqual(sModelName, CAN_PROPANE, false)) return true;
			if (StrEqual(sModelName, CAN_OXYGEN, false)) return true;
			if (StrEqual(sModelName, CAN_FIREWORKS, false)) return true;
		}
	}
	return false;
}

bool IsCanGlow(int entity)
{
	return GetEntProp(entity, Prop_Send, "m_glowColorOverride") == 16777215;
}
