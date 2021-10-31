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

#define HORDE_MIN_SIZE_AUDIAL_FEEDBACK 120
#define MAX_CHECKPOINTS 4

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
	// TO-DO: Find a value that tells wanderers from active event commons?
	if (strcmp(classname, "infected") == 0 && IsInfiniteHordeActive()) {
		// Our job here is done
		if (commonTotal >= commonLimit) {
			return;
		}
		
		commonTotal++;
		if (commonTotal >= ((lastCheckpoint + 1) * RoundFloat(float(commonLimit / MAX_CHECKPOINTS)))) {
			if (commonLimit >= HORDE_MIN_SIZE_AUDIAL_FEEDBACK) {
				EmitSoundToAll(HORDE_SOUND);
			}
			
			int remaining = commonLimit - commonTotal;
			if (remaining != 0) {
				CPrintToChatAll("<{G}Horde{W}> 事件剩余 {R}%i {W}.. ", remaining);
			}
			
			lastCheckpoint++;
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

stock void LaunchHorde()
{
	int client = -1;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			client = i;
			break;
		}
	}

	if (client != -1) {
		int flags = GetCommandFlags("director_force_panic_event");
		SetCommandFlags("director_force_panic_event", flags & ~FCVAR_CHEAT);
		FakeClientCommand(client, "director_force_panic_event");
		SetCommandFlags("director_force_panic_event", flags);
	}
}
