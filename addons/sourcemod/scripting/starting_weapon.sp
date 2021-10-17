#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util>
#include <readyup>

#define SPAWNCOUNT 2

public Plugin myinfo =
{
	name = "Starting Weapon",
	author = "Yukari190",
	description = "",
	version = "1.0"
};

static const char safeSpawns[SPAWNCOUNT][] =
{
	"weapon_pistol_magnum",
	"weapon_sniper_scout"
};

//bool bAllowUse[10000];

/*public void OnEntityCreated(int entity, const char[] classname)
{
	if (IsCheckWeapon(entity))
	{
		SDKHook(entity, SDKHook_SpawnPost, fOnEntitySpawned);
	}
}

public void fOnEntitySpawned(int entity)
{
	RemoveEntityLog(entity);
}*/

public void OnRoundIsLive()
{
	GiveStartingWeapon();
}

/*public void L4D2_OnRealRoundEnd()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (bAllowUse[i] && IsValidEntity(i))
		{
			RemoveEntityLog(i);
		}
		bAllowUse[i] = false;
	}
}*/

public void L4D2_OnRealRoundStart()
{
	/*int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		bAllowUse[i] = false;
	}*/
	CreateTimer(1.5, Timer_DelayedOnRoundStart, _, TIMER_FLAG_NO_MAPCHANGE);
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
			SpawnPosition[0] += (-10 + GetRandomInt(0, 20));
			SpawnPosition[1] += (-10 + GetRandomInt(0, 20));
			SpawnPosition[2] += GetRandomInt(0, 10);
			SpawnAngle[1] = GetRandomFloat( 0.0, 360.0 );
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
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
			clients++;
		}
	}
	
	return clients;
}

bool SpawnWeapon(char[] names, float origins[3], float angles[3])
{
	int entity = CreateEntityByName(names);
	if(!IsValidEntity(entity)) return false;
	//bAllowUse[entity] = true;
	
	TeleportEntity(entity, origins, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	return true;
}

/*bool IsCheckWeapon(int entity)
{
	if (bAllowUse[entity]) return false;
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return false;

	WeaponId source = IdentifyWeapon(entity, true);
	if (source == WEPID_PISTOL_MAGNUM) return true;
	if (source == WEPID_SNIPER_SCOUT) return true;

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
}*/

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
