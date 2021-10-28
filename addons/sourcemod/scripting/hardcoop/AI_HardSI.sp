#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

#define SMOKER_TONGUE_DELAY 1.0
#define ASSAULT_DELAY 0.3 // using 0.3 to be safe (command does not register in the first 0.2 seconds after spawn)
#define MAX_CHARGE_PROXIMITY 400
#define POSITIVE 0
#define NEGATIVE 1
#define X 0
#define Y 1
#define Z 2
#define STRAIGHT_POUNCE_PROXIMITY 100
#define CMD_ATTACK 0
#define BoostForward 60.0 // Bhop

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
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.1
#define CHARGER_MELEE_DELAY 0.2

#define MOVESPEED_MAX     1000

public Plugin myinfo = 
{
	name = "AI: Hard SI",
	author = "Breezy, High Cookie, Standalone, Newteee",
	description = "Improves the AI behaviour of special infected",
	version = "1.1",
	url = "github.com/breezyplease"
};

enum VelocityOverride
{
	VelocityOvr_None = 0,
	VelocityOvr_Velocity,
	VelocityOvr_OnlyWhenNegative,
	VelocityOvr_InvertReuseVelocity
};

static const int ai_fast_pounce_proximity = 2000;  //在什么距离开始快速猛扑
static const float ai_pounce_vertical_angle = 7.0; //AI猎人猛扑的垂直角度将受到限制
static const float ai_pounce_angle_mean = 10.0;  //Gaussian RNG 产生的平均角度
static const float ai_pounce_angle_std = 20.0;  //由 Gaussian RNG 产生的与平均值的一个标准偏差
static const int ai_straight_pounce_proximity = 200;  //到最近的幸存者的距离，猎人会考虑直接突袭
static const int ai_aim_offset_sensitivity_hunter = 360;  //如果猎人有目标，如果目标在水平轴上的瞄准在这个半径内，则不会直接突袭
static const int ai_wall_detection_distance = -1;  //被感染的机器人在他自己面前多远会检查一堵墙。 使用“-1”禁用功能
static const int ai_charge_proximity = 250;  //充电前充电器会靠近多远
static const int ai_health_threshold_charger = 300;  //如果充电器的生命值下降到这个水平，它就会充电
//static const int ai_jockey_stumble_radius = 50;
static const int ai_aim_offset_sensitivity_charger = 20;

ConVar cvLungeInterval;
ConVar cvJockeyLeapAgainTimer;
ConVar cvTongueDelay;
ConVar cvSmokerHealth;
ConVar cvChokeDamageInterrupt;
ConVar cvTankAttackRange;
ConVar cvTongueRange;
ConVar cvVomitRange;

bool bHasQueuedLunge[MAXPLAYERS+1];
bool bCanLunge[MAXPLAYERS+1];
bool bHasHunterShoved[MAXPLAYERS+1];
bool bHasJockeyShoved[MAXPLAYERS+1]; // shoved jockeys will stop hopping
bool bCanLeap[MAXPLAYERS+1];
bool bDoNormalJump[MAXPLAYERS+1]; // used to alternate pounces and normal jumps

int bShouldCharge[MAXPLAYERS+1];
int g_targetSurvivor[MAXPLAYERS+1]; // survivor target of each special infected

float fLungeInterval;
float fJockeyLeapAgainTimer;
float g_L4D2Infected_attack_time;
float fTankAttackRange;
float fToungeRange;
float fVomitRange;
float g_move_grad[MAXPLAYERS+1][3];
float g_move_speed[MAXPLAYERS+1];
float g_pos[MAXPLAYERS+1][3];
float g_delay[MAXPLAYERS+1][8];
int g_state[MAXPLAYERS+1][8];

