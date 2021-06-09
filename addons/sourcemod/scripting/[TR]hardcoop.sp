#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

#define VEL_MAX          450.0

#define TANK_MELEE_SCAN_DELAY 0.5
#define SMOKER_ATTACK_SCAN_DELAY 0.5
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE 300.0
#define HUNTER_FLY_DELAY 0.2
#define HUNTER_ATTACK_TIME 4.0
#define HUNTER_COOLDOWN_DELAY 2.0
#define HUNTER_FALL_DELAY 0.2
#define HUNTER_STATE_FLY_TYPE 0
#define HUNTER_STATE_FALL_FLAG 1
#define HUNTER_STATE_FLY_FLAG 2
#define HUNTER_REPEAT_SPEED 4
#define HUNTER_NEAR_RANGE 1000
#define JOCKEY_JUMP_DELAY 2.0
#define JOCKEY_JUMP_NEAR_DELAY 0.1
#define JOCKEY_JUMP_NEAR_RANGE 400.0 // この範囲に生存者がいたら荒ぶる
#define JOCKEY_JUMP_MIN_SPEED 130.0
#define BOMMER_SCAN_DELAY 0.5
#define SPITTER_RUN 200.0
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.1
#define CHARGER_MELEE_DELAY 0.2
#define CHARGER_MELEE_RANGE 400.0

public Plugin myinfo =
{
	name = "HardCoop",
	description = "Advanced Special Infected AI",
	author = "",
	version = "1.0",
	url = ""
};

ConVar vs_tank_damage;
ConVar tongue_range;
ConVar z_vomit_range;
ConVar tank_attack_range;

bool SurvivorNearTank[MAXPLAYERS + 1];

float s_tounge_range;
float s_vomit_range;
float s_tank_attack_range;
float tankDamage;
float g_L4D2Infected_attack_time;
float throwForce[MAXPLAYERS + 1][3];

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
public void OnPluginStart()
{
	vs_tank_damage = FindConVar("vs_tank_damage");
	tongue_range = FindConVar("tongue_range");
	z_vomit_range = FindConVar("z_vomit_range");
	tank_attack_range = FindConVar("tank_attack_range");
	
	vs_tank_damage.AddChangeHook(ConVarChange);
	tongue_range.AddChangeHook(ConVarChange);
	z_vomit_range.AddChangeHook(ConVarChange);
	tank_attack_range.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	AddCommandListener(TeamCmd, "jointeam");
	HookEvent("player_transitioned", ResetSurvivors);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	tankDamage = vs_tank_damage.FloatValue;
	s_tounge_range = tongue_range.FloatValue;
	s_vomit_range = z_vomit_range.FloatValue;
	s_tank_attack_range = tank_attack_range.FloatValue;
}

public Action TeamCmd(int client, const char[] command, int argc)
{
	return Plugin_Handled;
}

