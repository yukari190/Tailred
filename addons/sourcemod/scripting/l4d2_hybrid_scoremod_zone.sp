#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <colors>

Handle hCvarBonusPerSurvivorMultiplier;
Handle hCvarPermanentHealthProportion;
Handle hCvarPillsHpFactor;
Handle hCvarPillsMaxBonus;
Handle hCvarValveSurvivalBonus;
Handle hCvarValveTieBreaker;
Handle fSetCampaignScores;

float fMapBonus;
float fMapHealthBonus;
float fMapDamageBonus;
float fMapTempHealthBonus;
float fPermHpWorth;
float fTempHpWorth;
float fSurvivorBonus[2];

int iMapDistance;
int iTeamSize;
int iPillWorth;
int iLostTempHealth[2];
int iTempHealth[MAXPLAYERS + 1];
int iSiDamage[2];
int survivorScore;
int infectedScore;

char sSurvivorState[2][32];

bool bRoundOver;
bool bTiebreakerEligibility[2];
bool inFirstReadyUpOfRound;

public Plugin myinfo =
{
	name = "L4D2 Scoremod+",
	author = "Visor",
	description = "The next generation scoring mod",
	version = "2.2.2",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
    CreateNative("SMPlus_GetHealthBonus", Native_GetHealthBonus);
    CreateNative("SMPlus_GetDamageBonus", Native_GetDamageBonus);
    CreateNative("SMPlus_GetPillsBonus", Native_GetPillsBonus);
    CreateNative("SMPlus_GetMaxHealthBonus", Native_GetMaxHealthBonus);
    CreateNative("SMPlus_GetMaxDamageBonus", Native_GetMaxDamageBonus);
    CreateNative("SMPlus_GetMaxPillsBonus", Native_GetMaxPillsBonus);
    RegPluginLibrary("l4d2_hybrid_scoremod");
    return APLRes_Success;
}

public void OnPluginStart()
{
	Handle gConf;
	gConf = LoadGameConfigFile("left4dhooks.l4d2");
	if (gConf == INVALID_HANDLE) LogError("Could not load gamedata/left4dhooks.l4d2.txt");
	StartPrepSDKCall(SDKCall_GameRules);
	if (!PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetCampaignScores")) LogError("Function 'SetCampaignScores' not found.");
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	fSetCampaignScores = EndPrepSDKCall();
	if (fSetCampaignScores == INVALID_HANDLE) LogError("Function 'SetCampaignScores' found, but something went wrong.");
	delete gConf;
	
	hCvarBonusPerSurvivorMultiplier = CreateConVar("sm2_bonus_per_survivor_multiplier", "0.5", "Total Survivor Bonus = this * Number of Survivors * Map Distance", FCVAR_SS_ADDED);
	hCvarPermanentHealthProportion = CreateConVar("sm2_permament_health_proportion", "0.75", "Permanent Health Bonus = this * Map Bonus; rest goes for Temporary Health Bonus", FCVAR_SS_ADDED);
	hCvarPillsHpFactor = CreateConVar("sm2_pills_hp_factor", "6.0", "Unused pills HP worth = map bonus HP value / this", FCVAR_SS_ADDED);
	hCvarPillsMaxBonus = CreateConVar("sm2_pills_max_bonus", "30", "Unused pills cannot be worth more than this", FCVAR_SS_ADDED);
	
	hCvarValveSurvivalBonus = FindConVar("vs_survival_bonus");
	hCvarValveTieBreaker = FindConVar("vs_tiebreak_bonus");

	HookConVarChange(hCvarBonusPerSurvivorMultiplier, CvarChanged);
	HookConVarChange(hCvarPermanentHealthProportion, CvarChanged);

	HookEvent("player_ledge_grab", OnPlayerLedgeGrab);
	HookEvent("player_incapacitated", OnPlayerIncapped);
	HookEvent("revive_success", OnPlayerRevived, EventHookMode_Post);

	RegConsoleCmd("sm_health", CmdBonus);
	RegConsoleCmd("sm_damage", CmdBonus);
	RegConsoleCmd("sm_bonus", CmdBonus);
	RegConsoleCmd("sm_mapinfo", CmdMapInfo);
	RegAdminCmd("sm_setscores", Command_SetScores, ADMFLAG_CHAT, "sm_setscores <survivor score> <infected score>");
}

public void OnPluginEnd()
{
	ResetConVar(hCvarValveSurvivalBonus);
	ResetConVar(hCvarValveTieBreaker);
}

public void OnConfigsExecuted()
{
	iTeamSize = GetConVarInt(FindConVar("survivor_limit"));
	SetConVarInt(hCvarValveTieBreaker, 0);

	iMapDistance = L4D2_GetMapValueInt("max_distance", L4D_GetVersusMaxCompletionScore());
	L4D_SetVersusMaxCompletionScore(iMapDistance);

	float fPermHealthProportion = GetConVarFloat(hCvarPermanentHealthProportion);
	float fTempHealthProportion = 1.0 - fPermHealthProportion;
	fMapBonus = iMapDistance * (GetConVarFloat(hCvarBonusPerSurvivorMultiplier) * iTeamSize);
	fMapHealthBonus = fMapBonus * fPermHealthProportion;
	fMapDamageBonus = fMapBonus * fTempHealthProportion;
	fMapTempHealthBonus = iTeamSize * 100/* HP */ / fPermHealthProportion * fTempHealthProportion;
	fPermHpWorth = fMapBonus / iTeamSize / 100 * fPermHealthProportion;
	fTempHpWorth = fMapBonus * fTempHealthProportion / fMapTempHealthBonus; // this should be almost equal to the perm hp worth, but for accuracy we'll keep it separate
	iPillWorth = CLAMP(RoundToNearest(50 * (fPermHpWorth / GetConVarFloat(hCvarPillsHpFactor)) / 5) * 5, 5, GetConVarInt(hCvarPillsMaxBonus)); // make it pretty
}

public void OnMapStart()
{
	OnConfigsExecuted();
	iLostTempHealth[0] = 0;
	iLostTempHealth[1] = 0;
	iSiDamage[0] = 0;
	iSiDamage[1] = 0;
	bTiebreakerEligibility[0] = false;
	bTiebreakerEligibility[1] = false;
	inFirstReadyUpOfRound = true;
}

public int CvarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	OnConfigsExecuted();
}