public void OnPluginStart()
{
	cvLungeInterval = FindConVar("z_lunge_interval");
	cvJockeyLeapAgainTimer = FindConVar("z_jockey_leap_again_timer");
	cvTankAttackRange = FindConVar("tank_attack_range");
	cvTongueRange = FindConVar("tongue_range");
	cvVomitRange = FindConVar("z_vomit_range");
	
	cvLungeInterval.AddChangeHook(ConVarChange);
	cvJockeyLeapAgainTimer.AddChangeHook(ConVarChange);
	cvTankAttackRange.AddChangeHook(ConVarChange);
	cvTongueRange.AddChangeHook(ConVarChange);
	cvVomitRange.AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
	
	cvSmokerHealth = FindConVar("z_gas_health");
	cvChokeDamageInterrupt = FindConVar("tongue_break_from_damage_amount"); 
	cvTongueDelay = FindConVar("smoker_tongue_delay"); 
	
	cvSmokerHealth.AddChangeHook(OnTongueCvarChange);
	cvChokeDamageInterrupt.AddChangeHook(OnTongueCvarChange);
	cvTongueDelay.AddChangeHook(OnTongueCvarChange);
	OnTongueCvarChange(null, "", "");
	
	HookEvent("player_spawn", OnPlayerSpawn, EventHookMode_Pre);
	HookEvent("ability_use", OnAbilityUse, EventHookMode_Pre);
	HookEvent("player_shoved", OnPlayerShoved, EventHookMode_Pre);
	HookEvent("player_jump", OnPlayerJump, EventHookMode_Pre);
	HookEvent("player_incapacitated", OnPlayerImmobilised, EventHookMode_Pre);
	HookEvent("player_death", OnPlayerImmobilised, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	ResetConVar(cvChokeDamageInterrupt);
	ResetConVar(cvTongueDelay);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fLungeInterval = cvLungeInterval.FloatValue;
	fJockeyLeapAgainTimer = cvJockeyLeapAgainTimer.FloatValue;
	fTankAttackRange = cvTankAttackRange.FloatValue;
	fToungeRange = cvTongueRange.FloatValue;
	fVomitRange = cvVomitRange.FloatValue;
}

public void OnTongueCvarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	cvTongueDelay.SetFloat(SMOKER_TONGUE_DELAY);	
	cvChokeDamageInterrupt.SetInt(cvSmokerHealth.IntValue);
}

public void L4D2_OnRealRoundStart()
{
	float time = GetGameTime();
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_move_speed[i] = 0.0;
		for (int j = 0; j < 8; j++)
		{
			g_delay[i][j] = time;
			g_state[i][j] = 0;
		}
		for (int j = 0; j < 3; j++)
		{
			g_move_grad[i][j] = 0.0;
			g_pos[i][j] = 0.0;
		}
	}
}

public Action OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsBotInfected(client)) return;
	CreateTimer(ASSAULT_DELAY, Timer_PostSpawnAssault, client, TIMER_FLAG_NO_MAPCHANGE);
	if (IsCapper(client)) g_targetSurvivor[client] = GetTargetSurvivor();
	switch (GetInfectedClass(client))
	{
		case (L4D2Infected_Hunter):
		{
			bHasQueuedLunge[client] = false;
			bCanLunge[client] = true;
			bHasHunterShoved[client] = false;
		}
		case (L4D2Infected_Charger):
		{
			bShouldCharge[client] = false;
		}
		case (L4D2Infected_Jockey):
		{
			bHasJockeyShoved[client] = false;
			bCanLeap[client] = true;
		}
	}
}

public Action Timer_PostSpawnAssault(Handle timer, any client)
{
	CheatCommand(client, "nb_assault");
	return Plugin_Stop;
}

