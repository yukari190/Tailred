#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>
#include <[TR]builtinvotes>
#undef REQUIRE_PLUGIN
#include <[TR]readyup>
//#include <pause>
//#include <l4d2_boss_percents>
//#include <l4d2_hybrid_scoremod>
//#include <l4d2_scoremod>
//#include <l4d2_health_temp_bonus>
//#include <l4d_tank_control_eq>
#define REQUIRE_PLUGIN

#define PLUGIN_VERSION	"3.4.5"

#define SPECHUD_DRAW_INTERVAL   1.0

public Plugin myinfo = 
{
	name = "Hyper-V HUD Manager",
	author = "Visor, Forgetest",
	description = "Provides different HUDs for spectators",
	version = PLUGIN_VERSION,
	url = "https://github.com/Target5150/MoYu_Server_Stupid_Plugins"
};

ConVar survivor_limit, z_max_player_zombies, versus_boss_buffer, sv_maxplayers, tank_burn_duration, pain_pills_decay_rate;
int iSurvivorLimit, iMaxPlayerZombies, iMaxPlayers;
float fVsBossBuffer, fTankBurnDuration, fPainPillsDecayRate;

ConVar cVarMinUpdateRate, cVarMaxUpdateRate, cVarMinInterpRatio, cVarMaxInterpRatio;
float fMinUpdateRate, fMaxUpdateRate, fMinInterpRatio, fMaxInterpRatio;

ConVar l4d2_allow_tank_spawn, hServerNamer, l4d_ready_cfg_name;

char sReadyCfgName[64], sHostname[64];
bool bPendingArrayRefresh, bRoundLive;
int iSurvivorArray[MAXPLAYERS+1];

StringMap hFirstTankSpawningScheme, hSecondTankSpawningScheme;		// eq_finale_tanks (Zonemod, Acemod, etc.)

int iTankCount;
bool bRoundHasFlowTank, bRoundHasFlowWitch, bFlowTankActive;

//bool bScoremod, bHybridScoremod, bNextScoremod;

bool bTankSelection;

bool bSpecHudActive[MAXPLAYERS+1], bTankHudActive[MAXPLAYERS+1];
bool bSpecHudHintShown[MAXPLAYERS+1], bTankHudHintShown[MAXPLAYERS+1];

native bool IsStaticTankMap();
native bool IsDarkCarniRemix();
native int GetTankSelection();

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("IsStaticTankMap");
	MarkNativeAsOptional("IsDarkCarniRemix");
	MarkNativeAsOptional("GetTankSelection");
	return APLRes_Success;
}

public void OnPluginStart()
{
	survivor_limit			= FindConVar("survivor_limit");
	z_max_player_zombies	= FindConVar("z_max_player_zombies");
	versus_boss_buffer		= FindConVar("versus_boss_buffer");
	sv_maxplayers			= FindConVar("sv_maxplayers");
	tank_burn_duration		= FindConVar("tank_burn_duration");
	pain_pills_decay_rate	= FindConVar("pain_pills_decay_rate");
	
	l4d2_allow_tank_spawn		= FindConVar("l4d2_allow_tank_spawn");
	l4d_ready_cfg_name		= FindConVar("l4d_ready_cfg_name");
	
	if ((hServerNamer = FindConVar("sn_main_name")) == null)
	{
		hServerNamer = FindConVar("hostname");
	}
	hServerNamer.GetString(sHostname, sizeof(sHostname));
	hServerNamer.AddChangeHook(OnHostnameChanged);
	
	l4d_ready_cfg_name.GetString(sReadyCfgName, sizeof(sReadyCfgName));
	
	cVarMinUpdateRate		= FindConVar("sv_minupdaterate");
	cVarMaxUpdateRate		= FindConVar("sv_maxupdaterate");
	cVarMinInterpRatio		= FindConVar("sv_client_min_interp_ratio");
	cVarMaxInterpRatio		= FindConVar("sv_client_max_interp_ratio");
	
	iSurvivorLimit		= survivor_limit.IntValue;
	iMaxPlayerZombies	= z_max_player_zombies.IntValue;
	fVsBossBuffer	= versus_boss_buffer.FloatValue;

	iMaxPlayers			= sv_maxplayers.IntValue;
	fTankBurnDuration	= tank_burn_duration.FloatValue;
	fPainPillsDecayRate	= pain_pills_decay_rate.FloatValue;
	
	survivor_limit.AddChangeHook(OnGameConVarChanged);
	z_max_player_zombies.AddChangeHook(OnGameConVarChanged);
	versus_boss_buffer.AddChangeHook(OnGameConVarChanged);
	sv_maxplayers.AddChangeHook(OnGameConVarChanged);
	
	fMinUpdateRate		= cVarMinUpdateRate.FloatValue;
	fMaxUpdateRate		= cVarMaxUpdateRate.FloatValue;
	fMinInterpRatio		= cVarMinInterpRatio.FloatValue;
	fMaxInterpRatio		= cVarMaxInterpRatio.FloatValue;
	
	cVarMinUpdateRate.AddChangeHook(OnNetworkConVarChanged);
	cVarMaxUpdateRate.AddChangeHook(OnNetworkConVarChanged);
	cVarMinInterpRatio.AddChangeHook(OnNetworkConVarChanged);
	cVarMaxInterpRatio.AddChangeHook(OnNetworkConVarChanged);
	
	hFirstTankSpawningScheme	= new StringMap();
	hSecondTankSpawningScheme	= new StringMap();
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	
	RegServerCmd("tank_map_flow_and_second_event",	SetMapFirstTankSpawningScheme);
	RegServerCmd("tank_map_only_first_event",		SetMapSecondTankSpawningScheme);
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		bSpecHudActive[i] = false;
		bSpecHudHintShown[i] = false;
		bTankHudActive[i] = true;
		bTankHudHintShown[i] = false;
	}
	
	CreateTimer(SPECHUD_DRAW_INTERVAL, HudDrawTimer, _, TIMER_REPEAT);
}

