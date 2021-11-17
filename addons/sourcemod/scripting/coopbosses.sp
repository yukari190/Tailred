#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>
#include <colors>
#include <DirectInfectedSpawn>
#undef REQUIRE_PLUGIN
#include <readyup>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
	name = "Coop Bosses",
	description = "CanadaRox, Sir, devilesk, Derpduck, Yukari190",
	author = "Customisable tank and witch spawning in coop",
	version = "3.0",
	url = "https://github.com/yukari190/Tailred"
};

ConVar
	hVsBossFlowMax,
	hVsBossFlowMin,
	hCvarTankCanSpawn,
	hCvarWitchCanSpawn,
	hCvarWitchAvoidTank,
	l4d2_scripted_hud_hud1_text,
	hVsBossBuffer = null;
	
StringMap
	hStaticTankMaps,
	hStaticWitchMaps;

bool
	bTankSpawn,
	readyUpIsAvailable,
	readyFooterAdded;

float 
	fTankFlow,
	fVersusBossBuffer;

int 
	iTankPercent,
	survivorCompletion;

char
	g_sCurrentMap[64],
	sBossBuffer[64],
	curtext[128];

ArrayList
	hValidTankFlows,
	hValidWitchFlows;

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("AddStringToReadyFooter");
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public void OnLibraryRemoved(const char[] name)
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public void OnLibraryAdded(const char[] name)
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}

public void OnPluginStart()
{
	hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	hVsBossFlowMin = FindConVar("versus_boss_flow_min");
	l4d2_scripted_hud_hud1_text = FindConVar("l4d2_scripted_hud_hud1_text");
	
	(hVsBossBuffer = FindConVar("versus_boss_buffer")).AddChangeHook(GameConVarChanged);
	fVersusBossBuffer	= hVsBossBuffer.FloatValue;
	
	hCvarTankCanSpawn = CreateConVar("sm_tank_can_spawn", "1", "Tank and Witch ifier enables tanks to spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvarWitchCanSpawn = CreateConVar("sm_witch_can_spawn", "1", "Tank and Witch ifier enables witches to spawn", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	hCvarWitchAvoidTank = CreateConVar("sm_witch_avoid_tank_spawn", "20", "Minimum flow amount witches should avoid tank spawns by, by half the value given on either side of the tank spawn", FCVAR_NOTIFY, true, 0.0, true, 100.0);
	
	hStaticTankMaps = new StringMap();
	hStaticWitchMaps = new StringMap();
	
	hValidTankFlows = new ArrayList(2);
	hValidWitchFlows = new ArrayList(2);
	
	RegServerCmd("static_tank_map", StaticTank_Command);
	RegServerCmd("static_witch_map", StaticWitch_Command);
	RegServerCmd("reset_static_maps", Reset_Command);
	
	RegConsoleCmd("sm_boss", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_tank", Cmd_BossPercent, "Boss产生的百分比");
	
	FindConVar("director_no_bosses").SetBool(true);
	
	CreateTimer(1.0, HudDrawTimer, _, TIMER_REPEAT);
}

public void OnPluginEnd()
{
	FindConVar("director_no_bosses").RestoreDefault();
}

public void GameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fVersusBossBuffer	= hVsBossBuffer.FloatValue;
}

public Action HudDrawTimer(Handle hTimer)
{
	if (L4D2_IsInTransition() || GetSeriousClientCount(true) == 0) return Plugin_Continue;
	if (l4d2_scripted_hud_hud1_text != null)
	{
		Format(curtext, sizeof(curtext), "进度  [ %d%% ]        %s", GetHighestSurvivorFlow(), sBossBuffer);
		l4d2_scripted_hud_hud1_text.SetString(curtext);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public void OnMapStart()
{
	bTankSpawn = false;
	fTankFlow = 0.0;
	iTankPercent = 0;
	GetCurrentMapLower(g_sCurrentMap, sizeof g_sCurrentMap);
}

public Action StaticTank_Command(int args) {
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	StrToLower(mapname);
	hStaticTankMaps.SetValue(mapname, true);
}

public Action StaticWitch_Command(int args) {
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	StrToLower(mapname);
	hStaticWitchMaps.SetValue(mapname, true);
}

public Action Reset_Command(int args) {
	hStaticTankMaps.Clear();
	hStaticWitchMaps.Clear();
}

public Action Cmd_BossPercent(int client, int args)
{
	if (!IsValidAndInGame(client)) return Plugin_Handled;
	
	int iTeam = GetClientTeam(client);
	if (iTeam == 1)
	{
		PrintBossPercents(client);
		return Plugin_Handled;
	}
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == iTeam)
		  PrintBossPercents(i);
	}
	RequestFrame(PrintCurrent, GetClientUserId(client));
	return Plugin_Handled;
}

public void PrintCurrent(int userid) {
	int client = GetClientOfUserId(userid);
	if (client) FakeClientCommand(client, "say /current");
}

public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	return hCvarTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D_OnSpawnWitch(const float vecPos[3], const float vecAng[3])
{
	return hCvarWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}

public Action L4D2_OnSpawnWitchBride(const float vecPos[3], const float vecAng[3])
{
	return hCvarWitchCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
}


public void OnRoundIsLive()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		  PrintBossPercents(i);
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!readyUpIsAvailable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			  PrintBossPercents(i);
		}
	}
}

