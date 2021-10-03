#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <lgofnoc>

#define LIBRARYNAME "l4d2lib"

public Plugin myinfo =
{
	name = "l4d2lib",
	description = "Useful natives and fowards for L4D2 Plugins",
	author = "Confogl Team, Yukari190",
	version = "1.2",
	url = ""
};

enum Saferoom
{
	Saferoom_Neither = 0,
	Saferoom_Start = 1,
	Saferoom_End = 2,
	Saferoom_Both = 3
};

//static const char MAPINFO_PATH[] = "../../cfg/cfgogl/shared/mapinfo.txt";
static const char SAFEROOMINFO_PATH[] = "../../cfg/cfgogl/shared/saferoominfo.txt";
const int NUM_OF_SURVIVORS = 4;

KeyValues 
	kvMapInfo,
	kvSafeRoomInfo;

Handle hTankDeathTimer;

GlobalForward 
	hFwdRoundStart,
	hFwdRoundEnd,
	hFwdFirstTankSpawn,
	hFwdTankPassControl,
	hFwdTankDeath,
	hFwdPlayerHurt,
	hFwdJoinSurvivor,
	hFwdAwaySurvivor,
	hFwdJoinInfected,
	hFwdAwayInfected,
	hFwdTeamChanged;

ConVar 
	hGameMode,
	hSurvivorLimit;

int 
	iGameMode,
	iRoundNumber = 0,
	iSurvivorIndex[NUM_OF_SURVIVORS],
	iTank,
	iTankPassCount;

bool 
	bIsMapInit,
	bInSecondRound,
	bRoundEnd,
	bInRound,
	bIsTankActive,
	bExpectTankSpawn,
	g_bHasStart,
	g_bHasStartExtra,
	g_bHasEnd,
	g_bHasEndExtra,
	MapDataAvailable;

float 
	g_fStartLocA[3],
	g_fStartLocB[3],
	g_fStartLocC[3],
	g_fStartLocD[3],
	g_fStartRotate,
	g_fEndLocA[3],
	g_fEndLocB[3],
	g_fEndLocC[3],
	g_fEndLocD[3],
	g_fEndRotate,
	Start_Point[3],
	End_Point[3],
	Start_Dist,
	Start_Extra_Dist,
	End_Dist;