public void OnGameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSurvivorLimit		= survivor_limit.IntValue;
	iMaxPlayerZombies	= z_max_player_zombies.IntValue;
	fVsBossBuffer	= versus_boss_buffer.FloatValue;
	
	iMaxPlayers			= sv_maxplayers.IntValue;
	fTankBurnDuration	= tank_burn_duration.FloatValue;
	fPainPillsDecayRate	= pain_pills_decay_rate.FloatValue;
}

public void OnNetworkConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fMinUpdateRate	= cVarMinUpdateRate.FloatValue;
	fMaxUpdateRate	= cVarMaxUpdateRate.FloatValue;
	fMinInterpRatio	= cVarMinInterpRatio.FloatValue;
	fMaxInterpRatio	= cVarMaxInterpRatio.FloatValue;
}

public void OnHostnameChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	hServerNamer.GetString(sHostname, sizeof(sHostname));
}

public void OnAllPluginsLoaded()
{
	//bScoremod = LibraryExists("l4d2_scoremod");
	//bHybridScoremod = LibraryExists("l4d2_hybrid_scoremod") || LibraryExists("l4d2_hybrid_scoremod_zone");
	//bNextScoremod = LibraryExists("l4d2_health_temp_bonus");
	if ((hServerNamer = FindConVar("sn_main_name")) == null)
	{
		hServerNamer = FindConVar("hostname");
		hServerNamer.RemoveChangeHook(OnHostnameChanged);
		hServerNamer.GetString(sHostname, sizeof(sHostname));
		hServerNamer.AddChangeHook(OnHostnameChanged);
	}
	if (l4d_ready_cfg_name == null) l4d_ready_cfg_name = FindConVar("l4d_ready_cfg_name");
	
	bTankSelection = (GetFeatureStatus(FeatureType_Native, "GetTankSelection") != FeatureStatus_Unknown);
	
	if (LibraryExists("tank_spawner"))
	{
		if (!l4d2_allow_tank_spawn) l4d2_allow_tank_spawn = FindConVar("l4d2_allow_tank_spawn");
	}
}
public void OnLibraryAdded(const char[] name)
{
	//if (!strcmp(name, "l4d2_scoremod"))bScoremod = true;
	//if (!strcmp(name, "l4d2_hybrid_scoremod") || !strcmp(name, "l4d2_hybrid_scoremod_zone"))bHybridScoremod = true;
	//if (!strcmp(name, "l4d2_health_temp_bonus"))bNextScoremod = true;
	if (!strcmp(name, "tank_spawner"))
	{
		l4d2_allow_tank_spawn = FindConVar("l4d2_allow_tank_spawn");
	}
}
public void OnLibraryRemoved(const char[] name)
{
	//if (!strcmp(name, "l4d2_scoremod"))bScoremod = false;
	//if (!strcmp(name, "l4d2_hybrid_scoremod") || !strcmp(name, "l4d2_hybrid_scoremod_zone"))bHybridScoremod = false;
	//if (!strcmp(name, "l4d2_health_temp_bonus"))bNextScoremod = false;
	if (!strcmp(name, "tank_spawner"))
	{
		l4d2_allow_tank_spawn = null;
	}
}

public void OnClientDisconnect(int client)
{
	bSpecHudHintShown[client] = false;
	bTankHudHintShown[client] = false;
}

