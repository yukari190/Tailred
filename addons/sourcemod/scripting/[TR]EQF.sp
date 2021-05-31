#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

#define SURVIVOR_RUNSPEED		220.0
#define SURVIVOR_WATERSPEED_VS	170.0

public Plugin myinfo =
{
	name = "L4D2 Equitable",
	description = "",
	author = "",
	version = "1.0",
	url = ""
};

ConVar hSurvivorLimpHealth;
ConVar hMaxStaggerDuration;
ConVar hPounceCrouchDelay;
ConVar hLeapInterval;
ConVar hCvarTankSpeedVS;
bool blockStumble;
int iSurvivorLimpHealth;
float throwQueuedAt[MAXPLAYERS+1];
float staggerTime;
float fPounceCrouchDelay;
float fLeapInterval;
float fTankRunSpeed;

public void OnPluginStart()
{
	hSurvivorLimpHealth = FindConVar("survivor_limp_health");
	hMaxStaggerDuration = FindConVar("z_max_stagger_duration");
	hPounceCrouchDelay = FindConVar("z_pounce_crouch_delay");
	hLeapInterval = FindConVar("z_leap_interval");
	hCvarTankSpeedVS = FindConVar("z_tank_speed_vs");
	
	hSurvivorLimpHealth.AddChangeHook(ConVarChange);
	hMaxStaggerDuration.AddChangeHook(ConVarChange);
	hPounceCrouchDelay.AddChangeHook(ConVarChange);
	hLeapInterval.AddChangeHook(ConVarChange);
	hCvarTankSpeedVS.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	HookEvent("jockey_ride_end", JockeyRideEnd, EventHookMode_Post);
	HookEvent("player_shoved", OutSkilled, EventHookMode_Post);
	HookEvent("player_incapacitated_start", Incap_Event, EventHookMode_Post);
	HookEvent("player_incapacitated", PlayerIncap);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSurvivorLimpHealth = hSurvivorLimpHealth.IntValue;
	staggerTime = hMaxStaggerDuration.FloatValue;
	fPounceCrouchDelay = hPounceCrouchDelay.FloatValue;
	fLeapInterval = hLeapInterval.FloatValue;
	fTankRunSpeed = hCvarTankSpeedVS.FloatValue;
}

public void OnMapStart()
{
	CreateEntityByName("shadow_control");
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "shadow_control")) != -1)
	{
		SetVariantInt(1);
		AcceptEntityInput(ent, "SetShadowsDisabled");
	}
}