char g_sMapname[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	/* Plugin Native Declarations */
	CreateNative("L4D2_GetCurrentRound", _native_GetCurrentRound);
	CreateNative("L4D2_CurrentlyInRound", _native_CurrentlyInRound);
	CreateNative("L4D2_GetSurvivorCount", _native_GetSurvivorCount);
	CreateNative("L4D2_GetSurvivorOfIndex", _native_GetSurvivorOfIndex);
	CreateNative("L4D2_IsMapDataAvailable", _native_IsMapDataAvailable);
	CreateNative("L4D2_IsEntityInSaferoom", _native_IsEntityInSaferoom);
	CreateNative("L4D2_GetMapStartOrigin", _native_GetMapStartOrigin);
	CreateNative("L4D2_GetMapEndOrigin", _native_GetMapEndOrigin);
	CreateNative("L4D2_GetMapStartDistance", _native_GetMapStartDist);
	CreateNative("L4D2_GetMapStartExtraDistance", _native_GetMapStartExtraDist);
	CreateNative("L4D2_GetMapEndDistance", _native_GetMapEndDist);
	CreateNative("L4D2_GetMapValueInt", _native_GetMapValueInt);
	CreateNative("L4D2_GetMapValueFloat", _native_GetMapValueFloat);
	CreateNative("L4D2_GetMapValueVector", _native_GetMapValueVector);
	CreateNative("L4D2_GetMapValueString", _native_GetMapValueString);
	CreateNative("L4D2_CopyMapSubsection", _native_CopyMapSubsection);
	
	CreateNative("SAFEDETECT_IsEntityInStartSaferoom", _native_SAFEDETECT_IsEntityInStartSaferoom);
	CreateNative("SAFEDETECT_IsEntityInEndSaferoom", _native_SAFEDETECT_IsEntityInEndSaferoom);
	CreateNative("SAFEDETECT_IsEntityInSaferoom", _native_SAFEDETECT_IsEntityInSaferoom);
	CreateNative("L4D2_InSecondHalfOfRound", _native_InSecondHalfOfRound);
	CreateNative("L4D2_GetRandomSurvivor", _native_GetRandomSurvivor);
	CreateNative("L4D2_IsCoop", _native_IsCoop);
	CreateNative("L4D2_IsVersus", _native_IsVersus);
	CreateNative("L4D2_IsScavenge", _native_IsScavenge);
	CreateNative("L4D2_IsSurvival", _native_IsSurvival);
	
	
	/* Plugin Forward Declarations */
	hFwdRoundStart = new GlobalForward("L4D2_OnRealRoundStart", ET_Ignore, Param_Cell);
	hFwdRoundEnd = new GlobalForward("L4D2_OnRealRoundEnd", ET_Ignore, Param_Cell);
	hFwdFirstTankSpawn = new GlobalForward("L4D2_OnTankFirstSpawn", ET_Ignore, Param_Cell);
	hFwdTankPassControl = new GlobalForward("L4D2_OnTankPassControl", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	hFwdTankDeath = new GlobalForward("L4D2_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell);
	
	hFwdPlayerHurt = new GlobalForward("L4D2_OnPlayerHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	hFwdJoinSurvivor = new GlobalForward("L4D2_OnJoinSurvivor", ET_Event, Param_Cell);
	hFwdAwaySurvivor = new GlobalForward("L4D2_OnAwaySurvivor", ET_Event, Param_Cell);
	hFwdJoinInfected = new GlobalForward("L4D2_OnJoinInfected", ET_Event, Param_Cell);
	hFwdAwayInfected = new GlobalForward("L4D2_OnAwayInfected", ET_Event, Param_Cell);
	hFwdTeamChanged = new GlobalForward("L4D2_OnPlayerTeamChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	
	/* Register our library */
	RegPluginLibrary(LIBRARYNAME);
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	kvSafeRoomInfo = new KeyValues("SaferoomInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), SAFEROOMINFO_PATH);
	if (!FileToKeyValues(kvSafeRoomInfo, sNameBuff))
	{
		BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/saferoominfo.txt");
		if (!FileToKeyValues(kvSafeRoomInfo, sNameBuff))
		{
			LogError("[MI] 找不到 saferoominfo.txt 文件信息");
			delete kvSafeRoomInfo;
		}
	}
	
	kvMapInfo = new KeyValues("MapInfo");
	LGO_BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt"); //Build our filepath
	if (!FileToKeyValues(kvMapInfo, sNameBuff))
	{
		LogError("[MI] 找不到 mapinfo.txt 文件信息");
		delete kvMapInfo;
	}
	
	hGameMode = FindConVar("mp_gamemode");
	hSurvivorLimit = FindConVar("survivor_limit");
	
	hGameMode.AddChangeHook(ConVarChange);
	hSurvivorLimit.AddChangeHook(ConVarChange);
	
	ConVarChange(null, "", "");
	
	FindConVar("director_no_bosses").SetBool(true);
	
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
	
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	
	HookEvent("tank_spawn", TankSpawn_Event, EventHookMode_Post);
	HookEvent("item_pickup", ItemPickup_Event, EventHookMode_Post);
	HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	
	HookEvent("round_start", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_death", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("defibrillator_used", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
	HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);
}

public int ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	char gmode[20];
	hGameMode.GetString(gmode, sizeof(gmode));
	if(
		StrEqual(gmode, "coop") || StrEqual(gmode, "realism") || StrEqual(gmode, "mutation1") || StrEqual(gmode, "mutation2") || 
		StrEqual(gmode, "mutation3") || StrEqual(gmode, "mutation4") || StrEqual(gmode, "mutation5") || StrEqual(gmode, "mutation7") || 
		StrEqual(gmode, "mutation8") || StrEqual(gmode, "mutation9") || StrEqual(gmode, "mutation10") || StrEqual(gmode, "mutation14") || 
		StrEqual(gmode, "mutation16") || StrEqual(gmode, "mutation17") || StrEqual(gmode, "mutation20") || StrEqual(gmode, "community1") || 
		StrEqual(gmode, "community2") || StrEqual(gmode, "community5")
	) iGameMode = 0;
	else if(
		StrEqual(gmode,"versus") || StrEqual(gmode, "teamversus") || StrEqual(gmode, "mutation11") || StrEqual(gmode, "mutation12") || 
		StrEqual(gmode, "mutation18") || StrEqual(gmode, "mutation19") || StrEqual(gmode, "community3")
	) iGameMode = 1;
	else if(StrEqual(gmode, "scavenge") || StrEqual(gmode, "teamscavenge") || StrEqual(gmode, "mutation13")) iGameMode = 2;
	else if(StrEqual(gmode, "survival") || StrEqual(gmode, "mutation15") || StrEqual(gmode, "community4")) iGameMode = 3;
	else iGameMode = -1;
}

public void OnPluginEnd()
{
	delete kvMapInfo;
	delete kvSafeRoomInfo;
	FindConVar("director_no_bosses").RestoreDefault();
}

/*public void LGO_OnMatchModeLoaded()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	kvMapInfo = new KeyValues("MapInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), MAPINFO_PATH);
	if (!FileToKeyValues(kvMapInfo, sNameBuff))
	{
		LGO_BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt"); //Build our filepath
		if (!FileToKeyValues(kvMapInfo, sNameBuff))
		{
			LogError("[MI] 找不到 mapinfo.txt 文件信息");
			delete kvMapInfo;
		}
	}
}*/

public void OnMapStart()
{
    g_bHasStart = false;        g_bHasStartExtra = false;
    g_bHasEnd = false;          g_bHasEndExtra = false;
    g_fStartLocA = NULL_VECTOR; g_fStartLocB = NULL_VECTOR; g_fStartLocC = NULL_VECTOR; g_fStartLocD = NULL_VECTOR;
    g_fEndLocA = NULL_VECTOR;   g_fEndLocB = NULL_VECTOR;   g_fEndLocC = NULL_VECTOR;   g_fEndLocD = NULL_VECTOR;
    g_fStartRotate = 0.0;       g_fEndRotate = 0.0;
	
	GetCurrentMap(g_sMapname, 64);
	
    if (KvJumpToKey(kvSafeRoomInfo, g_sMapname))
    {
        KvGetVector(kvSafeRoomInfo, "start_loc_a", g_fStartLocA);
        KvGetVector(kvSafeRoomInfo, "start_loc_b", g_fStartLocB);
        KvGetVector(kvSafeRoomInfo, "start_loc_c", g_fStartLocC);
        KvGetVector(kvSafeRoomInfo, "start_loc_d", g_fStartLocD);
        g_fStartRotate = KvGetFloat(kvSafeRoomInfo, "start_rotate", g_fStartRotate);
        KvGetVector(kvSafeRoomInfo, "end_loc_a", g_fEndLocA);
        KvGetVector(kvSafeRoomInfo, "end_loc_b", g_fEndLocB);
        KvGetVector(kvSafeRoomInfo, "end_loc_c", g_fEndLocC);
        KvGetVector(kvSafeRoomInfo, "end_loc_d", g_fEndLocD);
        g_fEndRotate = KvGetFloat(kvSafeRoomInfo, "end_rotate", g_fEndRotate);
        
        if (g_fStartLocA[0] != 0.0 && g_fStartLocA[1] != 0.0 && g_fStartLocA[2] != 0.0 && g_fStartLocB[0] != 0.0 && g_fStartLocB[1] != 0.0 && g_fStartLocB[2] != 0.0) { g_bHasStart = true; }
        if (g_fStartLocC[0] != 0.0 && g_fStartLocC[1] != 0.0 && g_fStartLocC[2] != 0.0 && g_fStartLocD[0] != 0.0 && g_fStartLocD[1] != 0.0 && g_fStartLocD[2] != 0.0) { g_bHasStartExtra = true; }
        if (g_fEndLocA[0] != 0.0 && g_fEndLocA[1] != 0.0 && g_fEndLocA[2] != 0.0 && g_fEndLocB[0] != 0.0 && g_fEndLocB[1] != 0.0 && g_fEndLocB[2] != 0.0) { g_bHasEnd = true; }
        if (g_fEndLocC[0] != 0.0 && g_fEndLocC[1] != 0.0 && g_fEndLocC[2] != 0.0 && g_fEndLocD[0] != 0.0 && g_fEndLocD[1] != 0.0 && g_fEndLocD[2] != 0.0) { g_bHasEndExtra = true; }
        
        if (g_fStartRotate != 0.0)
		{
            RotatePoint(g_fStartLocA, g_fStartLocB[0], g_fStartLocB[1], g_fStartRotate);
            if (g_bHasStartExtra)
			{
                RotatePoint(g_fStartLocA, g_fStartLocC[0], g_fStartLocC[1], g_fStartRotate);
                RotatePoint(g_fStartLocA, g_fStartLocD[0], g_fStartLocD[1], g_fStartRotate);
            }
        }
        if (g_fEndRotate != 0.0)
		{
            RotatePoint(g_fEndLocA, g_fEndLocB[0], g_fEndLocB[1], g_fEndRotate);
            if (g_bHasEndExtra)
			{
                RotatePoint(g_fEndLocA, g_fEndLocC[0], g_fEndLocC[1], g_fEndRotate);
                RotatePoint(g_fEndLocA, g_fEndLocD[0], g_fEndLocD[1], g_fEndRotate);
            }
        }
    }
    else
    {
        LogMessage("[SI] SaferoomInfo for %s is missing.", g_sMapname);
    }
	
	if (KvJumpToKey(kvMapInfo, g_sMapname))
	{
		KvGetVector(kvMapInfo, "start_point", Start_Point);
		KvGetVector(kvMapInfo, "end_point", End_Point);
		Start_Dist = KvGetFloat(kvMapInfo, "start_dist");
		Start_Extra_Dist = KvGetFloat(kvMapInfo, "start_extra_dist");
		End_Dist = KvGetFloat(kvMapInfo, "end_dist");
		MapDataAvailable = true;
	}
	else
	{
		MapDataAvailable = false;
		Start_Dist = FindStartPointHeuristic(Start_Point);
		if(Start_Dist > 0.0)
		{
			Start_Extra_Dist = 500.0;
		}
		else
		{
			Start_Point = NULL_VECTOR;
			Start_Dist = -1.0;
			Start_Extra_Dist = -1.0;
		}
		
		End_Point = NULL_VECTOR;
		End_Dist = -1.0;
		LogMessage("[MI] MapInfo for %s is missing.", g_sMapname);
	}
	
	bRoundEnd = false;
	bInSecondRound = false;
	bIsMapInit = true;
}

public void OnMapEnd()
{
	bIsMapInit = false;
	KvRewind(kvMapInfo);
	KvRewind(kvSafeRoomInfo);
	bRoundEnd = false;
	bInSecondRound = false;
	bInRound = false;
	iRoundNumber = 0;
	MapDataAvailable = false;
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (L4D2Direct_GetTankCount() > 0)
	{
		return Plugin_Handled;
	}
	bExpectTankSpawn = true;
	return Plugin_Continue;
}



/* Events */
public void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (bInRound)
	{
		bInRound = false;
		bRoundEnd = true;
		Call_StartForward(hFwdRoundEnd);
		Call_PushCell(iRoundNumber);
		Call_Finish();
	}
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (bRoundEnd)
	{
		bInSecondRound = true;
	}
	CreateTimer(0.25, RoundStart_Delay, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action RoundStart_Delay(Handle timer)
{
	if (bIsMapInit)
	{
		if (!bInRound)
		{
			bInRound = true;
			iRoundNumber++;
			Call_StartForward(hFwdRoundStart);
			Call_PushCell(iRoundNumber);
			Call_Finish();
		}
		ResetStatus();
		PrintToServer("%s", g_sMapname);
		KillTimer(timer);
	}
}

public void TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bExpectTankSpawn) return;
	bExpectTankSpawn = false;
	if (bIsTankActive) return;
	bIsTankActive = true;
	
	iTank = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(iTank) || GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8) return;
	
	Call_StartForward(hFwdFirstTankSpawn);
	Call_PushCell(iTank);
	Call_Finish();
}

public void ItemPickup_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive)
	{
		return;
	}
	char item[64];
	event.GetString("item", item, 64);
	if (StrEqual(item, "tank_claw"))
	{
		int iPrevTank = iTank;
		iTank = GetClientOfUserId(event.GetInt("userid"));
		if (!IsValidAndInGame(iTank) || GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8) return;
		
		if (hTankDeathTimer != null)
		{
			KillTimer(hTankDeathTimer);
			hTankDeathTimer = null;
		}
		Call_StartForward(hFwdTankPassControl);
		Call_PushCell(iPrevTank);
		Call_PushCell(iTank);
		Call_PushCell(iTankPassCount);
		Call_Finish();
		iTankPassCount += 1;
	}
}

