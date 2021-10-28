#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2lib>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

#define HEALTH_FIRST_AID_KIT    (1 << 0)
#define HEALTH_DEFIBRILLATOR    (1 << 1)

#define HEALTH_PAIN_PILLS       (1 << 2)
#define HEALTH_ADRENALINE       (1 << 3)

#define THROWABLE_PIPE_BOMB     (1 << 4)
#define THROWABLE_MOLOTOV       (1 << 5)
#define THROWABLE_VOMITJAR      (1 << 6)

#define WEAPON_NAME_MAX 32

public Plugin myinfo =
{
	name = "Starting Items",
	author = "CircleSquared, Jacob, robex",
	description = "Gives health items and throwables to survivors at the start of each round",
	version = "2.0",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

ConVar
	hCvarItemType = null;
bool
	bReadyUpAvailable;

public void OnAllPluginsLoaded()
{
    bReadyUpAvailable = LibraryExists("readyup");
}
public void OnLibraryRemoved(const char[] name)
{
    if ( StrEqual(name, "readyup") ) { bReadyUpAvailable = false; }
}
public void OnLibraryAdded(const char[] name)
{
    if ( StrEqual(name, "readyup") ) { bReadyUpAvailable = true; }
}

public void OnPluginStart()
{
	hCvarItemType = CreateConVar("starting_item_flags", "4", "Item flags to give on leaving the saferoom (1: Kit, 2: Defib, 4: Pills, 8: Adren, 16: Pipebomb, 32: Molotov, 64: Bile)", FCVAR_SPONLY|FCVAR_NOTIFY);
}

public void OnRoundIsLive()
{
	DetermineItems();
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    if (!bReadyUpAvailable) DetermineItems();
}

void DetermineItems()
{
	int iItemFlags = GetConVarInt(hCvarItemType);

	if (iItemFlags < 1) {
		return;
	}

	ArrayList items = new ArrayList(ByteCountToCells(WEAPON_NAME_MAX));

	if (iItemFlags & HEALTH_FIRST_AID_KIT) {
		items.PushString("weapon_first_aid_kit");
	} else if (iItemFlags & HEALTH_DEFIBRILLATOR) {
		items.PushString("weapon_defibrillator");
	}

	if (iItemFlags & HEALTH_PAIN_PILLS) {
		items.PushString("weapon_pain_pills");
	} else if (iItemFlags & HEALTH_ADRENALINE) {
		items.PushString("weapon_adrenaline");
	}

	if (iItemFlags & THROWABLE_PIPE_BOMB) {
		items.PushString("weapon_pipe_bomb");
	} else if (iItemFlags & THROWABLE_MOLOTOV) {
		items.PushString("weapon_molotov");
	} else if (iItemFlags & THROWABLE_VOMITJAR) {
		items.PushString("weapon_vomitjar");
	}

	if (items.Length > 0) {
		giveStartingItems(items);
	}
	delete items;
}

void giveStartingItems(ArrayList items)
{
	char itemName[WEAPON_NAME_MAX];

	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		
		for (int j = 0; j < items.Length; j++)
		{
			items.GetString(j, itemName, WEAPON_NAME_MAX);
			giveItem(index, itemName);
		}
	}
}

void giveItem(int client, char[] itemName)
{
	float clientOrigin[3];

	int startingItem = CreateEntityByName(itemName);
	GetClientAbsOrigin(client, clientOrigin);
	DispatchSpawn(startingItem);
	TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
	EquipPlayerWeapon(client, startingItem);
}
