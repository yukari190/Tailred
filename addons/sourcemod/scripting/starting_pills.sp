#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
    name = "Starting Items",
    author = "CircleSquared + Jacob",
    description = "Gives health items and throwables to survivors at the start of each round",
    version = "1.1",
    url = "none"
}

bool g_bReadyUpAvailable = false;

public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
}
public void OnLibraryRemoved(const char[] name)
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = false; }
}
public void OnLibraryAdded(const char[] name)
{
    if ( StrEqual(name, "readyup") ) { g_bReadyUpAvailable = true; }
}

public void OnRoundIsLive()
{
	GiveStartingItem();
}

public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
    if (!g_bReadyUpAvailable) GiveStartingItem();
}	

void GiveStartingItem()
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
			DispatchSpawn(startingItem);
			TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
			EquipPlayerWeapon(index, startingItem);
		}
	}
}