public void PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive)
	{
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidAndInGame(client)) return;
	if (iTank != client) return;
	
	hTankDeathTimer = CreateTimer(0.5, TankDeath_Timer, attacker);
}

public Action TankDeath_Timer(Handle timer, any attacker)
{
	Call_StartForward(hFwdTankDeath);
	Call_PushCell(iTank);
	Call_PushCell(attacker);
	Call_Finish();
	ResetStatus();
}

public void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker;
	int health = event.GetInt("health");
	char weapon[256];
	event.GetString("weapon", weapon, 256);
	int damage = event.GetInt("dmg_health");
	int dmgtype = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	if (!IsValidAndInGame(victim) || !IsPlayerAlive(victim)) return;
	
	Call_StartForward(hFwdPlayerHurt);
	Call_PushCell(victim);
	int attackerid = event.GetInt("attacker");
	if (attackerid == 0)
	{
		attacker = event.GetInt("attackerentid");
	}
	else 
	{
		attacker = GetClientOfUserId(attackerid);
	}
	Call_PushCell(attacker);
	Call_PushCell(health);
	Call_PushString(weapon);
	Call_PushCell(damage);
	Call_PushCell(dmgtype);
	Call_PushCell(hitgroup);
	Call_Finish();
}

public Action PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");
	if (!IsValidAndInGame(client)) return;
	
	Action aResult = Plugin_Continue;
	if (team == 2)
	{
		Call_StartForward(hFwdJoinSurvivor);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	else if (team == 3)
	{
		Call_StartForward(hFwdJoinInfected);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	
	if (oldteam == 2)
	{
		Call_StartForward(hFwdAwaySurvivor);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	else if (oldteam == 3)
	{
		Call_StartForward(hFwdAwayInfected);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	
	Call_StartForward(hFwdTeamChanged);
	Call_PushCell(client);
	Call_PushCell(oldteam);
	Call_PushCell(team);
	Call_Finish(aResult);
	if (aResult == Plugin_Handled)
	{
		ChangeClientTeam(client, oldteam);
	}
	if (oldteam == 2 || team == 2)
	{
		CreateTimer(0.3, BuildArray_Timer);
	}
}

public Action BuildArray_Timer(Handle timer)
{
	Survivors_RebuildArray();
}

public void SI_BuildIndex_Event(Event event, const char[] name, bool dontBroadcast)
{
	Survivors_RebuildArray();
}

public Action Event_ServerConVar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}



/* Commands */
public Action Say_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    if (sayWord[0] == '!' || sayWord[0] == '/') return Plugin_Handled;
    return Plugin_Continue; 
}



/* Plugin Natives */
public any _native_GetCurrentRound(Handle plugin, int numParams)
{
	return GetCurrentRound();
}

public any _native_CurrentlyInRound(Handle plugin, int numParams)
{
	return CurrentlyInRound();
}

public any _native_GetSurvivorCount(Handle plugin, int numParams)
{
	return GetSurvivorCount();
}

public any _native_GetSurvivorOfIndex(Handle plugin, int numParams)
{
	return GetSurvivorOfIndex(GetNativeCell(1));
}

public any _native_IsMapDataAvailable(Handle plugin, int numParams)
{
	return IsMapDataAvailable();
}

public any _native_IsEntityInSaferoom(Handle plugin, int numParams)
{
	return IsEntityInSaferoom(GetNativeCell(1));
}

public any _native_GetMapStartOrigin(Handle plugin, int numParams)
{
	float origin[3];
	GetNativeArray(1, origin, 3);
	GetMapStartOrigin(origin);
	SetNativeArray(1, origin, 3);
}

public any _native_GetMapEndOrigin(Handle plugin, int numParams)
{
	float origin[3];
	GetNativeArray(1, origin, 3);
	GetMapEndOrigin(origin);
	SetNativeArray(1, origin, 3);
}

public any _native_GetMapStartDist(Handle plugin, int numParams)
{
	return GetMapStartDist();
}

public any _native_GetMapStartExtraDist(Handle plugin, int numParams)
{
	return GetMapStartExtraDist();
}

public any _native_GetMapEndDist(Handle plugin, int numParams)
{
	return GetMapEndDist();
}

public any _native_GetMapValueInt(Handle plugin, int numParams)
{
	int len, defval;
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	defval = GetNativeCell(2);
	
	return GetMapValueInt(key, defval);
}

public any _native_GetMapValueFloat(Handle plugin, int numParams)
{
	int len;
	float defval;
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	defval = GetNativeCell(2);
	
	return GetMapValueFloat(key, defval);
}

public any _native_GetMapValueVector(Handle plugin, int numParams)
{
	int len;
	float defval[3], value[3];
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	GetNativeArray(3, defval, 3);
	
	GetMapValueVector(key, value, defval);
	
	SetNativeArray(2, value, 3);
}

public any _native_GetMapValueString(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	
	GetNativeStringLength(4, len);
	char[] defval = new char[len+1];
	GetNativeString(4, defval, len+1);
	
	len = GetNativeCell(3);
	char[] buf = new char[len+1];
	
	GetMapValueString(key, buf, len, defval);
	
	SetNativeString(2, buf, len);
}

public any _native_CopyMapSubsection(Handle plugin, int numParams)
{
	int len;
	Handle kv;
	GetNativeStringLength(2, len);
	char[] key = new char[len+1];
	GetNativeString(2, key, len+1);
	
	kv = GetNativeCell(1);
	
	CopyMapSubsection(kv, key);
}


public any _native_InSecondHalfOfRound(Handle plugin, int numParams)
{
	return bInSecondRound;
}

public any _native_SAFEDETECT_IsEntityInStartSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	return IsPointInStartSaferoom(location);
}

