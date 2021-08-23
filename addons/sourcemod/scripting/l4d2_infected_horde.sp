#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#include <[LIB]l4d2library>

#define NO_HORDES 3600.0
#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

ConVar hMobSpawnMinSize;
ConVar hMobSpawnMaxSize;
ConVar hMobSpawnIntervalMin;
ConVar hMobSpawnIntervalMax;
bool bHordesDisabled;
bool announcedInChat;
int iMobSpawnMinSize;
int iMobSpawnMaxSize;
int commonLimit;
int commonTotal;
int lastCheckpoint;
int commonTank;

public void OnPluginStart()
{
	hMobSpawnMinSize = FindConVar("z_mob_spawn_min_size");
	hMobSpawnMaxSize = FindConVar("z_mob_spawn_max_size");
	hMobSpawnIntervalMin = FindConVar("z_mob_spawn_min_interval_normal");
	hMobSpawnIntervalMax = FindConVar("z_mob_spawn_max_interval_normal");
	
	hMobSpawnMinSize.AddChangeHook(ConVarChange);
	hMobSpawnMaxSize.AddChangeHook(ConVarChange);
	hMobSpawnIntervalMin.AddChangeHook(ConVarChange);
	hMobSpawnIntervalMax.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarFloat(hMobSpawnIntervalMin, NO_HORDES);
	SetConVarFloat(hMobSpawnIntervalMax, NO_HORDES);
	iMobSpawnMinSize = hMobSpawnMinSize.IntValue;
	iMobSpawnMaxSize = hMobSpawnMaxSize.IntValue;
}

public void OnMapStart()
{
	PrecacheSound(HORDE_SOUND);
	commonLimit = L4D_GetMapValueInt("horde_limit", -1);
	commonTank = L4D_GetMapValueInt("horde_tank", -1);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrEqual(classname, "infected", false))
		SDKHook(entity, SDKHook_SpawnPost, OnInfectedSpawned);
}

public void OnInfectedSpawned(int entity)
{
	if (isUncommon(entity))
	{
		float location[3];
		GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
		AcceptEntityInput(entity, "kill");
		SpawnCommon(location);
		return;
	}
	if (announcedInChat && IsInfiniteHordeActive())
	{
		if (commonLimit < 0) return;
		
		if (commonTotal >= commonLimit)
		{
			//L4D2Direct_SetPendingMobCount(0);
			return;
		}
		
		commonTotal++;
		
		if (commonLimit < 120) return;
		
		if ((commonTotal >= ((lastCheckpoint + 1) * RoundFloat(float(commonLimit / 4)))))
		{
			int remaining = commonLimit - commonTotal;
			if (remaining)
			{
				CPrintToChatAll("<{G}Horde{W}> 事件剩余 {R}%i {W}.. ", remaining);
				EmitSoundToAll(HORDE_SOUND);
			}
			lastCheckpoint++;
		}
	}
}

public void L4D_OnRoundStart()
{
	bHordesDisabled = false;
	announcedInChat = false;
	commonTotal = 0;
	lastCheckpoint = 0;
}

public void L4D_OnTankDeath()
{
	bHordesDisabled = false;
}

public void L4D_OnTankSpawn()
{
	bHordesDisabled = true;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
	return Plugin_Continue;
}

public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, NO_HORDES);
}

public Action L4D_OnSpawnITMob(int &amount)
{
	amount = iMobSpawnMaxSize;
	return Plugin_Changed;
}

public Action L4D_OnSpawnMob(int &amount)
{
	if (iMobSpawnMinSize <= amount <= iMobSpawnMaxSize && L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer)
	  && L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer) == NO_HORDES)
	{
		return Plugin_Handled;
	}
	if (IsInfiniteHordeActive())
	{
		if (commonTank > 0 && bHordesDisabled)
		{
			L4D2Direct_SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
		if (commonLimit < 0) return Plugin_Continue;
		if (!announcedInChat)
		{
			CPrintToChatAll("<{G}Horde{W}> {B}有限的{W}暴动事件开始! 总数: {G}%i{W} .", commonLimit);
			announcedInChat = true;
		}
		if (commonTotal >= commonLimit)
		{
			L4D2Direct_SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

bool IsInfiniteHordeActive()
{
	int countdown = CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
	return (countdown > -1 && countdown <= 10);
}

bool isUncommon(int entity)
{
	char model[128];
	L4D2_GetEntityModelName(entity, model, sizeof(model));
	if (StrContains(model, "_ceda", false) != -1) return true;
	if (StrContains(model, "_clown", false) != -1) return true;
	if (StrContains(model, "_mud", false) != -1) return true;
	if (StrContains(model, "_riot", false) != -1) return true;
	if (StrContains(model, "_roadcrew", false) != -1) return true;
	return false;
}

void SpawnCommon(float location[3])
{
	int zombie = CreateEntityByName("infected");
	int ticktime = RoundToNearest( GetGameTime() / GetTickInterval() ) + 5;
	SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
	DispatchSpawn(zombie);
	ActivateEntity(zombie);
	TeleportEntity(zombie, location, NULL_VECTOR, NULL_VECTOR);
}
