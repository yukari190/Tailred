#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <dhooks>
#undef REQUIRE_PLUGIN
#include <lgofnoc>

#define LIBRARYNAME "l4d2lib"

#define LEFT4FRAMEWORK_GAMEDATA "left4dhooks.l4d2"

#define MAPINFO_PATH "configs/l4d2lib/mapinfo.txt"
#define SAFEROOMINFO_PATH "configs/l4d2lib/saferoominfo.txt"

public Plugin myinfo =
{
	name = "l4d2lib",
	description = "Useful natives and fowards for L4D2 Plugins",
	author = "Confogl Team, Yukari190",
	version = "3.2b",
	url = "https://github.com/yukari190/Tailred"
};

enum
{
	Saferoom_Neither = 0,
	Saferoom_Start = 1,
	Saferoom_End = 2,
	Saferoom_Both = 3
};

KeyValues
	kvMapInfo = null,
	kvSafeRoomInfo = null;
ArrayList
	hTankClients;
Handle
	g_hDetour,
	hTankDeathTimer[MAXPLAYERS+1];
GlobalForward
	hFwdRoundStart,
	hFwdRoundEnd,
	hFwdFirstTankSpawn,
	hFwdTankPassControl,
	hFwdTankDeath;
int
	iRoundNumber = 0;
bool
	SaferoomDataAvailable,
	bIsMapActive,
	bInRound,
	bIsTankActive,
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
	g_fStartPoint[3] = {0.0, ...},
	g_fEndPoint[3] = {0.0, ...},
	g_fStartDist = 0.0,
	g_fStartExtraDist = 0.0,
	g_fEndDist = 0.0;
char
	g_sMapname[64];

/* Plugin Natives */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	/* Plugin Native Declarations */
	CreateNative("L4D2_GetCurrentRound", _native_GetCurrentRound);
	CreateNative("L4D2_CurrentlyInRound", _native_CurrentlyInRound);
	CreateNative("L4D2_IsMapDataAvailable", _native_IsMapDataAvailable);
	CreateNative("L4D2_IsEntityInSaferoom", _native_IsEntityInSaferoom);
	CreateNative("L4D2_GetMapValueInt", _native_GetMapValueInt);
	CreateNative("L4D2_GetMapValueFloat", _native_GetMapValueFloat);
	CreateNative("L4D2_GetMapValueVector", _native_GetMapValueVector);
	CreateNative("L4D2_GetMapValueString", _native_GetMapValueString);
	CreateNative("L4D2_CopyMapSubsection", _native_CopyMapSubsection);
	CreateNative("L4D2_IsInTransition", _native_IsInTransition);
	
	// l4d2_saferoom_detect
	CreateNative("SAFEDETECT_IsEntityInStartSaferoom", _native_IsEntityInStartSaferoom);
	CreateNative("SAFEDETECT_IsEntityInEndSaferoom", _native_IsEntityInEndSaferoom);
	
	
	/* Plugin Forward Declarations */
	hFwdRoundStart = new GlobalForward("L4D2_OnRealRoundStart", ET_Ignore, Param_Cell);
	hFwdRoundEnd = new GlobalForward("L4D2_OnRealRoundEnd", ET_Ignore, Param_Cell);
	hFwdFirstTankSpawn = new GlobalForward("L4D2_OnTankFirstSpawn", ET_Ignore, Param_Cell);
	hFwdTankPassControl = new GlobalForward("L4D2_OnTankPassControl", ET_Ignore, Param_Cell, Param_Cell);
	hFwdTankDeath = new GlobalForward("L4D2_OnTankDeath", ET_Ignore, Param_Cell);
	
	/* Register our library */
	RegPluginLibrary(LIBRARYNAME);
	return APLRes_Success;
}

public any _native_GetCurrentRound(Handle plugin, int numParams)
{
	return iRoundNumber;
}

public any _native_CurrentlyInRound(Handle plugin, int numParams)
{
	return bInRound;
}

public any _native_IsMapDataAvailable(Handle plugin, int numParams)
{
	return MapDataAvailable;
}

