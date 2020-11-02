#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <l4d2_weapon_stocks>
#include <colors>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <pause>
#include <l4d2_hybrid_scoremod>
#define REQUIRE_PLUGIN

ConVar survivor_limit, z_max_player_zombies, l4d_ready_cfg_name;
bool bSpecHudActive[MAXPLAYERS+1], bSpecHudHintShown[MAXPLAYERS+1], bTankHudActive[MAXPLAYERS+1], bTankHudHintShown[MAXPLAYERS+1], 
  bIsInReady, g_bReadyUpAvailable, hybridScoringAvailable;
char sReadyName[64];
int iSurvivorLimit, iMaxPlayerZombies;

public Plugin myinfo = 
{
	name = "Hyper-V HUD Manager [Public Version]",
	author = "Visor/黑井白子/janus/cmmdwl",
	description = "更新版旁观面板",
	version = "2.9",
	url = "https://github.com/Attano/smplugins"
};

public APLRes AskPluginLoad2(Handle plugin, bool late, char[] error, int errMax)
{
	MarkNativeAsOptional("SMPlus_GetHealthBonus");
	MarkNativeAsOptional("SMPlus_GetDamageBonus");
	MarkNativeAsOptional("SMPlus_GetPillsBonus");
	MarkNativeAsOptional("SMPlus_GetMaxHealthBonus");
	MarkNativeAsOptional("SMPlus_GetMaxDamageBonus");
	MarkNativeAsOptional("SMPlus_GetMaxPillsBonus");
	return APLRes_Success;
}

public void OnPluginStart()
{
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	l4d_ready_cfg_name = FindConVar("l4d_ready_cfg_name");
	
	iSurvivorLimit = GetConVarInt(survivor_limit);
	iMaxPlayerZombies = GetConVarInt(z_max_player_zombies);
	GetConVarString(l4d_ready_cfg_name, sReadyName, sizeof(sReadyName));
	
	survivor_limit.AddChangeHook(ConVarChange);
	z_max_player_zombies.AddChangeHook(ConVarChange);
	l4d_ready_cfg_name.AddChangeHook(ConVarChange);
	
	RegConsoleCmd("sm_spechud", ToggleSpecHudCmd);
	RegConsoleCmd("sm_tankhud", ToggleTankHudCmd);
	
	CreateTimer(1.0, HudDrawTimer, _, TIMER_REPEAT);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iSurvivorLimit = survivor_limit.IntValue;
	iMaxPlayerZombies = z_max_player_zombies.IntValue;
	GetConVarString(l4d_ready_cfg_name, sReadyName, sizeof(sReadyName));
}

public void OnAllPluginsLoaded()
{
    g_bReadyUpAvailable = LibraryExists("readyup");
    hybridScoringAvailable = LibraryExists("l4d2_hybrid_scoremod");
}
public void OnLibraryRemoved(const char[] name)
{
    if (StrEqual(name, "readyup")) g_bReadyUpAvailable = false;
    if (StrEqual(name, "l4d2_hybrid_scoremod")) hybridScoringAvailable = false;
}
public void OnLibraryAdded(const char[] name)
{
    if (StrEqual(name, "readyup")) g_bReadyUpAvailable = true;
    if (StrEqual(name, "l4d2_hybrid_scoremod")) hybridScoringAvailable = true;
}

public void OnRoundIsLive()
{
    bIsInReady = false;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (!g_bReadyUpAvailable) bIsInReady = false;
	return Plugin_Continue;
}

public void L4D2_OnRealRoundStart()
{
	bIsInReady = true;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	bSpecHudActive[client] = false;
	bSpecHudHintShown[client] = false;
	bTankHudActive[client] = true;
	bTankHudHintShown[client] = false;
}

public Action ToggleSpecHudCmd(int client, int args) 
{
	bSpecHudActive[client] = !bSpecHudActive[client];
	CPrintToChat(client, "<{G}HUD{W}> 旁观者专业面板已经 %s.", (bSpecHudActive[client] ? "{B}开启{W}" : "{R}关闭{W}"));
}

public Action ToggleTankHudCmd(int client, int args) 
{
	bTankHudActive[client] = !bTankHudActive[client];
	CPrintToChat(client, "<{G}HUD{W}> 坦克面板已经 %s.", (bTankHudActive[client] ? "{B}开启{W}" : "{R}关闭{W}"));
}

