#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

ConVar 
	hGunSwingVsMin,
	hGunSwingCoopMin,
	hGunSwingVsMax,
	hGunSwingCoopMax,
	hTankSpeedVs,
	hTankSpeed,
	hHunterLimit,
	hBoomerLimit,
	hSmokerLimit,
	hJockeyLimit,
	hChargerLimit,
	hSpitterLimit,
	hVsHunterLimit,
	hVsBoomerLimit,
	hVsSmokerLimit,
	hVsJockeyLimit,
	hVsChargerLimit,
	hVsSpitterLimit,
	hAllowInfectedBots,
	hGhostDelayMinspawn,
	hGhostDelayMin;

public void OnPluginStart()
{
	hGunSwingVsMin = FindConVar("z_gun_swing_vs_min_penalty");
	hGunSwingVsMin.AddChangeHook(Cvar_GunSwingMin);
	hGunSwingCoopMin = FindConVar("z_gun_swing_coop_min_penalty");
	hGunSwingCoopMin.AddChangeHook(Cvar_GunSwingMin);
	Cvar_GunSwingMin(null, "", "");
	
	hGunSwingVsMax = FindConVar("z_gun_swing_vs_max_penalty");
	hGunSwingVsMax.AddChangeHook(Cvar_GunSwingMax);
	hGunSwingCoopMax = FindConVar("z_gun_swing_coop_max_penalty");
	hGunSwingCoopMax.AddChangeHook(Cvar_GunSwingMax);
	Cvar_GunSwingMax(null, "", "");
	
	hTankSpeedVs = FindConVar("z_tank_speed_vs");
	hTankSpeedVs.AddChangeHook(Cvar_TankSpeed);
	hTankSpeed = FindConVar("z_tank_speed");
	hTankSpeed.AddChangeHook(Cvar_TankSpeed);
	Cvar_TankSpeed(null, "", "");

	hVsHunterLimit = FindConVar("z_versus_hunter_limit");
	hVsHunterLimit.AddChangeHook(Cvar_HunterLimit);
	hHunterLimit = FindConVar("z_hunter_limit");
	hHunterLimit.AddChangeHook(Cvar_HunterLimit);
	Cvar_HunterLimit(null, "", "");
	
	hVsBoomerLimit = FindConVar("z_versus_boomer_limit");
	hVsBoomerLimit.AddChangeHook(Cvar_BoomerLimit);
	hBoomerLimit = FindConVar("z_boomer_limit");
	hBoomerLimit.AddChangeHook(Cvar_BoomerLimit);
	Cvar_BoomerLimit(null, "", "");
	
	hVsSmokerLimit = FindConVar("z_versus_smoker_limit");
	hVsSmokerLimit.AddChangeHook(Cvar_SmokerLimit);
	hSmokerLimit = FindConVar("z_smoker_limit");
	hSmokerLimit.AddChangeHook(Cvar_SmokerLimit);
	Cvar_SmokerLimit(null, "", "");
	
	hVsJockeyLimit = FindConVar("z_versus_jockey_limit");
	hVsJockeyLimit.AddChangeHook(Cvar_JockeyLimit);
	hJockeyLimit = FindConVar("z_jockey_limit");
	hJockeyLimit.AddChangeHook(Cvar_JockeyLimit);
	Cvar_JockeyLimit(null, "", "");
	
	hVsChargerLimit = FindConVar("z_versus_charger_limit");
	hVsChargerLimit.AddChangeHook(Cvar_ChargerLimit);
	hChargerLimit = FindConVar("z_charger_limit");
	hChargerLimit.AddChangeHook(Cvar_ChargerLimit);
	Cvar_ChargerLimit(null, "", "");
	
	hVsSpitterLimit = FindConVar("z_versus_spitter_limit");
	hVsSpitterLimit.AddChangeHook(Cvar_SpitterLimit);
	hSpitterLimit = FindConVar("z_spitter_limit");
	hSpitterLimit.AddChangeHook(Cvar_SpitterLimit);
	Cvar_SpitterLimit(null, "", "");
	
	hAllowInfectedBots = FindConVar("director_allow_infected_bots");
	hGhostDelayMinspawn = FindConVar("z_ghost_delay_minspawn");
	hGhostDelayMin = FindConVar("z_ghost_delay_min");
	hAllowInfectedBots.AddChangeHook(Cvar_AllowInfectedBots);
	Cvar_AllowInfectedBots(null, "", "");
}

public void Cvar_AllowInfectedBots(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (FindConVar("z_max_player_zombies").IntValue == 4)
	{
		if (hAllowInfectedBots.IntValue == 1)
			hGhostDelayMinspawn.SetInt(hGhostDelayMin.IntValue);
		else
			hGhostDelayMinspawn.RestoreDefault();
	}
}

public void OnPluginEnd()
{
	hGunSwingVsMin.RestoreDefault();
	hGunSwingCoopMin.RestoreDefault();
	hGunSwingVsMax.RestoreDefault();
	hGunSwingCoopMax.RestoreDefault();
	hTankSpeedVs.RestoreDefault();
	hTankSpeed.RestoreDefault();
	hHunterLimit.RestoreDefault();
	hBoomerLimit.RestoreDefault();
	hSmokerLimit.RestoreDefault();
	hJockeyLimit.RestoreDefault();
	hChargerLimit.RestoreDefault();
	hSpitterLimit.RestoreDefault();
	hVsHunterLimit.RestoreDefault();
	hVsBoomerLimit.RestoreDefault();
	hVsSmokerLimit.RestoreDefault();
	hVsJockeyLimit.RestoreDefault();
	hVsChargerLimit.RestoreDefault();
	hVsSpitterLimit.RestoreDefault();
}

public void Cvar_GunSwingMin(ConVar convar, const char[] oldValue, const char[] newValue) { hGunSwingCoopMin.SetInt(hGunSwingVsMin.IntValue); }
public void Cvar_GunSwingMax(ConVar convar, const char[] oldValue, const char[] newValue) { hGunSwingCoopMax.SetInt(hGunSwingVsMax.IntValue); }
public void Cvar_TankSpeed(ConVar convar, const char[] oldValue, const char[] newValue) { hTankSpeed.SetInt(hTankSpeedVs.IntValue); }
public void Cvar_HunterLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hHunterLimit.SetInt(hVsHunterLimit.IntValue); }
public void Cvar_BoomerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hBoomerLimit.SetInt(hVsBoomerLimit.IntValue); }
public void Cvar_SmokerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hSmokerLimit.SetInt(hVsSmokerLimit.IntValue); }
public void Cvar_JockeyLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hJockeyLimit.SetInt(hVsJockeyLimit.IntValue); }
public void Cvar_ChargerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hChargerLimit.SetInt(hVsChargerLimit.IntValue); }
public void Cvar_SpitterLimit(ConVar convar, const char[] oldValue, const char[] newValue) { hSpitterLimit.SetInt(hVsSpitterLimit.IntValue); }
