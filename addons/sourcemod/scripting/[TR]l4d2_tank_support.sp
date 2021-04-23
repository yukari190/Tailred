#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>

int OUR_COLOR[3];
bool bVision[MAXPLAYERS + 1];

ArrayList g_ArrayHittableClones;
ArrayList g_ArrayHittables;

public void OnPluginStart()
{
	OUR_COLOR[0] = 255;
	OUR_COLOR[1] = 255;
	OUR_COLOR[2] = 255;
	// Setup Clone Array
	g_ArrayHittableClones = new ArrayList(32);
	g_ArrayHittables = new ArrayList(32);
}

public void OnPluginEnd()
{
	KillClones(true);
}

public Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (bVision[client])
	{
		bVision[client] = false;
	}
}

public void L4D2_OnRealRoundEnd()
{
	KillClones(true);
}

public void L4D2_OnRealRoundStart()
{
	KillClones(true);
}

public void L4D2_OnTankDeath()
{
	KillClones(true);
}

public void L4D2_OnTankFirstSpawn()
{
	KillClones(true);
	HookProps();
}

public void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
	KillClones(false);
	bVision[newTank] = true;
	RecreateHittableClones();
}

public int CreateClone(any entity)
{
	float vOrigin[3], vAngles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vOrigin);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", vAngles); 
	char entityModel[64]; 
	GetEntPropString(entity, Prop_Data, "m_ModelName", entityModel, sizeof(entityModel)); 
	int clone = 0;
	clone = CreateEntityByName("prop_dynamic_override"); //prop_dynamic
	SetEntityModel(clone, entityModel);  
	DispatchSpawn(clone);

	TeleportEntity(clone, vOrigin, vAngles, NULL_VECTOR); 
	SetEntProp(clone, Prop_Send, "m_CollisionGroup", 0);
	SetEntProp(clone, Prop_Send, "m_nSolidType", 0);
	
	SetVariantString("!activator");
	AcceptEntityInput(clone, "SetParent", entity);
	return clone;
}

public void TankHittablePunched(const char[] output, int caller, int activator, float delay)
{
	int iEntity = caller;
	int clone = CreateClone(iEntity);
	if (clone > 0)
	{
		PushArrayCell(g_ArrayHittableClones, clone);
		PushArrayCell(g_ArrayHittables, iEntity);
		MakeEntityVisible(clone, false);
		SDKHook(clone, SDKHook_SetTransmit, CloneTransmit);
		L4D2_SetEntGlow(clone, L4D2Glow_Constant, 3250, 250, OUR_COLOR, false);
	}
}

public void RecreateHittableClones()
{
	int ArraySize = GetArraySize(g_ArrayHittables);
	if (ArraySize > 0)
	{
		for (int i = 0; i < ArraySize; i++)
		{
			int storedEntity = GetArrayCell(g_ArrayHittables, i);
			if (IsValidEntity(storedEntity))
			{
				int clone = CreateClone(storedEntity);
				if (clone > 0)
				{
					PushArrayCell(g_ArrayHittableClones, clone);
					MakeEntityVisible(clone, false);
					SDKHook(clone, SDKHook_SetTransmit, CloneTransmit);
					L4D2_SetEntGlow(clone, L4D2Glow_Constant, 3250, 250, OUR_COLOR, false);
				}
			}
		}
	}
}

public Action CloneTransmit(int entity, int client)
{
	if (bVision[client])
	{
		// Showing Clone
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

void KillClones(bool both)
{
	// 1. Loop through Array.
	// 2. Unhook Clones safely and then Kill them.
	// 3. Empty Array.
	int ArraySize = GetArraySize(g_ArrayHittableClones);
	for (int i = 0; i < ArraySize; i++)
	{
		int storedEntity = GetArrayCell(g_ArrayHittableClones, i);
		if (IsValidEntity(storedEntity))
		{
			SDKUnhook(storedEntity, SDKHook_SetTransmit, CloneTransmit);
			AcceptEntityInput(storedEntity, "Kill");
		}
	}
	ClearArray(g_ArrayHittableClones);
	if (both) { ClearArray(g_ArrayHittables); }

	// 4. Reset bVision
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && bVision[i])
		{
			bVision[i] = false;
		}
	}
}

void MakeEntityVisible(int ent, bool visible=true)
{
	if(visible)
	{
		SetEntityRenderMode(ent, RENDER_NORMAL);
		SetEntityRenderColor(ent, 255, 255, 255, 255);         
	}
	else
	{
		SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
		SetEntityRenderColor(ent, 0, 0, 0, 0);
	} 
}

void HookProps()
{
	int iEntity = -1;
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1) 
	{
		if (L4D2_IsTankHittable(iEntity)) 
		{
			HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched, true);
		}
	}
	
	iEntity = -1;
	
	while ((iEntity = FindEntityByClassname(iEntity, "prop_car_alarm")) != -1) 
	{
		HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched, true);
	}
}
