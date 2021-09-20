#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>
#include <l4d2lib>
#define L4D2UTIL_STOCKS_ONLY
#include <l4d2util>

public Plugin myinfo = 
{
	name = "Tank Management",
	author = "",
	description = "",
	version = "1.0",
	url = ""
};

static const char sDang[] = "ui/pickup_secret01.wav";

float 
	throwQueuedAt[MAXPLAYERS+1],
	fTankSpawn[3];

int 
	g_iQueuedThrow[MAXPLAYERS + 1],
	iTankCount;

bool 
	bFinaleStarted,
	bIsBridge,
	bFinaleVehicleIncoming,
	bTankSpawned;

public void OnPluginStart()
{
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_vehicle_incoming", Event_FinaleVehicleIncoming, EventHookMode_PostNoCopy);
	HookEvent("player_incapacitated", PlayerIncap);
}

public void OnMapStart()
{
	PrecacheSound(sDang);
	char g_sMap[64];
	GetCurrentMap(g_sMap, 64);
	if (StrEqual(g_sMap, "c5m5_bridge", false))
	{
		bIsBridge = true;
	}
	else
	{
		bIsBridge = false;
	}
}

public void L4D2_OnRealRoundStart()
{
	bFinaleStarted = false;
	bFinaleVehicleIncoming = false;
	iTankCount = 0;
	bTankSpawned = false;
	for (int i = 1; i <= MAXPLAYERS; i++)
	  throwQueuedAt[i] = 0.0;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	CPrintToChatAll("{R}[{W}!{R}] {G}Tank{W} 已产生!");
	EmitSoundToAll(sDang);
	
	if (!bFinaleStarted && !bIsBridge)
	{
		if (L4D2_GetMapValueInt("tank_z_fix")) FixZDistance(tankClient); // fix stuck tank spawns, ex c1m1
		if (!bTankSpawned)
		{
			if (!L4D2_InSecondHalfOfRound())
			{
				GetClientAbsOrigin(tankClient, fTankSpawn);
			}
			else
			{
				TeleportEntity(tankClient, fTankSpawn, NULL_VECTOR, NULL_VECTOR);
			}
			bTankSpawned = true;
		}
	}
}

public void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
	if (!IsFakeClient(newTank))
	{
		bool hidemessage = false;
		char buffer[3];
		if (GetClientInfo(newTank, "rs_hidemessage", buffer, sizeof(buffer)))
		  hidemessage = view_as<bool>(StringToInt(buffer));
		if (!hidemessage)
		{
			CPrintToChat(newTank, "{B}[{W}Tank 岩石选择器{B}]");
			CPrintToChat(newTank, "{G}Reload {W}= {B}双手举过头顶");
			CPrintToChat(newTank, "{G}Use {W}= {B}低抛");
			CPrintToChat(newTank, "{G}M2 {W}= {B}单手举过头顶");
		}
	}
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
	if (IsValidSurvivor(victim) && L4D2Util_IsValidClient(attacker) && IsTank(attacker) && !IsFakeClient(attacker) && damage >= 5)
	  SetTankFrustration(attacker, 100);
}

public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	bFinaleStarted = true;
}

public Action Event_FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
	bFinaleVehicleIncoming = true;
}

public Action PlayerIncap(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSurvivor(victim) || !L4D2Util_IsValidClient(attacker) || !IsTank(attacker)) return;
	
	char weapon[16];
	event.GetString("weapon", weapon, 16);
	if (StrEqual(weapon, "tank_claw", false))
	{
		SetEntProp(victim, Prop_Send, "m_isIncapacitated", 0);
		SetEntityHealth(victim, 1);
		CreateTimer(0.4, IncapTimer_Function, victim, TIMER_REPEAT);
	}
	if (IsFakeClient(attacker)) return;
	SetTankFrustration(attacker, 100);
}

public Action IncapTimer_Function(Handle timer, any victim)
{
	if (!IsValidAndInGame(victim)) return Plugin_Stop;
	SetEntProp(victim, Prop_Send, "m_isIncapacitated", 1);
	SetEntityHealth(victim, 300);
	return Plugin_Stop;
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!L4D2Util_IsValidClient(client) || !IsTank(client)) return Plugin_Continue;
	
	if (IsFakeClient(client))
	{
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == 54 || sequence == 55 || sequence == 57) SetEntProp(client, Prop_Send, "m_nSequence", 0);
		if (sequence == 56) buttons |= IN_ATTACK;
		if ((buttons & IN_ATTACK2)) buttons |= IN_ATTACK;
		return Plugin_Changed;
	}
	else
	{
		if ((buttons & IN_JUMP) && (1.5 > GetGameTime() - throwQueuedAt[client]))
		{
			buttons &= ~IN_JUMP;
		}
		if (buttons & IN_RELOAD)
		{
			g_iQueuedThrow[client] = 3; //two hand overhand
			buttons |= IN_ATTACK2;
		}
		else if (buttons & IN_USE)
		{
			g_iQueuedThrow[client] = 2; //underhand
			buttons |= IN_ATTACK2;
		}
		else
		{
			g_iQueuedThrow[client] = 1; //one hand overhand
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnCThrowActivate(int ability)
{
	if (!IsValidEntity(ability))
	{
		LogMessage("无效 'ability_throw' 索引: %d. 继续投掷.", ability);
		return Plugin_Continue;
	}
	int client = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if (GetClientButtons(client) & IN_ATTACK) return Plugin_Handled;
	throwQueuedAt[client] = GetGameTime();
	return Plugin_Continue;
}

//l4dt_forwards
public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (iTankCount >= 2 || bFinaleVehicleIncoming)
	{
		return Plugin_Handled;
	}
	iTankCount += 1;
	return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	enterStasis = false;
	if (bFinaleVehicleIncoming)
	{
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action L4D2_OnSelectTankAttack(int client, int &sequence)
{
	if (IsFakeClient(client) && sequence == 50)
	{
		sequence = GetRandomInt(0, 1) ? 49 : 51;
		return Plugin_Handled;
	}
	
	if (sequence > 48 && g_iQueuedThrow[client])
	{
		sequence = g_iQueuedThrow[client] + 48;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

void FixZDistance(int client)
{
	float TankLocation[3], TempSurvivorLocation[3];
	int index;
	GetClientAbsOrigin(client, TankLocation);
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		float distance = L4D2_GetMapValueFloat("max_tank_z", 99999999999999.9);
		index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		GetClientAbsOrigin(index, TempSurvivorLocation);
		if (FloatAbs(TempSurvivorLocation[2] - TankLocation[2]) > distance)
		{
			float WarpToLocation[3];
			L4D2_GetMapValueVector("tank_warpto", WarpToLocation);
			if (!GetVectorLength(WarpToLocation, true))
			{
				LogMessage("[BS] tank_warpto missing from mapinfo.txt");
				return;
			}
			TeleportEntity(client, WarpToLocation, NULL_VECTOR, NULL_VECTOR);
		}
	}
}