public void OnRoundIsLive()
{
	inFirstReadyUpOfRound = false;
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client)) return;
	
	if (nowteam == 2 && oldteam != 2)
	{
		SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
	else if (nowteam != 2 && oldteam == 2)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
		SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
	}
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 0; i < MAXPLAYERS; i++)
	{
		iTempHealth[i] = 0;
	}
	bRoundOver = false;
}

public int Native_GetHealthBonus(Handle plugin, int numParams)
{
    return RoundToFloor(GetSurvivorHealthBonus());
}
 
public int Native_GetMaxHealthBonus(Handle plugin, int numParams)
{
    return RoundToFloor(fMapHealthBonus);
}
 
public int Native_GetDamageBonus(Handle plugin, int numParams)
{
    return RoundToFloor(GetSurvivorDamageBonus());
}
 
public int Native_GetMaxDamageBonus(Handle plugin, int numParams)
{
    return RoundToFloor(fMapDamageBonus);
}
 
public int Native_GetPillsBonus(Handle plugin, int numParams)
{
    return RoundToFloor(GetSurvivorPillBonus());
}
 
public int Native_GetMaxPillsBonus(Handle plugin, int numParams)
{
    return iPillWorth * iTeamSize;
}

public Action CmdBonus(int client, int args)
{
	if (bRoundOver || !IsValidInGame(client)) return Plugin_Handled;
	char sCmdType[64];
	GetCmdArg(1, sCmdType, sizeof(sCmdType));
	float fHealthBonus = GetSurvivorHealthBonus();
	float fDamageBonus = GetSurvivorDamageBonus();
	float fPillsBonus = GetSurvivorPillBonus();
	float fMaxPillsBonus = float(iPillWorth * iTeamSize);
	if (StrEqual(sCmdType, "full"))
	{
		if (InSecondHalfOfRound()) CPrintToChat(client, "[{B}综合计分{W}]{W}R{O}#1{W} 分数: {G}%d{W}/{G}%d{W} <{O}%.1f%%{W}> [%s]", RoundToFloor(fSurvivorBonus[0]), RoundToFloor(fMapBonus + fMaxPillsBonus), CalculateBonusPercent(fSurvivorBonus[0]), sSurvivorState[0]);
		CPrintToChat(client, "[{B}综合计分{W}]{W}R{O}#%i{W} 分数: {G}%d{W} <{O}%.1f%%{W}> [健康分: {G}%d{W} <{O}%.1f%%{W}> | 伤害分: {G}%d{W} <{O}%.1f%%{W}> | 药分: {G}%d{W} <{O}%.1f%%{W}>]", InSecondHalfOfRound() + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, fMapHealthBonus + fMapDamageBonus + fMaxPillsBonus), RoundToFloor(fHealthBonus), CalculateBonusPercent(fHealthBonus, fMapHealthBonus), RoundToFloor(fDamageBonus), CalculateBonusPercent(fDamageBonus, fMapDamageBonus), RoundToFloor(fPillsBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
	}
	else if (StrEqual(sCmdType, "lite"))
	{
		CPrintToChat(client, "[{B}综合计分{W}]{W}R{O}#%i{W} 分数: {G}%d{W} <{O}%.1f%%{W}>", InSecondHalfOfRound() + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, fMapHealthBonus + fMapDamageBonus + fMaxPillsBonus));
	}
	else
	{
		if (InSecondHalfOfRound()) CPrintToChat(client, "[{B}综合计分{W}]{W}R{O}#1{W} 分数: {G}%d{W} <{O}%.1f%%{W}>", RoundToFloor(fSurvivorBonus[0]), CalculateBonusPercent(fSurvivorBonus[0]));
		CPrintToChat(client, "[{B}综合计分{W}]{W}R{O}#%i{W} 分数: {G}%d{W} <{O}%.1f%%{W}> [健康分: {O}%.0f%%{W} | 伤害分: {O}%.0f%%{W} | 药分: {O}%.0f%%{W}]", InSecondHalfOfRound() + 1, RoundToFloor(fHealthBonus + fDamageBonus + fPillsBonus), CalculateBonusPercent(fHealthBonus + fDamageBonus + fPillsBonus, fMapHealthBonus + fMapDamageBonus + fMaxPillsBonus), CalculateBonusPercent(fHealthBonus, fMapHealthBonus), CalculateBonusPercent(fDamageBonus, fMapDamageBonus), CalculateBonusPercent(fPillsBonus, fMaxPillsBonus));
	}
	return Plugin_Handled;
}