public Action HudDrawTimer(Handle hTimer) 
{
	if (bIsInReady || IsInPause())
		return Plugin_Handled;
	
	bool bSpecsOnServer = false;
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidSpectator(i))
		{
			bSpecsOnServer = true;
			break;
		}
	}
	
	if (bSpecsOnServer) // Only bother if someone's watching us
	{
		Handle specHud = CreatePanel();

		FillHeaderInfo(specHud);
		FillSurvivorInfo(specHud);
		FillInfectedInfo(specHud);
		FillTankInfo(specHud);
		FillGameInfo(specHud);

		for (int i = 1; i <= MaxClients; i++) 
		{
			if (!bSpecHudActive[i] || !IsValidSpectator(i) || IsFakeClient(i))
				continue;

			SendPanelToClient(specHud, i, DummySpecHudHandler, 3);
			if (!bSpecHudHintShown[i])
			{
				bSpecHudHintShown[i] = true;
				CPrintToChat(i, "<{G}提示{W}> {O}输入!spechud{B} 开启/关闭旁观面板{W}.");
			}
		}

		CloseHandle(specHud);
	}
	
	Handle tankHud = CreatePanel();
	if (!FillTankInfo(tankHud, true)) // No tank -- no HUD
	{
		CloseHandle(tankHud);
		return Plugin_Handled;
	}
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (!bTankHudActive[i] || !IsClientInGame(i) || IsFakeClient(i) || IsValidSurvivor(i) || (bSpecHudActive[i] && IsValidSpectator(i)))
			continue;

		SendPanelToClient(tankHud, i, DummyTankHudHandler, 3);
		if (!bTankHudHintShown[i])
		{
			bTankHudHintShown[i] = true;
			CPrintToChat(i, "<{G}提示{W}> {O}!tankhud{B} 开启/关闭坦克面板{W}.");
		}
	}
	
	CloseHandle(tankHud);
	return Plugin_Continue;
}

public int DummySpecHudHandler(Handle hMenu, MenuAction action, int param1, int param2) {}
public int DummyTankHudHandler(Handle hMenu, MenuAction action, int param1, int param2) {}

void FillHeaderInfo(Handle hSpecHud) 
{
	DrawPanelText(hSpecHud, "Spectator HUD");

	char buffer[512];
	Format(buffer, sizeof(buffer), "Slots %i/%i | TickRate %i", GetRealClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), RoundToNearest(1.0 / GetTickInterval()));
	DrawPanelText(hSpecHud, buffer);
}

void GetMeleePrefix(int client, char[] prefix, int length) 
{
	int secondary = GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Secondary));
	WeaponId secondaryWep = IdentifyWeapon(secondary);

	char buf[16];
	switch (secondaryWep)
	{
		case WEPID_NONE: buf = "N";
		case WEPID_PISTOL: buf = (GetEntProp(secondary, Prop_Send, "m_isDualWielding") ? "手枪x2" : "手枪");
		case WEPID_MELEE: buf = "近战";
		case WEPID_PISTOL_MAGNUM: buf = "沙鹰";
		default: buf = "?";
	}

	strcopy(prefix, length, buf);
}

