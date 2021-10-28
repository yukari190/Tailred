#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

public Plugin myinfo = 
{
	name = "Item Tracking",
	author = "Confogl Team, Yukari190",
	description = "A competitive mod for L4D2",
	version = "2.2.4b",
	url = "https://github.com/yukari190/Tailred"
};

enum ItemList
{
	IL_PainPills,
	IL_Adrenaline,
	// Not sure we need these.
	IL_FirstAid,
	//IL_Defib,  
	IL_PipeBomb,
	IL_Molotov,
	IL_VomitJar
};

enum ItemNames
{
	IN_shortname,	
	IN_longname, 	
	IN_officialname, 	
	IN_modelname 
};

enum struct ItemTracking
{
	int entity;
	float origins;
	float origins1;
	float origins2;
	float angles;
	float angles1;
	float angles2;
}

static const char sItemNames[ItemList][ItemNames][] =
{
	{ "pills", "pain pills", "pain_pills", "painpills" },
	{ "adrenaline", "adrenaline shots", "adrenaline", "pipebomb" },
	{ "kits", "first aid kits", "first_aid_kit", "medkit" },
	// { "defib", "defibrillators", "defibrillator", "defibrillator" },
	{ "pipebomb", "pipe bombs", "pipe_bomb", "pipebomb" },
	{ "molotov", "molotovs", "molotov", "molotov" },
	{ "vomitjar", "bile bombs", "vomitjar", "bile_flask" }
};

ConVar
	hCvarEnabled = null,
	hCvarConsistentSpawns = null,
	hCvarMapSpecificSpawns = null,
	hCvarLimits[view_as<int>(ItemList)],
	hReplaceFinaleKits = null,
	hRemoveKits = null;

ArrayList
	hItemSpawns[view_as<int>(ItemList)];

int
	iItemLimits[view_as<int>(ItemList)];

bool
	bExtraWeapon[4096];

public void OnPluginStart()
{
	// Create item spawns array;
	for (int i = 0; i < view_as<int>(ItemList); i++)
	{
		hItemSpawns[i] = new ArrayList(sizeof(ItemTracking)); 
	}
	
	char sNameBuf[64], sCvarDescBuf[256];
	
	hCvarEnabled = CreateConVar("sm_enable_itemtracking", "0", "Enable the itemtracking module", CVAR_FLAGS, true, 0.0, true, 1.0);
	hCvarConsistentSpawns = CreateConVar("sm_itemtracking_savespawns", "0", "Keep item spawns the same on both rounds", CVAR_FLAGS, true, 0.0, true, 1.0);
	hCvarMapSpecificSpawns = CreateConVar("sm_itemtracking_mapspecific", "0", "Change how mapinfo.txt overrides work. 0 = ignore mapinfo.txt, 1 = allow limit reduction, 2 = allow limit increases,", CVAR_FLAGS, true, 0.0, true, 2.0);
	
	// Create itemlimit cvars
	for(int i = 0; i < view_as<int>(ItemList); i++)
	{
		Format(sNameBuf, sizeof(sNameBuf), "sm_%s_limit", sItemNames[i][IN_shortname]);
		Format(sCvarDescBuf, sizeof(sCvarDescBuf), "Limits the number of %s on each map. -1: no limit; >=0: limit to cvar value", sItemNames[i][IN_longname]);
		hCvarLimits[i] = CreateConVar(sNameBuf, "-1", sCvarDescBuf, CVAR_FLAGS);
	}
	
	hReplaceFinaleKits = CreateConVar("sm_replace_finalekits", "1", "Replaces finale medkits with pills", CVAR_FLAGS, true, 0.0, true, 1.0);
	hRemoveKits = CreateConVar("sm_remove_statickits", "1", "Remove all static medkits (medkits such as the gun shop, these are compiled into the map)", CVAR_FLAGS, true, 0.0, true, 1.0);
	
	RegAdminCmd("sm_item_track", Command_ItemTrack, ADMFLAG_ROOT, "");
}

public Action Command_ItemTrack(int client, int args)
{
	if (!client) return Plugin_Handled;
	WeaponSearchLoop();
	return Plugin_Handled;
}

