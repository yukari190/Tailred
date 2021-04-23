#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[TR]l4d2library>

public Plugin myinfo =
{
	name = "Easier Pill Passer",
	author = "CanadaRox",
	description = "Lets players pass pills and adrenaline with +reload when they are holding one of those items",
	version = "3",
	url = "http://github.com/CanadaRox/sourcemod-plugins/"
};

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!IsValidEntity(client) || !IsClientInGame(client)) return Plugin_Continue;
	
	if (buttons & IN_RELOAD && !(buttons & IN_USE) && !IsFakeClient(client))
	{
		char weapon_name[64];
		GetClientWeapon(client, weapon_name, sizeof(weapon_name));
		WeaponId wep = L4D2_WeaponNameToId(weapon_name);
		if (wep == WEPID_PAIN_PILLS || wep == WEPID_ADRENALINE)
		{
			int target = GetClientAimTarget(client);
			if (target != -1 && L4D2_IsSurvivor(target) && GetPlayerWeaponSlot(target, 4) == -1 && !L4D2_IsPlayerIncap(target))
			{
				float clientOrigin[3], targetOrigin[3];
				GetClientAbsOrigin(client, clientOrigin);
				GetClientAbsOrigin(target, targetOrigin);
				if (GetVectorDistance(clientOrigin, targetOrigin, true) < 48400 /* 普通药丸通过范围是~220单位 */)
				{
					if (IsVisibleTo(client, target) || IsVisibleTo(client, target, true))
					{
						AcceptEntityInput(GetPlayerWeaponSlot(client, 4), "Kill");
						int ent = CreateEntityByName(weapon_name);
						DispatchSpawn(ent);
						EquipPlayerWeapon(target, ent);

						Handle hFakeEvent = CreateEvent("weapon_given");
						SetEventInt(hFakeEvent, "userid", GetClientUserId(target));
						SetEventInt(hFakeEvent, "giver", GetClientUserId(client));
						SetEventInt(hFakeEvent, "weapon", view_as<int>(wep));
						SetEventInt(hFakeEvent, "weaponentid", ent);
						FireEvent(hFakeEvent);
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

bool IsVisibleTo(int client, int client2, bool ghetto_lagcomp = false) // check an entity for being visible to a client
{
	float vAngles[3], vOrigin[3], vEnt[3], vLookAt[3], vClientVelocity[3], vClient2Velocity[3];
	GetClientEyePosition(client, vOrigin); // get both player and zombie position
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vClientVelocity);
	GetClientAbsOrigin(client2, vEnt);
	GetEntPropVector(client2, Prop_Data, "m_vecAbsVelocity", vClient2Velocity);
	float ping = GetClientAvgLatency(client, NetFlow_Outgoing);
	float lerp = GetEntPropFloat(client, Prop_Data, "m_fLerpTime");
	lerp *= 4;

	if (ghetto_lagcomp)
	{
		vOrigin[0] += vClientVelocity[0] * (ping + lerp) * -1;
		vOrigin[1] += vClientVelocity[1] * (ping + lerp) * -1;
		vOrigin[2] += vClientVelocity[2] * (ping + lerp) * -1;

		vEnt[0] += vClient2Velocity[0] * (ping) * -1;
		vEnt[1] += vClient2Velocity[1] * (ping) * -1;
		vEnt[2] += vClient2Velocity[2] * (ping) * -1;
	}
	MakeVectorFromPoints(vOrigin, vEnt, vLookAt); // compute vector from player to zombie
	GetVectorAngles(vLookAt, vAngles); // get angles from vector for trace
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_OPAQUE_AND_NPCS, RayType_Infinite, TraceFilter);
	bool isVisible = false;
	if (TR_DidHit(trace))
	{
		float vStart[3];
		TR_GetEndPosition(vStart, trace); // retrieve our trace endpoint
		if ((GetVectorDistance(vOrigin, vStart, false) + 30.0) >= GetVectorDistance(vOrigin, vEnt)) isVisible = true;
	}
	else isVisible = true;
	CloseHandle(trace);
	return isVisible;
}

public bool TraceFilter(int entity, int contentsMask)
{
	if (entity <= MaxClients) return false;
	return true;
}