void FillSurvivorInfo(Handle hSpecHud) 
{
	char info[512];
	char buffer[64];
	char name[MAX_NAME_LENGTH];

	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, "->1. 生还者");

	int survivorCount;
	for (int client = 1; client <= MaxClients && survivorCount < iSurvivorLimit; client++) 
	{
		if (!IsValidSurvivor(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client))
		{
			Format(info, sizeof(info), "%s: 死了", name);
		}
		else
		{
			WeaponId primaryWep = IdentifyWeapon(GetPlayerWeaponSlot(client, view_as<int>(L4D2WeaponSlot_Primary)));
			GetLongWeaponName(primaryWep, info, sizeof(info));
			GetMeleePrefix(client, buffer, sizeof(buffer)); 
			Format(info, sizeof(info), "%s/%s", info, buffer);

			if (IsHangingFromLedge(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Hanging> [%s]", name, GetSurvivorPermanentHealth(client), info);
			}
			else if (IsPlayerIncap(client))
			{
				Format(info, sizeof(info), "%s: %iHP <Incapped(#%i)> [%s]", name, GetSurvivorPermanentHealth(client), (GetSurvivorIncapCount(client) + 1), info);
			}
			else
			{
				int health = GetSurvivorPermanentHealth(client) + GetSurvivorTemporaryHealth(client);
				int incapCount = GetSurvivorIncapCount(client);
				if (incapCount == 0)
				{
					Format(info, sizeof(info), "%s: %iHP [%s]", name, health, info);
				}
				else
				{
					Format(buffer, sizeof(buffer), "%i incap%s", incapCount, (incapCount > 1 ? "s" : ""));
					Format(info, sizeof(info), "%s: %iHP (%s) [%s]", name, health, buffer, info);
				}
			}
		}

		survivorCount++;
		DrawPanelText(hSpecHud, info);
	}
	
	if (hybridScoringAvailable)
	{
		int healthBonus = RoundToNearest(SMPlus_GetHealthBonus());
		int damageBonus = RoundToNearest(SMPlus_GetDamageBonus());
		int pillsBonus = RoundToNearest(SMPlus_GetPillsBonus());
		DrawPanelText(hSpecHud, " ");
		Format(info, sizeof(info), "HB: %i <%.1f%%>", healthBonus, ToPercent(healthBonus, RoundToNearest(SMPlus_GetMaxHealthBonus())));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), "DB: %i <%.1f%%>", damageBonus, ToPercent(damageBonus, RoundToNearest(SMPlus_GetMaxDamageBonus())));
		DrawPanelText(hSpecHud, info);
		Format(info, sizeof(info), "Pills: %i <%.1f%%>", pillsBonus, ToPercent(pillsBonus, RoundToNearest(SMPlus_GetMaxPillsBonus())));
		DrawPanelText(hSpecHud, info);
	}
}

void FillInfectedInfo(Handle hSpecHud) 
{
	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, "->2. 感染者");

	char info[512];
	char buffer[32];
	char name[MAX_NAME_LENGTH];

	int infectedCount;
	for (int client = 1; client <= MaxClients && infectedCount < iMaxPlayerZombies; client++) 
	{
		if (!IsValidInfected(client))
			continue;

		GetClientFixedName(client, name, sizeof(name));
		if (!IsPlayerAlive(client)) 
		{
			CountdownTimer spawnTimer = L4D2Direct_GetSpawnTimer(client);
			float timeLeft = -1.0;
			if (spawnTimer != CTimer_Null)
			{
				timeLeft = L4D2_CTimerGetRemainingTime(view_as<L4D2CountdownTimer>(spawnTimer));
			}

			if (timeLeft < 0.0)
			{
				Format(info, sizeof(info), "%s: 死了", name);
			}
			else
			{
				Format(buffer, sizeof(buffer), "%is", RoundToNearest(timeLeft));
				Format(info, sizeof(info), "%s: 死了 (%s)", name, (RoundToNearest(timeLeft) ? buffer : "等待刷新时间..."));
			}
		}
		else 
		{
			int zClass = GetInfectedClass(client);
			if (zClass == ZC_TANK)
				continue;

			if (IsInfectedGhost(client))
			{
				// TO-DO: Handle a case of respawning chipped SI, show the ghost's health
				Format(info, sizeof(info), "%s: %s (灵魂状态)", name, L4D2_InfectedNames[zClass]);
			}
			else if (GetEntityFlags(client) & FL_ONFIRE)
			{
				Format(info, sizeof(info), "%s: %s (%iHP) [On Fire]", name, L4D2_InfectedNames[zClass], GetClientHealth(client));
			}
			else
			{
				Format(info, sizeof(info), "%s: %s (%iHP)", name, L4D2_InfectedNames[zClass], GetClientHealth(client));
			}
		}

		infectedCount++;
		DrawPanelText(hSpecHud, info);
	}
	
	if (!infectedCount)
	{
		DrawPanelText(hSpecHud, "没有感染者.");
	}
}