public void OnMapStart() { bRoundLive = false; }
public void L4D2_OnRealRoundEnd() { bRoundLive = false; }
public void OnRoundIsLive()
{
	l4d_ready_cfg_name.GetString(sReadyCfgName, sizeof(sReadyCfgName));
	
	bRoundLive = true;
	
	
	
	//for (int i = 1; i <= MaxClients; ++i) storedClass[i] = L4D2Infected_None;
	
	if (L4D2_IsVersus())
	{
		bRoundHasFlowTank = L4D2_GetTankToSpawn();
		bRoundHasFlowWitch = false;
		
		iTankCount = 0;
		
		if (GetConVarBool(l4d2_allow_tank_spawn))
		{
			iTankCount = 1;
			bFlowTankActive = bRoundHasFlowTank;
			
			static char mapname[64], dummy;
			GetCurrentMap(mapname, sizeof(mapname));
			
			if (strcmp(mapname, "hf03_themansion") == 0) iTankCount += 1;
			else if (!IsDarkCarniRemix() && L4D_IsMissionFinalMap())
			{
				iTankCount = 3
							- view_as<int>(hFirstTankSpawningScheme.GetValue(mapname, dummy))
							- view_as<int>(hSecondTankSpawningScheme.GetValue(mapname, dummy))
							- view_as<int>(IsStaticTankMap());
			}
		}
	}
}

//public void L4D2_OnEndVersusModeRound_Post() { if (!L4D2_IsSecondRound()) iFirstHalfScore = L4D_GetTeamScore(GetRealTeam(0) + 1); }

public void L4D2_OnTankDeath(int tankClient, int attacker)
{
	if (!L4D2_IsValidClient(tankClient)) return;
	
	if (iTankCount > 0) iTankCount--;
	if (!bRoundHasFlowTank) bFlowTankActive = false;
}

public Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (team == view_as<int>(L4D2Team_None))
	{
		bSpecHudActive[client] = false;
		bTankHudActive[client] = true;
	}
	
	if (team == view_as<int>(L4D2Team_Survivor) || oldteam == view_as<int>(L4D2Team_Survivor)) bPendingArrayRefresh = true;
}

public Action ToggleSpecHudCmd(int client, int args) 
{
	bSpecHudActive[client] = !bSpecHudActive[client];
	L4D2_CPrintToChat(client, "<{G}HUD{W}> 旁观面板 %s.", (bSpecHudActive[client] ? "{B}打开{W}" : "{R}关闭{W}"));
}

public Action ToggleTankHudCmd(int client, int args) 
{
	bTankHudActive[client] = !bTankHudActive[client];
	L4D2_CPrintToChat(client, "<{G}HUD{W}> Tank面板 %s.", (bTankHudActive[client] ? "{B}打开{W}" : "{R}关闭{W}"));
}

public Action HudDrawTimer(Handle hTimer)
{
	if (IsInReady()/* || IsInPause()*/)
		return Plugin_Continue;

	bool bSpecsOnServer = false;
	for (int i = 1; i <= MaxClients; ++i)
	{
		// 1. Debug active.
		// 2. Human spectator with spechud active. 
		// 3. SourceTV active.
		if(IsClientInGame(i) && (IsClientSourceTV(i) || (L4D2_IsSpectator(i) && bSpecHudActive[i])))
		{
			bSpecsOnServer = true;
			break;
		}
	}

	if (bSpecsOnServer) // Only bother if someone's watching us
	{
		Panel specHud = new Panel();

		FillHeaderInfo(specHud);
		FillSurvivorInfo(specHud);
		//FillScoreInfo(specHud);
		FillInfectedInfo(specHud);
		if (!FillTankInfo(specHud))
			FillGameInfo(specHud);

		for (int i = 1; i <= MaxClients; ++i)
		{
			// - Client is in game.
			//    1. Client is debug active.
			//    2. Client is non-bot and spectator with spechud active.
			//    3. Client is bot as SourceTV.
			if (!IsClientInGame(i) || (!L4D2_IsSpectator(i) || !bSpecHudActive[i] || (IsFakeClient(i) && !IsClientSourceTV(i))))
				continue;

			if (IsBuiltinVoteInProgress() && IsClientInBuiltinVotePool(i))
				continue;

			SendPanelToClient(specHud, i, DummySpecHudHandler, 3);
			if (!bSpecHudHintShown[i])
			{
				bSpecHudHintShown[i] = true;
				L4D2_CPrintToChat(i, "<{G}HUD{W}> 输入 {green}!spechud{W} 切换 {B}旁观面板{W} 状态.");
			}
		}
		delete specHud;
	}
	
	Panel tankHud = new Panel();
	if (FillTankInfo(tankHud, true)) // No tank -- no HUD
	{
		for (int i = 1; i <= MaxClients; ++i)
		{
			// Client is in game and non-bot
			//   1. Client is in infected team or spectator team with tankhud active, spechud inactive.
			if (!IsClientInGame(i) || IsFakeClient(i) || L4D2_IsSurvivor(i) || !bTankHudActive[i] || (bSpecHudActive[i] && L4D2_IsSpectator(i)))
				continue;
			
			if (IsBuiltinVoteInProgress() && IsClientInBuiltinVotePool(i))
				continue;
	
			SendPanelToClient(tankHud, i, DummyTankHudHandler, 3);
			if (!bTankHudHintShown[i])
			{
				bTankHudHintShown[i] = true;
				L4D2_CPrintToChat(i, "<{G}HUD{W}> 输入 {green}!tankhud{W} 切换 {R}Tank面板{W} 状态.");
			}
		}
	}
	
	delete tankHud;
	return Plugin_Continue;
}

