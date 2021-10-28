#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2util>
#include <l4d2lib>
#undef REQUIRE_PLUGIN
#include <readyup>

#define SPAWNCOUNT 3

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
	WEPID_AMMO_PACK
};

public void OnRoundIsLive()
{
	GiveStartingWeapon();
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.1, Timer_DelayedOnRoundStart);
}

public Action Timer_DelayedOnRoundStart(Handle timer)
{
	if (GetSeriousClientCount(true) != 0)
	{
		float SpawnPosition[3], SpawnAngle[3];
		int count = 0;
		for (int i = 0; i < L4D2_GetSurvivorCount() && count < SPAWNCOUNT; i++)
		{
			int index = L4D2_GetSurvivorOfIndex(i);
			if (index == 0) continue;
			GetClientAbsOrigin(index, SpawnPosition);
			SpawnAngle[1] = 135.0;SpawnAngle[2] = 90.0;
			WeaponId wepid = safeSpawns[count];
			if (wepid == WEPID_AMMO_PACK)
			{
				SpawnAmmo(SpawnPosition);
			}
			else
			{
				CreateWeaponSpawn(wepid, SpawnPosition, SpawnAngle);
			}
			count++;
		}
		return;
	}
	CreateTimer(1.1, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
}

void GiveStartingWeapon()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsFakeClient(index)) continue;
		CheatCommand(index, "give", "pistol");
		if (GetPlayerWeaponSlot(index, 0) <= -1)
		{
			CheatCommand(index, "give", "smg_silenced");
		}
	}
}

void CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (IsValidAndInGame(client))
		{
		    int originalUserFlags = GetUserFlagBits(client);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(client, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(client, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(client, originalUserFlags);
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(null, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}

bool SpawnAmmo(float origins[3])
{
	int entity = CreateEntityByName("weapon_ammo_spawn");
	if (!IsValidEntity(entity)) return false;
	
	TeleportEntity(entity, origins, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
	return true;
}