public any _native_IsEntityInSaferoom(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);

	int result = Saferoom_Neither;
	if (IsEntityInStartSaferoom(entity))
	{
		result |= Saferoom_Start;
	}
	if (IsEntityInEndSaferoom(entity))
	{
		result |= Saferoom_End;
	}
	return result;
}

public any _native_GetMapValueInt(Handle plugin, int numParams)
{
	int len, defval;
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	defval = GetNativeCell(2);
	
	return KvGetNum(kvMapInfo, key, defval); 
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
	
	return KvGetFloat(kvMapInfo, key, defval);
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
	
	KvGetVector(kvMapInfo, key, value, defval);
	
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
	
	KvGetString(kvMapInfo, key, buf, len, defval);
	
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
	
	if (KvJumpToKey(kvMapInfo, key, false))
	{
		KvCopySubkeys(kvMapInfo, kv);
		KvGoBack(kvMapInfo);
	}
}

public any _native_IsInTransition(Handle plugin, int numParams)
{
	return !bIsMapActive;
}

public any _native_IsEntityInStartSaferoom(Handle plugin, int numParams)
{
    return IsEntityInStartSaferoom(GetNativeCell(1));
}

public any _native_IsEntityInEndSaferoom(Handle plugin, int numParams)
{
    return IsEntityInEndSaferoom(GetNativeCell(1));
}

public void OnPluginStart()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	kvSafeRoomInfo = new KeyValues("SaferoomInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), SAFEROOMINFO_PATH);
	if (!FileToKeyValues(kvSafeRoomInfo, sNameBuff))
	{
		LogError("[l4d2lib] 找不到 saferoominfo.txt 文件信息");
		if (kvSafeRoomInfo != null)
		{
			CloseHandle(kvSafeRoomInfo);
			kvSafeRoomInfo = null;
		}
	}
	
	MI_KV_Load();
	
	Handle hGameData = LoadGameConfigFile(LEFT4FRAMEWORK_GAMEDATA);
	if (hGameData == null) {
		SetFailState("Missing gamedata \"%s\".", LEFT4FRAMEWORK_GAMEDATA);
	}
	
	g_hDetour = DHookCreateFromConf(hGameData, "L4DD::ZombieManager::SpawnTank");
	if (g_hDetour == null) {
		SetFailState("Failed to create detour \"L4DD::ZombieManager::SpawnTank\" from gamedata.");
	}
	
	if (!DHookEnableDetour(g_hDetour, true, OnSpawnTank)) {
		SetFailState("Failed to enable detour \"L4DD::ZombieManager::SpawnTank\".");
	}

	delete hGameData;
	
	hTankClients = new ArrayList();
	
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
	
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	
	HookEvent("item_pickup", ItemPickup_Event);
	HookEvent("player_death", PlayerDeath_Event);
}

public void OnPluginEnd()
{
	delete kvMapInfo;
	delete kvSafeRoomInfo;
	
	if (!DHookDisableDetour(g_hDetour, true, OnSpawnTank))
		SetFailState("Failed to disable detour \"L4DD::ZombieManager::SpawnTank\".");
}

public void LGO_OnMatchModeLoaded()
{
	MapInfo_Reload();
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapname, 64);
	
	MapDataAvailable = Update_MapInfo();
	SaferoomDataAvailable = UpdateSaferoomInfo();
	
	bIsMapActive = true;
}

public void OnMapEnd()
{
	RoundEnd_Event(null, "", false);
	
	bIsMapActive = false;
	KvRewind(kvMapInfo);
	KvRewind(kvSafeRoomInfo);
	bInRound = false;
	iRoundNumber = 0;
	MapDataAvailable = false;
}