public int DummySpecHudHandler(Menu hMenu, MenuAction action, int param1, int param2) {}
public int DummyTankHudHandler(Menu hMenu, MenuAction action, int param1, int param2) {}

void FillHeaderInfo(Panel hSpecHud)
{
	static char buf[64];
	Format(buf, sizeof(buf), "服务器: %s [人数 %i/%i | %iT]", sHostname, GetRealClientCount(), iMaxPlayers, RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buf);
}

void GetMeleePrefix(int client, char[] prefix, int length)
{
	int secondary = GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Secondary));
	WeaponId secondaryWep = L4D2_IdentifyWeapon(secondary);

	static char buf[4];
	switch (secondaryWep)
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (GetEntProp(secondary, Prop_Send, "m_isDualWielding") ? "DP" : "P");
		case WEPID_PISTOL_MAGNUM: buf = "DE";
		case WEPID_MELEE: buf = "M";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

void GetWeaponInfo(int client, char[] info, int length)
{
	static char buffer[32];
	
	int activeWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	int primaryWep = GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Primary));
	WeaponId activeWepId = L4D2_IdentifyWeapon(activeWep);
	WeaponId primaryWepId = L4D2_IdentifyWeapon(primaryWep);
	
	// Let's begin with what player is holding,
	// but cares only pistols if holding secondary.
	switch (activeWepId)
	{
		case WEPID_PISTOL, WEPID_PISTOL_MAGNUM:
		{
			if (activeWepId == WEPID_PISTOL && !!GetEntProp(activeWep, Prop_Send, "m_isDualWielding"))
			{
				// Dual Pistols Scene
				// Straight use the prefix since full name is a bit long.
				Format(buffer, sizeof(buffer), "DP");
			}
			else L4D2_GetLongWeaponName(activeWepId, buffer, sizeof(buffer));
			
			FormatEx(info, length, "%s %i", buffer, GetWeaponClip(activeWep));
		}
		default:
		{
			L4D2_GetLongWeaponName(primaryWepId, buffer, sizeof(buffer));
			FormatEx(info, length, "%s %i/%i", buffer, GetWeaponClip(primaryWep), GetWeaponAmmo(client, primaryWepId));
		}
	}
	
	// Format our result info
	if (primaryWep == -1)
	{
		// In case with no primary,
		// show the melee full name.
		if (activeWepId == WEPID_MELEE || activeWepId == WEPID_CHAINSAW)
		{
			MeleeWeaponId meleeWepId = L4D2_IdentifyMeleeWeapon(activeWep);
			L4D2_GetLongMeleeWeaponName(meleeWepId, info, length);
		}
	}
	else
	{
		// Default display -> [Primary <In Detail> | Secondary <Prefix>]
		// Holding melee included in this way
		// i.e. [Chrome 8/56 | M]
		if (L4D2_GetSlotFromWeaponId(activeWepId) != 1 || activeWepId == WEPID_MELEE || activeWepId == WEPID_CHAINSAW)
		{
			GetMeleePrefix(client, buffer, sizeof(buffer));
			Format(info, length, "%s | %s", info, buffer);
		}

		// Secondary active -> [Secondary <In Detail> | Primary <Ammo Sum>]
		// i.e. [Deagle 8 | Mac 700]
		else
		{
			L4D2_GetLongWeaponName(primaryWepId, buffer, sizeof(buffer));
			Format(info, length, "%s | %s %i", info, buffer, GetWeaponClip(primaryWep) + GetWeaponAmmo(client, primaryWepId));
		}
	}
}

