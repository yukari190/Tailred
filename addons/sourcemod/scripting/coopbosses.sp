#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <builtinvotes>
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
	description = "CanadaRox, Sir, devilesk, Derpduck",
	author = "Customisable tank and witch spawning in coop",
	version = "3.0",
	url = ""
};

ConVar
	hVsBossBuffer,
	hVsBossFlowMax,
	hVsBossFlowMin,
	hCvarTankCanSpawn,
	hCvarWitchCanSpawn,
	hCvarWitchAvoidTank,
	hTankDamage;
	
StringMap
	hStaticTankMaps,
	hStaticWitchMaps;

Handle sdkCallFling;

bool
	bTankSpawn,
	readyUpIsAvailable,
	readyFooterAdded,
	SurvivorNearTank[MAXPLAYERS + 1],
	bv_bTank,
	bv_bWitch,
	bIsFinale;

float 
	fTankFlow,
	throwForce[MAXPLAYERS + 1][3];

int 
	iTankPercent,
	bv_iTank,
	bv_iWitch;

char
	g_sCurrentMap[64];
	
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

bool RunVoteChecks(int client)
{
	if (IsDarkCarniRemix())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is not available on this map.");
		return false;
	}
	if (!IsInReady())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is only available during ready up.");
		return false;
	}
	if (InSecondHalfOfRound())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is only available during the first round of a map.");
		return false;
	}
	if (GetClientTeam(client) == 1)
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss voting is not available for spectators.");
		return false;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		CPrintToChat(client, "{blue}<{green}BossVote{blue}>{default} Boss Vote cannot be called right now...");
		return false;
	}
	return true;
}

public void OnPluginStart()
{
	SDKCallInit();
	
	hTankDamage = FindConVar("vs_tank_damage");
	hVsBossBuffer = FindConVar("versus_boss_buffer");
	hVsBossFlowMax = FindConVar("versus_boss_flow_max");
	hVsBossFlowMin = FindConVar("versus_boss_flow_min");
	
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
	RegConsoleCmd("sm_cu", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_cur", Cmd_BossPercent, "Boss产生的百分比");
	RegConsoleCmd("sm_current", Cmd_BossPercent, "Boss产生的百分比");
	
	RegConsoleCmd("sm_voteboss", VoteBossCmd); // Allows players to vote for custom boss spawns
	RegConsoleCmd("sm_bossvote", VoteBossCmd); // Allows players to vote for custom boss spawns
	
	FindConVar("director_no_bosses").SetBool(true);
	
	HookEvent("finale_start", FinaleStart_Event, EventHookMode_PostNoCopy);	
}

public void OnPluginEnd()
{
	FindConVar("director_no_bosses").RestoreDefault();
}

public void OnMapStart()
{
	bTankSpawn = false;
	fTankFlow = 0.0;
	iTankPercent = 0;
	GetCurrentMapLower(g_sCurrentMap, sizeof g_sCurrentMap);
}

public Action FinaleStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	bIsFinale = true;
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
	return Plugin_Handled;
}