public Action CmdMapInfo(int client, int args)
{
	float fMaxPillsBonus = float(iPillWorth * iTeamSize);
	float fTotalBonus = fMapBonus + fMaxPillsBonus;
	CPrintToChat(client, "{W}[{O}综合计分{W} :: {O}%iv%i{W}] 地图信息", iTeamSize, iTeamSize);
	CPrintToChat(client, "{W}距离: {G}%d{W}", iMapDistance);
	CPrintToChat(client, "{W}总分: {G}%d{W} <{O}100.0%%{W}>", RoundToFloor(fTotalBonus));
	CPrintToChat(client, "{W}健康分: {G}%d{W} <{O}%.1f%%{W}>", RoundToFloor(fMapHealthBonus), CalculateBonusPercent(fMapHealthBonus, fTotalBonus));
	CPrintToChat(client, "{W}伤害分: {G}%d{W} <{O}%.1f%%{W}>", RoundToFloor(fMapDamageBonus), CalculateBonusPercent(fMapDamageBonus, fTotalBonus));
	CPrintToChat(client, "{W}药分: {G}%d{W}(max {G}%d{W}) <{O}%.1f%%{W}>", iPillWorth, RoundToFloor(fMaxPillsBonus), CalculateBonusPercent(fMaxPillsBonus, fTotalBonus));
	CPrintToChat(client, "{W}决胜局: {G}%d{W}", iPillWorth);
	return Plugin_Handled;
}

public Action Command_SetScores(int client, int args)
{
	if (!inFirstReadyUpOfRound)
	{
		ReplyToCommand(client, "分数只能在回合开始前的准备期间更改.");
		return Plugin_Handled;
	}
	if (args < 2)
	{
		ReplyToCommand(client, "用法: sm_setscores <生还者分数> <感染者分数>");
		return Plugin_Handled;
	}
	char buffer[32];
	GetCmdArg(1, buffer, sizeof(buffer));
	survivorScore = StringToInt(buffer);
	GetCmdArg(2, buffer, sizeof(buffer));
	infectedScore = StringToInt(buffer);
	int SurvivorTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped") ? 1 : 0;
	int InfectedTeamIndex = GameRules_GetProp("m_bAreTeamsFlipped") ? 0 : 1;
	SDKCall(fSetCampaignScores, survivorScore, infectedScore);
	L4D2Direct_SetVSCampaignScore(SurvivorTeamIndex, survivorScore);
	L4D2Direct_SetVSCampaignScore(InfectedTeamIndex, infectedScore);
	CPrintToChatAll("分数设置为 {G}%d {W} ({O}Sur{W}) - {G}%d {W} ({O}Inf{W}) by {LG}%N{W}.", survivorScore, infectedScore, client);
	return Plugin_Handled;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if (!IsValidSurvivor(victim) || IsPlayerIncap(victim)) return Plugin_Continue;
	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);
	if (!IsAnyInfected(attacker)) iSiDamage[InSecondHalfOfRound()] += (damage <= 100.0 ? RoundFloat(damage) : 100);
	return Plugin_Continue;
}

