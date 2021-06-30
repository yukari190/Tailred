#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]l4d2library>

ConVar cRemoveInfClips;
ConVar cRemoveC5m4Hurts;
ConVar cRemoveGrenade;

char mapname[64];

public void OnPluginStart()
{
	cRemoveInfClips = CreateConVar("remove_inf_clips", "1", "删除所有受感染的笔刷. 这可以解决坦克卡在Dark Carnival 5上的问题, 并在几张地图上产生更多受感染的区域. 因电梯错误而被取消No Mercy 4的权限 ");
	cRemoveC5m4Hurts = CreateConVar("remove_c5m4_hurts", "1", "从c5m4中删除所有非致命的trigger_hurt. 去除爆炸伤害点, 包括安全室中的一些伤害点");
	cRemoveGrenade = CreateConVar("remove_grenade", "1", "卸下所有榴弹发射器 ");
}

public void OnMapStart()
{
	GetCurrentMap(mapname, sizeof(mapname));
}

bool ER_KillParachutist(int ent)
{
	char buf[32];
	if (StrEqual(mapname, "c3m2_swamp"))
	{
		GetEntPropString(ent, Prop_Data, "m_iName", buf, sizeof(buf));
		if(!strncmp(buf, "parachute_", 10))
		{
			AcceptEntityInput(ent, "Kill");
			return true;
		}
	}
	return false;
}

bool ER_ReplaceTriggerHurtGhost(int ent, char[] buf)
{
	if (StrEqual(buf, "trigger_hurt_ghost"))
	{
		int replace = CreateEntityByName("trigger_hurt");
		if (replace == -1) 
		{
			LogError("[ER] Could not create trigger_hurt entity!");
			return false;
		}
		
		char model[16];
		GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));
		
		float pos[3], ang[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);

		AcceptEntityInput(ent, "Kill");		
		
		DispatchKeyValue(replace, "StartDisabled", "0");
		DispatchKeyValue(replace, "spawnflags", "67");
		DispatchKeyValue(replace, "damagetype", "32");
		DispatchKeyValue(replace, "damagemodel", "0");
		DispatchKeyValue(replace, "damagecap", "10000");
		DispatchKeyValue(replace, "damage", "10000");
		DispatchKeyValue(replace, "model", model);
		
		DispatchKeyValue(replace, "filtername", "filter_infected");
		
		TeleportEntity(replace, pos, ang, NULL_VECTOR);
		DispatchSpawn(replace);
		ActivateEntity(replace);
		return true;
	}
	return false;
}

public void L4D_OnRoundStart()
{
	CreateTimer(0.3,  ER_RoundStart_Timer);
}

public Action ER_RoundStart_Timer(Handle timer)
{
	char sBuffer[64];
	int iEntCount = GetEntityCount();
	for (int ent = MaxClients+1; ent <= iEntCount; ent++)
	{
		if (IsValidEntity(ent))
		{
			GetEdictClassname(ent, sBuffer, sizeof(sBuffer));
			if (ER_KillParachutist(ent))
			{
			}
			else if (ER_ReplaceTriggerHurtGhost(ent, sBuffer))
			{
			}
			else
			{
				if(!GetConVarBool(cRemoveInfClips) || StrContains("func_playerinfected_clip", sBuffer) == -1 || StrContains("c8m4_interior", mapname) != -1) continue;
				if(!GetConVarBool(cRemoveC5m4Hurts) || StrContains("trigger_hurt", sBuffer) == -1 || StrContains("c5m4_quarter", mapname) == -1 || !(GetEntPropFloat(ent, Prop_Data, "m_flDamage") < 500.0)) continue;
				if(!GetConVarBool(cRemoveGrenade) || StrContains("logic_director_query", sBuffer) == -1 || StrContains("c5m5_bridge", mapname) == -1) continue;
				AcceptEntityInput(ent, "Kill");
			}
		}
	}
}