public Action OnAbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsBotInfected(client))
	{
		if (IsJockey(client)) bHasJockeyShoved[client] = false;
		
		char abilityName[32];
		event.GetString("ability", abilityName, sizeof(abilityName));
		
		if (StrEqual(abilityName, "ability_lunge"))
		{
			bHasHunterShoved[client] = false;
			int entLunge = GetEntPropEnt(client, Prop_Send, "m_customAbility");	
			float lungeVector[3];
			GetEntPropVector(entLunge, Prop_Send, "m_queuedLunge", lungeVector);
			float hunterPos[3];
			float hunterAngle[3];
			GetClientAbsOrigin(client, hunterPos);
			GetClientEyeAngles(client, hunterAngle); 
			TR_TraceRayFilter( hunterPos, hunterAngle, MASK_PLAYERSOLID, RayType_Infinite, TracerayFilter, client );
			float impactPos[3];
			TR_GetEndPosition( impactPos );
			if (GetVectorDistance(hunterPos, impactPos) < ai_wall_detection_distance)
			{
				if (GetRandomInt(0, 1))
				{
					AngleLunge(entLunge, 45.0);
				}
				else
				{
					AngleLunge(entLunge, 315.0);
				}
			}
			else
			{
				GetClientAbsOrigin(client, hunterPos);		
				if (IsTargetWatchingAttacker(client, ai_aim_offset_sensitivity_hunter) && GetSurvivorProximity(hunterPos) > ai_straight_pounce_proximity)
				{
					float pounceAngle = GaussianRNG(ai_pounce_angle_mean, ai_pounce_angle_std);
					AngleLunge(entLunge, pounceAngle);
					LimitLungeVerticality(entLunge);
					return Plugin_Changed;					
				}	
			}
		}
		else if (StrEqual(abilityName, "ability_charge"))
		{
			int aimTarget = GetClientAimTarget(client);
			if (!IsValidSurvivor(aimTarget) || IsTargetWatchingAttacker(client, ai_aim_offset_sensitivity_charger))
			{	
				float chargerPos[3];
				GetClientAbsOrigin(client, chargerPos);
				int newTarget = GetClosestSurvivor(chargerPos, aimTarget);
				if (newTarget != -1 && GetSurvivorProximity(chargerPos, newTarget) <= ai_charge_proximity)
				{
					aimTarget = newTarget;
				}
				
				if (!IsBotInfected(client) || !IsCharger(client) || !IsValidSurvivor(aimTarget)) return Plugin_Continue;
				float survivorPos[3];
				float attackDirection[3];
				float attackAngle[3];
				GetClientAbsOrigin(client, chargerPos);
				GetClientAbsOrigin(aimTarget, survivorPos);
				MakeVectorFromPoints(chargerPos, survivorPos, attackDirection);
				GetVectorAngles(attackDirection, attackAngle);	
				TeleportEntity(client, NULL_VECTOR, attackAngle, NULL_VECTOR);
			}
		}
	}
	return Plugin_Continue;
}

public bool TracerayFilter(int impactEntity, int contentMask, any rayOriginEntity)
{
	return impactEntity != rayOriginEntity;
}

public Action OnPlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int player = GetClientOfUserId(event.GetInt("userid"));
	if (IsBotInfected(player) && IsJockey(player)) bHasJockeyShoved[player] = false;
}

public Action OnPlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int shovedPlayer = GetClientOfUserId(event.GetInt("userid"));
	if (!IsBotInfected(shovedPlayer)) return;
	if (IsHunter(shovedPlayer)) bHasHunterShoved[shovedPlayer] = true;
	if (IsJockey(shovedPlayer))
	{
		bHasJockeyShoved[shovedPlayer] = true;
		if (GetInfectedClass(shovedPlayer) == L4D2Infected_Jockey )
		{
			bCanLeap[shovedPlayer] = false;
			CreateTimer(fJockeyLeapAgainTimer, Timer_LeapCooldown, shovedPlayer, TIMER_FLAG_NO_MAPCHANGE) ;
		}
	}
}

public Action Timer_LeapCooldown(Handle timer, any jockey)
{
	bCanLeap[jockey] = true;
}

public Action OnPlayerImmobilised(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidAndInGame(client))
	{
		if (
			(StrEqual(name, "player_incapacitated") && IsSurvivor(client)) || 
			(StrEqual(name, "player_death"))
		) RefreshTargets();
	}	
}