public Action ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client))
	{
		L4D2_RestoreHealth(client);
		L4D2_ResetInventory(client);
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(2.0, Timer_ForceInfectedAssault, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ForceInfectedAssault(Handle timer)
{
	L4D2_CheatCommand(0, "nb_assault");
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SurvivorNearTank[i] = false;
		throwForce[i][0] = 0.0;
		throwForce[i][1] = 0.0;
		throwForce[i][2] = 0.0;
	}
}

public void L4D2_OnRealRoundEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !L4D2_IsSurvivor(i) && IsFakeClient(i))
			CreateTimer(0.1, Timer_KickBot, i);
	}
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (
		!L4D2_IsValidClient(victim) || !L4D2_IsSurvivor(victim) || !IsPlayerAlive(victim) || 
		!L4D2_IsValidClient(attacker) || !IsPlayerAlive(attacker) || L4D2_GetInfectedClass(attacker) != L4D2Infected_Tank
	) return Plugin_Continue;
	char classname[64];
	if (attacker == inflictor) GetClientWeapon(inflictor, classname, sizeof(classname));
	else GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrContains(classname, "tank_claw", false) != -1)
	{
		for (int i = 0; i < NUM_OF_SURVIVORS; i++)
		{
			int index = L4D2_GetSurvivorOfIndex(i);
			if (index == 0 || !IsPlayerAlive(index) || index == victim || !SurvivorNearTank[index]) continue;
			
			if (!L4D2_IsPlayerIncap(index)) L4D2_SetAnimFling(index, attacker, throwForce[index]);
			SDKHooks_TakeDamage(index, attacker, attacker, tankDamage, DMG_GENERIC);
		}
	}
	return Plugin_Continue;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	CreateTimer(0.1, Tank_Distance, tankClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Tank_Distance(Handle timer, any client)
{
	if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client) || L4D2_GetInfectedClass(client) != L4D2Infected_Tank || !IsPlayerAlive(client)) return Plugin_Stop;
	float survivorPos[3], tankPos[3];
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		GetClientAbsOrigin(client, tankPos);
		GetClientAbsOrigin(index, survivorPos);
		if (GetVectorDistance(survivorPos, tankPos) < 120)
		{
			NormalizeVector(survivorPos, survivorPos);
			NormalizeVector(tankPos, tankPos);
			throwForce[index][0] = L4D2_Clamp((360000.0 * (survivorPos[0] - tankPos[0])), -400.0, 400.0);
			throwForce[index][1] = L4D2_Clamp((90000.0 * (survivorPos[1] - tankPos[1])), -400.0, 400.0);
			throwForce[index][2] = 300.0;
			SurvivorNearTank[index] = true;
		}
		else
		{
			SurvivorNearTank[index] = false;
			throwForce[index][0] = 0.0;
			throwForce[index][1] = 0.0;
			throwForce[index][2] = 0.0;
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnTankRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (GetEntityMoveType(client) != MOVETYPE_LADDER && (GetEntityFlags(client) & FL_ONGROUND) && IsPlayerAlive(client))
	{
		int target = GetClientAimTarget(client, true);
		if (target > 0 && L4D2_IsSurvivor(target) && isVisibleTo(client, target))
		{
			float target_pos[3];
			float self_pos[3];
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			if (GetVectorDistance(self_pos, target_pos) < 150)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
		if (L4D2_DelayExpired(client, 0, TANK_MELEE_SCAN_DELAY))
		{
			L4D2_DelayStart(client, 0);
			if (L4D2_NearestActiveSurvivorDistance(client) < s_tank_attack_range * 0.95)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnSmokerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (buttons & IN_ATTACK)
	{
		g_L4D2Infected_attack_time = GetGameTime();
	}
	else if (L4D2_DelayExpired(client, 0, SMOKER_ATTACK_SCAN_DELAY) && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		L4D2_DelayStart(client, 0);
		int target = GetClientAimTarget(client, true);
		if (target > 0 && L4D2_IsSurvivor(target) && isVisibleTo(client, target))
		{
			float target_pos[3], self_pos[3], dist;
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < SMOKER_MELEE_RANGE)
			{
				buttons |= IN_ATTACK|IN_ATTACK2;
				return Plugin_Changed;
			}
			else if (dist < s_tounge_range)
			{
				if (GetGameTime() - g_L4D2Infected_attack_time < SMOKER_ATTACK_TOGETHER_LIMIT)
				{
					buttons |= IN_ATTACK;
					return Plugin_Changed;
				}
				else
				{
					int target_aim = GetClientAimTarget(target, true);
					if (target_aim == client)
					{
						buttons |= IN_ATTACK;
						return Plugin_Changed;
					}
				}
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnHunterRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	Action ret = Plugin_Continue;
	bool internal_trigger = false;

	if (!L4D2_DelayExpired(client, 1, HUNTER_ATTACK_TIME) && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		buttons |= IN_DUCK;
		if (GetRandomInt(0, HUNTER_REPEAT_SPEED) == 0)
		{
			buttons |= IN_ATTACK;
			internal_trigger = true;
		}
		ret = Plugin_Changed;
	}
	if (!(GetEntityFlags(client) & FL_ONGROUND) && L4D2_GetState(client, HUNTER_STATE_FLY_FLAG) == 0)
	{
		L4D2_DelayStart(client, 2);
		L4D2_SetState(client, HUNTER_STATE_FALL_FLAG, 0);
		L4D2_SetState(client, HUNTER_STATE_FLY_FLAG, 1);
	}
	else if (!(GetEntityFlags(client) & FL_ONGROUND))
	{
		if (L4D2_GetState(client, HUNTER_STATE_FLY_TYPE) == IN_FORWARD)
		{
			buttons |= IN_FORWARD;
			vel[0] = VEL_MAX;
			if (L4D2_GetState(client, HUNTER_STATE_FALL_FLAG) == 0 && L4D2_DelayExpired(client, 2, HUNTER_FALL_DELAY))
			{
				if (angles[2] == 0.0)
				{
					angles[0] = GetRandomFloat(-50.0, 20.0);
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				L4D2_SetState(client, HUNTER_STATE_FALL_FLAG, 1);
			}
		ret = Plugin_Changed;
		}
	}
	else if (L4D2_GetState(client, 2) == 1)
	{
		// 着地
	}
	else
	{
		L4D2_SetState(client, HUNTER_STATE_FLY_FLAG, 0);
	}
	if (L4D2_DelayExpired(client, 0, HUNTER_FLY_DELAY) && (buttons & IN_ATTACK) && (GetEntityFlags(client) & FL_ONGROUND))
	{
		float dist = L4D2_NearestSurvivorDistance(client);
		L4D2_DelayStart(client, 0);
		if (!internal_trigger && !(buttons & IN_BACK) && dist < HUNTER_NEAR_RANGE && L4D2_DelayExpired(client, 1, HUNTER_ATTACK_TIME + HUNTER_COOLDOWN_DELAY))
		{
			L4D2_DelayStart(client, 1);
		}
		if (GetRandomInt(0, 1) == 0)
		{
			if (dist < HUNTER_NEAR_RANGE)
			{
				if (angles[2] == 0.0)
				{
					if (GetRandomInt(0, 4) == 0)
					{
						angles[0] = GetRandomFloat(-50.0, -30.0);
					}
					else
					{
						angles[0] = GetRandomFloat(-10.0, 20.0);
					}
					TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
				}
				L4D2_SetState(client, HUNTER_STATE_FLY_TYPE, IN_FORWARD);
			}
			else
			{
				L4D2_SetState(client, HUNTER_STATE_FLY_TYPE, 0);
			}
		}
		else
		{
			L4D2_SetState(client, HUNTER_STATE_FLY_TYPE, 0);
		}
		ret = Plugin_Changed;
	}
	return ret;
}

public Action L4D2_OnJockeyRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if ((L4D2_GetMoveSpeed(client)  > JOCKEY_JUMP_MIN_SPEED && (buttons & IN_FORWARD) && (GetEntityFlags(client) & FL_ONGROUND) 
	  && GetEntityMoveType(client) != MOVETYPE_LADDER) && ((L4D2_NearestSurvivorDistance(client) < JOCKEY_JUMP_NEAR_RANGE 
	  && L4D2_DelayExpired(client, 0, JOCKEY_JUMP_NEAR_DELAY)) || L4D2_DelayExpired(client, 0, JOCKEY_JUMP_DELAY)))
	{
		vel[0] = VEL_MAX;
		if (L4D2_GetState(client, 0) == IN_JUMP)
		{
			if (angles[2] == 0.0)
			{
				angles = angles;
				angles[0] = GetRandomFloat(-50.0,-10.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			buttons |= IN_ATTACK;
			L4D2_SetState(client, 0, IN_ATTACK);
		}
		else
		{
			if (angles[2] == 0.0)
			{
				angles[0] = GetRandomFloat(-10.0, 0.0);
				TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
			}
			buttons |= IN_JUMP;
			switch (GetRandomInt(0, 2))
			{
				case 0: { buttons |= IN_DUCK; }
				case 1: { buttons |= IN_ATTACK2; }
			}
			L4D2_SetState(client, 0, IN_JUMP);
		}
		L4D2_DelayStart(client, 0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action L4D2_OnBoomerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (buttons & IN_ATTACK)
	{
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	}
	else if (L4D2_DelayExpired(client, 0, BOMMER_SCAN_DELAY) && GetEntityMoveType(client) != MOVETYPE_LADDER)
	{
		L4D2_DelayStart(client, 0);
		int target = GetClientAimTarget(client, true);
		if (target > 0 && L4D2_IsSurvivor(target) && isVisibleTo(client, target))
		{
			float target_pos[3];
			float self_pos[3];
			float dist;
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < s_vomit_range)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnSpitterRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (L4D2_GetMoveSpeed(client) > SPITTER_RUN && L4D2_DelayExpired(client, 0, SPITTER_JUMP_DELAY) && (GetEntityFlags(client) & FL_ONGROUND))
	{
		L4D2_DelayStart(client, 0);
		buttons |= IN_JUMP;
		if (L4D2_GetState(client, 0) == IN_MOVERIGHT)
		{
			L4D2_SetState(client, 0, IN_MOVELEFT);
			buttons |= IN_MOVERIGHT;
			vel[1] = VEL_MAX;
		}
		else
		{
			L4D2_SetState(client, 0, IN_MOVERIGHT);
			buttons |= IN_MOVELEFT;
			vel[1] = -VEL_MAX;
		}
		return Plugin_Changed;
	}
	if (buttons & IN_ATTACK)
	{
		if (L4D2_DelayExpired(client, 1, SPITTER_SPIT_DELAY))
		{
			L4D2_DelayStart(client, 1);
			buttons |= IN_JUMP;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action L4D2_OnChargerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
	if (!(buttons & IN_ATTACK) && GetEntityMoveType(client) != MOVETYPE_LADDER && (GetEntityFlags(client) & FL_ONGROUND)
		&& L4D2_DelayExpired(client, 0, CHARGER_MELEE_DELAY) && L4D2_NearestSurvivorDistance(client) < CHARGER_MELEE_RANGE)
	{
		L4D2_DelayStart(client, 0);
		buttons |= IN_ATTACK2;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/
bool isVisibleTo(int client, int target)
{
	bool ret = false;
	float angles[3];
	float self_pos[3];
	float target_pos[3];
	float lookat[3];
	GetClientEyePosition(client, self_pos);
	GetClientEyePosition(target, target_pos);
	MakeVectorFromPoints(self_pos, target_pos, lookat);
	GetVectorAngles(lookat, angles);
	Handle trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
	if (TR_DidHit(trace))
	{
		int hit = TR_GetEntityIndex(trace);
		if (hit == target)
		{
			ret = true;
		}
	}
	CloseHandle(trace);
	return ret;
}

public bool traceFilter(int entity, int mask, any self)
{
	return entity != self;
}