public Action VoteBossCmd(int client, int args)
{
	if (!RunVoteChecks(client)) return;
	if (args != 2)
	{
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Usage: !voteboss {olive}<{default}tank{olive}> <{default}witch{olive}>{default}.");
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Use {default}\"{blue}0{default}\" for {olive}No Spawn{default}, \"{blue}-1{default}\" for {olive}Ignorance.");
		return;
	}
	
	// Get all non-spectating players
	int iNumPlayers;
	int[] iPlayers = new int[MaxClients];
	for (int i=1; i<=MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i) || (GetClientTeam(i) == 1))
		{
			continue;
		}
		iPlayers[iNumPlayers++] = i;
	}
	
	// Get Requested Boss Percents
	char bv_sTank[8];
	char bv_sWitch[8];
	GetCmdArg(1, bv_sTank, 8);
	GetCmdArg(2, bv_sWitch, 8);
	
	bv_iTank = -1;
	bv_iWitch = -1;
	
	// Make sure the args are actual numbers
	if (!IsInteger(bv_sTank) || !IsInteger(bv_sWitch))
	{
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Percentages are {olive}invalid{default}.");
		return;
	}
	
	// Check to make sure static bosses don't get changed
	if (!IsStaticTankMap(g_sCurrentMap))
	{
		bv_bTank = (bv_iTank = StringToInt(bv_sTank)) > 0;
	}
	else
	{
		bv_bTank = false;
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Tank spawn is static and can not be changed on this map.");
	}
	
	if (!IsStaticWitchMap(g_sCurrentMap))
	{
		bv_bWitch = (bv_iWitch = StringToInt(bv_sWitch)) > 0;
	}
	else
	{
		bv_bWitch = false;
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Witch spawn is static and can not be changed on this map.");
	}
	
	// Check if percent is within limits
	if (bv_bTank && !IsTankPercentValid(bv_iTank))
	{
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Tank percentage is {blue}banned{default}.");
		return;
	}
	
	if (bv_bWitch && !IsWitchPercentValid(bv_iWitch))
	{
		CReplyToCommand(client, "{blue}<{green}BossVote{blue}>{default} Witch percentage is {blue}banned{default}.");
		return;
	}
	
	char bv_voteTitle[64];
	
	// Set vote title
	if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
	{
		Format(bv_voteTitle, 64, "Set Tank to: %s and Witch to: %s?", bv_sTank, bv_sWitch);
	}
	else if (bv_bTank)	// Only Tank can be changed
	{
		if (bv_iWitch == 0)
		{
			Format(bv_voteTitle, 64, "Set Tank to: %s and Witch to: Disabled?", bv_sTank);
		}
		else
		{
			Format(bv_voteTitle, 64, "Set Tank to: %s?", bv_sTank);
		}
	}
	else if (bv_bWitch) // Only Witch can be changed
	{
		if (bv_iTank == 0)
		{
			Format(bv_voteTitle, 64, "Set Tank to: Disabled and Witch to: %s?", bv_sWitch);
		}
		else
		{
			Format(bv_voteTitle, 64, "Set Witch to: %s?", bv_sWitch);
		}
	}
	else // Neither can be changed... ok...
	{
		if (bv_iTank == 0 && bv_iWitch == 0)
		{
			Format(bv_voteTitle, 64, "Set Bosses to: Disabled?");
		}
		else if (bv_iTank == 0)
		{
			Format(bv_voteTitle, 64, "Set Tank to: Disabled?");
		}
		else if (bv_iWitch == 0)
		{
			Format(bv_voteTitle, 64, "Set Witch to: Disabled?");
		}
		else // Probably not.
		{
			return;
		}
	}
	
	// Start the vote!
	Handle bv_hVote = CreateBuiltinVote(BossVoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
	SetBuiltinVoteArgument(bv_hVote, bv_voteTitle);
	SetBuiltinVoteInitiator(bv_hVote, client);
	SetBuiltinVoteResultCallback(bv_hVote, BossVoteResultHandler);
	DisplayBuiltinVote(bv_hVote, iPlayers, iNumPlayers, 20);
	FakeClientCommand(client, "Vote Yes");
}

public void BossVoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, view_as<BuiltinVoteFailReason>(param1));
		}
	}
}

public void BossVoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i=0; i<num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
			
				// One last ready-up check.
				if (!IsInReady())  {
					DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
					CPrintToChatAll("{blue}<{green}BossVote{blue}>{default} Spawns can only be set during ready up.");
					return;
				}
				
				if (bv_bTank && bv_bWitch)	// Both Tank and Witch can be changed 
				{
					DisplayBuiltinVotePass(vote, "Setting Boss Spawns...");
				}
				else if (bv_bTank)	// Only Tank can be changed -- Witch must be static
				{
					DisplayBuiltinVotePass(vote, "Setting Tank Spawn...");
				}
				else if (bv_bWitch) // Only Witch can be changed -- Tank must be static
				{
					DisplayBuiltinVotePass(vote, "Setting Witch Spawn...");
				}
				else // Neither can be changed... ok...
				{
					DisplayBuiltinVotePass(vote, "Setting Boss Disabled...");
				}
				
				SetTankPercent(bv_iTank);
				SetWitchPercent(bv_iWitch);
				return;
			}
		}
	}
	
	// Vote Failed
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
	return;
}


