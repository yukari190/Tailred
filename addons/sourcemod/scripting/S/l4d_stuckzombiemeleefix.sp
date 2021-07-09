#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo = 
{
	name = "Stuck Zombie Melee Fix",
	author = "AtomicStryker",
	description = "Smash nonstaggering Zombies",
	version = "1.0.4",
	url = "http://forums.alliedmods.net/showthread.php?p=932416"
}

public void OnPluginStart()
{
	HookEvent("entity_shoved", Event_EntShoved);
	AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback));
}

bool MeleeDelay[MAXPLAYERS+1];

public Action HookSound_Callback(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity)
{
	if (StrContains(sample, "Swish", false) == -1) return Plugin_Continue;
	
	if (entity > MAXPLAYERS) return Plugin_Continue;
	
	if (MeleeDelay[entity]) return Plugin_Continue;
	MeleeDelay[entity] = true;
	CreateTimer(1.0, ResetMeleeDelay, entity);
	
	int entid = GetClientAimTarget(entity, false);
	if (entid <= 0) return Plugin_Continue;
	
	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected", false)) return Plugin_Continue;
	
	float clientpos[3], entpos[3];
	GetEntityAbsOrigin(entid, entpos);
	GetClientEyePosition(entity, clientpos);
	if (GetVectorDistance(clientpos, entpos) < 50) return Plugin_Continue;
	
	Handle newEvent = CreateEvent("entity_shoved", true);
	SetEventInt(newEvent, "attacker", entity);
	SetEventInt(newEvent, "entityid", entid);
	FireEvent(newEvent, true);
	return Plugin_Continue;
}

public Action ResetMeleeDelay(Handle timer, any client)
{
	MeleeDelay[client] = false;
}

public Action Event_EntShoved(Event event, const char[] name, bool dontBroadcast)
{
	int entid = event.GetInt("entityid");
	char entclass[96];
	GetEntityNetClass(entid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected", false)) return;
	
	Handle data = CreateDataPack();
	CreateTimer(0.5, CheckForMovement, data);
	WritePackCell(data, entid);
	
	float pos[3];
	GetEntityAbsOrigin(entid, pos);
	WritePackFloat(data, pos[0]);
	WritePackFloat(data, pos[1]);
	WritePackFloat(data, pos[2]);
}

public Action CheckForMovement(Handle timer, Handle data)
{
	ResetPack(data);
	int zombieid = ReadPackCell(data);
	if (!IsValidEntity(zombieid)) return Plugin_Handled;
	char entclass[96];
	GetEntityNetClass(zombieid, entclass, sizeof(entclass));
	if (!StrEqual(entclass, "Infected", false)) return Plugin_Handled;
	
	float oldpos[3];
	oldpos[0] = ReadPackFloat(data);
	oldpos[1] = ReadPackFloat(data);
	oldpos[2] = ReadPackFloat(data);
	CloseHandle(data);
	float newpos[3];
	GetEntityAbsOrigin(zombieid, newpos);
	if (GetVectorDistance(oldpos, newpos) > 5) return Plugin_Handled;
	
	int zombiehealth = GetEntProp(zombieid, Prop_Data, "m_iHealth");
	int zombiehealthmax = GetConVarInt(FindConVar("z_health"));
	if (zombiehealth - (zombiehealthmax / 2) <= 0) AcceptEntityInput(zombieid, "BecomeRagdoll");
	else SetEntProp(zombieid, Prop_Data, "m_iHealth", zombiehealth - (zombiehealthmax / 2));	
	return Plugin_Handled;
}

public void GetEntityAbsOrigin(int entity, float origin[3])
{
	float mins[3], maxs[3];
	GetEntPropVector(entity,Prop_Send,"m_vecOrigin",origin);
	GetEntPropVector(entity,Prop_Send,"m_vecMins",mins);
	GetEntPropVector(entity,Prop_Send,"m_vecMaxs",maxs);
	origin[0] += (mins[0] + maxs[0]) * 0.5;
	origin[1] += (mins[1] + maxs[1]) * 0.5;
	origin[2] += (mins[2] + maxs[2]) * 0.5;
}