void FillSurvivorInfo(Panel hSpecHud)
{
	static char info[100];
	static char name[MAX_NAME_LENGTH];

	int SurvivorTeamIndex = L4D2_AreTeamsFlipped();
	
	if (bRoundLive) {
		int distance = 0;
		for (int i = 0; i < 4; ++i) {
			distance += GameRules_GetProp("m_iVersusDistancePerSurvivor", _, i + 4 * SurvivorTeamIndex);
		}
		FormatEx(info, sizeof(info), "->1. 生还者 [%d]",
					L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex) + (bRoundLive ? distance : 0));
	} else {
		FormatEx(info, sizeof(info), "->1. 生还者 [%d]",
					L4D2Direct_GetVSCampaignScore(SurvivorTeamIndex));
	}
	
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);
	
	if (bPendingArrayRefresh)
	{
		bPendingArrayRefresh = false;
		PushSerialSurvivors();
	}
	
	for (int i = 0; i < iSurvivorLimit; ++i)
	{
		int client = iSurvivorArray[i];
		if (!client) continue;
		
		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			FormatEx(info, sizeof(info), "%s: 死亡", name);
		}
		else
		{
			if (L4D2_IsHangingFromLedge(client))
			{
				FormatEx(info, sizeof(info), "%s: <%iHP@Hanging>", name, GetClientHealth(client));
			}
			else if (L4D2_IsPlayerIncap(client))
			{
				int activeWep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
				L4D2_GetLongWeaponName(L4D2_IdentifyWeapon(activeWep), info, sizeof(info));
				Format(info, sizeof(info), "%s: <%iHP@%s> [%s %i]", name, GetClientHealth(client), (L4D2_GetSurvivorIncapCount(client) == 1 ? "2nd" : "1st"), info, GetWeaponClip(activeWep));
			}
			else
			{
				GetWeaponInfo(client, info, sizeof(info));
				
				int tempHealth = RoundToCeil(L4D2_GetSurvivorTemporaryHealth(client));
				int health = GetClientHealth(client) + tempHealth;
				int incapCount = L4D2_GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					//FormatEx(buffer, sizeof(buffer), "#%iT", tempHealth);
					Format(info, sizeof(info), "%s: %iHP%s [%s]", name, health, (tempHealth > 0 ? "#" : ""), info);
				}
				else
				{
					//FormatEx(buffer, sizeof(buffer), "%i incap%s", incapCount, (incapCount > 1 ? "s" : ""));
					Format(info, sizeof(info), "%s: %iHP (#%s) [%s]", name, health, (incapCount == 2 ? "2nd" : "1st"), info);
				}
			}
		}
		
		DrawPanelText(hSpecHud, info);
	}
}

/*void FillScoreInfo(Panel hSpecHud)
{
	static char info[64];

	if (bHybridScoremod)
	{
		int healthBonus	= SMPlus_GetHealthBonus(),	maxHealthBonus	= SMPlus_GetMaxHealthBonus();
		int damageBonus	= SMPlus_GetDamageBonus(),	maxDamageBonus	= SMPlus_GetMaxDamageBonus();
		int pillsBonus	= SMPlus_GetPillsBonus(),	maxPillsBonus	= SMPlus_GetMaxPillsBonus();
		
		int totalBonus		= healthBonus		+ damageBonus		+ pillsBonus;
		int maxTotalBonus	= maxHealthBonus	+ maxDamageBonus	+ maxPillsBonus;
		
		DrawPanelText(hSpecHud, " ");
		
		FormatEx(	info,
					sizeof(info),
					"> HB: %.0f%% | DB: %.0f%% | Pills: %i / %.0f%%",
					ToPercent(healthBonus, maxHealthBonus),
					ToPercent(damageBonus, maxDamageBonus),
					pillsBonus, ToPercent(pillsBonus, maxPillsBonus));
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Bonus: %i <%.1f%%>", totalBonus, ToPercent(totalBonus, maxTotalBonus));
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Distance: %i", L4D_GetVersusMaxCompletionScore() / 4 * iSurvivorLimit);
		//if (L4D2_IsSecondRound())
		//{
		//	Format(info, sizeof(info), "%s | R#1: %i <%.1f%%>", info, iFirstHalfScore, ToPercent(iFirstHalfScore, L4D_GetVersusMaxCompletionScore() + maxTotalBonus));
		//}
		DrawPanelText(hSpecHud, info);
	}
	else if (bScoremod)
	{
		int healthBonus = HealthBonus();
		
		DrawPanelText(hSpecHud, " ");
		
		FormatEx(info, sizeof(info), "> Health Bonus: %i", healthBonus);
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Distance: %i", L4D_GetVersusMaxCompletionScore() / 4 * iSurvivorLimit);
		//if (L4D2_IsSecondRound())
		//{
		//	Format(info, sizeof(info), "%s | R#1: %i", info, iFirstHalfScore);
		//}
		DrawPanelText(hSpecHud, info);
	}
	else if (bNextScoremod)
	{
		int permBonus	= SMNext_GetPermBonus(),	maxPermBonus	= SMNext_GetMaxPermBonus();
		int tempBonus	= SMNext_GetTempBonus(),	maxTempBonus	= SMNext_GetMaxTempBonus();
		int pillsBonus	= SMNext_GetPillsBonus(),	maxPillsBonus	= SMNext_GetMaxPillsBonus();
		
		int totalBonus		= permBonus		+ tempBonus		+ pillsBonus;
		int maxTotalBonus	= maxPermBonus	+ maxTempBonus	+ maxPillsBonus;
		
		DrawPanelText(hSpecHud, " ");
		
		FormatEx(	info,
					sizeof(info),
					"> Perm: %i | Temp: %i | Pills: %i",
					permBonus, tempBonus, pillsBonus);
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Bonus: %i <%.1f%%>", totalBonus, ToPercent(totalBonus, maxTotalBonus));
		DrawPanelText(hSpecHud, info);
		
		FormatEx(info, sizeof(info), "> Distance: %i", L4D_GetVersusMaxCompletionScore() / 4 * iSurvivorLimit);
		//if (L4D2_IsSecondRound())
		//{
		//	Format(info, sizeof(info), "%s | R#1: %i <%.1f%%>", info, iFirstHalfScore, ToPercent(iFirstHalfScore, L4D_GetVersusMaxCompletionScore() + maxTotalBonus));
		//}
		DrawPanelText(hSpecHud, info);
	}
}*/