public Action OnTankRunCmd(int client, int &buttons)
{
	int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
	if (sequence == 54 || sequence == 55 || sequence == 57)
	{
		SetEntProp(client, Prop_Send, "m_nSequence", 0);
		return Plugin_Changed;
	}
	if ((buttons & IN_ATTACK2) || sequence == 56)
	{
		buttons |= IN_ATTACK;
		return Plugin_Changed;
	}
	
	int target = GetClientAimTarget(client, true);
	if (IsValidSurvivor(target) && isVisibleTo(client, target))
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
	if (GetGameTime() - g_delay[client][0] > TANK_MELEE_SCAN_DELAY)
	{
		g_delay[client][0] = GetGameTime();
		if (NearestActiveSurvivorDistance(client) < fTankAttackRange * 0.95)
		{
			buttons |= IN_ATTACK;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnSmokerRunCmd(int client, int &buttons)
{
	if (buttons & IN_ATTACK)
	{
		g_L4D2Infected_attack_time = GetGameTime();
	}
	else if (GetGameTime() - g_delay[client][0] > SMOKER_ATTACK_SCAN_DELAY)
	{
		g_delay[client][0] = GetGameTime();
		int target = GetClientAimTarget(client, true);
		if (IsValidSurvivor(target) && isVisibleTo(client, target))
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
			else if (dist < fToungeRange)
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

public Action OnHunterRunCmd(int client, int &buttons)
{
	buttons &= ~IN_ATTACK2;
	if (!bHasHunterShoved[client])
	{
		int flags = GetEntityFlags(client);
		if ((flags & FL_DUCKING) && (flags & FL_ONGROUND))
		{
			float hunterPos[3];
			GetClientAbsOrigin(client, hunterPos);
			int iSurvivorsProximity = GetSurvivorProximity(hunterPos, -1);
			if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && (iSurvivorsProximity < ai_fast_pounce_proximity))
			{
				buttons &= ~IN_ATTACK;
				if (!bHasQueuedLunge[client])
				{
					bCanLunge[client] = false;
					bHasQueuedLunge[client] = true;
					CreateTimer(fLungeInterval, Timer_LungeInterval, client, TIMER_FLAG_NO_MAPCHANGE);
				}
				else if (bCanLunge[client])
				{
					buttons |= IN_ATTACK;
					bHasQueuedLunge[client] = false;
				}
			}
		}
	}
	return Plugin_Changed;
}

public Action Timer_LungeInterval(Handle timer, any client)
{
	bCanLunge[client] = true;
	return Plugin_Stop;
}

public Action OnJockeyRunCmd(int client, int &buttons)
{
	int flags = GetEntityFlags(client);
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	float currentspeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
	float clientEyeAngles[3];
	GetClientEyeAngles(client, clientEyeAngles);
	float jockeyPos[3];
	GetClientAbsOrigin(client, jockeyPos);
	int iSurvivorsProximity = GetSurvivorProximity(jockeyPos, -1);
	if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && 1500 > iSurvivorsProximity > 250)
	{
		if (currentspeed > 200.0)
		{
			if (flags & 1)
			{
				buttons = buttons | IN_DUCK;
				buttons = buttons | IN_JUMP;
				if (buttons & IN_FORWARD)
				{
					Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
				}
				if (buttons & IN_BACK)
				{
					clientEyeAngles[1] += 180.0;
					Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
				}
				if (buttons & IN_MOVELEFT)
				{
					clientEyeAngles[1] += 90.0;
					Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
				}
				if (buttons & IN_MOVERIGHT)
				{
					clientEyeAngles[1] += -90.0;
					Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
				}
			}
			if (GetEntityMoveType(client) & MOVETYPE_LADDER)
			{
				buttons = buttons & -3;
				buttons = buttons & -5;
			}
			return Plugin_Changed;
		}
		
		buttons |= IN_FORWARD;
		
		if (!bHasJockeyShoved[client] && (flags & FL_ONGROUND))
		{
			if (bDoNormalJump[client])
			{
				buttons |= IN_JUMP;
				bDoNormalJump[client] = false;
			}
			else
			{
				if (bCanLeap[client])
				{
					buttons |= IN_ATTACK;
					bCanLeap[client] = false;
					CreateTimer(fJockeyLeapAgainTimer, Timer_LeapCooldown, client, TIMER_FLAG_NO_MAPCHANGE);
					bDoNormalJump[client] = true;
				} 			
			}
		}
		else
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_ATTACK;
		}		
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnBoomerRunCmd(int client, int &buttons)
{
	int flags = GetEntityFlags(client);
	float clientEyeAngles[3];
	GetClientEyeAngles(client, clientEyeAngles);
	float boomerPos[3];
	GetClientAbsOrigin(client, boomerPos);
	int iSurvivorsProximity = GetSurvivorProximity(boomerPos, -1);
	if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && 1500 > iSurvivorsProximity > 200)
	{
		if (flags & FL_ONGROUND)
		{
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			if (buttons & IN_FORWARD)
			{
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_MOVELEFT)
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_MOVERIGHT)
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
		}
		if (GetEntityMoveType(client) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	
	if (buttons & IN_ATTACK)
	{
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	}
	else if (GetGameTime() - g_delay[client][0] > BOMMER_SCAN_DELAY)
	{
		g_delay[client][0] = GetGameTime();
		int target = GetClientAimTarget(client, true);
		if (IsValidSurvivor(target) && isVisibleTo(client, target))
		{
			float target_pos[3];
			float self_pos[3];
			float dist;
			GetClientAbsOrigin(client, self_pos);
			GetClientAbsOrigin(target, target_pos);
			dist = GetVectorDistance(self_pos, target_pos);
			if (dist < fVomitRange)
			{
				buttons |= IN_ATTACK;
				return Plugin_Changed;
			}
		}
	}
	return Plugin_Continue;
}

public Action OnSpitterRunCmd(int client, int &buttons, float vel[3])
{
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	float currentspeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
	if (currentspeed > 200.0 && GetGameTime() - g_delay[client][0] > SPITTER_JUMP_DELAY)
	{
		g_delay[client][0] = GetGameTime();
		buttons |= IN_JUMP;
		if (g_state[client][0] == IN_MOVERIGHT)
		{
			g_state[client][0] = IN_MOVELEFT;
			buttons |= IN_MOVERIGHT;
			vel[1] = VEL_MAX;
		}
		else
		{
			g_state[client][0] = IN_MOVERIGHT;
			buttons |= IN_MOVELEFT;
			vel[1] = -VEL_MAX;
		}
		return Plugin_Changed;
	}
	if (buttons & IN_ATTACK)
	{
		if (GetGameTime() - g_delay[client][1] > SPITTER_SPIT_DELAY)
		{
			g_delay[client][1] = GetGameTime();
			buttons |= IN_JUMP;
			return Plugin_Changed;
		}
	}
	return Plugin_Continue;
}

public Action OnChargerRunCmd(int client, int &buttons)
{
	int flags = GetEntityFlags(client);
	float chargerPos[3];
	GetClientAbsOrigin(client, chargerPos);
	int target = GetClientAimTarget(client, true);
	int iProximity = GetSurvivorProximity(chargerPos, target);
	int chargerHealth = GetEntProp(client, Prop_Send, "m_iHealth");
	int chargeDistance = GetRandomInt(ai_charge_proximity, MAX_CHARGE_PROXIMITY);
	float clientEyeAngles[3];
	GetClientEyeAngles(client, clientEyeAngles);
	float fVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVelocity);
	float currentspeed = SquareRoot(Pow(fVelocity[0], 2.0) + Pow(fVelocity[1], 2.0));
	
	if (GetEntProp(client, Prop_Send, "m_hasVisibleThreats") && 1500 > iProximity > chargeDistance && currentspeed > 150.0)
	{
		if (flags & FL_ONGROUND)
		{
			buttons |= IN_DUCK;
			buttons |= IN_JUMP;
			if (buttons & IN_FORWARD)
			{
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_BACK)
			{
				clientEyeAngles[1] += 180.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_MOVELEFT)
			{
				clientEyeAngles[1] += 90.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
			if (buttons & IN_MOVERIGHT)
			{
				clientEyeAngles[1] += -90.0;
				Client_Push(client, clientEyeAngles, BoostForward, view_as<VelocityOverride>({VelocityOvr_None,VelocityOvr_None,VelocityOvr_None}));
			}
		}
		if (GetEntityMoveType(client) & MOVETYPE_LADDER)
		{
			buttons &= ~IN_JUMP;
			buttons &= ~IN_DUCK;
		}
	}
	
	if (chargerHealth > ai_health_threshold_charger && iProximity > chargeDistance)
	{
		if (!bShouldCharge[client] || IsPinned(target))
		{
			BlockCharge(client);
			return Plugin_Changed;
		}
	}
	else
	{
		bShouldCharge[client] = true;
	}
	
	if (target > 0 && 150 >= iProximity && !IsIncapacitated(target))
	{
		buttons |= IN_ATTACK2;
		buttons |= IN_ATTACK;
	}
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsValidInfected(client) || !IsFakeClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;
	if (!AnySurvivorAlive()) return Plugin_Continue;
	
	if (!GetEntProp(client, Prop_Send, "m_isGhost"))
	{
		switch (GetInfectedClass(client))
		{
			case L4D2Infected_Tank:
			{
				return OnTankRunCmd(client, buttons);
			}
			case L4D2Infected_Smoker:
			{
				return OnSmokerRunCmd(client, buttons);
			}
			case L4D2Infected_Hunter:
			{
				if (!bHasHunterShoved[client]) return OnHunterRunCmd(client, buttons);
			}
			case L4D2Infected_Jockey:
			{
				return OnJockeyRunCmd(client, buttons);
			}
			case L4D2Infected_Boomer:
			{
				return OnBoomerRunCmd(client, buttons);
			}
			case L4D2Infected_Spitter:
			{
				return OnSpitterRunCmd(client, buttons, vel);
			}
			case L4D2Infected_Charger:
			{
				return OnChargerRunCmd(client, buttons);
			}
		}
		if (IsCapper(client) && GetRandomInt(0, 100) < 50)
		{
			AttackTarget(client);
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client)) return Plugin_Continue;
	float pos[3];
	GetClientAbsOrigin(client, pos);
	g_move_grad[client][0] = pos[0] - g_pos[client][0];
	g_move_grad[client][1] = pos[1] - g_pos[client][1];
	g_move_grad[client][2] = pos[2] - g_pos[client][2];
	g_move_speed[client] = SquareRoot(g_move_grad[client][0] * g_move_grad[client][0] + g_move_grad[client][1] * g_move_grad[client][1]);
	if (g_move_speed[client] > MOVESPEED_MAX)
	{
		g_move_speed[client] = 0.0;
		g_move_grad[client][0] = 0.0;
		g_move_grad[client][1] = 0.0;
		g_move_grad[client][2] = 0.0;
	}
	g_pos[client] = pos;
	return Plugin_Continue;
}

bool IsBotInfected(int client)
{
	return IsValidInfected(client) && IsFakeClient(client);
}

bool IsHunter(int client)
{
	return GetInfectedClass(client) == L4D2Infected_Hunter;
}

bool IsJockey(int client)
{
	return GetInfectedClass(client) == L4D2Infected_Jockey;
}

bool IsCharger(int client)
{
	return GetInfectedClass(client) == L4D2Infected_Charger;
}

bool IsCapper(int client)
{
	L4D2_Infected zombieClass = GetInfectedClass(client);
	if (zombieClass != L4D2Infected_Boomer && zombieClass != L4D2Infected_Spitter && zombieClass != L4D2Infected_Tank)
	{
		return true;
	}
	return false;
}

void BlockCharge(int charger)
{
	int chargeEntity = GetEntPropEnt(charger, Prop_Send, "m_customAbility");
	if (chargeEntity > 0 || !GetEntProp(charger, Prop_Send, "m_hasVisibleThreats"))
	{
		SetEntPropFloat(chargeEntity, Prop_Send, "m_timestamp", GetGameTime() + 0.1);
	}
}


bool IsPinned(int client)
{
	bool bIsPinned = false;
	if (IsValidSurvivor(client))
	{
		if (GetEntPropEnt(client, Prop_Send, "m_tongueOwner") > 0) bIsPinned = true; // smoker
		if (GetEntPropEnt(client, Prop_Send, "m_pounceAttacker") > 0) bIsPinned = true; // hunter
		if (GetEntPropEnt(client, Prop_Send, "m_pummelAttacker") > 0) bIsPinned = true; // charger
		if (GetEntPropEnt(client, Prop_Send, "m_jockeyAttacker") > 0) bIsPinned = true; // jockey
	}		
	return bIsPinned;
}

int GetSurvivorProximity(const float rp[3], int specificSurvivor = -1)
{
	int targetSurvivor;
	float targetSurvivorPos[3];
	float referencePos[3];
	referencePos[0] = rp[0];
	referencePos[1] = rp[1];
	referencePos[2] = rp[2];
	if (IsValidSurvivor(specificSurvivor))
	{
		targetSurvivor = specificSurvivor;		
	}
	else
	{
		targetSurvivor = GetClosestSurvivor(referencePos);
	}
	GetClientAbsOrigin(targetSurvivor, targetSurvivorPos);
	return RoundToNearest(GetVectorDistance(referencePos, targetSurvivorPos));
}

int GetClosestSurvivor(float referencePos[3], int excludeSurvivor = -1)
{
	float survivorPos[3];
	int closestSurvivor = GetRandomSurvivor();	
	if (!IsValidAndInGame(closestSurvivor)) 
	{
		LogError("GetClosestSurvivor([%f, %f, %f], %d) = invalid client %d", referencePos[0], referencePos[1], referencePos[2], excludeSurvivor, closestSurvivor);
		return -1;
	}
	GetClientAbsOrigin(closestSurvivor, survivorPos);
	int iClosestAbsDisplacement = RoundToNearest(GetVectorDistance(referencePos, survivorPos));
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int client = L4D2_GetSurvivorOfIndex(i);
		if (client == 0 || client == excludeSurvivor) continue;
		GetClientAbsOrigin( client, survivorPos );
		int displacement = RoundToNearest(GetVectorDistance(referencePos, survivorPos));			
		if (displacement < iClosestAbsDisplacement || iClosestAbsDisplacement < 0)
		{
			iClosestAbsDisplacement = displacement;
			closestSurvivor = client;
		}
	}
	return closestSurvivor;
}



void CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (!IsValidAndInGame(client))
		{
			int[] player = new int[MaxClients];
			int numplayer = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					player[numplayer] = i;
					numplayer++;
				}
			}
			client = player[GetRandomInt(0, numplayer - 1)];
		}
		if (IsValidAndInGame(client))
		{
		    int originalUserFlags = GetUserFlagBits(client);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(client, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(client, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(client, originalUserFlags);
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}

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

void AngleLunge(int lungeEntity, float turnAngle)
{
	float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
	turnAngle = DegToRad(turnAngle);
	float forcedLunge[3];
	forcedLunge[X] = x * Cosine(turnAngle) - y * Sine(turnAngle); 
	forcedLunge[Y] = x * Sine(turnAngle)   + y * Cosine(turnAngle);
	forcedLunge[Z] = z;
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", forcedLunge);	
}

void LimitLungeVerticality(int lungeEntity)
{
	float vertAngle = ai_pounce_vertical_angle;
	float lungeVector[3];
	GetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", lungeVector);
	float x = lungeVector[X];
	float y = lungeVector[Y];
	float z = lungeVector[Z];
	vertAngle = DegToRad(vertAngle);	
	float flatLunge[3];
	flatLunge[Y] = y * Cosine(vertAngle) - z * Sine(vertAngle);
	flatLunge[Z] = y * Sine(vertAngle) + z * Cosine(vertAngle);
	flatLunge[X] = x * Cosine(vertAngle) + z * Sine(vertAngle);
	flatLunge[Z] = x * -Sine(vertAngle) + z * Cosine(vertAngle);
	SetEntPropVector(lungeEntity, Prop_Send, "m_queuedLunge", flatLunge);
}

float GaussianRNG(float mean, float std)
{
	float chanceToken = GetRandomFloat(0.0, 1.0);
	int signBit;	
	if (chanceToken >= 0.5)
	{
		signBit = POSITIVE;
	}
	else
	{
		signBit = NEGATIVE;
	}	   
	
	float x1;
	float x2;
	float w;
	do
	{
	    float random1 = GetRandomFloat( 0.0, 1.0 );
	    float random2 = GetRandomFloat( 0.0, 1.0 );
	 
	    x1 = (2.0 * random1) - 1.0;
	    x2 = (2.0 * random2) - 1.0;
	    w = (x1 * x1) + (x2 * x2);
	 
	} while (w >= 1.0);
	float e = 2.71828;
	w = SquareRoot((-2.0 * (Logarithm(w, e) / w)));

	float y1 = (x1 * w);
	float y2 = (x2 * w);
	float z1 = (y1 * std) + mean;
	float z2 = (y2 * std) - mean;
	
	if( signBit == NEGATIVE )return z1;
	else return z2;
}

void Client_Push(int client, float clientEyeAngle[3], float power, VelocityOverride override[3] = VelocityOvr_None)
{
	float forwardVector[3], newVel[3];
	GetAngleVectors(clientEyeAngle, forwardVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(forwardVector, forwardVector);
	ScaleVector(forwardVector, power);
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", newVel);
	
	for (int i = 0; i < 3; i++)
	{
		switch(override[i])
		{
			case VelocityOvr_Velocity:
			{
				newVel[i] = 0.0;
			}
			case VelocityOvr_OnlyWhenNegative:
			{
				if(newVel[i] < 0.0)
				{
					newVel[i] = 0.0;
				}
			}
			case VelocityOvr_InvertReuseVelocity:
			{
				if(newVel[i] < 0.0)
				{
					newVel[i] *= -1.0;
				}
			}
		}
		newVel[i] += forwardVector[i];
	}
	TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, newVel);
}

void AttackTarget(int client)
{
	int botID = GetClientUserId(client);
	int target = g_targetSurvivor[client];
	if (IsValidSurvivor(target))
	{
		if (IsMobile(target))
		{
			int targetID = GetClientUserId(target);		
			char clientName[MAX_NAME_LENGTH];
			if (IsBotInfected(client) && GetClientName(client, clientName, sizeof(clientName)))
			{
				if (StrContains(clientName, "dummy", false) == -1)
				{
					ScriptCommand("CommandABot({cmd=%i,bot=GetPlayerFromUserID(%i),target=GetPlayerFromUserID(%i)})", CMD_ATTACK, botID, targetID); // attack
				}
			}				
		}			
	}
}

void ScriptCommand(const char[] arguments, any ...)
{
	char vscript[PLATFORM_MAX_PATH];
	VFormat(vscript, sizeof(vscript), arguments, 2);
	CheatCommand(0, "script", vscript);
}

bool IsMobile(int client)
{
	bool bIsMobile = true;
	if (IsValidSurvivor(client))
	{
		if (IsPinned(client) || IsIncapacitated(client) || !IsPlayerAlive(client))
		{
			bIsMobile = false;
		}
	} 
	return bIsMobile;
}

void RefreshTargets()
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsInfected(i) && IsFakeClient(i) && IsCapper(i) && IsPlayerAlive(i))
		{
			g_targetSurvivor[i] = GetTargetSurvivor();
		}
	}
}