public void OnMapStart()
{
	for (int i; i < view_as<int>(ItemList); i++) iItemLimits[i] = hCvarLimits[i].IntValue;
	if (hCvarMapSpecificSpawns.IntValue)
	{
		int itemlimit;
		KeyValues kOverrideLimits = new KeyValues("ItemLimits");
		L4D2_CopyMapSubsection(kOverrideLimits, "ItemLimits");
		for (int i = 0; i < view_as<int>(ItemList); i++)
		{
			itemlimit = hCvarLimits[i].IntValue;
			int temp = KvGetNum(kOverrideLimits, sItemNames[i][IN_officialname], itemlimit);
			if (((iItemLimits[i] > temp) && (hCvarMapSpecificSpawns.IntValue & 1)) || ((iItemLimits[i] < temp) && (hCvarMapSpecificSpawns.IntValue & 2)))
			{
				iItemLimits[i] = temp;
			}
			hItemSpawns[i].Clear();
		}
		delete kOverrideLimits;
	}
}

public void L4D2_OnRealRoundStart()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		bExtraWeapon[i] = false;
	}
	
	// Mapstart happens after round_start most of the time, so we need to wait for bIsRound1Over.
	// Plus, we don't want to have conflicts with EntityRemover.
	CreateTimer(1.0, RoundStartTimer);
}

public Action RoundStartTimer(Handle timer)
{
	if(!InSecondHalfOfRound())
	{
		// Round1
		if(hCvarEnabled.BoolValue)
		{
			EnumAndElimSpawns();
		}
	}
	else
	{
		// Round2
		if(hCvarEnabled.BoolValue)
		{
			if(hCvarConsistentSpawns.BoolValue)
			{
				GenerateStoredSpawns();
			}
			else
			{
				EnumAndElimSpawns(); 
			}
		}
	}
	
	WeaponSearchLoop();
	
	return Plugin_Handled;
}

void WeaponSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		CheckEntity(i);
	}
}

void CheckEntity(int entity)
{
	ItemList itemindex = GetItemIndexFromEntity(entity);
	if (itemindex >= view_as<ItemList>(0) && !L4D2_IsEntityInSaferoom(entity) && !bExtraWeapon[entity])
	{
		if (itemindex == IL_FirstAid)
		{
			if (hReplaceFinaleKits.BoolValue && L4D_IsMissionFinalMap())
			{
				ReplaceKits(entity);
			}
			else if (hRemoveKits.BoolValue)
			{
				RemoveEntityLog(entity);
			}
		}
		
		// Item limit is zero, justkill it as we find it
		else if (iItemLimits[itemindex] == 0)
		{
			RemoveEntityLog(entity);
		}
	}
}

void EnumAndElimSpawns()
{
	EnumerateSpawns();
	RemoveToLimits();
}

void GenerateStoredSpawns()
{
	KillRegisteredItems();
	SpawnItems();
}

void KillRegisteredItems()
{
	ItemList itemindex;
	int psychonic = GetEntityCount();
	for (int i = MaxClients+1; i <= psychonic; i++)
	{
		itemindex = GetItemIndexFromEntity(i);
		if (itemindex >= view_as<ItemList>(0) && !L4D2_IsEntityInSaferoom(i) && !bExtraWeapon[i])
		{
			// Item limit is zero, justkill it as we find it
			if (iItemLimits[itemindex] > 0)
			{
				// Kill items we're tracking;
				RemoveEntityLog(i);
			}
		}
	}
}

void SpawnItems()
{
	ItemTracking curitem;
	float origins[3], angles[3];
	int arrsize;
	int itement;
	char sModelname[PLATFORM_MAX_PATH];
	WeaponId wepid;
	for (int itemidx = 0; itemidx < view_as<int>(ItemList); itemidx++)
	{
		Format(sModelname, sizeof(sModelname), "models/w_models/weapons/w_eq_%s.mdl", sItemNames[itemidx][IN_modelname]);
		arrsize = hItemSpawns[itemidx].Length;
		for (int idx = 0; idx < arrsize; idx++)
		{
			hItemSpawns[itemidx].GetArray(idx, curitem);
			GetSpawnOrigins(origins, curitem);
			GetSpawnAngles(angles, curitem);
			wepid = GetWeaponIDFromItemList(view_as<ItemList>(itemidx));
			itement = CreateEntityByName("weapon_spawn");
			SetEntProp(itement, Prop_Send, "m_weaponID", wepid);
			SetEntityModel(itement, sModelname);
			DispatchKeyValue(itement, "count", "1");
			TeleportEntity(itement, origins, angles, NULL_VECTOR);
			DispatchSpawn(itement);
			SetEntityMoveType(itement,MOVETYPE_NONE);
		}
	}
}