public Action L4D_OnSpawnTank(const float vecPos[3], const float vecAng[3])
{
	return (IsExceptStatic() || bIsFinale || AllowTankSpawn()) && hCvarTankCanSpawn.BoolValue ? Plugin_Continue : Plugin_Handled;
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
		if (IsClientInGame(i))
		  PrintBossPercents(i);
	}
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!readyUpIsAvailable)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			  PrintBossPercents(i);
		}
	}
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SurvivorNearTank[i] = false;
		throwForce[i][0] = 0.0;
		throwForce[i][1] = 0.0;
		throwForce[i][2] = 0.0;
	}
	bIsFinale = false;
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
	
	if (InSecondHalfOfRound()) return;
	
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
}

public Action AddReadyFooter(Handle timer)
{
	if (readyFooterAdded) return Plugin_Continue;
	if (readyUpIsAvailable)
	{
		char readyString[68];
		if (GetTankToSpawn()) Format(readyString, sizeof(readyString), "Tank: %d%%", iTankPercent);
		else Format(readyString, sizeof(readyString), "Tank: None");

		AddStringToReadyFooter(readyString);
		readyFooterAdded = true;
	}
	return Plugin_Continue;
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (!IsValidSurvivor(victim) || !IsPlayerAlive(victim) || 
		!IsValidAndInGame(attacker) || !IsPlayerAlive(attacker) || GetInfectedClass(attacker) != L4D2Infected_Tank
	) return Plugin_Continue;
	char classname[64];
	if (attacker == inflictor) GetClientWeapon(inflictor, classname, sizeof(classname));
	else GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrContains(classname, "tank_claw", false) != -1)
	{
		for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
		{
			int index = L4D2_GetSurvivorOfIndex(i);
			if (index == 0 || !IsPlayerAlive(index) || index == victim || !SurvivorNearTank[index]) continue;
			
			if (!IsIncapacitated(index)) SetAnimFling(index, attacker, throwForce[index]);
			SDKHooks_TakeDamage(index, attacker, attacker, hTankDamage.FloatValue, DMG_GENERIC);
		}
	}
	return Plugin_Continue;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	CreateTimer(0.1, Tank_Distance, tankClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(5.0, ActiveTankTimer);
}

public Action Tank_Distance(Handle timer, any client)
{
	if (!IsValidClient(client) || !IsTank(client) || !IsPlayerAlive(client)) return Plugin_Stop;
	float survivorPos[3], tankPos[3];
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		GetClientAbsOrigin(client, tankPos);
		GetClientAbsOrigin(index, survivorPos);
		if (GetVectorDistance(survivorPos, tankPos) < 120)
		{
			NormalizeVector(survivorPos, survivorPos);
			NormalizeVector(tankPos, tankPos);
			throwForce[index][0] = GetClamp((360000.0 * (survivorPos[0] - tankPos[0])), -400.0, 400.0);
			throwForce[index][1] = GetClamp((90000.0 * (survivorPos[1] - tankPos[1])), -400.0, 400.0);
			throwForce[index][2] = 300.0;
			SurvivorNearTank[index] = true;
		}
		else
		{
			SurvivorNearTank[index] = false;
			throwForce[index][0] = 0.0;
			throwForce[index][1] = 0.0;
			throwForce[index][2] = 0.0;
		}
	}
	return Plugin_Continue;
}

public Action ActiveTankTimer(Handle timer)
{
	int iTank = FindAnyTank();
	int attacker = L4D2_GetRandomSurvivor();
	if (iTank == -1 || attacker == -1) return;
	
	for (int i = 0; i < 10; i++)
	{
		SDKHooks_TakeDamage(iTank, attacker, attacker, 1.0, DMG_BULLET);
		SetEntityHealth(iTank, GetClientHealth(iTank) + 1);

		//SendHurtMessage(iTank, attacker, "pistol", 1, DMG_BULLET);
		//SetEntityHealth(iTank, GetClientHealth(iTank) + 1);
		//PrintToChatAll("Tank 仇恨测试");
	}
}


