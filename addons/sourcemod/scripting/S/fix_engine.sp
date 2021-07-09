#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define FIRST_RESTORE_TIME 0.3
#define RESTORE_TIME 2.0
#define MAX_HEALTH_PER_RESTORE 10
#define MAX_HEALTH 100
#define CONSTANT_HEALTH 1
#define MAX_TEMP_HEALTH MAX_HEALTH - CONSTANT_HEALTH

public Plugin myinfo =
{
	name = "[L4D & L4D2] Engine Fix",
	author = "raziEiL [disawar1]",
	description = "无掉落伤害bug，健康提升小故障.",
	version = "1.1",
	url = "http://steamcommunity.com/id/raziEiL"
}

Handle g_hFixGlitchTimer[MAXPLAYERS+1];
Handle g_hRestoreTimer[MAXPLAYERS+1];
int g_iHealthToRestore[MAXPLAYERS+1];
int g_iLastKnownHealth[MAXPLAYERS+1];

public void OnPluginStart()
{
	HookEvent("pills_used", EF_ev_PillsUsed);
	HookEvent("heal_success", EF_ev_HealSuccess);
	HookEvent("revive_success", EF_ev_HealSuccess);
	HookEvent("player_incapacitated", EF_ev_HealSuccess);
}

public void OnPluginEnd()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		EF_ClearAllVars(i);
	}
}
/*                                      +==========================================+
                                        |               LADDER GLITCH              |
                                        |             NO FALL DMG GLITCH           |
                                        +==========================================+
*/
public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsPlayerAlive(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == 2 && IsFallDamage(client) && buttons & IN_USE)
		{
			buttons &= ~IN_USE;
		}
	}
	return Plugin_Continue;
}

bool IsFallDamage(int client)
{
	return GetEntPropFloat(client, Prop_Send, "m_flFallVelocity") > 440;
}

/*                                      +==========================================+
                                        |               DROWN GLITCH               |
                                        +==========================================+
*/
public void OnClientDisconnect(int client)
{
	if (client)
		EF_ClearAllVars(client);
}

