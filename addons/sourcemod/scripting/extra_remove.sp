#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo =
{
	name = "Items Remove",
	description = "",
	author = "Confogl Team",
	version = "1.0",
	url = ""
};

ConVar 
	hNoCans,
	hNoPropane,
	hNoOxygen,
	hNoFireworks,
	hNoMinigun,
	hNoFuelBarrel,
	hNoLocker,
	hRemoveLaserSight,
	hRemoveChainsaw,
	hRemoveGrenade,
	hRemoveM60,
	hRemoveDefib,
	hRemoveUpgExplosive,
	hRemoveUpgIncendiary;

public void OnPluginStart()
{
    hNoCans = CreateConVar("sm_remove_cans", "1", "Remove Gascans?", FCVAR_NONE);
    hNoPropane = CreateConVar("sm_remove_propane", "1", "Remove Propane Tanks?", FCVAR_NONE);
    hNoOxygen = CreateConVar("sm_remove_oxygen", "1", "Remove Oxygen Tanks?", FCVAR_NONE);
    hNoFireworks = CreateConVar("sm_remove_fireworks", "1", "Remove Fireworks?", FCVAR_NONE);
    hNoMinigun = CreateConVar("sm_remove_minigun", "1", "Remove Minigun?", FCVAR_NONE);
    hNoFuelBarrel = CreateConVar("sm_remove_fuelbarrel", "1", "Remove Fuel Barrel?", FCVAR_NONE);
	hNoLocker = CreateConVar("sm_remove_locker", "1", "Remove Locker?", FCVAR_NONE);
	hRemoveLaserSight = CreateConVar("sm_remove_lasersight", "1", "Remove all laser sight upgrades");
	hRemoveChainsaw = CreateConVar("sm_remove_chainsaw", "1", "Remove all chainsaws");
	hRemoveGrenade = CreateConVar("sm_remove_grenade", "0", "Remove all grenade launchers");
	hRemoveM60 = CreateConVar("sm_remove_m60", "0", "Remove all M60 rifles");
	hRemoveDefib = CreateConVar("sm_remove_defib", "1", "Remove all defibrillators");
	hRemoveUpgExplosive = CreateConVar("sm_remove_upg_explosive", "1", "Remove all explosive upgrade packs");
	hRemoveUpgIncendiary = CreateConVar("sm_remove_upg_incendiary", "1", "Remove all incendiary upgrade packs");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!IsInTransition() && IsCheckItems(entity))
	{
		SDKHook(entity, SDKHook_SpawnPost, fOnEntitySpawned);
	}
}

public void fOnEntitySpawned(int entity)
{
	RemoveEntityLog(entity);
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(0.3, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStartDelay(Handle hTimer)
{
	WeaponSearchLoop();
}

void WeaponSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (IsCheckItems(i))
		{
			RemoveEntityLog(i);
		}
	}
}

bool IsCheckItems(int entity)
{
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return false;
	char classname[64];
	if (!GetEdictClassname(entity, classname, sizeof(classname))) return false;
	
	char targetname[64];
	GetEdictName(entity, targetname, 64);
	if (StrContains(targetname, "_locker", false) != -1 && hNoLocker.BoolValue) return true;
	else if (StrContains(classname, "laser_sight", false) != -1 && hRemoveLaserSight.BoolValue) return true;
	else if (StrContains(classname, "minigun", false) != -1 && hNoMinigun.BoolValue) return true;
	else if (StrContains(classname, "fuel_barrel", false) != -1 && hNoFuelBarrel.BoolValue) return true;
	else if (StrEqual(classname, "prop_physics", false) && GetEntProp(entity, Prop_Send, "m_isCarryable"))
	{
		char model[128];
		GetEdictModelName(entity, model, sizeof(model));
		if (StrContains(model, "models/props_junk/gascan001a.mdl", false) != -1 && hNoCans.BoolValue) return true;
		else if (StrContains(model, "models/props_junk/propanecanister001a.mdl", false) != -1 && hNoPropane.BoolValue) return true;
		else if (StrContains(model, "models/props_equipment/oxygentank01.mdl", false) != -1 && hNoOxygen.BoolValue) return true;
		else if (StrContains(model, "models/props_junk/explosive_box001.mdl", false) != -1 && hNoFireworks.BoolValue) return true;
	}
	else
	{
		WeaponId source = IdentifyWeapon(entity);
		if (source == WEPID_CHAINSAW && hRemoveChainsaw.BoolValue) return true;
		if (source == WEPID_GRENADE_LAUNCHER && hRemoveGrenade.BoolValue) return true;
		if (source == WEPID_RIFLE_M60 && hRemoveM60.BoolValue) return true;
		if (source == WEPID_DEFIBRILLATOR && hRemoveDefib.BoolValue) return true;
		if (source == WEPID_UPGRADE_ITEM && hRemoveLaserSight.BoolValue) return true;
		if (source == WEPID_FRAG_AMMO && hRemoveUpgExplosive.BoolValue) return true;
		if (source == WEPID_INCENDIARY_AMMO && hRemoveUpgIncendiary.BoolValue) return true;
	}
	return false;
}

void RemoveEntityLog(int entity)
{
	char pluginName[128], classname[64];
	GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
	GetEdictClassname(entity, classname, 64);
	if (!AcceptEntityInput(entity, "kill"))
	{
		LogError("[%s] 删除实体 %s 失败", pluginName, classname);
	}
	else
	{
		PrintToServer("[%s] Removed %s", pluginName, classname);
	}
}