/* Events */
public void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (bInRound)
	{
		bInRound = false;
		Call_StartForward(hFwdRoundEnd);
		Call_PushCell(iRoundNumber);
		Call_Finish();
	}
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.25, RoundStart_Delay, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action RoundStart_Delay(Handle timer)
{
	if (bIsMapActive)
	{
		if (!bInRound)
		{
			bInRound = true;
			iRoundNumber++;
			
			OnRoundStart();
			
			Call_StartForward(hFwdRoundStart);
			Call_PushCell(iRoundNumber);
			Call_Finish();
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void OnRoundStart()
{
	PrintToServer("%s", g_sMapname);
	
	hTankClients.Clear();
	
	bIsTankActive = false;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		if (hTankDeathTimer[i] != INVALID_HANDLE)
		{
			KillTimer(hTankDeathTimer[i]);
			hTankDeathTimer[i] = INVALID_HANDLE;
		}
	}
}

public MRESReturn OnSpawnTank(Handle hReturn, Handle hParams)
{
	bool ret = DHookGetReturn(hReturn) != 0; // left4dhooks sets it 0 to disable tank spawns
	
	if (ret == true) {
		RequestFrame(OnNextFrame, 0);	// seems it occurs often that prints with wrong teamcolors
									// make a slight delay here to try fixing this
	}
	return MRES_Ignored;
}

public void OnNextFrame(any data)
{
	int iNumTanks = NumTanksInPlay();
	
	if (hTankClients.Length < iNumTanks)
	{
		int tankClient = FindAliveTankClient();
		if (tankClient > 0)
		{
			bIsTankActive = true;
			AddTankToArray(tankClient);
			Call_StartForward(hFwdFirstTankSpawn);
			Call_PushCell(tankClient);
			Call_Finish();
		}
    }
}

public void ItemPickup_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive) return;
	
	char item[64];
	event.GetString("item", item, 64);
	
	if (strcmp(item, "tank_claw") == 0)
	{
		int userid = event.GetInt("userid");
		RequestFrame(OnItemPickup, userid);
	}
}

public void OnItemPickup(int userid)
{
	int iPrevTank = FindOldTankClient();
	if (iPrevTank == -1) return;
	RemoveTankFromArray(iPrevTank);
	
	if (hTankDeathTimer[iPrevTank] != INVALID_HANDLE)
	{
		KillTimer(hTankDeathTimer[iPrevTank]);
		hTankDeathTimer[iPrevTank] = INVALID_HANDLE;
	}
	int iTankClient = GetClientOfUserId(userid);
	
	if (iTankClient > 0 && !FindTankInArray(iTankClient)) AddTankToArray(iTankClient);
	
	Call_StartForward(hFwdTankPassControl);
	Call_PushCell(iPrevTank);
	Call_PushCell(iTankClient);
	Call_Finish();
}

public void PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!FindTankInArray(client)) return;
	
	hTankDeathTimer[client] = CreateTimer(0.5, TankDeath_Timer, client);
}

public Action TankDeath_Timer(Handle timer, any iTankClient)
{
	RemoveTankFromArray(iTankClient);
	Call_StartForward(hFwdTankDeath);
	Call_PushCell(iTankClient);
	Call_Finish();
    
	if (!NumTanksInPlay()) bIsTankActive = false;
	if (hTankDeathTimer[iTankClient] != INVALID_HANDLE)
	{
		KillTimer(hTankDeathTimer[iTankClient]);
		hTankDeathTimer[iTankClient] = INVALID_HANDLE;
	}
	
	return Plugin_Stop;
}


/* NATIVE FUNCTIONS */
// New Super Awesome Functions!!!
bool bIsMatchModeLoaded()
{
	return (GetFeatureStatus(FeatureType_Native, "LGO_IsMatchModeLoaded") != FeatureStatus_Unknown);
}

void MapInfo_Reload()
{
	MI_KV_Close();
	MI_KV_Load();
}

void MI_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	
	kvMapInfo = new KeyValues("MapInfo");
	if (bIsMatchModeLoaded() && LGO_IsMatchModeLoaded())
	{
		LGO_BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt");
	}
	else
	{
		BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), MAPINFO_PATH);
	}

	if (!FileToKeyValues(kvMapInfo, sNameBuff))
	{
		LogError("[l4d2lib] 找不到 %s 文件信息", sNameBuff);
		MI_KV_Close();
	}
}

void MI_KV_Close()
{
	if (kvMapInfo != null)
	{
		CloseHandle(kvMapInfo);
		kvMapInfo = null;
	}
}