public void L4D_OnRoundStart()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		EF_ClearAllVars(i);

		if (IsClientInGame(i) && IsDrownPropNotEqual(i))
			ForceEqualDrownProp(i);
	}
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype)
{
	if (dmgtype & DMG_DROWN)
	{
		if (IsIncapacitated(victim)) return;

		if (health == CONSTANT_HEALTH)
		{
			if (g_iLastKnownHealth[victim] && damage >= g_iLastKnownHealth[victim])
			{
				damage -= g_iLastKnownHealth[victim];
				g_iLastKnownHealth[victim] -= CONSTANT_HEALTH;
			}
			if (g_iHealthToRestore[victim] < 0)
				g_iHealthToRestore[victim] = 0;

			if (!g_iHealthToRestore[victim])
			{
				EF_KillRestoreTimer(victim);
				CreateTimer(FIRST_RESTORE_TIME, EF_t_CheckRestoring, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			}

			g_iHealthToRestore[victim] += damage;

			Handle hdataPack;
			CreateDataTimer(0.1, EF_t_SetDrownDmg, hdataPack, TIMER_FLAG_NO_MAPCHANGE);
			WritePackCell(hdataPack, victim);
			WritePackCell(hdataPack, GetEntProp(victim, Prop_Data, "m_idrowndmg") + g_iLastKnownHealth[victim]);

			g_iLastKnownHealth[victim] = 0;
		}
		else
			g_iLastKnownHealth[victim] = health;
	}
}

public Action EF_t_SetDrownDmg(Handle timer, Handle datapack)
{
	ResetPack(datapack, false);
	int client = ReadPackCell(datapack);

	if (!IsSurvivor(client)) return;

	int drowndmg = ReadPackCell(datapack);

	SetEntProp(client, Prop_Data, "m_idrowndmg", drowndmg);
}

public Action EF_t_CheckRestoring(Handle timer, any victim)
{
	if (g_iHealthToRestore[victim] <= 0 || !IsSurvivor(victim))
	{
		g_iHealthToRestore[victim] = 0;
		return Plugin_Stop;
	}

	if (IsUnderWater(victim))
		return Plugin_Continue;

	float fHealthToRestore = float(GetEntProp(victim, Prop_Data, "m_idrowndmg") - GetEntProp(victim, Prop_Data, "m_idrownrestored"));

	if (fHealthToRestore <= 0)
	{
		g_hRestoreTimer[victim] = CreateTimer(RESTORE_TIME, EF_t_RestoreTempHealth, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		return Plugin_Stop;
	}

	int iRestoreCount = RoundToCeil(fHealthToRestore / MAX_HEALTH_PER_RESTORE);
	float fRestoreTimeEnd = RESTORE_TIME * float(iRestoreCount);

	CreateTimer(fRestoreTimeEnd, EF_t_StartRestoreTempHealth, victim, TIMER_FLAG_NO_MAPCHANGE);
	return Plugin_Stop;
}

public Action EF_t_StartRestoreTempHealth(Handle timer, any victim)
{
	if (g_iHealthToRestore[victim] <= 0 || !IsSurvivor(victim)) return;

	g_hRestoreTimer[victim] = CreateTimer(RESTORE_TIME, EF_t_RestoreTempHealth, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action EF_t_RestoreTempHealth(Handle timer, any victim)
{
	if (g_iHealthToRestore[victim] <= 0 || !IsSurvivor(victim))
	{
		EF_ClearVars(victim);
		return Plugin_Stop;
	}

	if (!IsUnderWater(victim) && !IsDrownPropNotEqual(victim))
	{
		float fTemp = GetTempHealth(victim);
		int iLimit = MAX_TEMP_HEALTH - (GetClientHealth(victim) + RoundToFloor(fTemp));
		int iTempToRestore = g_iHealthToRestore[victim] >= MAX_HEALTH_PER_RESTORE ? MAX_HEALTH_PER_RESTORE : g_iHealthToRestore[victim];

		if (iTempToRestore > iLimit)
		{
			iTempToRestore = iLimit;
			g_iHealthToRestore[victim] = 0;

			if (iTempToRestore <= 0)
				return Plugin_Continue;
		}

		SetTempHealth(victim, fTemp + iTempToRestore);
		g_iHealthToRestore[victim] -= MAX_HEALTH_PER_RESTORE;
	}

	return Plugin_Continue;
}

public Action EF_ev_HealSuccess(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt(StrEqual(name, "player_incapacitated", false) ? "userid" : "subject"));

	if (IsDrownPropNotEqual(client))
	{
		EF_ClearVars(client);
		ForceEqualDrownProp(client);
	}
}

public Action EF_ev_PillsUsed(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (IsDrownPropNotEqual(client))
	{
		EF_KillFixGlitchTimer(client);
		g_hFixGlitchTimer[client] = CreateTimer(0.0, EF_t_FixTempHpGlitch, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action EF_t_FixTempHpGlitch(Handle timer, any client)
{
	if (IsSurvivor(client) && !IsIncapacitated(client))
	{
		float fTemp = GetTempHealth(client);

		if (fTemp)
		{
			int iHealth = GetClientHealth(client);

			if ((iHealth + RoundToFloor(fTemp)) > MAX_TEMP_HEALTH)
			{
				SetTempHealth(client, float(MAX_HEALTH - iHealth));
			}
		}
		if (IsDrownPropNotEqual(client))
			return Plugin_Continue;
	}

	g_hFixGlitchTimer[client] = INVALID_HANDLE;
	return Plugin_Stop;
}

void EF_KillRestoreTimer(int client)
{
	if (g_hRestoreTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hRestoreTimer[client]);
		g_hRestoreTimer[client] = INVALID_HANDLE;
	}
}

void EF_KillFixGlitchTimer(int client)
{
	if (g_hFixGlitchTimer[client] != INVALID_HANDLE)
	{
		KillTimer(g_hFixGlitchTimer[client]);
		g_hFixGlitchTimer[client] = INVALID_HANDLE;
	}
}

void EF_ClearVars(int client)
{
	EF_KillRestoreTimer(client);
	g_iHealthToRestore[client] = 0;
	g_iLastKnownHealth[client] = 0;
}

void EF_ClearAllVars(int client)
{
	EF_ClearVars(client);
	EF_KillFixGlitchTimer(client);
}

bool IsSurvivor(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == 2 && IsPlayerAlive(client);
}

bool IsUnderWater(int client)
{
	return GetEntProp(client, Prop_Send, "m_nWaterLevel") == 3;
}

int IsIncapacitated(int client)
{
	return GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

bool IsDrownPropNotEqual(int client)
{
	return GetEntProp(client, Prop_Data, "m_idrowndmg") != GetEntProp(client, Prop_Data, "m_idrownrestored");
}

void ForceEqualDrownProp(int client)
{
	SetEntProp(client, Prop_Data, "m_idrownrestored", GetEntProp(client, Prop_Data, "m_idrowndmg"));
}

void SetTempHealth(int client, float health)
{
	SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", health);
}

float GetTempHealth(int client)
{
	float fTempHealth = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	fTempHealth -= (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate"));
	return fTempHealth < 0.0 ? 0.0 : fTempHealth;
}
