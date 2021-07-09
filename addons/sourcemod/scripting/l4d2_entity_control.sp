#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>
#include <[LIB]l4d2_weapon_stocks>

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

ConVar cPillsLimits;
ConVar cSurvivorLimit;
ConVar cNoCans;
ConVar cNoPropane;
ConVar cNoOxygen;
ConVar cNoFireworks;
ConVar cNoLaser;
ConVar cNoMinigun;
ConVar cNoFuelBarrel;

bool bNoCans = true;
bool bNoPropane = true;
bool bNoOxygen = true;
bool bNoFireworks = true;
bool bNoLaser = true;
bool bNoMinigun = true;
bool bNoFuelBarrel = true;

int g_iItemLimits;
int g_GlobalWeaponRules[view_as<int>(WEPID_UPGRADE_ITEM)+1];
int g_iSurvivorLimit;

public void OnPluginStart()
{
	g_hItemSpawns = new ArrayList(sizeof(ItemTracking));
	
	for (int i = 0; i < view_as<int>(WEPID_UPGRADE_ITEM)+1; i++)
	  g_GlobalWeaponRules[i] = -1;
	
	cSurvivorLimit = FindConVar("survivor_limit");
	cPillsLimits = CreateConVar("l4d2_pills_limit", "-1", "限制每张地图上止痛药的数量. -1: 没有限制; >=0: 限制为cvar值");
    cNoCans = CreateConVar("l4d_no_cans", "1", "Remove Gascans?", FCVAR_NONE);
    cNoPropane = CreateConVar("l4d_no_propane", "1", "Remove Propane Tanks?", FCVAR_NONE);
    cNoOxygen = CreateConVar("l4d_no_oxygen", "1", "Remove Oxygen Tanks?", FCVAR_NONE);
    cNoFireworks = CreateConVar("l4d_no_fireworks", "1", "Remove Fireworks?", FCVAR_NONE);
    cNoLaser = CreateConVar("l4d_no_laser", "1", "Remove Laser Sight?", FCVAR_NONE);
    cNoMinigun = CreateConVar("l4d_no_minigun", "1", "Remove Minigun?", FCVAR_NONE);
    cNoFuelBarrel = CreateConVar("l4d_no_fuelbarrel", "1", "Remove Fuel Barrel?", FCVAR_NONE);
	
	cSurvivorLimit.AddChangeHook(ConVarChange);
	cPillsLimits.AddChangeHook(ConVarChange);
	cNoCans.AddChangeHook(ConVarChange);
	cNoPropane.AddChangeHook(ConVarChange);
	cNoOxygen.AddChangeHook(ConVarChange);
	cNoFireworks.AddChangeHook(ConVarChange);
	cNoLaser.AddChangeHook(ConVarChange);
	cNoMinigun.AddChangeHook(ConVarChange);
	cNoFuelBarrel.AddChangeHook(ConVarChange);

	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
    RegServerCmd("l4d2_addweaponrule", AddWeaponRuleCb);
    RegServerCmd("l4d2_resetweaponrules", ResetWeaponRulesCb);
	
	HookEvent("player_use", OnPlayerUse, EventHookMode_PostNoCopy);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iItemLimits = cPillsLimits.IntValue;
	g_iSurvivorLimit = cSurvivorLimit.IntValue;
	bNoCans = cNoCans.BoolValue;
	bNoPropane = cNoPropane.BoolValue;
	bNoOxygen = cNoOxygen.BoolValue;
	bNoFireworks = cNoFireworks.BoolValue;
	bNoLaser = cNoLaser.BoolValue;
	bNoMinigun = cNoMinigun.BoolValue;
	bNoFuelBarrel = cNoFuelBarrel.BoolValue;
}

