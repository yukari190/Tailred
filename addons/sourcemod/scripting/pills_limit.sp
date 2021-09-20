#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo =
{
	name = "Pills Limit",
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

ConVar hPillsLimits;

int g_iItemLimits;

public void OnPluginStart()
{
	g_hItemSpawns = new ArrayList(sizeof(ItemTracking));
	
	hPillsLimits = CreateConVar("sm_pills_limit", "-1", "限制每张地图上止痛药的数量. -1: 没有限制; >=0: 限制为cvar值");
	g_iItemLimits = hPillsLimits.IntValue;
	hPillsLimits.AddChangeHook(ConVarChange);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iItemLimits = convar.IntValue;
}

public void OnMapStart()
{
	g_iItemLimits = hPillsLimits.IntValue;
	if (L4D_IsMissionFinalMap() && g_iItemLimits != -1)
	{
		g_iItemLimits = 0; 
	}
	g_hItemSpawns.Clear();
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(1.0, RoundStartDelay);
}

public Action RoundStartDelay(Handle timer)
{
	if (g_iItemLimits != -1)
	{
		if (!L4D2_InSecondHalfOfRound())
		{
			ItemTracking curitem;
			float origins[3], angles[3];
			int iEntCount = GetEntityCount();
			for (int i = MaxClients+1; i <= iEntCount; i++)
			{
				WeaponId source = IdentifyWeapon(i);
				if (source == WEPID_PAIN_PILLS && !SAFEDETECT_IsEntityInSaferoom(i))
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
			
			while (g_hItemSpawns.Length > g_iItemLimits)
			{
				int killidx = GetRandomInt(0, g_hItemSpawns.Length - 1);
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
				WeaponId source = IdentifyWeapon(i);
				if (source == WEPID_PAIN_PILLS && !SAFEDETECT_IsEntityInSaferoom(i)) RemoveEntityLog(i);
			}
			
			ItemTracking curitem;
			float origins[3], angles[3];
			for (int idx = 0; idx < g_hItemSpawns.Length; idx++)
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