int GetTargetSurvivor()
{
	int target = -1;
	bool bDoesPermHealthRemain = false;
	
	int[] survivors = new int[L4D2_GetSurvivorCount()];
	int numSurvivors = 0;
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int survivor = L4D2_GetSurvivorOfIndex(i);
		if (survivor == 0) continue;
	    survivors[numSurvivors] = survivor;
	    numSurvivors++;
		
		if (GetSurvivorIncapCount(survivor) < 1 && IsMobile(survivor))
		{
			bDoesPermHealthRemain = true;
		}
	}
	
	if (bDoesPermHealthRemain)
	{
		int iRandomSurvivor;
		do
		{
			iRandomSurvivor = survivors[GetRandomInt(0, numSurvivors - 1)];
		}
		while (GetSurvivorIncapCount(iRandomSurvivor) > 0);
		target = iRandomSurvivor;
	}		
	
	return target;
}

any NearestActiveSurvivorDistance(int client)
{
	float self[3];
	float min_dist = 100000.0;
	GetClientAbsOrigin(client, self);
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		if (!IsIncapacitated(client))
		{
			float target[3];
			GetClientAbsOrigin(index, target);
			float dist = GetVectorDistance(self, target);
			if (dist < min_dist)
			{
				min_dist = dist;
			}
		}
	}
	return min_dist;
}