public Action OnPlayerLedgeGrab(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	iLostTempHealth[InSecondHalfOfRound()] += L4D2Direct_GetPreIncapHealthBuffer(client);
}

public Action OnPlayerIncapped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client))
	{
		iLostTempHealth[InSecondHalfOfRound()] += RoundToFloor((fMapDamageBonus / 100.0) * 5.0 / fTempHpWorth);
	} 
}

public Action OnPlayerRevived(Event event, const char[] name, bool dontBroadcast)
{
	bool bLedge = event.GetBool("ledge_hang");
	if (!bLedge) return;
	int client = GetClientOfUserId(event.GetInt("subject"));
	if (!IsValidSurvivor(client)) return;
	RequestFrame(Revival, client);
}

public void Revival(int client)
{
	iLostTempHealth[InSecondHalfOfRound()] -= GetSurvivorTemporaryHealth(client);
}

public void L4D2_OnPlayerHurtPost(int victim, int attacker, int currentPerm, char[] weaponName, int damage, int damagetype)
{
	int fFakeDamage = damage;
	if (!IsValidSurvivor(victim) || !IsValidSurvivor(attacker) || IsPlayerIncap(victim) || damagetype != DMG_PLASMA || fFakeDamage < GetSurvivorPermanentHealth(victim)) return;
	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim);
	if (fFakeDamage > iTempHealth[victim]) fFakeDamage = iTempHealth[victim];
	iLostTempHealth[InSecondHalfOfRound()] += fFakeDamage;
	iTempHealth[victim] = GetSurvivorTemporaryHealth(victim) - fFakeDamage;
}

public void OnTakeDamagePost(int victim, int attacker, int inflictor, float damage, int damagetype)
{
	if (!IsValidSurvivor(victim)) return;
	if (!IsPlayerAlive(victim) || (IsPlayerIncap(victim) && !IsHangingFromLedge(victim)))
	{
		iLostTempHealth[InSecondHalfOfRound()] += iTempHealth[victim];
	}
	else if (!IsHangingFromLedge(victim))
	{
		iLostTempHealth[InSecondHalfOfRound()] += iTempHealth[victim] ? (iTempHealth[victim] - GetSurvivorTemporaryHealth(victim)) : 0;
	}
	iTempHealth[victim] = IsPlayerIncap(victim) ? 0 : GetSurvivorTemporaryHealth(victim);
}

public void L4D2_ADM_OnTemporaryHealthSubtracted(int client, int oldHealth, int newHealth)
{
	int healthLost = oldHealth - newHealth;
	iTempHealth[client] = newHealth;
	iLostTempHealth[InSecondHalfOfRound()] += healthLost;
	iSiDamage[InSecondHalfOfRound()] += healthLost; // this forward doesn't fire for ledged/incapped survivors so we're good
}

public Action L4D2_OnEndVersusModeRound(bool countSurvivors)
{
	if (bRoundOver) return Plugin_Continue;
	int team = InSecondHalfOfRound();
	int iSurvivalMultiplier = GetUprightSurvivors();    // I don't know how reliable countSurvivors is and I'm too lazy to test
	fSurvivorBonus[team] = GetSurvivorHealthBonus() + GetSurvivorDamageBonus() + GetSurvivorPillBonus();
	fSurvivorBonus[team] = float(RoundToFloor(fSurvivorBonus[team] / float(iTeamSize)) * iTeamSize); // make it a perfect divisor of team size value
	if (iSurvivalMultiplier > 0 && RoundToFloor(fSurvivorBonus[team] / iSurvivalMultiplier) >= iTeamSize) // anything lower than team size will result in 0 after division
	{
		SetConVarInt(hCvarValveSurvivalBonus, RoundToFloor(fSurvivorBonus[team] / iSurvivalMultiplier));
		fSurvivorBonus[team] = float(GetConVarInt(hCvarValveSurvivalBonus) * iSurvivalMultiplier);    // workaround for the discrepancy caused by RoundToFloor()
		Format(sSurvivorState[team], 32, "%s%i{W}/{G}%i{W}", (iSurvivalMultiplier == iTeamSize ? "{G}" : "{O}"), iSurvivalMultiplier, iTeamSize);
	}
	else
	{
		fSurvivorBonus[team] = 0.0;
		SetConVarInt(hCvarValveSurvivalBonus, 0);
		Format(sSurvivorState[team], 32, "{O}%s{W}", (iSurvivalMultiplier == 0 ? "wiped out" : "bonus depleted"));
		bTiebreakerEligibility[team] = (iSurvivalMultiplier == iTeamSize);
	}
	if (team > 0 && bTiebreakerEligibility[0] && bTiebreakerEligibility[1])
	{
		GameRules_SetProp("m_iChapterDamage", iSiDamage[0], _, 0, true);
		GameRules_SetProp("m_iChapterDamage", iSiDamage[1], _, 1, true);
		if (iSiDamage[0] != iSiDamage[1]) SetConVarInt(hCvarValveTieBreaker, iPillWorth);
	}
	CreateTimer(3.0, PrintRoundEndStats, _, TIMER_FLAG_NO_MAPCHANGE);
	bRoundOver = true;
	return Plugin_Continue;
}