void EnumerateSpawns()
{
	ItemList itemindex;
	ItemTracking curitem;
	float origins[3], angles[3];
	int psychonic = GetEntityCount();
	for (int i = MaxClients+1; i <= psychonic; i++)
	{
		itemindex = GetItemIndexFromEntity(i);
		if (itemindex >= view_as<ItemList>(0) && !L4D2_IsEntityInSaferoom(i) && !bExtraWeapon[i])
		{
			// Item limit is zero, justkill it as we find it
			if (iItemLimits[itemindex] > 0)
			{
				// Store entity, angles, origin
				curitem.entity=i;
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
				GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
				SetSpawnOrigins(origins, curitem);
				SetSpawnAngles(angles, curitem);
				
				// Push this instance onto our array for that item
				hItemSpawns[itemindex].PushArray(curitem);
			}
		}
	}
}

void RemoveToLimits()
{
	int curlimit;
	ItemTracking curitem;
	for (int itemidx = 0; itemidx < view_as<int>(ItemList); itemidx++)
	{
		curlimit = iItemLimits[view_as<ItemList>(itemidx)];
		if (curlimit >0)
		{
			// Kill off item spawns until we've reduced the item to the limit
			while (hItemSpawns[itemidx].Length > curlimit)
			{
				// Pick a random
				int killidx = GetURandomIntRange(0, hItemSpawns[itemidx].Length - 1);
				hItemSpawns[itemidx].GetArray(killidx, curitem);
				if (IsValidEntity(curitem.entity))
				{
					RemoveEntityLog(curitem.entity);
				}
				hItemSpawns[itemidx].Erase(killidx);
			}
		}
		// If limit is 0, they're already dead. If it's negative, we kill nothing.
	}
}

void SetSpawnOrigins(const float buf[3], ItemTracking spawn)
{
	spawn.origins = buf[0];
	spawn.origins1 = buf[1];
	spawn.origins2 = buf[2];
}

void SetSpawnAngles(const float buf[3], ItemTracking spawn)
{
	spawn.angles = buf[0];
	spawn.angles1 = buf[1];
	spawn.angles2 = buf[2];
}

void GetSpawnOrigins(float buf[3], const ItemTracking spawn)
{
	buf[0] = spawn.origins;
	buf[1] = spawn.origins1;
	buf[2] = spawn.origins2;
}

void GetSpawnAngles(float buf[3], const ItemTracking spawn)
{
	buf[0] = spawn.angles;
	buf[1] = spawn.angles1;
	buf[2] = spawn.angles2;
}

WeaponId GetWeaponIDFromItemList(ItemList id)
{
	switch(id)
	{
		case IL_PainPills:
		{
			return WEPID_PAIN_PILLS;
		}
		case IL_Adrenaline:
		{
			return WEPID_ADRENALINE;
		}
		case IL_FirstAid:
		{
			return WEPID_FIRST_AID_KIT;
		}
		case IL_PipeBomb:
		{
			return WEPID_PIPE_BOMB;
		}
		case IL_Molotov:
		{
			return WEPID_MOLOTOV;
		}
		case IL_VomitJar:
		{
			return WEPID_VOMITJAR;
		}
		default:
		{
		
		}
	}
	return WEPID_NONE;
}

ItemList GetItemIndexFromEntity(int entity)
{
	WeaponId id = IdentifyWeapon(entity);
	switch(id)
	{
		case WEPID_VOMITJAR:
		{
			return IL_VomitJar;
		}
		case WEPID_PIPE_BOMB:
		{
			return IL_PipeBomb;
		}
		case WEPID_MOLOTOV:
		{
			return IL_Molotov;
		}
		case WEPID_PAIN_PILLS:
		{
			return IL_PainPills;
		}
		case WEPID_ADRENALINE:
		{
			return IL_Adrenaline;
		}
		case WEPID_FIRST_AID_KIT:
		{
			return IL_FirstAid;
		}
		default:
		{
		
		}
	}
	return view_as<ItemList>(-1);
}

int GetURandomIntRange(int min, int max)
{
	return RoundToNearest((GetURandomFloat() * (max-min))+min);
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

void ReplaceKits(int entity)
{
	float origins[3], angles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origins);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
	RemoveEntityLog(entity);
	SpawnPills(origins, angles);
}

void SpawnPills(float origin[3], float angles[3])
{
	int entity = CreateEntityByName("weapon_spawn");
	bExtraWeapon[entity] = true;
	SetEntProp(entity, Prop_Send, "m_weaponID", WEPID_PAIN_PILLS);
	DispatchKeyValue(entity, "count", "1");
	TeleportEntity(entity, origin, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
}