public any _native_SAFEDETECT_IsEntityInEndSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	return IsPointInEndSaferoom(location);
}

public any _native_SAFEDETECT_IsEntityInSaferoom(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) { return false; }
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	return IsPointInStartSaferoom(location) || IsPointInEndSaferoom(location);
}

public any _native_GetRandomSurvivor(Handle plugin, int numParams)
{
	int[] survivors = new int[GetSurvivorCount()];
	int numSurvivors = 0;
	for (int i = 0; i < GetSurvivorCount(); i++)
	{
		int index = iSurvivorIndex[i];
		if (index == 0 || !IsValidAndInGame(index) || !IsPlayerAlive(index)) continue;
	    survivors[numSurvivors] = index;
	    numSurvivors++;
	}
	int iRandomSurvivor = survivors[GetRandomInt(0, numSurvivors - 1)];
	if (iRandomSurvivor) return iRandomSurvivor;
	return -1;
}

public any _native_IsCoop(Handle plugin, int numParams)
{
	return iGameMode == 0;
}

public any _native_IsVersus(Handle plugin, int numParams)
{
	return iGameMode == 1;
}

public any _native_IsScavenge(Handle plugin, int numParams)
{
	return iGameMode == 2;
}

public any _native_IsSurvival(Handle plugin, int numParams)
{
	return iGameMode == 3;
}