void FillInfectedInfo(Panel hSpecHud)
{
	static char info[80];
	static char buffer[16];
	static char name[MAX_NAME_LENGTH];

	int InfectedTeamIndex = !L4D2_AreTeamsFlipped();
	
	FormatEx(info, sizeof(info), "->2. 感染者 [%d]", L4D2Direct_GetVSCampaignScore(InfectedTeamIndex));
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, info);

	int infectedCount;
	for (int client = 1; client <= MaxClients && infectedCount < iMaxPlayerZombies; ++client) 
	{
		if (!L4D2_IsInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			int timeLeft = RoundToFloor(L4D_GetPlayerSpawnTime(client));
			if (timeLeft < 0)
			{
				FormatEx(info, sizeof(info), "%s: 死亡", name);
			}
			else
			{
				FormatEx(buffer, sizeof(buffer), "%is", timeLeft);
				FormatEx(info, sizeof(info), "%s: 死亡 (%s)", name, (timeLeft ? buffer : "重生中..."));
			}
		}
		else
		{
			L4D2_Infected zClass = L4D2_GetInfectedClass(client);
			if (zClass == L4D2Infected_Tank)
				continue;
			
			char sNameBuffer[16];
			L4D2_GetInfectedClassName(zClass, sNameBuffer, sizeof(sNameBuffer));
			int iHP = GetClientHealth(client), iMaxHP = GetEntProp(client, Prop_Send, "m_iMaxHealth");
			if (L4D2_IsInfectedGhost(client))
			{
				// DONE: Handle a case of respawning chipped SI, show the ghost's health
				if (iHP < iMaxHP)
				{
					FormatEx(info, sizeof(info), "%s: %s (Ghost@%iHP)", name, sNameBuffer, iHP);
				}
				else
				{
					FormatEx(info, sizeof(info), "%s: %s (Ghost)", name, sNameBuffer);
				}
			}
			else
			{
				int iCooldown = RoundToNearest(L4D2_GetAbilityCooldown(client));
				if (iCooldown > 0)
				{
					if (L4D2_GetAbilityCooldownDuration(client) > 1.0
						&& !L4D2_GetInfectedVictim(client))
					{
						FormatEx(buffer, sizeof(buffer), " [%is]", info, iCooldown);
					}
				}
				else { buffer[0] = '\0'; }
				
				if (GetEntityFlags(client) & FL_ONFIRE)
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP) [On Fire]%s", name, sNameBuffer, iHP, buffer);
				}
				else
				{
					FormatEx(info, sizeof(info), "%s: %s (%iHP)%s", name, sNameBuffer, iHP, buffer);
				}
			}
		}

		infectedCount++;
		DrawPanelText(hSpecHud, info);
	}
	
	if (!infectedCount)
	{
		DrawPanelText(hSpecHud, "There are no SI at this moment.");
	}
}

