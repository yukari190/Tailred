#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <colors>

#include "confoglcompmod/constants.sp"
#include "confoglcompmod/functions.sp"
#include "confoglcompmod/survivorindex.sp"
#include "confoglcompmod/customtags.sp"

#include "confoglcompmod/WeaponInformation.sp"
#include "confoglcompmod/l4dt_forwards.sp"
#include "confoglcompmod/GhostTank.sp"
#include "confoglcompmod/GhostWarp.sp"
#include "confoglcompmod/FinaleSpawn.sp"
#include "confoglcompmod/BossSpawning.sp"
#include "confoglcompmod/ClientSettings.sp"
#include "confoglcompmod/ItemTracking.sp"

public Plugin myinfo = 
{
	name = "Confogl's Competitive Mod Lite",
	author = "Confogl Team, Yukari190",
	description = "A competitive mod for L4D2",
	version = "2.2.4l",
	url = "https://github.com/yukari190/Tailred"
};

public void OnPluginStart()
{
	SI_OnModuleStart();
	WI_OnModuleStart();
	GW_OnModuleStart();
	GT_OnModuleStart();
	FS_OnModuleStart();
	BS_OnModuleStart();
	CLS_OnModuleStart();
	IT_OnModuleStart();
	
	AddCustomServerTag("confogl");
	
	//HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	//HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("tank_spawn", TankSpawn_Event);
}

public void OnPluginEnd()
{
	RemoveCustomServerTag("confogl");
}

public void OnMapStart()
{
	bIsMapActive = true;
	BS_OnMapStart();
	IT_OnMapStart();
}

public void OnMapEnd()
{
	bIsMapActive = false;
}

//public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
public void L4D2_OnRealRoundStart()
{
	WI_RoundStart();
	IT_RoundStart();
	FS_RoundStart();
	GT_RoundStart();
}

//public void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
public void L4D2_OnRealRoundEnd()
{
	BS_RoundEnd();
	IT_RoundEnd();
}

public void FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	BS_FinaleStart();
	FS_FinaleStart();
}

public void PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	GT_TankKilled(event);
	GW_PlayerDeath(event);
}

public void TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	GT_TankSpawn(event);
	BS_TankSpawn(event);
}
