#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util>

#define SAFEROOM_END        1
#define SAFEROOM_START      2

public Plugin myinfo = 
{
	name = "Saferoom Item Remover",
	author = "Tabun, Sir, Yukari190",
	description = "Removes any saferoom item (start or end).",
	version = "0.0.7b",
	url = ""
};

enum eTrieItemKillable
{
	ITEM_KILLABLE           = 0,
	ITEM_KILLABLE_HEALTH    = (1 << 0),    //1
	ITEM_KILLABLE_WEAPON    = (1 << 1),    //2
	ITEM_KILLABLE_MELEE     = (1 << 2),    //4
	ITEM_KILLABLE_OTHER     = (1 << 3)    //8
};

ConVar
	g_hCvarEnabled = null,
	g_hCvarSaferoom = null,
	g_hCvarItems = null;

StringMap
	g_hTrieItems = null;

public void OnPluginStart()
{
	g_hCvarEnabled = CreateConVar("sm_safeitemkill_enable", "1", "Whether end saferoom items should be removed.", FCVAR_NONE, true, 0.0, true, 1.0);
	g_hCvarSaferoom = CreateConVar("sm_safeitemkill_saferooms", "1", "Saferooms to empty. Flags: 1 = end saferoom, 2 = start saferoom (3 = kill items from both).", FCVAR_NONE, true, 0.0, false);
	g_hCvarItems = CreateConVar("sm_safeitemkill_items", "7", "Types to rmove. Flags: 1 = health items, 2 = guns, 4 = melees, 8 = all other usable items", FCVAR_NONE, true, 0.0, false);
	
	PrepareTrie();
}

/*public void OnEntityCreated(int entity, const char[] classname)
{
	if (!g_hCvarEnabled.BoolValue) return;
	eTrieItemKillable checkItem;
	if (g_hTrieItems.GetValue(classname, checkItem))
	{
		SDKHook(entity, SDKHook_SpawnPost, fOnEntitySpawned);
	}
}

public void fOnEntitySpawned(int entity)
{
	CheckEntity(entity);
}*/

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
		CheckEntity(i);
	}
}

void CheckEntity(int entity)
{
	if (g_hCvarEnabled.BoolValue && IsValidEntity(entity))
	{
		char classname[64];
		GetEdictClassname(entity, classname, 64);
		
		eTrieItemKillable checkItem;
		
		if (g_hTrieItems.GetValue(classname, checkItem))
		{
			if (checkItem == ITEM_KILLABLE || GetConVarInt(g_hCvarItems) & view_as<int>(checkItem))
			{
				if (GetConVarInt(g_hCvarSaferoom) & SAFEROOM_END)
				{
					if (L4D2_IsEntityInSaferoom(entity) == Saferoom_End)
					{
						RemoveEntityLog(entity);
					}
				}
				
				if (GetConVarInt(g_hCvarSaferoom) & SAFEROOM_START)
				{
					if (L4D2_IsEntityInSaferoom(entity) == Saferoom_Start)
					{
						RemoveEntityLog(entity);
					}
				}
			}
		}
	}
}

void PrepareTrie()
{
	g_hTrieItems = new StringMap();
	g_hTrieItems.SetValue("weapon_spawn",                         ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_ammo_spawn",                    ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_pistol_spawn",                  ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_pistol_magnum_spawn",           ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_smg_spawn",                     ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_smg_silenced_spawn",            ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_pumpshotgun_spawn",             ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_shotgun_chrome_spawn",          ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_hunting_rifle_spawn",           ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_sniper_military_spawn",         ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_rifle_spawn",                   ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_rifle_ak47_spawn",              ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_rifle_desert_spawn",            ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_autoshotgun_spawn",             ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_shotgun_spas_spawn",            ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_rifle_m60_spawn",               ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_grenade_launcher_spawn",        ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_chainsaw_spawn",                ITEM_KILLABLE_WEAPON);
	g_hTrieItems.SetValue("weapon_melee_spawn",                   ITEM_KILLABLE_MELEE);
	g_hTrieItems.SetValue("weapon_item_spawn",                    ITEM_KILLABLE_HEALTH);
	g_hTrieItems.SetValue("weapon_first_aid_kit_spawn",           ITEM_KILLABLE_HEALTH);
	g_hTrieItems.SetValue("weapon_defibrillator_spawn",           ITEM_KILLABLE_HEALTH);
	g_hTrieItems.SetValue("weapon_pain_pills_spawn",              ITEM_KILLABLE_HEALTH);
	g_hTrieItems.SetValue("weapon_adrenaline_spawn",              ITEM_KILLABLE_HEALTH);
	g_hTrieItems.SetValue("weapon_pipe_bomb_spawn",               ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("weapon_molotov_spawn",                 ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("weapon_vomitjar_spawn",                ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("weapon_gascan_spawn",                  ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("upgrade_spawn",                        ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("upgrade_laser_sight",                  ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("weapon_upgradepack_explosive_spawn",   ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("weapon_upgradepack_incendiary_spawn",  ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("upgrade_ammo_incendiary",              ITEM_KILLABLE_OTHER);
	g_hTrieItems.SetValue("upgrade_ammo_explosive",               ITEM_KILLABLE_OTHER);
	//g_hTrieItems.SetValue("prop_fuel_barrel",                     ITEM_KILLABLE);
	//g_hTrieItems.SetValue("prop_physics",                         ITEM_KILLABLE);
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
