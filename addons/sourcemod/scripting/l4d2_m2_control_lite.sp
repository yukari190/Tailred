#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2util>

// Sometimes the ability timer doesn't get reset if the timer interval is the
// stagger time. Use an epsilon to set it slightly before the stagger is over.
#define STAGGER_TIME_EPS 0.1

ConVar 
	hPounceCrouchDelayCvar,
	hMaxStaggerDurationCvar,
	hLeapIntervalCvar;

public Plugin myinfo =
{
	name		= "L4D2 M2 Control",
	author		= "Jahze, Visor", //update syntax, minor fixes A1m`
	version		= "1.7",
	description	= "Blocks instant repounces and gives m2 penalty after a shove/deadstop",
	url 		= "https://github.com/SirPlease/L4D2-Competitive-Rework"
}

public void OnPluginStart()
{
	HookEvent("player_shoved", OutSkilled);
	hPounceCrouchDelayCvar = FindConVar("z_pounce_crouch_delay");
	hMaxStaggerDurationCvar = FindConVar("z_max_stagger_duration");
	hLeapIntervalCvar = FindConVar("z_leap_interval");
}

public void OutSkilled(Event hEvent, const char[] eName, bool dontBroadcast)
{
	int shover = GetClientOfUserId(hEvent.GetInt("attacker"));
	if (!IsValidSurvivor(shover)) return;
	
	int shovee_userid = hEvent.GetInt("userid");
	int shovee = GetClientOfUserId(shovee_userid);
	if (!IsValidInfected(shovee) || GetInfectedClass(shovee) == L4D2Infected_Smoker) return;
	
	float staggerTime = hMaxStaggerDurationCvar.FloatValue - STAGGER_TIME_EPS;
	CreateTimer(staggerTime, ResetAbilityTimer, shovee_userid, TIMER_FLAG_NO_MAPCHANGE);
}

public Action ResetAbilityTimer(Handle hTimer, any shovee)
{
	shovee = GetClientOfUserId(shovee);
	if (shovee > 0) {
		float recharge = (GetInfectedClass(shovee) == L4D2Infected_Hunter) ? hPounceCrouchDelayCvar.FloatValue : hLeapIntervalCvar.FloatValue;
		
		float timestamp, duration;
		if (!GetInfectedAbilityTimer(shovee, timestamp, duration)) {
			return;
		}

		duration = GetGameTime() + recharge + STAGGER_TIME_EPS;
		if (duration > timestamp) {
			SetInfectedAbilityTimer(shovee, duration, recharge);
		}
	}
}
