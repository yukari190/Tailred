#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <colors>
#include <l4d2lib>
#include <l4d2util>

#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

bool bHordesDisabled;
bool announcedInChat;
int commonLimit;
int commonTotal;
int lastCheckpoint;
int commonTank;

public void OnMapStart()
{
	PrecacheSound(HORDE_SOUND);
	commonLimit = L4D2_GetMapValueInt("horde_limit", -1);
	commonTank = L4D2_GetMapValueInt("horde_tank", -1);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity <= 0 || !IsValidEntity(entity) || !IsValidEdict(entity)) return;
	SDKHook(entity, SDKHook_SpawnPost, fOnEntitySpawned);
}

public void fOnEntitySpawned(int entity)
{
	char classname[64];
	if (!GetEdictClassname(entity, classname, sizeof(classname))) return;
	
	if (StrEqual(classname, "infected", false))
	{
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
}

public void L4D2_OnRealRoundStart()
{
	bHordesDisabled = false;
	announcedInChat = false;
	commonTotal = 0;
	lastCheckpoint = 0;
}

public void L4D2_OnTankDeath()
{
	bHordesDisabled = false;
}

public void L4D2_OnTankFirstSpawn()
{
	bHordesDisabled = true;
}


public Action L4D_OnSpawnMob(int &amount)
{
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