bool IsTargetWatchingAttacker(int attacker, int offsetThreshold)
{
	bool isWatching = true;
	if (GetClientTeam(attacker) == 3 && IsPlayerAlive(attacker))
	{
		int target = GetClientAimTarget(attacker);
		if (IsValidSurvivor(target))
		{
			int aimOffset = RoundToNearest(GetPlayerAimOffset(target, attacker));
			if (aimOffset <= offsetThreshold)
			{
				isWatching = true;
			}
			else
			{
				isWatching = false;
			}		
		} 
	}	
	return isWatching;
}

float GetPlayerAimOffset(int attacker, int target)
{
	if (!IsClientInGame(attacker) || !IsPlayerAlive(attacker))
		ThrowError("Client is not Alive."); 
	if (!IsClientInGame(target) || !IsPlayerAlive(target))
		ThrowError("Target is not Alive.");
		
	float attackerPos[3], targetPos[3];
	float aimVector[3], directVector[3];
	float resultAngle;
	
	GetClientEyeAngles(attacker, aimVector);
	aimVector[0] = aimVector[2] = 0.0;
	GetAngleVectors(aimVector, aimVector, NULL_VECTOR, NULL_VECTOR);
	NormalizeVector(aimVector, aimVector);
	
	GetClientAbsOrigin(target, targetPos); 
	GetClientAbsOrigin(attacker, attackerPos);
	attackerPos[2] = targetPos[2] = 0.0;
	MakeVectorFromPoints(attackerPos, targetPos, directVector);
	NormalizeVector(directVector, directVector);
	
	resultAngle = RadToDeg(ArcCosine(GetVectorDotProduct(aimVector, directVector)));
	return resultAngle;
}

bool AnySurvivorAlive()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		if (!IsIncapacitated(index))
		{
			return true;
		}
	}
	return false;
}