public void L4D2_OnEntitySpawned(int entity, char[] classname)
{
	if (StrContains(classname,"upgrade_laser_sight", false) != -1)
	{
		if (bNoLaser) RemoveEntityLog(entity);
	}
	else if (StrContains(classname,"prop_minigun", false) != -1)
	{
		if (bNoMinigun) RemoveEntityLog(entity);
	}
	else if (StrContains(classname,"prop_fuel_barrel", false) != -1)
	{
		if (bNoFuelBarrel) RemoveEntityLog(entity);
	}
	else if (StrEqual(classname,"prop_physics", false) && GetEntProp(entity, Prop_Send, "m_isCarryable"))
	{
		char model[128];
		L4D2_GetEntityModelName(entity, model, sizeof(model));
		if (StrContains(model, "models/props_junk/gascan001a.mdl", false) != -1)
		{
			if (bNoCans) RemoveEntityLog(entity);
		}
		else if (StrContains(model, "models/props_junk/propanecanister001a.mdl", false) != -1)
		{
			if (bNoPropane) RemoveEntityLog(entity);
		}
		else if (StrContains(model, "models/props_equipment/oxygentank01.mdl", false) != -1)
		{
			if (bNoOxygen) RemoveEntityLog(entity);
		}
		else if (StrContains(model, "models/props_junk/explosive_box001.mdl", false) != -1)
		{
			if (bNoFireworks) RemoveEntityLog(entity);
		}
	}
	else
	{
		WeaponId source;
		if (StrEqual(classname, "weapon_spawn") || StrEqual(classname, "weapon_item_spawn"))
		{
			source = view_as<WeaponId>(GetEntProp(entity, Prop_Send, "m_weaponID"));
		}
		else
		{
			int len = strlen(classname);
			if (len-6 > 0 && StrEqual(classname[len-6], "_spawn"))
			{
				classname[len-6]='\0';
				source = WeaponNameToId(classname);
			}
			else
			  source = WeaponNameToId(classname);
		}
		if (
			(source == WEPID_FIRST_AID_KIT && (!L4D_IsMissionFinalMap() || L4D_IsEntityInSaferoom(entity))) ||
			source == WEPID_CHAINSAW || source == WEPID_DEFIBRILLATOR ||
			source == WEPID_UPGRADE_ITEM || source == WEPID_FRAG_AMMO ||
			source == WEPID_INCENDIARY_AMMO || source == WEPID_ADRENALINE ||
			source == WEPID_MOLOTOV || source == WEPID_VOMITJAR
		)
		{
			RemoveEntityLog(entity);
		}
	}
}

