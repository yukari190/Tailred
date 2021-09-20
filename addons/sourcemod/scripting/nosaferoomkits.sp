#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo = 
{
	name = "No Safe Room Medkits",
	author = "Blade", //update syntax A1m`
	description = "Removes Safe Room Medkits",
	version = "0.2",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

ConVar 
	hReplaceStartKits,
	hReplaceFinaleKits,
	hRemoveKits;

public void OnPluginStart()
{
	hReplaceStartKits = CreateConVar("sm_replace_startkits", "0", "Replaces start medkits with pills");
	hReplaceFinaleKits = CreateConVar("sm_replace_finalekits", "1", "Replaces finale medkits with pills");
	hRemoveKits = CreateConVar("sm_remove_statickits", "1", "Remove all static medkits (medkits such as the gun shop, these are compiled into the map)");
	
	HookEvent("spawner_give_item", SpawnerGiveItem_Event, EventHookMode_PostNoCopy);
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(0.3, RoundStartDelay);
}

public Action RoundStartDelay(Handle hTimer)
{
	KitsSearchLoop();
}

public Action SpawnerGiveItem_Event(Event event, const char[] name, bool dontBroadcast)
{
	KitsSearchLoop();
}

void KitsSearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		WeaponId source = IdentifyWeapon(i);
		if (source == WEPID_FIRST_AID_KIT)
		{
			if (hReplaceStartKits.BoolValue && SAFEDETECT_IsEntityInStartSaferoom(i)) ReplaceKits(i);
			else if (hReplaceFinaleKits.BoolValue && L4D_IsMissionFinalMap() && !SAFEDETECT_IsEntityInSaferoom(i)) ReplaceKits(i);
			else if (hRemoveKits.BoolValue) RemoveEntityLog(i);
		}
	}
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
	
	DataPack data = CreateDataPack();
	data.WriteFloat(origins[0]);
	data.WriteFloat(origins[1]);
	data.WriteFloat(origins[2]);
	data.WriteFloat(angles[0]);
	data.WriteFloat(angles[1]);
	data.WriteFloat(angles[2]);
	CreateTimer(5.0, SpawnPillsDelay, data);
}

public Action SpawnPillsDelay(Handle hTimer, DataPack data)
{
	data.Reset();
	float pos0 = data.ReadFloat();
	float pos1 = data.ReadFloat();
	float pos2 = data.ReadFloat();
	float ang0 = data.ReadFloat();
	float ang1 = data.ReadFloat();
	float ang2 = data.ReadFloat();
	if (data != null)
	{ CloseHandle(data); }
	float origins[3];origins[0]=pos0;origins[1]=pos1;origins[2]=pos2;
	float angles[3];angles[0]=ang0;angles[1]=ang1;angles[2]=ang2;
	
	SpawnPills(origins, angles);
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