public void L4D2_OnRealRoundStart()
{
	survivorCompletion = 0;
	readyFooterAdded = false;
	AllowTankSpawn(true, false);
	CreateTimer(0.5, TankSpawnPercentCheck, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
	CreateTimer(0.1, AdjustBossFlow, _, TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(2.0, AddReadyFooter);
}

public Action TankSpawnPercentCheck(Handle timer)
{
	if (AllowTankSpawn())
	{
		float spawnPos[3];
		int client = L4D_GetHighestFlowSurvivor();
		if (client)
		{
			if (!L4D_GetRandomPZSpawnPosition(client, view_as<int>(L4D2Infected_Tank), 30, spawnPos))
			{
				if (!GridSpawn(L4D2Infected_Tank, 100, spawnPos))
				{
					PrintToChatAll("[SM] Failed to find a spawn for tank in maximum allowed attempts");
					AllowTankSpawn(true, true);
					return Plugin_Stop;
				}
			}
			L4D2_SpawnTank(spawnPos, NULL_VECTOR);
		}
		else
		{
			PrintToChatAll("[SM] Failed to find a spawn for tank in maximum allowed attempts");
		}
		AllowTankSpawn(true, true);
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action AdjustBossFlow(Handle timer)
{
	L4D2Direct_SetVSTankFlowPercent(0, 0.0);
	L4D2Direct_SetVSTankFlowPercent(1, 0.0);
	L4D2Direct_SetVSTankToSpawnThisRound(0, false);
	L4D2Direct_SetVSTankToSpawnThisRound(1, false);
	
	if (L4D2_GetCurrentRound() > 1) return Plugin_Stop;
	
	hValidTankFlows.Clear();
	hValidWitchFlows.Clear();
	
	int iCvarMinFlow = RoundToCeil(hVsBossFlowMin.FloatValue * 100);
	int iCvarMaxFlow = RoundToFloor(hVsBossFlowMax.FloatValue * 100);
	
	// mapinfo override
	iCvarMinFlow = L4D2_GetMapValueInt("versus_boss_flow_min", iCvarMinFlow);
	iCvarMaxFlow = L4D2_GetMapValueInt("versus_boss_flow_max", iCvarMaxFlow);
	
	if (!IsStaticTankMap(g_sCurrentMap) && hCvarTankCanSpawn.BoolValue) {
		
		ArrayList hBannedFlows = new ArrayList(2);
		
		int interval[2];
		interval[0] = 0, interval[1] = iCvarMinFlow - 1;
		if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
		interval[0] = iCvarMaxFlow + 1, interval[1] = 100;
		if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
	
		KeyValues kv = new KeyValues("tank_ban_flow");
		L4D2_CopyMapSubsection(kv, "tank_ban_flow");
		
		if (kv.GotoFirstSubKey()) {
			do {
				interval[0] = kv.GetNum("min", -1);
				interval[1] = kv.GetNum("max", -1);
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
			} while (kv.GotoNextKey());
		}
		delete kv;
		
		MergeIntervals(hBannedFlows);
		MakeComplementaryIntervals(hBannedFlows, hValidTankFlows);
		
		delete hBannedFlows;
		
		// check each array index to see if it is within a ban range
		int iValidSpawnTotal = hValidTankFlows.Length;
		if (iValidSpawnTotal == 0) {
			SetTankPercent(0);
		}
		else {
			int iTankFlow = GetRandomFlow(hValidTankFlows);
			SetTankPercent(iTankFlow);
		}
	}
	else {
		SetTankPercent(0);
	}
	
	bool canWitchSpawn = GetConVarBool(hCvarWitchCanSpawn);
	if (!IsStaticWitchMap(g_sCurrentMap) && canWitchSpawn) {

		ArrayList hBannedFlows = new ArrayList(2);
		
		int interval[2];
		interval[0] = 0, interval[1] = iCvarMinFlow - 1;
		if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
		interval[0] = iCvarMaxFlow + 1, interval[1] = 100;
		if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
	
		KeyValues kv = new KeyValues("witch_ban_flow");
		L4D2_CopyMapSubsection(kv, "witch_ban_flow");
		
		if (kv.GotoFirstSubKey()) {
			do {
				interval[0] = kv.GetNum("min", -1);
				interval[1] = kv.GetNum("max", -1);
				if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
			} while (kv.GotoNextKey());
		}
		delete kv;
		
		interval[0] = RoundToFloor((GetTankFlowPercent() * 100) - (hCvarWitchAvoidTank.FloatValue / 2));
		interval[1] = RoundToCeil((GetTankFlowPercent() * 100) + (hCvarWitchAvoidTank.FloatValue / 2));
		if (IsValidInterval(interval)) hBannedFlows.PushArray(interval);
		
		MergeIntervals(hBannedFlows);
		MakeComplementaryIntervals(hBannedFlows, hValidWitchFlows);
		
		delete hBannedFlows;
		
		// check each array index to see if it is within a ban range
		int iValidSpawnTotal = hValidWitchFlows.Length;
		if (iValidSpawnTotal == 0) {
			SetWitchPercent(0);
		}
		else {
			int iWitchFlow = GetRandomFlow(hValidWitchFlows);
			SetWitchPercent(iWitchFlow);
		}
	}
	else {
		SetWitchPercent(0);
	}
	
	return Plugin_Stop;
}

public Action AddReadyFooter(Handle timer)
{
	if (readyFooterAdded) return Plugin_Stop;
	if (readyUpIsAvailable)
	{
		char readyString[68];
		if (GetTankToSpawn()) Format(readyString, sizeof(readyString), "Tank: %d%%", iTankPercent);
		else Format(readyString, sizeof(readyString), "Tank: None");

		AddStringToReadyFooter(readyString);
		readyFooterAdded = true;
	}
	return Plugin_Stop;
}

void PrintBossPercents(int client)
{
	if (hCvarTankCanSpawn.BoolValue)
	{
		if (GetTankToSpawn()) CPrintToChat(client, "{R}Tank{W}:  [ {G}%d%%{W} ]", iTankPercent);
		else CPrintToChat(client, "{R}Tank{W}:  [ {G}--%%{W} ]");
	}
}

bool IsValidInterval(int interval[2]) {
	return interval[0] > -1 && interval[1] >= interval[0];
}

void MergeIntervals(ArrayList merged) {
	ArrayList intervals = merged.Clone();
	intervals.Sort(Sort_Ascending, Sort_Integer);
	
	merged.Clear();
	
	int current[2];
	intervals.GetArray(0, current);
	merged.PushArray(current);
	
	int intv_size = intervals.Length;
	for (int i = 1; i < intv_size; ++i) {
		intervals.GetArray(i, current);
		
		int back_index = merged.Length - 1;
		int back_R = merged.Get(back_index, 1);
		
		if (back_R < current[0]) { // not coincide
			merged.PushArray(current);
		} else {
			back_R = (back_R > current[1] ? back_R : current[1]); // override the right value with maximum
			merged.Set(back_index, back_R, 1);
		}
	}
	
	delete intervals;
}

void MakeComplementaryIntervals(ArrayList intervals, ArrayList dest) {
	int intv_size = intervals.Length;
	if (intv_size < 2) return;
	
	int intv[2];
	for (int i = 1; i < intv_size; ++i) {
		intv[0] = intervals.Get(i-1, 1) + 1;
		intv[1] = intervals.Get(i, 0) - 1;
		if (IsValidInterval(intv)) dest.PushArray(intv);
	}
}

int GetRandomFlow(ArrayList aList) {
	int total_length = 0, size = aList.Length;
	int[] lengths = new int[size];
	for (int i = 0; i < size; ++i) {
		lengths[i] = aList.Get(i, 1) - aList.Get(i, 0) + 1;
		total_length += lengths[i];
	}
	
	int random = Math_GetRandomInt(0, total_length-1);
	
	for (int i = 0; i < size; ++i) {
		if (random < lengths[i]) {
			return aList.Get(i, 0) + random;
		} else {
			random -= lengths[i];
		}
	}
	return 0;
}


bool IsStaticTankMap(const char[] map) {
	bool dummy;
	return hStaticTankMaps.GetValue(map, dummy);
}

bool IsStaticWitchMap(const char[] map) {
	bool dummy;
	return hStaticWitchMaps.GetValue(map, dummy);
}

bool GetTankToSpawn()
{
	return bTankSpawn;
}

float GetTankFlowPercent()
{
	return fTankFlow;
}

void SetTankPercent(int percent) {
	if (percent == 0) {
		fTankFlow = 0.0;
		bTankSpawn = false;
	} else {
		float p_newPercent = (float(percent)/100);
		fTankFlow = p_newPercent;
		bTankSpawn = true;
	}
	
	AddHudString();
}

void SetWitchPercent(int percent) {
	if (percent == 0) {
		L4D2Direct_SetVSWitchFlowPercent(0, 0.0);
		L4D2Direct_SetVSWitchFlowPercent(1, 0.0);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, false);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, false);
	} else {
		float p_newPercent = (float(percent)/100);
		L4D2Direct_SetVSWitchFlowPercent(0, p_newPercent);
		L4D2Direct_SetVSWitchFlowPercent(1, p_newPercent);
		L4D2Direct_SetVSWitchToSpawnThisRound(0, true);
		L4D2Direct_SetVSWitchToSpawnThisRound(1, true);
	}
}


#define SIZE_OF_INT		 2147483647 // without 0
int Math_GetRandomInt(int min, int max)
{
	int random = GetURandomInt();

	if (random == 0) {
		random++;
	}

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}

void StrToLower(char[] arg) {
	int length = strlen(arg);
	for (int i = 0; i < length; i++) {
		arg[i] = CharToLower(arg[i]);
	}
}

int GetCurrentMapLower(char[] buffer, int buflen) {
	int iBytesWritten = GetCurrentMap(buffer, buflen);
	StrToLower(buffer);
	return iBytesWritten;
}

bool bTankSpawned = false;

bool AllowTankSpawn(bool bSetStatus = false, bool bStatus = false)
{
	if (bSetStatus)
	{
		bTankSpawned = bStatus;
	}
	if (bTankSpawned) return false;
	return (!IsInReady() && L4D_HasAnySurvivorLeftSafeArea() && GetTankToSpawn() && GetBossProximity() >= GetTankFlowPercent());
}

/*void SendHurtMessage(int victim, int attacker, const char[] weapon, int damage, int dmgtype)
{
	Event newEvent = CreateEvent("player_hurt", true);
	if(newEvent == null) return;

	newEvent.SetInt("userid", GetClientUserId(victim));
	newEvent.SetInt("attacker", GetClientUserId(attacker));
	newEvent.SetString("weapon", weapon);
	newEvent.SetInt("dmg_health", damage);
	newEvent.SetInt("type", dmgtype);
	FireEvent(newEvent, true);
}*/

void AddHudString()
{
	iTankPercent = RoundToNearest(GetTankFlowPercent() * 100.0);
	
	if (!hCvarTankCanSpawn.BoolValue && !hCvarWitchCanSpawn.BoolValue)
	{
		Format(sBossBuffer, sizeof(sBossBuffer), "  ");
	}
	else if (hCvarTankCanSpawn.BoolValue && !hCvarWitchCanSpawn.BoolValue)
	{
		if (IsStaticTankMap(g_sCurrentMap))
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ 固定 ]");
		}
		else
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ %d%% ]", iTankPercent);
		}
	}
	else if (!hCvarTankCanSpawn.BoolValue && hCvarWitchCanSpawn.BoolValue)
	{
		if (IsStaticWitchMap(g_sCurrentMap))
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "女巫 [ 固定 ]");
		}
		else
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "女巫  [  ]");
		}
	}
	else
	{
		if (IsStaticTankMap(g_sCurrentMap) && IsStaticWitchMap(g_sCurrentMap))
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ 固定 ]        女巫  [ 固定 ]");
		}
		else if (!IsStaticTankMap(g_sCurrentMap) && IsStaticWitchMap(g_sCurrentMap))
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ %d%% ]        女巫  [ 固定 ]", iTankPercent);
		}
		else if (IsStaticTankMap(g_sCurrentMap) && !IsStaticWitchMap(g_sCurrentMap))
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ 固定 ]        女巫  [  ]");
		}
		else
		{
			Format(sBossBuffer, sizeof(sBossBuffer), "坦克  [ %d%% ]        女巫  [  ]", iTankPercent);
		}
	}
}

int GetHighestSurvivorFlow()
{
	int flow = RoundToNearest(100.0 * GetBossProximity());
	if (survivorCompletion < flow)
	{
		survivorCompletion = flow;
	}
	return survivorCompletion;
}

float GetBossProximity()
{
	float flow = -1.0;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0)
	{
		flow = (L4D2Direct_GetFlowDistance(client) + fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
	}
	return (flow > 1.0) ? 1.0 : flow;
}