public Action PrintRoundEndStats(Handle timer) 
{
	for (int i = 0; i <= InSecondHalfOfRound(); i++)
	{
		CPrintToChatAll("[{B}综合计分{W}]{W}回合 {O}%i{W} 分数: {G}%d{W}/{G}%d{W} <{O}%.1f%%{W}> [%s]", (i + 1), RoundToFloor(fSurvivorBonus[i]), RoundToFloor(fMapBonus + float(iPillWorth * iTeamSize)), CalculateBonusPercent(fSurvivorBonus[i]), sSurvivorState[i]);
	}
	if (InSecondHalfOfRound() && bTiebreakerEligibility[0] && bTiebreakerEligibility[1])
	{
		CPrintToChatAll("[{B}综合计分{W}]{O}决胜局{W}: 团队 {O}%#1{W} - {G}%i{W}, 团队 {O}%#2{W} - {G}%i{W}", iSiDamage[0], iSiDamage[1]);
		if (iSiDamage[0] == iSiDamage[1]) CPrintToChatAll("[{B}综合计分{W}]{G}双方团队的表现持平! 无法决定明确的回合赢家");
	}
}

float GetSurvivorHealthBonus()
{
	float fHealthBonus;
	int survivalMultiplier;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			if (!IsPlayerIncap(index) && !IsHangingFromLedge(index))
			{
				survivalMultiplier++;
				fHealthBonus += GetSurvivorPermanentHealth(index) * fPermHpWorth;
			}
		}
	}
	return (fHealthBonus / iTeamSize * survivalMultiplier);
}

float GetSurvivorDamageBonus()
{
	int survivalMultiplier = GetUprightSurvivors();
	float fDamageBonus = (fMapTempHealthBonus - float(iLostTempHealth[InSecondHalfOfRound()])) * fTempHpWorth / iTeamSize * survivalMultiplier;
	return (fDamageBonus > 0.0 && survivalMultiplier > 0) ? fDamageBonus : 0.0;
}

float GetSurvivorPillBonus()
{			
	int pillsBonus;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			if (!IsPlayerIncap(index) && HasPills(index))
			{
				pillsBonus += iPillWorth;
			}
		}
	}
	return float(pillsBonus);
}

float CalculateBonusPercent(float score, float maxbonus = -1.0)
{
	return score / (maxbonus == -1.0 ? (fMapBonus + float(iPillWorth * iTeamSize)) : maxbonus) * 100;
}

/************/
/** Stocks **/
/************/

bool IsAnyInfected(int entity)
{
	if (entity > 0 && entity <= MaxClients)
	{
		return IsClientInGame(entity) && GetClientTeam(entity) == 3;
	}
	else if (entity > MaxClients)
	{
		char classname[64];
		GetEdictClassname(entity, classname, sizeof(classname));
		if (StrEqual(classname, "infected") || StrEqual(classname, "witch")) 
		{
			return true;
		}
	}
	return false;
}

int GetUprightSurvivors()
{
	int aliveCount;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			if (!IsPlayerIncap(index) && !IsHangingFromLedge(index)) aliveCount++;
		}
	}
	return aliveCount;
}

bool HasPills(int client)
{
	int item = GetPlayerWeaponSlot(client, 4);
	if (IsValidEdict(item))
	{
		char buffer[64];
		GetEdictClassname(item, buffer, sizeof(buffer));
		return StrEqual(buffer, "weapon_pain_pills");
	}
	return false;
}