bool Update_MapInfo()
{
	if (kvMapInfo != null && KvJumpToKey(kvMapInfo, g_sMapname))
	{
		KvGetVector(kvMapInfo, "start_point", g_fStartPoint);
		KvGetVector(kvMapInfo, "end_point", g_fEndPoint);

		g_fStartDist = KvGetFloat(kvMapInfo, "start_dist");
		g_fStartExtraDist = KvGetFloat(kvMapInfo, "start_extra_dist");
		g_fEndDist = KvGetFloat(kvMapInfo, "end_dist");

		return true;
	}
	else
	{
		g_fStartDist = FindStartPointHeuristic(g_fStartPoint);

		if (g_fStartDist > 0.0)
		{
			g_fStartExtraDist = 500.0;
		}
		else
		{
			g_fStartPoint = NULL_VECTOR;
			g_fStartDist = -1.0;
			g_fStartExtraDist = -1.0;
		}

		g_fEndPoint = NULL_VECTOR;
		g_fEndDist = -1.0;
		LogMessage("[l4d2lib] MapInfo for %s is missing.", g_sMapname);
		return false;
	}
}

bool UpdateSaferoomInfo()
{
	if (kvSafeRoomInfo == null)
	{
		LogError("[l4d2lib] No saferoom keyvalues loaded!");
		return false;
	}
	
	g_bHasStart = false;        g_bHasStartExtra = false;
	g_bHasEnd = false;          g_bHasEndExtra = false;
	g_fStartLocA = NULL_VECTOR; g_fStartLocB = NULL_VECTOR; g_fStartLocC = NULL_VECTOR; g_fStartLocD = NULL_VECTOR;
	g_fEndLocA = NULL_VECTOR;   g_fEndLocB = NULL_VECTOR;   g_fEndLocC = NULL_VECTOR;   g_fEndLocD = NULL_VECTOR;
	g_fStartRotate = 0.0;       g_fEndRotate = 0.0;
	
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
		
		return true;
	}
	else
	{
		LogMessage("[l4d2lib] SaferoomInfo for %s is missing.", g_sMapname);
		
		return false;
	}
}

bool IsEntityInStartSaferoom(int entity)
{
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
	
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	
	return IsPointInStartSaferoom(location);
}

bool IsEntityInEndSaferoom(int entity)
{
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
	
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	
	return IsPointInEndSaferoom(location);
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
	if (SaferoomDataAvailable && g_bHasStart)
	{
		//if (!g_bHasStart) { return false; }
		
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
	else
	{
		return GetVectorDistance(location, g_fStartPoint) <= ((g_fStartExtraDist > g_fStartDist) ? g_fStartExtraDist : g_fStartDist);
	}
}

bool IsPointInEndSaferoom(float location[3])
{
	if (SaferoomDataAvailable && g_bHasEnd)
	{
		//if (!g_bHasEnd) { return false; }
		
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
	else
	{
		return GetVectorDistance(location, g_fEndPoint) <= g_fEndDist;
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

void AddTankToArray(int client)
{
    hTankClients.Push(client);
}

void RemoveTankFromArray(int client)
{
    for (int i = 0; i < hTankClients.Length; ++i)
	{
        if (hTankClients.Get(i) == client)
		{
            hTankClients.Erase(i);
        }
    }
}

bool FindTankInArray(int client)
{
    for (int i = 0; i < hTankClients.Length; ++i)
	{
        if (hTankClients.Get(i) == client)
		{
            return true;
        }       
    }
    
    return false;
}

int FindOldTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (FindTankInArray(i))
		{
			if (!IsTank(i) || IsIncapacitated(i) || !IsPlayerAlive(i))
			{
				return i;
			}
		}
	}

	return -1;
}

int NumTanksInPlay()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i))
		{
			count++;
		}
	}
	
	return count;
}

int FindAliveTankClient()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsTank(i) && IsPlayerAlive(i))
		{
			if (!FindTankInArray(i))
			{
				return i;
			}
		}
	}

	return -1;
}

bool IsTank(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == 3 && GetEntProp(client, Prop_Send, "m_zombieClass") == 8);
}

bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}