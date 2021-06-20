#pragma tabsize 0
#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]colors>
#pragma newdecls required

public Plugin myinfo =
{
	name = "Survivor Stats",
	description = "",
	author = "Yukari190",
	version = "1.0",
	url = ""
};

enum Pinned
{
	Pinned_None = 0,
	Pinned_Smoker,
	Pinned_Hunter,
	Pinned_Charger,
	Pinned_Jockey
};

int PinnedSmoker[MAXPLAYERS+1];
int PinnedHunter[MAXPLAYERS+1];
int PinnedCharger[MAXPLAYERS+1];
int PinnedJockey[MAXPLAYERS+1];

bool OnPinned[MAXPLAYERS+1];

public void OnPluginStart()
{
	RegConsoleCmd("sm_stats", Cmd_Stats);
	RegConsoleCmd("sm_stats_reset", Cmd_StatsReset);
	
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	HookEvent("player_spawn", OnInfectedSpawn, EventHookMode_Post);
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
}

public Action Cmd_Stats(int client, int args)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Handled;
	if (!L4D2_IsSurvivor(client)) PrintStats();
	else PrintStats(client);
	return Plugin_Handled;
}
public Action Cmd_StatsReset(int client, int args)
{
	Reset();
}

public Action PlayerHurt_Event(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!L4D2_IsValidClient(victim) || !L4D2_IsValidClient(attacker)) return;
	
	if (L4D2_IsSurvivor(victim) && L4D2_IsInfected(attacker) && !OnPinned[attacker])
	{
		OnPinned[attacker] = true;
		switch (IsPinned(victim))
		{
			case Pinned_Smoker: PinnedSmoker[victim]++;
			case Pinned_Hunter: PinnedHunter[victim]++;
			case Pinned_Charger: PinnedCharger[victim]++;
			case Pinned_Jockey: PinnedJockey[victim]++;
		}
	}
}

public Action OnInfectedSpawn(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client) || !IsPlayerAlive(client)) return;
	OnPinned[client] = false;
}

public Action RoundStart_Event(Event event, char[] name, bool dontBroadcast)
{
	Reset();
}

public Action RoundEnd_Event(Event event, char[] name, bool dontBroadcast)
{
	PrintStats();
}




public void OnSkeet(int attacker, int victim)
{}

public void OnSkeetHurt(int attacker, int victim, int damage, int bOverKill)
{}

public void OnSkeetMelee(int attacker, int victim)
{}

public void OnSkeetMeleeHurt(int attacker, int victim, int damage, int bOverKill)
{}

public void OnSkeetSniper(int attacker, int victim)
{}

public void OnSkeetSniperHurt(int attacker, int victim, int damage, int bOverKill)
{}

public void OnSkeetGL(int attacker, int victim)
{}

public void OnHunterDeadstop(int attacker, int victim)
{}

public void OnBoomerPop(int attacker, int victim, int shoveCount, float timeAlive)
{}

public void OnChargerLevel(int attacker, int victim)
{}

public void OnChargerLevelHurt(int attacker, int victim, int damage)
{}

public void OnTongueCut(int attacker, int victim)
{}

public void OnSmokerSelfClear(int attacker, int victim, int withShove)
{}

public void OnTankRockSkeeted(int attacker, int victim)
{}





void Reset()
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		PinnedSmoker[i] = 0;
		PinnedHunter[i] = 0;
		PinnedCharger[i] = 0;
		PinnedJockey[i] = 0;
		OnPinned[i] = false;
	}
}

void PrintStats(int client = -1)
{
	char printBuffer[256];
	
	Format(printBuffer, sizeof(printBuffer), "{B}[{O}生还者统计{B}]\n");
	CPrintToChatAll("%s", printBuffer);
	
	if (client != -1)
	{
		Format(
				printBuffer, sizeof(printBuffer), 
				"{B}[{O}被控{B}]{G} (我){W} Smoker:{O}%d{W} | Hunter:{O}%d{W} | Charger:{O}%d{W} | Jockey:{O}%d\n", 
				PinnedSmoker[client], PinnedHunter[client], PinnedCharger[client], PinnedJockey[client]
		);
		CPrintToChatAll("%s", printBuffer);
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !L4D2_IsSurvivor(i) || i == client) continue;
		/*Format(
				tmpBuffer, sizeof(tmpBuffer), 
				"{B}({O}Skill{B}){G} (%N) Smoker:%d | Hunter:%d | Charger:%d | Jockey:%d \n", 
				i, 
		);
		StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);*/
		
		Format(
				printBuffer, sizeof(printBuffer), 
				"{B}[{O}被控{B}]{G} (%N){W} Smoker:{O}%d{W} | Hunter:{O}%d{W} | Charger:{O}%d{W} | Jockey:{O}%d\n", 
				i, PinnedSmoker[i], PinnedHunter[i], PinnedCharger[i], PinnedJockey[i]
		);
		CPrintToChatAll("%s", printBuffer);
	}
}

Pinned IsPinned(int client)
{
	Pinned bIsPinned = Pinned_None;
	// check if held by:
	if( GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0 ) bIsPinned = Pinned_Smoker; // smoker
	if( GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0 ) bIsPinned = Pinned_Hunter; // hunter
	if( GetEntPropEnt(client, Prop_Send, "m_carryAttacker") > 0 ) bIsPinned = Pinned_Charger; // charger carry
	if( GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0 ) bIsPinned = Pinned_Charger; // charger pound
	if( GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0 ) bIsPinned = Pinned_Jockey; // jockey
	return bIsPinned;
}

bool L4D2_IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

bool L4D2_IsSurvivor(int client)
{
	return GetClientTeam(client) == 2;
}

bool L4D2_IsInfected(int client)
{
	return GetClientTeam(client) == 3;
}
