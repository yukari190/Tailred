#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <l4d2lib>

#define SPAWNCOUNT 4

public Plugin myinfo = 
{
	name = "Saferoom Gun Control",
	author = "",
	description = "",
	version = "1.0",
	url = ""
};

static const WeaponId safeSpawns[SPAWNCOUNT] =
{
	WEPID_SHOTGUN_CHROME,
	WEPID_SMG_SILENCED,
	WEPID_SNIPER_SCOUT,
	WEPID_AMMO
};

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.1, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_DelayedOnRoundStart(Handle timer)
{
	if (GetSeriousClientCount() != 0)
	{
		float SpawnPosition[3], SpawnAngle[3];
		int count = 0;
		for (int i = 0; i < L4D2_GetSurvivorCount() && count < SPAWNCOUNT; i++)
		{
			int index = L4D2_GetSurvivorOfIndex(i);
			if (index == 0) continue;
			GetClientAbsOrigin(index, SpawnPosition);
			SpawnAngle[1] = 135.0;SpawnAngle[2] = 90.0;
			SpawnWeapon(safeSpawns[count], SpawnPosition, SpawnAngle);
			count++;
		}
		return;
	}
	CreateTimer(1.1, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

int GetSeriousClientCount()
{
	int clients = 0;
	
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		clients++;
	}
	
	return clients;
}

bool SpawnWeapon(WeaponId wepid, float origins[3], float angles[3])
{
	if(!IsValidWeaponId(wepid)) return false;
	//if(!HasValidWeaponModel(wepid)) return false;

	if (wepid == WEPID_AMMO)
	{
		int entity = CreateEntityByName("weapon_ammo_spawn");
		SetEntityModel(entity, "models/props/terror/ammo_stack.mdl");
		DispatchSpawn(entity);
		ActivateEntity(entity);
		TeleportEntity(entity, origins, NULL_VECTOR, NULL_VECTOR);
		return true;
	}
	int entity = CreateEntityByName("weapon_spawn");
	if(!IsValidEntity(entity)) return false;
	SetEntProp(entity, Prop_Send, "m_weaponID", wepid);

	DispatchKeyValue(entity, "count", "5");

	TeleportEntity(entity, origins, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
	return true;
}
