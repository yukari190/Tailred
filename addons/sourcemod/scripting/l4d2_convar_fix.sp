#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

ConVar 
	cvGunSwingVsMin,
	cvGunSwingCoopMin,
	cvGunSwingVsMax,
	cvGunSwingCoopMax,
	cvTankSpeedVs,
	cvTankSpeed,
	cvHunterLimit,
	cvBoomerLimit,
	cvSmokerLimit,
	cvJockeyLimit,
	cvChargerLimit,
	cvSpitterLimit,
	cvVsHunterLimit,
	cvVsBoomerLimit,
	cvVsSmokerLimit,
	cvVsJockeyLimit,
	cvVsChargerLimit,
	cvVsSpitterLimit;

public void OnPluginStart()
{
	cvGunSwingVsMin = FindConVar("z_gun_swing_vs_min_penalty");
	cvGunSwingVsMin.AddChangeHook(Cvar_GunSwingMin);
	cvGunSwingCoopMin = FindConVar("z_gun_swing_coop_min_penalty");
	cvGunSwingCoopMin.AddChangeHook(Cvar_GunSwingMin);
	Cvar_GunSwingMin(null, "", "");
	
	cvGunSwingVsMax = FindConVar("z_gun_swing_vs_max_penalty");
	cvGunSwingVsMax.AddChangeHook(Cvar_GunSwingMax);
	cvGunSwingCoopMax = FindConVar("z_gun_swing_coop_max_penalty");
	cvGunSwingCoopMax.AddChangeHook(Cvar_GunSwingMax);
	Cvar_GunSwingMax(null, "", "");
	
	cvTankSpeedVs = FindConVar("z_tank_speed_vs");
	cvTankSpeedVs.AddChangeHook(Cvar_TankSpeed);
	cvTankSpeed = FindConVar("z_tank_speed");
	cvTankSpeed.AddChangeHook(Cvar_TankSpeed);
	Cvar_TankSpeed(null, "", "");

	cvVsHunterLimit = FindConVar("z_versus_hunter_limit");
	cvVsHunterLimit.AddChangeHook(Cvar_HunterLimit);
	cvHunterLimit = FindConVar("z_hunter_limit");
	cvHunterLimit.AddChangeHook(Cvar_HunterLimit);
	Cvar_HunterLimit(null, "", "");
	
	cvVsBoomerLimit = FindConVar("z_versus_boomer_limit");
	cvVsBoomerLimit.AddChangeHook(Cvar_BoomerLimit);
	cvBoomerLimit = FindConVar("z_boomer_limit");
	cvBoomerLimit.AddChangeHook(Cvar_BoomerLimit);
	Cvar_BoomerLimit(null, "", "");
	
	cvVsSmokerLimit = FindConVar("z_versus_smoker_limit");
	cvVsSmokerLimit.AddChangeHook(Cvar_SmokerLimit);
	cvSmokerLimit = FindConVar("z_smoker_limit");
	cvSmokerLimit.AddChangeHook(Cvar_SmokerLimit);
	Cvar_SmokerLimit(null, "", "");
	
	cvVsJockeyLimit = FindConVar("z_versus_jockey_limit");
	cvVsJockeyLimit.AddChangeHook(Cvar_JockeyLimit);
	cvJockeyLimit = FindConVar("z_jockey_limit");
	cvJockeyLimit.AddChangeHook(Cvar_JockeyLimit);
	Cvar_JockeyLimit(null, "", "");
	
	cvVsChargerLimit = FindConVar("z_versus_charger_limit");
	cvVsChargerLimit.AddChangeHook(Cvar_ChargerLimit);
	cvChargerLimit = FindConVar("z_charger_limit");
	cvChargerLimit.AddChangeHook(Cvar_ChargerLimit);
	Cvar_ChargerLimit(null, "", "");
	
	cvVsSpitterLimit = FindConVar("z_versus_spitter_limit");
	cvVsSpitterLimit.AddChangeHook(Cvar_SpitterLimit);
	cvSpitterLimit = FindConVar("z_spitter_limit");
	cvSpitterLimit.AddChangeHook(Cvar_SpitterLimit);
	Cvar_SpitterLimit(null, "", "");
}

public void OnPluginEnd()
{
	cvGunSwingVsMin.RestoreDefault();
	cvGunSwingCoopMin.RestoreDefault();
	cvGunSwingVsMax.RestoreDefault();
	cvGunSwingCoopMax.RestoreDefault();
	cvTankSpeedVs.RestoreDefault();
	cvTankSpeed.RestoreDefault();
	cvHunterLimit.RestoreDefault();
	cvBoomerLimit.RestoreDefault();
	cvSmokerLimit.RestoreDefault();
	cvJockeyLimit.RestoreDefault();
	cvChargerLimit.RestoreDefault();
	cvSpitterLimit.RestoreDefault();
	cvVsHunterLimit.RestoreDefault();
	cvVsBoomerLimit.RestoreDefault();
	cvVsSmokerLimit.RestoreDefault();
	cvVsJockeyLimit.RestoreDefault();
	cvVsChargerLimit.RestoreDefault();
	cvVsSpitterLimit.RestoreDefault();
}

public void Cvar_GunSwingMin(ConVar convar, const char[] oldValue, const char[] newValue) { cvGunSwingCoopMin.SetInt(cvGunSwingVsMin.IntValue); }
public void Cvar_GunSwingMax(ConVar convar, const char[] oldValue, const char[] newValue) { cvGunSwingCoopMax.SetInt(cvGunSwingVsMax.IntValue); }
public void Cvar_TankSpeed(ConVar convar, const char[] oldValue, const char[] newValue) { cvTankSpeed.SetInt(cvTankSpeedVs.IntValue); }
public void Cvar_HunterLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvHunterLimit.SetInt(cvVsHunterLimit.IntValue); }
public void Cvar_BoomerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvBoomerLimit.SetInt(cvVsBoomerLimit.IntValue); }
public void Cvar_SmokerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvSmokerLimit.SetInt(cvVsSmokerLimit.IntValue); }
public void Cvar_JockeyLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvJockeyLimit.SetInt(cvVsJockeyLimit.IntValue); }
public void Cvar_ChargerLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvChargerLimit.SetInt(cvVsChargerLimit.IntValue); }
public void Cvar_SpitterLimit(ConVar convar, const char[] oldValue, const char[] newValue) { cvSpitterLimit.SetInt(cvVsSpitterLimit.IntValue); }