bool FillTankInfo(Panel hSpecHud, bool bTankHUD = false)
{
	int tank = L4D2_FindAnyTank();
	if (tank == -1)
		return false;

	static char info[64];
	static char name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		FormatEx(info, sizeof(info), "%s :: Tank面板", sReadyCfgName);
		DrawPanelText(hSpecHud, info);
		
		int len = strlen(info);
		for (int i = 0; i < len; ++i) info[i] = '_';
		DrawPanelText(hSpecHud, info);
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Tank");
	}

	// Draw owner & pass counter
	int passCount = L4D2Direct_GetTankPassedCount();
	switch (passCount)
	{
		case 0: FormatEx(info, sizeof(info), "native");
		case 1: FormatEx(info, sizeof(info), "%ist", passCount);
		case 2: FormatEx(info, sizeof(info), "%ind", passCount);
		case 3: FormatEx(info, sizeof(info), "%ird", passCount);
		default: FormatEx(info, sizeof(info), "%ith", passCount);
	}

	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "控制: %s (%s)", name, info);
	}
	else
	{
		Format(info, sizeof(info), "控制: AI (%s)", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	int health = GetClientHealth(tank);
	int maxhealth = GetEntProp(tank, Prop_Send, "m_iMaxHealth");
	if (health <= 0 || L4D2_IsPlayerIncap(tank) || !IsPlayerAlive(tank))
	{
		info = "健康 : 死亡";
	}
	else
	{
		int healthPercent = RoundFloat((100.0 / maxhealth) * health);
		FormatEx(info, sizeof(info), "健康 : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "控制权. : %d%%", L4D2_GetTankFrustration(tank));
	}
	else
	{
		info = "控制权. : AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw network
	if (!IsFakeClient(tank))
	{
		FormatEx(info, sizeof(info), "网络: %ims / %.1f", RoundToNearest(GetClientAvgLatency(tank, NetFlow_Both) * 1000.0), GetLerpTime(tank) * 1000.0);
	}
	else
	{
		info = "网络: AI";
	}
	DrawPanelText(hSpecHud, info);

	// Draw fire status
	if (GetEntityFlags(tank) & FL_ONFIRE)
	{
		int timeleft = RoundToCeil(health / (maxhealth / fTankBurnDuration));
		FormatEx(info, sizeof(info), "On Fire : %is", timeleft);
		DrawPanelText(hSpecHud, info);
	}
	
	return true;
}

void FillGameInfo(Panel hSpecHud)
{
	// Turns out too much info actually CAN be bad, funny ikr
	static char info[64];
	static char buffer[8];

	if (L4D2_IsScavenge())
	{
		FormatEx(info, sizeof(info), "->3. %s", sReadyCfgName);
		
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, info);

		int round = L4D2_GetScavengeRoundNumber();
		switch (round)
		{
			case 0: Format(buffer, sizeof(buffer), "N/A");
			case 1: Format(buffer, sizeof(buffer), "%ist", round);
			case 2: Format(buffer, sizeof(buffer), "%ind", round);
			case 3: Format(buffer, sizeof(buffer), "%ird", round);
			default: Format(buffer, sizeof(buffer), "%ith", round);
		}

		FormatEx(info, sizeof(info), "半场: %s | 回合: %s", (L4D2_IsSecondRound() ? "2nd" : "1st"), buffer);
		DrawPanelText(hSpecHud, info);
	}
	else
	{
		FormatEx(info, sizeof(info), "->3. %s (R#%s)", sReadyCfgName, (L4D2_IsSecondRound() ? "2" : "1"));
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, info);

		int tankPercent = L4D2_GetTankFlowPercent();
		int survivorFlow = L4D2_GetHighestSurvivorFlow();
		if (survivorFlow == -1)
			survivorFlow = L4D2_GetFurthestSurvivorFlow2();
		
		bool bDivide = false;
				
		// tank percent
		if (iTankCount > 0)
		{
			bDivide = true;
			FormatEx(buffer, sizeof(buffer), "%i%%", tankPercent);
			
			if ((bFlowTankActive && bRoundHasFlowTank) || IsDarkCarniRemix())
			{
				FormatEx(info, sizeof(info), "Tank: %s", buffer);
			}
			else
			{
				FormatEx(info, sizeof(info), "Tank: %s", (IsStaticTankMap() ? "静态" : "事件"));
			}
		}
		
		// current
		if (bDivide) {
			Format(info, sizeof(info), "%s | 当前: %i%%", info, survivorFlow);
		} else {
			FormatEx(info, sizeof(info), "当前: %i%%", survivorFlow);
		}
		
		DrawPanelText(hSpecHud, info);
		
		// tank selection
		if (bTankSelection && iTankCount > 0)
		{
			int tankClient = GetTankSelection();
			if (tankClient > 0 && IsClientInGame(tankClient))
			{
				FormatEx(info, sizeof(info), "Tank -> %N", tankClient);
				DrawPanelText(hSpecHud, info);
			}
		}
	}
}

public Action SetMapFirstTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hFirstTankSpawningScheme, mapname, true);
}

public Action SetMapSecondTankSpawningScheme(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));
	SetTrieValue(hSecondTankSpawningScheme, mapname, true);
}

/**
 *	Stocks
**/

//int GetRealTeam(int team)
//{
//	return team ^ view_as<int>(!!L4D2_IsSecondRound() != L4D2_AreTeamsFlipped());
//}

/**
 *	Datamap m_iAmmo
 *	offset to add - gun(s) - control cvar
 *	
 *	+12: M4A1, AK74, Desert Rifle, also SG552 - ammo_assaultrifle_max
 *	+20: both SMGs, also the MP5 - ammo_smg_max
 *	+28: both Pump Shotguns - ammo_shotgun_max
 *	+32: both autoshotguns - ammo_autoshotgun_max
 *	+36: Hunting Rifle - ammo_huntingrifle_max
 *	+40: Military Sniper, AWP, Scout - ammo_sniperrifle_max
 *	+68: Grenade Launcher - ammo_grenadelauncher_max
 */

#define	ASSAULT_RIFLE_OFFSET_IAMMO		12;
#define	SMG_OFFSET_IAMMO				20;
#define	PUMPSHOTGUN_OFFSET_IAMMO		28;
#define	AUTO_SHOTGUN_OFFSET_IAMMO		32;
#define	HUNTING_RIFLE_OFFSET_IAMMO		36;
#define	MILITARY_SNIPER_OFFSET_IAMMO	40;
#define	GRENADE_LAUNCHER_OFFSET_IAMMO	68;

