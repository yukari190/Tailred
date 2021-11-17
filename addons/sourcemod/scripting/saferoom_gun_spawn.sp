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

static const int safeSpawns[SPAWNCOUNT] =
{
	WEPID_SHOTGUN_CHROME,
	WEPID_SMG_SILENCED,
	WEPID_AMMO_PACK
};

public void OnPluginStart()
{
	RegAdminCmd("sm_spawn_gun", Command_ItemTrack, ADMFLAG_ROOT);
}

public Action Command_ItemTrack(int client, int args)
{
	CreateTimer(0.5, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	return Plugin_Handled;
}

public void OnRoundIsLive()
{
	GiveStartingWeapon();
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.5, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action Timer_DelayedOnRoundStart(Handle timer)
{
	if (GetSeriousClientCount(true) != 0)
	{
		float SpawnPosition[3], SpawnAngle[3];
		int count = 0;
		
		for (int i = 1; i <= MaxClients && count < SPAWNCOUNT; i++)
		{
			if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i)) continue;
			
			GetClientAbsOrigin(i, SpawnPosition);
			SpawnAngle[1] = 135.0;SpawnAngle[2] = 90.0;
			int wepid = safeSpawns[count];
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
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void GiveStartingWeapon()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) != 2 || !IsPlayerAlive(i) || !IsFakeClient(i)) continue;
		CheatCommand(i, "give", "pistol");
		if (GetPlayerWeaponSlot(i, 0) <= -1)
		{
			CheatCommand(i, "give", "smg_silenced");
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

/**
 * 创建一个给定的武器生成
 * @remark 说实话, 这适用于任何具有原点/旋转的实体。
 * 此外，要求武器具有有效的武器模型或已提供 
 *
 * @param wepid            WeaponId of the weapon to have the spawner hold
 * @param origins
 * @param angles
 * @param count            Weapon count for the spawner (default 5)
 * @param model            World model to use for the weapon spawn
 * @return entity of the new weapon spawn, or -1 on errors.
 */
stock int CreateWeaponSpawn(int wepid, float origins[3], float angles[3], int count = 5, const char[] model = "")
{
	if (!IsValidWeaponId(wepid)) {
		return -1;
	}
	
	if (model[0] == '\0' && !HasValidWeaponModel(wepid)) {
		return -1;
	}
	
	int entity = CreateEntityByName("weapon_spawn");
	if (!IsValidEntity(entity)) {
		return -1;
	}
	
	SetEntProp(entity, Prop_Send, "m_weaponID", wepid);

	static char buf[PLATFORM_MAX_PATH - 16], modelName[PLATFORM_MAX_PATH];
	if (model[0] != '\0') {
		SetEntityModel(entity, model);
	} else {
		GetWeaponModel(wepid, buf, sizeof(buf));
		Format(modelName, sizeof(modelName), "models%s", buf);
		SetEntityModel(entity, modelName);
	}
	
	IntToString(count, buf, sizeof(buf));
	DispatchKeyValue(entity, "count", buf);

	TeleportEntity(entity, origins, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	return entity;
}