public void OnMapStart()
{
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    if (StrEqual(mapname, "c2m1_highway", false) ||
      StrEqual(mapname, "c2m3_coaster", false) ||
      StrEqual(mapname, "c3m4_plantation", false) ||
      StrEqual(mapname, "c4m2_sugarmill_a", false) ||
	  StrEqual(mapname, "c4m3_sugarmill_b", false))
	  DisableClips();
    else if (StrEqual(mapname, "c5m1_waterfront", false))
    {
        DisableClips();
        DisableFuncBrush();
    }
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
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
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
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

public void L4D_OnRoundStart()
{
	CreateTimer(0.1, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action RoundStartDelay(Handle timer)
{
	if (L4D2_IsServerActive())
	{
		if (g_iItemLimits != -1)
		{
			if (!L4D2_IsSecondRound())
			{
				ItemTracking curitem;
				float origins[3], angles[3];
				int iEntCount = GetEntityCount();
				for (int i = MaxClients+1; i <= iEntCount; i++)
				{
					if (!IsValidEntity(i) || !IsValidEdict(i)) continue;
					char class[64];
					if (!GetEdictClassname(i, class, sizeof(class))) continue;
					WeaponId source;
					if (StrEqual(class, "weapon_spawn") || StrEqual(class, "weapon_item_spawn"))
					{
						source = view_as<WeaponId>(GetEntProp(i, Prop_Send, "m_weaponID"));
					}
					else
					{
						int len = strlen(class);
						if (len-6 > 0 && StrEqual(class[len-6], "_spawn"))
						{
							class[len-6]='\0';
							source = WeaponNameToId(class);
						}
						else
						  source = WeaponNameToId(class);
					}
					if (source == WEPID_PAIN_PILLS)
					{
						if (L4D_IsEntityInSaferoom(i))
						  RemoveEntityLog(i);
						else
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
				}
				
				while (GetArraySize(g_hItemSpawns) > g_iItemLimits)
				{
					int killidx = GetRandomInt(0, GetArraySize(g_hItemSpawns)-1);
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
					if (!IsValidEntity(i) || !IsValidEdict(i)) continue;
					char class[64];
					if (!GetEdictClassname(i, class, sizeof(class))) continue;
					WeaponId source;
					if (StrEqual(class, "weapon_spawn") || StrEqual(class, "weapon_item_spawn"))
					{
						source = view_as<WeaponId>(GetEntProp(i, Prop_Send, "m_weaponID"));
					}
					else
					{
						int len = strlen(class);
						if (len-6 > 0 && StrEqual(class[len-6], "_spawn"))
						{
							class[len-6]='\0';
							source = WeaponNameToId(class);
						}
						else
						  source = WeaponNameToId(class);
					}
					if (source == WEPID_PAIN_PILLS)
					  RemoveEntityLog(i);
				}
				
				ItemTracking curitem;
				float origins[3], angles[3];
				for (int idx = 0; idx < GetArraySize(g_hItemSpawns); idx++)
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
		EntitySearchLoop();
		
		return;
	}
	CreateTimer(1.0, RoundStartDelay, _, TIMER_FLAG_NO_MAPCHANGE);
}

//Event
public Action OnPlayerUse(Event event, const char[] name, bool dontBroadcast)
{
	EntitySearchLoop();
}

void EntitySearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (!IsValidEntity(i) || !IsValidEdict(i)) continue;
		char classname[64];
		if (!GetEdictClassname(i, classname, sizeof(classname))) continue;
		WeaponId source;
		if (StrEqual(classname, "weapon_spawn") || StrEqual(classname, "weapon_item_spawn"))
		{
			source = view_as<WeaponId>(GetEntProp(i, Prop_Send, "m_weaponID"));
		}
		else
		{
			int len = strlen(classname);
			if (len-6 > 0 && StrEqual(classname[len-6], "_spawn"))
			{
				classname[len-6]='\0';
				source = WeaponNameToId(classname);
			}
			else
			  source = WeaponNameToId(classname);
		}
		
		if (g_iSurvivorLimit > 1 && source == WEPID_FIRST_AID_KIT && L4D_IsMissionFinalMap() && !L4D_IsEntityInSaferoom(i))
		{
			float origins[3], angles[3];
			GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
			GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
			RemoveEntityLog(i);
			SpawnPills(origins, angles);
		}
		
		if (g_GlobalWeaponRules[source] != -1)
		{
			if (g_GlobalWeaponRules[source] == view_as<int>(WEPID_NONE))
			  RemoveEntityLog(i);
			else
			  ConvertWeaponSpawn(i, view_as<WeaponId>(g_GlobalWeaponRules[source]));
		}
	}
}

//Command
public Action AddWeaponRuleCb(int args)
{
    if (args < 2)
    {
        LogMessage("Usage: l4d2_addweaponrule <match> <replace>");
        return Plugin_Handled;
    }
    char weaponbuf[64];
    GetCmdArg(1, weaponbuf, sizeof(weaponbuf));
    WeaponId match = WeaponNameToId2(weaponbuf);
    GetCmdArg(2, weaponbuf, sizeof(weaponbuf));
    WeaponId to = WeaponNameToId2(weaponbuf);
	if (IsValidWeaponId(match) && (to == view_as<WeaponId>(-1) || IsValidWeaponId(to))) g_GlobalWeaponRules[match] = view_as<int>(to);
    return Plugin_Handled;
}

public Action ResetWeaponRulesCb(int args)
{
    for (int i = 0; i < view_as<int>(WEPID_UPGRADE_ITEM)+1; i++)
	  g_GlobalWeaponRules[i] = -1;
    return Plugin_Handled;
}

//Stock
void DisableClips()
{
    ModifyEntity("env_player_blocker", "Disable");
}

void DisableFuncBrush()
{
    ModifyEntity("func_brush", "Kill");
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

void SpawnPills(float origin[3], float angles[3])
{
	int entity = CreateEntityByName("weapon_spawn");
	SetEntProp(entity, Prop_Send, "m_weaponID", WEPID_PAIN_PILLS);
	DispatchKeyValue(entity, "count", "1");
	TeleportEntity(entity, origin, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
}

WeaponId WeaponNameToId2(const char[] name)
{
    static char namebuf[64]="weapon_";
    WeaponId wepid = WeaponNameToId(name);
    if (wepid == WEPID_NONE)
    {
        strcopy(namebuf[7], sizeof(namebuf)-7, name);
        wepid = WeaponNameToId(namebuf);
    }
    return wepid;
}

void RemoveEntityLog(int entity)
{
	char classname[64];
	GetEdictClassname(entity, classname, 64);
	if (!AcceptEntityInput(entity, "kill"))
	{
		LogError("[l4d2_entity_control] 删除实体 %s 失败", classname);
	}
	else
	{
		PrintToServer("[l4d2_entity_control] Removed %s", classname);
	}
}