public void L4D2_OnRealRoundStart()
{
	blockStumble = false;
	for (int i = 1; i <= MAXPLAYERS; i++)
	  throwQueuedAt[i] = 0.0;
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
	if (L4D2_IsInfected(victim))
	{
		SetEntPropFloat(victim, Prop_Send, "m_flVelocityModifier", 1.0);
	}
	
	if (L4D2_IsSurvivor(victim) && L4D2_IsValidClient(attacker) && L4D2_IsInfected(attacker)
	  && IsTank(attacker) && !IsFakeClient(attacker) && damage >= 5)
	  L4D2_SetTankFrustration(attacker, 100);
	
    if (L4D2_IsSurvivor(victim) && StrEqual(weapon, "tank_claw"))
    {
        int activeweapon = GetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon");
        if (IsValidEdict(activeweapon))
        {
            char weaponname[64];
            GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));    
            
            if (StrEqual(weaponname, "weapon_melee", false) && GetPlayerWeaponSlot(victim, 0) != -1)
            {
                int PrimaryWeapon = GetPlayerWeaponSlot(victim, 0);
                SetEntPropEnt(victim, Prop_Send, "m_hActiveWeapon", PrimaryWeapon);
				SetEntPropFloat(PrimaryWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.1); // Prevent players instantly firing their Primary Weapon when they're holding down M1 with their melee.
            }
        }
    }
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Continue;
	if (L4D2_IsInfected(client) && IsTank(client))
	{
		if ((buttons & IN_JUMP) && (1.5 > GetGameTime() - throwQueuedAt[client]))
		{
			buttons &= ~IN_JUMP;
		}
		if (!IsFakeClient(client)) return Plugin_Continue;
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == 54 || sequence == 55 || sequence == 57) SetEntProp(client, Prop_Send, "m_nSequence", 0);
		if (sequence == 56) buttons |= IN_ATTACK;
		if ((buttons & IN_ATTACK2)) buttons |= IN_ATTACK;
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Continue;
	//if (GetEntityFlags(client) & FL_INWATER)
	{
		if (L4D2_IsSurvivor(client)) 
		{
			if (GetEntProp(client, Prop_Send, "m_bAdrenalineActive")) 
			  return Plugin_Continue;
			if (!IsLimping(client))
			{
				retVal = SURVIVOR_RUNSPEED;
				return Plugin_Handled;
			}
		}
		else if (L4D2_IsInfected(client) && IsTank(client))
		{
			retVal = fTankRunSpeed;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

public Action L4D_OnShovedBySurvivor(int shover, int shovee, const float vector[3])
{
	if (!L4D2_IsValidClient(shover) || !L4D2_IsSurvivor(shover)
	  || !L4D2_IsValidClient(shovee) || !L4D2_IsInfected(shovee) || !IsPlayerAlive(shovee))
	  return Plugin_Continue;
	if (IsTankOrCharger(shovee) || (IsHunter(shovee) && L4D2_GetInfectedVictim(shovee) == -1))
	  return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D2_OnEntityShoved(int shover, int shovee_ent, int weapon, float vector[3], bool bIsHunterDeadstop)
{
	if (!L4D2_IsValidClient(shover) || !L4D2_IsSurvivor(shover)
	  || !L4D2_IsValidClient(shovee_ent) || !L4D2_IsInfected(shovee_ent) || !IsPlayerAlive(shovee_ent))
	  return Plugin_Continue;
	if (IsTankOrCharger(shovee_ent) || (IsHunter(shovee_ent) && L4D2_GetInfectedVictim(shovee_ent) == -1))
	  return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D2_OnStagger(int target)
{
	if (!L4D2_IsValidClient(target) || !L4D2_IsInfected(target) || !IsTank(target) || !blockStumble)
	{
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action L4D_OnCThrowActivate(int ability)
{
	if (!IsValidEntity(ability))
	{
		LogMessage("无效 'ability_throw' 索引: %d. 继续投掷.", ability);
		return Plugin_Continue;
	}
    blockStumble = true;
    CreateTimer(2.0, UnblockStumble);
	int client = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if (GetClientButtons(client) & IN_ATTACK) return Plugin_Handled;
	throwQueuedAt[client] = GetGameTime();
	return Plugin_Continue;
}

public Action UnblockStumble(Handle timer)
{
    blockStumble = false;
}

public Action JockeyRideEnd(Event event, char[] name, bool dontBroadcast)
{
    int jockeyAttacker = GetClientOfUserId(event.GetInt("userid"));
    int jockeyVictim = GetClientOfUserId(event.GetInt("victim"));
    if (L4D2_IsHangingFromLedge(jockeyVictim))
	{
		int iEntity = -1;
		while ((iEntity = FindEntityByClassname(iEntity, "ability_leap")) != -1)
		{
			if (GetEntPropEnt(iEntity, Prop_Send, "m_owner") == jockeyAttacker) break;
		}
		if (iEntity == -1) return;
		SetEntPropFloat(iEntity, Prop_Send, "m_timestamp", GetGameTime() + 12.0);
		SetEntPropFloat(iEntity, Prop_Send, "m_duration", 12.0);
	}
}

public Action OutSkilled(Event event, char[] name, bool dontBroadcast)
{
	int shovee = GetClientOfUserId(event.GetInt("userid"));
	int shover = GetClientOfUserId(event.GetInt("attacker"));
	if (!L4D2_IsValidClient(shover) || !L4D2_IsSurvivor(shover) || !L4D2_IsValidClient(shovee) || !L4D2_IsInfected(shovee)) return;
	L4D2_Infected zClass = L4D2_GetInfectedClass(shovee);
	if (zClass != L4D2Infected_Hunter && zClass != L4D2Infected_Jockey && zClass != L4D2Infected_Smoker) return;
	if (zClass == L4D2Infected_Smoker) return;
	CreateTimer(staggerTime - 0.1, ResetAbilityTimer, shovee);
}

public Action ResetAbilityTimer(Handle timer, any shovee)
{
	if (!L4D2_IsValidClient(shovee)) return;
	L4D2_Infected zClass = L4D2_GetInfectedClass(shovee);
	float time = GetGameTime();
	float recharge;
	if (zClass == L4D2Infected_Hunter)
	  recharge = fPounceCrouchDelay;
	else
	  recharge = fLeapInterval;
	float timestamp;
	float duration;
	if (!L4D2_GetInfectedAbilityTimer(shovee, timestamp, duration)) return;
	duration = time + recharge + 0.1;
	if (duration > timestamp)
	  L4D2_SetInfectedAbilityTimer(shovee, duration, recharge);
}

public Action Incap_Event(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

public Action PlayerIncap(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	char weapon[16];
	event.GetString("weapon", weapon, 16);
	if (!L4D2_IsValidClient(victim) || !L4D2_IsSurvivor(victim) || !L4D2_IsValidClient(attacker) || !L4D2_IsInfected(attacker) || !IsTank(attacker))
	{
		return;
	}
	if (StrEqual(weapon, "tank_claw", false))
	{
		SetEntProp(victim, Prop_Send, "m_isIncapacitated", 0);
		SetEntityHealth(victim, 1);
		CreateTimer(0.4, IncapTimer_Function, victim, TIMER_REPEAT);
	}
	if (IsFakeClient(attacker))
	{
		return;
	}
	L4D2_SetTankFrustration(attacker, 100);
}

public Action IncapTimer_Function(Handle timer, any victim)
{
	if (!L4D2_IsValidClient(victim)) return Plugin_Stop;
	SetEntProp(victim, Prop_Send, "m_isIncapacitated", 1);
	SetEntityHealth(victim, 300);
	return Plugin_Stop;
}

bool IsLimping(int client)
{
	return RoundToFloor(GetClientHealth(client) + L4D2_GetSurvivorTemporaryHealth(client)) < iSurvivorLimpHealth;
}

bool IsTankOrCharger(int client)  
{
	L4D2_Infected class = L4D2_GetInfectedClass(client);
	return (class == L4D2Infected_Charger || class == L4D2Infected_Tank);
}

bool IsHunter(int client)
{
	return L4D2_GetInfectedClass(client) == L4D2Infected_Hunter;
}

bool IsTank(int client)
{
	return L4D2_GetInfectedClass(client) == L4D2Infected_Tank;
}