/* NATIVE FUNCTIONS */
// New Super Awesome Functions!!!

bool IsMapDataAvailable()
{
	return MapDataAvailable;
}

/**
 * Determines if an entity is in a start or end saferoom (based on mapinfo.txt or automatically generated info)
 *
 * @param ent			The entity to be checked
 * @return				Saferoom_Neither if entity is not in any saferoom
 *						Saferoom_Start if it is in the starting saferoom
 *						Saferoom_End if it is in the ending saferoom
 *						Saferoom_Start | Saferoom_End if it is in both saferooms (probably won't happen)
 */
Saferoom IsEntityInSaferoom(int ent)
{
	Saferoom result=Saferoom_Neither;
	float origins[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", origins);
	
	if ((GetVectorDistance(origins, Start_Point) <= (Start_Extra_Dist > Start_Dist ? Start_Extra_Dist : Start_Dist)))
	{
		result |= Saferoom_Start;
	}
	if (GetVectorDistance(origins, End_Point) <= End_Dist)
	{
		result |= Saferoom_End;
	}
	return result;
}

int GetMapValueInt(const char[] key, const int defvalue=0) 
{
	return KvGetNum(kvMapInfo, key, defvalue); 
}

float GetMapValueFloat(const char[] key, const float defvalue=0.0) 
{
	return KvGetFloat(kvMapInfo, key, defvalue); 
}

void GetMapValueVector(const char[] key, float vector[3], const float defvalue[3]=NULL_VECTOR) 
{
	KvGetVector(kvMapInfo, key, vector, defvalue);
}

void GetMapValueString(const char[] key, char[] value, int maxlength, const char[] defvalue="")
{
	KvGetString(kvMapInfo, key, value, maxlength, defvalue);
}

void CopyMapSubsection(Handle kv, const char[] section)
{
	if(KvJumpToKey(kvMapInfo, section, false))
	{
		KvCopySubkeys(kvMapInfo, kv);
		KvGoBack(kvMapInfo);
	}
}

float GetMapStartOrigin(float origin[3])
{
	origin = Start_Point;
}

float GetMapEndOrigin(float origin[3])
{
	origin = End_Point;
}

float GetMapEndDist()
{
	return End_Dist;
}

float GetMapStartDist()
{
	return Start_Dist;
}

float GetMapStartExtraDist()
{
	return Start_Extra_Dist;
}

int GetCurrentRound()
{
	return iRoundNumber;
}

bool CurrentlyInRound()
{
	return bInRound;
}

int GetSurvivorCount()
{
	return NUM_OF_SURVIVORS;
}

int GetSurvivorOfIndex(int index)
{
	if (index < 0 || index > 3)
	{
		return 0;
	}
	return iSurvivorIndex[index];
}

void RotatePoint(float origin[3], float &pointX, float &pointY, float angle)
{
    float newPoint[2];
    angle = angle / 57.2957795130823;
    
    newPoint[0] = (Cosine(angle) * (pointX - origin[0])) - (Sine(angle) * (pointY - origin[1]))   + origin[0];
    newPoint[1] = (Sine(angle) * (pointX - origin[0]))   + (Cosine(angle) * (pointY - origin[1])) + origin[1];
    
    pointX = newPoint[0];
    pointY = newPoint[1];
}

bool IsPointInStartSaferoom(float location[3])
{
	if (!g_bHasStart) { return false; }
	
	bool inSaferoom = false;
	
	if (g_fStartRotate)
	{
		RotatePoint(g_fStartLocA, location[0], location[1], g_fStartRotate);
	}
	
	float xMin, xMax, yMin, yMax, zMin, zMax;
	
	if (g_fStartLocA[0] < g_fStartLocB[0]) { xMin = g_fStartLocA[0]; xMax = g_fStartLocB[0]; } else { xMin = g_fStartLocB[0]; xMax = g_fStartLocA[0]; }
	if (g_fStartLocA[1] < g_fStartLocB[1]) { yMin = g_fStartLocA[1]; yMax = g_fStartLocB[1]; } else { yMin = g_fStartLocB[1]; yMax = g_fStartLocA[1]; }
	if (g_fStartLocA[2] < g_fStartLocB[2]) { zMin = g_fStartLocA[2]; zMax = g_fStartLocB[2]; } else { zMin = g_fStartLocB[2]; zMax = g_fStartLocA[2]; }
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
		
	if (!inSaferoom && g_bHasStartExtra)
	{
		if (g_fStartLocC[0] < g_fStartLocD[0]) { xMin = g_fStartLocC[0]; xMax = g_fStartLocD[0]; } else { xMin = g_fStartLocD[0]; xMax = g_fStartLocC[0]; }
		if (g_fStartLocC[1] < g_fStartLocD[1]) { yMin = g_fStartLocC[1]; yMax = g_fStartLocD[1]; } else { yMin = g_fStartLocD[1]; yMax = g_fStartLocC[1]; }
		if (g_fStartLocC[2] < g_fStartLocD[2]) { zMin = g_fStartLocC[2]; zMax = g_fStartLocD[2]; } else { zMin = g_fStartLocD[2]; zMax = g_fStartLocC[2]; }
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	
	return inSaferoom;
}

bool IsPointInEndSaferoom(float location[3])
{    
	if (!g_bHasEnd) { return false; }
	
	bool inSaferoom = false;
	
	if (g_fEndRotate)
	{
		RotatePoint(g_fEndLocA, location[0], location[1], g_fEndRotate);
	}
	
	float xMin, xMax, yMin, yMax, zMin, zMax;
	
	if (g_fEndLocA[0] < g_fEndLocB[0]) { xMin = g_fEndLocA[0]; xMax = g_fEndLocB[0]; } else { xMin = g_fEndLocB[0]; xMax = g_fEndLocA[0]; }
	if (g_fEndLocA[1] < g_fEndLocB[1]) { yMin = g_fEndLocA[1]; yMax = g_fEndLocB[1]; } else { yMin = g_fEndLocB[1]; yMax = g_fEndLocA[1]; }
	if (g_fEndLocA[2] < g_fEndLocB[2]) { zMin = g_fEndLocA[2]; zMax = g_fEndLocB[2]; } else { zMin = g_fEndLocB[2]; zMax = g_fEndLocA[2]; }
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	
	if (!inSaferoom && g_bHasEndExtra)
	{
		if (g_fEndLocC[0] < g_fEndLocD[0]) { xMin = g_fEndLocC[0]; xMax = g_fEndLocD[0]; } else { xMin = g_fEndLocD[0]; xMax = g_fEndLocC[0]; }
		if (g_fEndLocC[1] < g_fEndLocD[1]) { yMin = g_fEndLocC[1]; yMax = g_fEndLocD[1]; } else { yMin = g_fEndLocD[1]; yMax = g_fEndLocC[1]; }
		if (g_fEndLocC[2] < g_fEndLocD[2]) { zMin = g_fEndLocC[2]; zMax = g_fEndLocD[2]; } else { zMin = g_fEndLocD[2]; zMax = g_fEndLocC[2]; }
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	
	return inSaferoom;
}

void ResetStatus()
{
	bExpectTankSpawn = false;
	bIsTankActive = false;
	iTank = -1;
	iTankPassCount = 0;
	
	if (hTankDeathTimer != null)
	{
		KillTimer(hTankDeathTimer);
		hTankDeathTimer = null;
	}
}

void Survivors_RebuildArray()
{
	if (!IsServerProcessing()) return;
	int iSurvivorCount = 0;
	int charz;
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++) iSurvivorIndex[i] = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (iSurvivorCount == NUM_OF_SURVIVORS) break;
		
		if (!IsClientInGame(i) || GetClientTeam(i) != 2) continue;
		
		charz = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		iSurvivorCount++;
		
		if (charz > 3 || charz < 0) continue;
		
		iSurvivorIndex[charz] = i;
	}
}

float FindStartPointHeuristic(float result[3])
{
	int kits, entcount = GetEntityCount();
	float kitOrigin[4][3], averageOrigin[3];
	char entclass[128];
	for (int iEntity = 1;iEntity<=entcount && kits <4;iEntity++)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) continue;
		GetEdictClassname(iEntity,entclass,sizeof(entclass));
		if (StrEqual(entclass, "weapon_first_aid_kit_spawn"))
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", kitOrigin[kits]);
			averageOrigin[0] += kitOrigin[kits][0];
			averageOrigin[1] += kitOrigin[kits][1];
			averageOrigin[2] += kitOrigin[kits][2];
			kits++;
		}
	}
	if (kits < 4) return -1.0;
	ScaleVector(averageOrigin, 0.25);
	
	float greatestDist, tempDist;
	for (int i; i < 4; i++)
	{
		tempDist = GetVectorDistance(averageOrigin, kitOrigin[i]);
		if (tempDist > greatestDist) greatestDist = tempDist;
	}
	result = averageOrigin;
	return greatestDist+1.0;
}

bool IsValidAndInGame(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
