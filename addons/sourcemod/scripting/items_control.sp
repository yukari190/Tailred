#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>
#include <readyup>

public Plugin myinfo =
{
	name = "L4D2 Entity Control",
	description = "",
	author = "Confogl Team",
	version = "1.0",
	url = ""
};

enum struct ItemTracking
{
	int IT_entity;
	float IT_origins;
	float IT_origins1;
	float IT_origins2;
	float IT_angles;
	float IT_angles1;
	float IT_angles2;
}

ArrayList g_hItemSpawns;

ConVar 
	hPillsLimits,
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
	hRemoveAdrenaline,
	hRemovePipebomb,
	hRemoveMolotov,
	hRemoveVomitjar,
	hRemoveUpgExplosive,
	hRemoveUpgIncendiary,
	hRemoveExtraItems;

int g_iItemLimits;

public void OnPluginStart()
{
	g_hItemSpawns = new ArrayList(sizeof(ItemTracking));
	
	hPillsLimits = CreateConVar("sm_pills_limit", "-1", "限制每张地图上止痛药的数量. -1: 没有限制; >=0: 限制为cvar值");
	g_iItemLimits = hPillsLimits.IntValue;
	hPillsLimits.AddChangeHook(ConVarChange);
	
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
	hRemoveAdrenaline = CreateConVar("sm_remove_adrenaline", "1", "Remove all adrenaline");
	hRemovePipebomb = CreateConVar("sm_remove_pipebomb", "1", "Remove all pipe bombs");
	hRemoveMolotov = CreateConVar("sm_remove_molotov", "1", "Remove all molotovs");
	hRemoveVomitjar = CreateConVar("sm_remove_vomitjar", "1", "Remove all bile bombs");
	hRemoveUpgExplosive = CreateConVar("sm_remove_upg_explosive", "1", "Remove all explosive upgrade packs");
	hRemoveUpgIncendiary = CreateConVar("sm_remove_upg_incendiary", "1", "Remove all incendiary upgrade packs");
	hRemoveExtraItems = CreateConVar("sm_remove_saferoomitems", "1", "Remove all extra items inside saferooms (items for slot 3, 4 and 5, minus medkits)");
	
	HookEvent("spawner_give_item", SpawnerGiveItem_Event, EventHookMode_PostNoCopy);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iItemLimits = convar.IntValue;
}

public void OnMapStart()
{
	g_iItemLimits = hPillsLimits.IntValue;
	if (L4D_IsMissionFinalMap() && g_iItemLimits != -1)
	{
		g_iItemLimits = 0; 
	}
	g_hItemSpawns.Clear();
}

public void OnRoundIsLive()
{
	int startingItem;
	float clientOrigin[3];
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		if (GetPlayerWeaponSlot(index, 4) <= -1 && GetPlayerWeaponSlot(index, 3) <= -1)
		{
			startingItem = CreateEntityByName("weapon_pain_pills");
			GetClientAbsOrigin(index, clientOrigin);
			TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
			DispatchSpawn(startingItem);
			EquipPlayerWeapon(index, startingItem);
		}
	}
}

public Action SpawnerGiveItem_Event(Event event, const char[] name, bool dontBroadcast)
{
	ItemsSearchLoop();
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.0, RoundStartDelay);
}

public Action RoundStartDelay(Handle timer)
{
	ItemsSearchLoop();
	
	if (g_iItemLimits != -1)
	{
		if (!L4D2_InSecondHalfOfRound())
		{
			ItemTracking curitem;
			float origins[3], angles[3];
			int iEntCount = GetEntityCount();
			for (int i = MaxClients+1; i <= iEntCount; i++)
			{
				WeaponId source = IdentifyWeapon(i);
				if (source == WEPID_PAIN_PILLS && !SAFEDETECT_IsEntityInSaferoom(i))
				{
					if (g_iItemLimits == 0)
					{
						RemoveEntityLog(i);
					}
					else if (g_iItemLimits > 0)
					{
						curitem.IT_entity = i;
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
						GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
						curitem.IT_origins = origins[0];
						curitem.IT_origins1 = origins[1];
						curitem.IT_origins2 = origins[2];
						curitem.IT_angles = angles[0];
						curitem.IT_angles1 = angles[1];
						curitem.IT_angles2 = angles[2];
						g_hItemSpawns.PushArray(curitem, sizeof(curitem));
					}
				}
			}
			
			while (g_hItemSpawns.Length > g_iItemLimits)
			{
				int killidx = GetRandomInt(0, g_hItemSpawns.Length - 1);
				g_hItemSpawns.GetArray(killidx, curitem, sizeof(curitem));
				WeaponId source = IdentifyWeapon(curitem.IT_entity);
				if (source == WEPID_PAIN_PILLS)
				  RemoveEntityLog(curitem.IT_entity);
				RemoveFromArray(g_hItemSpawns, killidx);
			}
		}
		else
		{
			int iEntCount = GetEntityCount();
			for (int i = MaxClients+1; i <= iEntCount; i++)
			{
				WeaponId source = IdentifyWeapon(i);
				if (source == WEPID_PAIN_PILLS && !SAFEDETECT_IsEntityInSaferoom(i)) RemoveEntityLog(i);
			}
			
			ItemTracking curitem;
			float origins[3], angles[3];
			for (int idx = 0; idx < g_hItemSpawns.Length; idx++)
			{
				g_hItemSpawns.GetArray(idx, curitem, sizeof(curitem));
				origins[0] = curitem.IT_origins;
				origins[1] = curitem.IT_origins1;
				origins[2] = curitem.IT_origins2;
				angles[0] = curitem.IT_angles;
				angles[1] = curitem.IT_angles1;
				angles[2] = curitem.IT_angles2;
				SpawnPills(origins, angles);
			}
		}
	}
}

void ItemsSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int entity = MaxClients+1; entity <= iEntCount; entity++)
	{
		if (!IsValidEntity(entity) || !IsValidEdict(entity)) return;
		char classname[64];
		if (!GetEdictClassname(entity, classname, sizeof(classname))) return;
		
		char targetname[64];
		GetEdictName(entity, targetname, 64);
		if (StrContains(targetname, "_locker", false) != -1 && hNoLocker.BoolValue) RemoveEntityLog(entity);
		else if (StrContains(classname, "laser_sight", false) != -1 && hRemoveLaserSight.BoolValue) RemoveEntityLog(entity);
		else if (StrContains(classname, "minigun", false) != -1 && hNoMinigun.BoolValue) RemoveEntityLog(entity);
		else if (StrContains(classname, "fuel_barrel", false) != -1 && hNoFuelBarrel.BoolValue) RemoveEntityLog(entity);
		else if (StrEqual(classname, "prop_physics", false) && GetEntProp(entity, Prop_Send, "m_isCarryable"))
		{
			char model[128];
			GetEdictModelName(entity, model, sizeof(model));
			if (StrContains(model, "models/props_junk/gascan001a.mdl", false) != -1 && hNoCans.BoolValue) RemoveEntityLog(entity);
			else if (StrContains(model, "models/props_junk/propanecanister001a.mdl", false) != -1 && hNoPropane.BoolValue) RemoveEntityLog(entity);
			else if (StrContains(model, "models/props_equipment/oxygentank01.mdl", false) != -1 && hNoOxygen.BoolValue) RemoveEntityLog(entity);
			else if (StrContains(model, "models/props_junk/explosive_box001.mdl", false) != -1 && hNoFireworks.BoolValue) RemoveEntityLog(entity);
		}
		else
		{
			WeaponId source = IdentifyWeapon(entity);
			if (source == WEPID_CHAINSAW && hRemoveChainsaw.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_GRENADE_LAUNCHER && hRemoveGrenade.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_RIFLE_M60 && hRemoveM60.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_DEFIBRILLATOR && hRemoveDefib.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_UPGRADE_ITEM && hRemoveLaserSight.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_FRAG_AMMO && hRemoveUpgExplosive.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_INCENDIARY_AMMO && hRemoveUpgIncendiary.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_ADRENALINE && hRemoveAdrenaline.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_PIPE_BOMB && hRemovePipebomb.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_MOLOTOV && hRemoveMolotov.BoolValue) RemoveEntityLog(entity);
			if (source == WEPID_VOMITJAR && hRemoveVomitjar.BoolValue) RemoveEntityLog(entity);
			if (IsExtraItems(entity, source)) RemoveEntityLog(entity);
		}
	}
}

void SpawnPills(float origin[3], float angles[3])
{
	int entity = CreateEntityByName("weapon_spawn");
	SetEntProp(entity, Prop_Send, "m_weaponID", WEPID_PAIN_PILLS);
	DispatchKeyValue(entity, "count", "1");
	TeleportEntity(entity, origin, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
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

bool IsExtraItems(int entity, WeaponId source)
{
	if (!SAFEDETECT_IsEntityInSaferoom(entity) || !hRemoveExtraItems.BoolValue) return false;
	if (source == WEPID_CHAINSAW || source == WEPID_GRENADE_LAUNCHER || source == WEPID_RIFLE_M60 || source == WEPID_UPGRADE_ITEM) return true;
	if (WEPID_MOLOTOV <= source <= WEPID_OXYGEN_TANK) return true;
	if (WEPID_ADRENALINE <= source <= WEPID_VOMITJAR) return true;
	if (WEPID_FIREWORKS_BOX <= source <= WEPID_FRAG_AMMO) return true;
	return false;
}
