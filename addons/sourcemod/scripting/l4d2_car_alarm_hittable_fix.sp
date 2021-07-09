#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod> 
#include <sdkhooks> 
#include <sdktools> 
#include <[LIB]l4d2library>

public Plugin myinfo = 
{
	name = "L4D2 Car Alarm Hittable Fix",
	author = "Sir",
	description = "当坦克命中台击中警报的汽车时, 禁用汽车警报.",
	version = "1.1",
	url = "nah"
};

public void OnEntityCreated(int entity, const char[] classname) 
{
	// Hook Alarmed Cars.
	if(!StrEqual(classname, "prop_car_alarm")) return; 
	SDKHook(entity, SDKHook_Touch, OnAlarmCarTouch); 
}

public Action OnAlarmCarTouch(int car, int entity) 
{ 
	// Speaks for itself
	if (L4D2_IsTankHittable(entity))
	{
		// This returns 1 on every hittable at all times.
		if (GetEntProp(entity, Prop_Send, "m_hasTankGlow") > 0)
		{
			// Disable the Car Alarm
			AcceptEntityInput(car, "Disable");

			// Fake damage to Car to stop the glass from still blinking, delay it to prevent issues.
			CreateTimer(0.3, DisableAlarm, car);

			// Unhook car, we don't need it anymore.
			SDKUnhook(car, SDKHook_Touch, OnAlarmCarTouch);
		}
	}
}

public Action DisableAlarm(Handle timer, any car)
{
	int Tank = -1;

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidTank(i))
		{
			Tank = i;
			break;
		}
	}

	if (Tank != -1) SDKHooks_TakeDamage(car, Tank, Tank, 0.0);
}

bool IsValidTank(int client) 
{ 
    return (L4D2_IsValidClient(client) && L4D2_IsInfected(client) && L4D2_GetInfectedClass(client) == L4D2Infected_Tank); 
}