void PrintBossPercents(int client)
{
	if (hCvarTankCanSpawn.BoolValue)
	{
		if (GetTankToSpawn()) CPrintToChat(client, "{R}Tank{W}:  [ {G}%d%%{W} ]", iTankPercent);
		else CPrintToChat(client, "{R}Tank{W}:  [ {G}--%%{W} ]");
	}
	
	int boss_proximity = GetHighestSurvivorFlow();
	CPrintToChat(client, "{W}当前: {O}%d%%", boss_proximity);
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
	iTankPercent = RoundToFloor(GetTankFlowPercent() * 100);
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

float GetBossProximity()
{
	float flow = -1.0;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0) {
		flow = (L4D2Direct_GetFlowDistance(client) + hVsBossBuffer.FloatValue) / L4D2Direct_GetMapMaxFlowDistance();
	}
	return ((flow > 0.0) ? flow : 0.0);
}

int GetHighestSurvivorFlow()
{
	return GetMin(RoundToNearest(100.0 * GetBossProximity()), 100);
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

void SetAnimFling(int client, int attacker, float vector[3])
{
	SDKCall(sdkCallFling, client, vector, 96, attacker, 3.0); //76 is the 'got bounced' animation in L4D2
}

void SDKCallInit()
{
	GameData ConfigFile = LoadGameConfigFile("left4dhooks.l4d2");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	if (sdkCallFling == null) LogError("Cant initialize Fling SDKCall");
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

bool IsDarkCarniRemix()
{
	if (StrEqual(g_sCurrentMap, "dkr_m1_motel", true) || StrEqual(g_sCurrentMap, "dkr_m2_carnival", true) || StrEqual(g_sCurrentMap, "dkr_m3_tunneloflove", true) || StrEqual(g_sCurrentMap, "dkr_m4_ferris", true) || StrEqual(g_sCurrentMap, "dkr_m5_stadium", true))
	{
		return true;
	}
	return false;
	
}

bool IsInteger(const char[] buffer)
{
	// negative check
	if ( !IsCharNumeric(buffer[0]) && buffer[0] != '-' )
		return false;
	
	int len = strlen(buffer);
	for (int i = 1; i < len; i++)
	{
		if ( !IsCharNumeric(buffer[i]) )
			return false;
	}

	return true;
}

bool IsTankPercentValid(int flow) {
	if (flow == 0) {
		return true;
	}
	int size = hValidTankFlows.Length;
	if (!size) {
		return false;
	}
	if (flow > hValidTankFlows.Get(size-1, 1)
		|| flow < hValidTankFlows.Get(0, 0)
	){ // out of bounds
		return false;
	}
	for (int i = 0; i < size; ++i) {
		if (flow <= hValidTankFlows.Get(i, 1)) {
			return flow >= hValidTankFlows.Get(i, 0);
		}
	}
	return false;
}

bool IsWitchPercentValid(int flow){
	if (flow == 0) {
		return true;
	}
	int size = hValidWitchFlows.Length;
	if (!size) {
		return false;
	}
	if (flow > hValidWitchFlows.Get(size-1, 1)
		|| flow < hValidWitchFlows.Get(0, 0)
	){ // out of bounds
		return false;
	}
	for (int i = 0; i < size; ++i) {
		if (flow <= hValidWitchFlows.Get(i, 1)) {
			return flow >= hValidWitchFlows.Get(i, 0);
		}
	}
	return false;
}

bool IsExceptStatic()
{
	if (
	StrEqual(g_sCurrentMap, "c7m1_docks") || 
	StrEqual(g_sCurrentMap, "c13m2_southpinestream") || 
	StrEqual(g_sCurrentMap, "c5m5_bridge") || 
	StrEqual(g_sCurrentMap, "c13m4_cutthroatcreek")
	)
	{
		return true;
	}
	return false;
	
}