stock int GetWeaponAmmo(int client, WeaponId wepid)
{
	static int ammoOffset;
	if (!ammoOffset) ammoOffset = FindSendPropInfo("CCSPlayer", "m_iAmmo");
	
	int offset;
	switch (wepid)
	{
		case WEPID_RIFLE, WEPID_RIFLE_AK47, WEPID_RIFLE_DESERT, WEPID_RIFLE_SG552:
			offset = ASSAULT_RIFLE_OFFSET_IAMMO
		case WEPID_SMG, WEPID_SMG_SILENCED:
			offset = SMG_OFFSET_IAMMO
		case WEPID_PUMPSHOTGUN, WEPID_SHOTGUN_CHROME:
			offset = PUMPSHOTGUN_OFFSET_IAMMO
		case WEPID_AUTOSHOTGUN, WEPID_SHOTGUN_SPAS:
			offset = AUTO_SHOTGUN_OFFSET_IAMMO
		case WEPID_HUNTING_RIFLE:
			offset = HUNTING_RIFLE_OFFSET_IAMMO
		case WEPID_SNIPER_MILITARY, WEPID_SNIPER_AWP, WEPID_SNIPER_SCOUT:
			offset = MILITARY_SNIPER_OFFSET_IAMMO
		case WEPID_GRENADE_LAUNCHER:
			offset = GRENADE_LAUNCHER_OFFSET_IAMMO
		default:
			return -1;
	}
	return GetEntData(client, ammoOffset + offset);
} 

stock int GetWeaponClip(int weapon)
{
	return (weapon > 0 ? GetEntProp(weapon, Prop_Send, "m_iClip1") : -1);
}

void PushSerialSurvivors()
{
	int survivorCount = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		if (survivorCount < iSurvivorLimit)
		{
			iSurvivorArray[survivorCount++] = index;
		}
	}
	iSurvivorArray[survivorCount] = 0;
	
	SortCustom1D(iSurvivorArray, survivorCount, SortSurvArray);
}

public int SortSurvArray(int elem1, int elem2, const int[] array, Handle hndl)
{
	L4D2_SurvivorCharacter sc1 = GetFixedSurvivorCharacter(elem1);
	L4D2_SurvivorCharacter sc2 = GetFixedSurvivorCharacter(elem2);
	
	if (sc1 > sc2) { return 1; }
	else if (sc1 < sc2) { return -1; }
	else { return 0; }
}

L4D2_SurvivorCharacter GetFixedSurvivorCharacter(int client)
{
	int sc = GetEntProp(client, Prop_Send, "m_survivorCharacter");
	
	switch (sc)
	{
		case 6:						// Francis' netprop is 6
			return L4D2SurvivorCharacter_Francis;		// but here to match the official serial
			
		case 7:						// Louis' netprop is 7
			return L4D2SurvivorCharacter_Louis;		// but here to match the official serial
			
		case 9, 11:					// Bill's alternative netprop
			return L4D2SurvivorCharacter_Bill;			// match it correctly
	}
	return view_as<L4D2_SurvivorCharacter>(sc);
}

float GetLerpTime(int client)
{
	static char value[16];
	
	if (!GetClientInfo(client, "cl_updaterate", value, sizeof(value))) value = "";
	int updateRate = StringToInt(value);
	updateRate = RoundFloat(L4D2_Clamp(float(updateRate), fMinUpdateRate, fMaxUpdateRate));
	
	if (!GetClientInfo(client, "cl_interp_ratio", value, sizeof(value))) value = "";
	float flLerpRatio = StringToFloat(value);
	
	if (!GetClientInfo(client, "cl_interp", value, sizeof(value))) value = "";
	float flLerpAmount = StringToFloat(value);
	
	if (cVarMinInterpRatio != null && cVarMaxInterpRatio != null && fMinInterpRatio != -1.0 ) {
		flLerpRatio = L4D2_Clamp(flLerpRatio, fMinInterpRatio, fMaxInterpRatio );
	}
	
	return L4D2_Max(flLerpAmount, flLerpRatio / updateRate);
}

stock float ToPercent(int score, int maxbonus)
{
	return (score < 1 ? 0.0 : (100.0 * score / maxbonus));
}

void GetClientFixedName(int client, char[] name, int length)
{
	GetClientName(client, name, length);

	if (name[0] == '[')
	{
		char temp[MAX_NAME_LENGTH];
		strcopy(temp, sizeof(temp), name);
		temp[sizeof(temp)-2] = 0;
		strcopy(name[1], length-1, temp);
		name[0] = ' ';
	}

	if (strlen(name) > 18)
	{
		name[15] = name[16] = name[17] = '.';
		name[18] = 0;
	}
}

int GetRealClientCount() 
{
	int clients = 0;
	for (int i = 1; i <= MaxClients; ++i) 
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) clients++;
	}
	return clients;
}