bool FillTankInfo(Handle hSpecHud, bool bTankHUD = false)
{
	int tank = FindTank();
	if (tank == -1)
		return false;

	char info[512];
	char name[MAX_NAME_LENGTH];

	if (bTankHUD)
	{
		Format(info, sizeof(info), "%s :: Tank HUD", sReadyName);
		DrawPanelText(hSpecHud, info);
		DrawPanelText(hSpecHud, "——————————————————");
	}
	else
	{
		DrawPanelText(hSpecHud, " ");
		DrawPanelText(hSpecHud, "->3. Tank");
	}

	// Draw owner & pass counter
	if (!IsFakeClient(tank))
	{
		GetClientFixedName(tank, name, sizeof(name));
		Format(info, sizeof(info), "Tank : %s (%d%% %d控)", name, GetTankFrustration(tank),  L4D2Direct_GetTankPassedCount());
	}
	else
	{
		Format(info, sizeof(info), "Tank : AI", info);
	}
	DrawPanelText(hSpecHud, info);

	// Draw health
	int health = GetClientHealth(tank);
	if (health <= 0 || IsPlayerIncap(tank) || !IsPlayerAlive(tank))
	{
		info = "生命 : 死亡";
	}
	else
	{
		int healthPercent = RoundFloat((100.0 / (GetConVarFloat(FindConVar("z_tank_health")) * 1.5)) * health);
		Format(info, sizeof(info), "生命 : %i / %i%%", health, ((healthPercent < 1) ? 1 : healthPercent));
	}
	DrawPanelText(hSpecHud, info);

	// Draw frustration
	if (!IsFakeClient(tank))
	{
		Format(info, sizeof(info), "控制权 : %d%%", GetTankFrustration(tank));
	}
	else
	{
		info = "控制权 : 0%";
	}
	DrawPanelText(hSpecHud, info);

	return true;
}

void FillGameInfo(Handle hSpecHud)
{
	// Turns out too much info actually CAN be bad, funny ikr
	int tank = FindTank();
	if (tank != -1)
		return;

	DrawPanelText(hSpecHud, " ");
	DrawPanelText(hSpecHud, "->3. 游戏");

	char info[512];
	char buffer[512];
	
	if (Gamemode() == GAMEMODE_VERSUS)
	{
		Format(info, sizeof(info), "%s (回合%s)", sReadyName, (InSecondHalfOfRound() ? "2" : "1"));
		DrawPanelText(hSpecHud, info);

		//Format(info, sizeof(info), "尸潮: %is", CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(L4D2_CTimerGetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : 0);
		//DrawPanelText(hSpecHud, info);

		Format(info, sizeof(info), "幸存者进度: %i%%", RoundToNearest(GetHighestSurvivorFlow() * 100.0));
		DrawPanelText(hSpecHud, info);

		if (RoundHasFlowTank())
		{
			Format(info, sizeof(info), "Tank: %i%%", RoundToNearest(GetTankFlow(0) * 100.0));
			DrawPanelText(hSpecHud, info);
		}
		if (RoundHasFlowWitch())
		{
			Format(info, sizeof(info), "Witch: %i%%", RoundToNearest(GetWitchFlow(0) * 100.0));
			DrawPanelText(hSpecHud, info);
		}
	}
	else if (Gamemode() == GAMEMODE_SCAVENGE)
	{
		DrawPanelText(hSpecHud, info);

		int round = GetScavengeRoundNumber();
		switch (round)
		{
			case 0: Format(buffer, sizeof(buffer), "N/A");
			case 1: Format(buffer, sizeof(buffer), "%i", round);
			case 2: Format(buffer, sizeof(buffer), "%i", round);
			case 3: Format(buffer, sizeof(buffer), "%i", round);
			default: Format(buffer, sizeof(buffer), "%i", round);
		}

		Format(info, sizeof(info), "Half: %s", (InSecondHalfOfRound() ? "2nd" : "1st"));
		DrawPanelText(hSpecHud, info);

		Format(info, sizeof(info), "Round: %s", buffer);
		DrawPanelText(hSpecHud, info);
	}
}

/* Stocks */

float ToPercent(int score, int maxbonus)
{
	return ((score < 1) ? 0.0 : float(score) / float(maxbonus) * 100.0);
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

	if (strlen(name) > 25) 
	{
		name[22] = name[23] = name[24] = '.';
		name[25] = 0;
	}
}

int GetRealClientCount() 
{
	int clients = 0;
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i)) clients++;
	}
	return clients;
}

int GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

float GetClientFlow(int client)
{
	return (L4D2Direct_GetFlowDistance(client) / L4D2Direct_GetMapMaxFlowDistance());
}

float GetHighestSurvivorFlow()
{
	float flow;
	float maxflow = 0.0;
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsValidSurvivor(i))
		{
			flow = GetClientFlow(i);
			if (flow > maxflow)
			{
				maxflow = flow;
			}
		}
	}
	return maxflow;
}

bool RoundHasFlowTank()
{
	return L4D2Direct_GetVSTankToSpawnThisRound(InSecondHalfOfRound());
}

bool RoundHasFlowWitch()
{
	return L4D2Direct_GetVSWitchToSpawnThisRound(InSecondHalfOfRound());
}
