#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <colors>
#include <l4d2util>

public Plugin myinfo =
{
	name = "Tank Damage Announce L4D2",
	author = "Griffin and Blade",
	description = "Announce damage dealt to tanks by survivors",
	version = "0.6.7",
};

bool
	g_bAnnounceTankDamage,            // Whether or not tank damage should be announced
	g_bIsTankInPlay,            // Whether or not the tank is active
	bPrintedHealth;            // Is Remaining Health showed?

int
	g_iWasTank[MAXPLAYERS + 1]  = {0, ...},         // Was Player Tank before he died.
	g_iWasTankAI = 0,
	g_iTankClient = 0,                // Which client is currently playing as tank
	g_iLastTankHealth = 0,                // Used to award the killing blow the exact right amount of damage
	g_iSurvivorLimit = 4,                // For survivor array in damage print
	g_iDamage[MAXPLAYERS + 1];

float
	g_fMaxTankHealth = 6000.0;

ConVar
	g_hCvarEnabled = null,
	g_hCvarTankHealth = null,
	g_hCvarDifficulty = null,
	g_hCvarSurvivorLimit = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetTankDamageFromSurvivor", Native_GetTankDamageFromSurvivor);
	RegPluginLibrary("l4d_tank_damage_announce");
}

public any Native_GetTankDamageFromSurvivor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_iDamage[client];
}

public void OnPluginStart()
{
	HookEvent("tank_spawn", Event_TankSpawn);
	HookEvent("player_death", Event_PlayerKilled);
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_hurt", Event_PlayerHurt);
	
	g_hCvarEnabled = CreateConVar("l4d_tankdamage_enabled", "1", "Announce damage done to tanks when enabled", FCVAR_NONE|FCVAR_SPONLY|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_hCvarTankHealth = FindConVar("z_tank_health");
	g_hCvarDifficulty = FindConVar("z_difficulty");
	
	g_hCvarSurvivorLimit.AddChangeHook(Cvar_SurvivorLimit);
	g_hCvarTankHealth.AddChangeHook(Cvar_TankHealth);
	g_hCvarDifficulty.AddChangeHook(Cvar_TankHealth);
	FindConVar("mp_gamemode").AddChangeHook(Cvar_TankHealth);
	CalculateTankHealth();
}

public void OnClientDisconnect_Post(int client)
{
	if (!g_bIsTankInPlay || client != g_iTankClient) return;
	CreateTimer(0.1, Timer_CheckTank, client); // Use a delayed timer due to bugs where the tank passes to another player
}

public void Cvar_SurvivorLimit(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iSurvivorLimit = StringToInt(newValue);
}

public void Cvar_TankHealth(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CalculateTankHealth();
}

void CalculateTankHealth()
{
	char sGameMode[32];
	FindConVar("mp_gamemode").GetString(sGameMode, sizeof(sGameMode));

	g_fMaxTankHealth = g_hCvarTankHealth.FloatValue;
	if (g_fMaxTankHealth <= 0.0) g_fMaxTankHealth = 1.0;

	// Versus or Realism Versus
	if (StrEqual(sGameMode, "versus") || StrEqual(sGameMode, "mutation12"))
		g_fMaxTankHealth *= 1.5;

	// Anything else (should be fine...?)
	else 
	{
		g_fMaxTankHealth = g_hCvarTankHealth.FloatValue;

		char sDifficulty[16];
		g_hCvarDifficulty.GetString(sDifficulty, sizeof(sDifficulty));

		if (sDifficulty[0] == 'E') g_fMaxTankHealth *= 0.75;     // Easy
		else if (sDifficulty[0] == 'H'
		|| sDifficulty[0] == 'I') g_fMaxTankHealth *= 2.0; // Advanced or Expert
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay) return; // No tank in play; no damage to record
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim != GetTankClient() ||        // Victim isn't tank; no damage to record
	IsTankDying()                                   // Something buggy happens when tank is dying with regards to damage
	) return;
	
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	// We only care about damage dealt by survivors, though it can be funny to see
	// claw/self inflicted hittable damage, so maybe in the future we'll do that
	if (!IsValidSurvivor(attacker)) return;
	
	g_iDamage[attacker] += event.GetInt("dmg_health");
	g_iLastTankHealth = event.GetInt("health");
}

public void Event_PlayerKilled(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bIsTankInPlay) return; // No tank in play; no damage to record
	
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (victim != g_iTankClient) return;
	
	// Award the killing blow's damage to the attacker; we don't award
	// damage from player_hurt after the tank has died/is dying
	// If we don't do it this way, we get wonky/inaccurate damage values
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidAndInGame(attacker)) g_iDamage[attacker] += g_iLastTankHealth;
	
	//Player was Tank
	if(!IsFakeClient(victim)) g_iWasTank[victim] = 1;
	else g_iWasTankAI = 1;
	// Damage announce could probably happen right here...
	CreateTimer(0.1, Timer_CheckTank, victim); // Use a delayed timer due to bugs where the tank passes to another player
}

public void Event_TankSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iTankClient = client;
	
	if (g_bIsTankInPlay) return; // Tank passed
	
	// New tank, damage has not been announced
	g_bAnnounceTankDamage = true;
	g_bIsTankInPlay = true;
	// Set health for damage print in case it doesn't get set by player_hurt (aka no one shoots the tank)
	g_iLastTankHealth = GetClientHealth(client);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	bPrintedHealth = false;
	g_bIsTankInPlay = false;
	g_iTankClient = 0;
	ClearTankDamage(); // Probably redundant
}

// When survivors wipe or juke tank, announce damage
public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	// But only if a tank that hasn't been killed exists
	if (g_bAnnounceTankDamage)
	{
		PrintRemainingHealth();
		PrintTankDamage();
	}
	ClearTankDamage();
}

public Action Timer_CheckTank(Handle timer, any oldtankclient)
{
	if (g_iTankClient != oldtankclient) return Plugin_Stop; // Tank passed
	
	int tankclient = FindAliveTankClient();
	if (tankclient != -1 && tankclient != oldtankclient)
	{
		g_iTankClient = tankclient;
		
		return Plugin_Stop; // Found tank, done
	}
	
	if (g_bAnnounceTankDamage) PrintTankDamage();
	ClearTankDamage();
	g_bIsTankInPlay = false; // No tank in play
	
	return Plugin_Stop;
}

bool IsTankDying()
{
	int tankclient = GetTankClient();
	if (!tankclient) return false;
	
	return IsIncapacitated(tankclient);
}

void PrintRemainingHealth()
{
	bPrintedHealth = true;
	if (!g_hCvarEnabled.BoolValue) return;
	int tankclient = GetTankClient();
	if (!IsValidAndInGame(tankclient)) return;
	
	char name[MAX_NAME_LENGTH];
	if (IsFakeClient(tankclient)) name = "AI";
	else GetClientName(tankclient, name, sizeof(name));
	CPrintToChatAll("{default}[{green}!{default}] {blue}坦克 {default}({olive}%s{default}) 还剩 {green}%d {default}生命值", name, g_iLastTankHealth);
}

void PrintTankDamage()
{
	if (!g_hCvarEnabled.BoolValue) return;
	
	if (!bPrintedHealth)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if(g_iWasTank[i] > 0)
			{
				char name[MAX_NAME_LENGTH];
				GetClientName(i, name, sizeof(name));
				CPrintToChatAll("{default}[{green}!{default}] 对 {blue}坦克 {default}({olive}%s{default}) 造成的{blue}伤害", name);
				g_iWasTank[i] = 0;
			}
			else if(g_iWasTankAI > 0) 
				CPrintToChatAll("{default}[{green}!{default}] 对 {blue}坦克 {default}({olive}AI{default}) 造成的{blue}伤害");
			g_iWasTankAI = 0;
		}
	}
	
	int client, percent_total, damage_total, survivor_index = -1, percent_damage, damage;
	int[] survivor_clients = new int[g_iSurvivorLimit];
	for (client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !IsSurvivor(client) || g_iDamage[client] == 0) continue;
		survivor_index++;
		survivor_clients[survivor_index] = client;
		damage = g_iDamage[client];
		damage_total += damage;
		percent_damage = GetDamageAsPercent(damage);
		percent_total += percent_damage;
	}
	SortCustom1D(survivor_clients, g_iSurvivorLimit, SortByDamageDesc);
	
	int percent_adjustment;
	// Percents add up to less than 100% AND > 99.5% damage was dealt to tank
	if ((percent_total < 100 && float(damage_total) > (g_fMaxTankHealth - (g_fMaxTankHealth / 200.0))))
	{
		percent_adjustment = 100 - percent_total;
	}
	
	int last_percent = 100; // Used to store the last percent in iteration to make sure an adjusted percent doesn't exceed the previous percent
	int adjusted_percent_damage;
	for (int k; k <= survivor_index; k++)
	{
		client = survivor_clients[k];
		damage = g_iDamage[client];
		percent_damage = GetDamageAsPercent(damage);
		// Attempt to adjust the top damager's percent, defer adjustment to next player if it's an exact percent
		// e.g. 3000 damage on 6k health tank shouldn't be adjusted
		if (percent_adjustment != 0 && // Is there percent to adjust
		damage > 0 &&  // Is damage dealt > 0%
		!IsExactPercent(damage) // Percent representation is not exact, e.g. 3000 damage on 6k tank = 50%
		)
		{
			adjusted_percent_damage = percent_damage + percent_adjustment;
			if (adjusted_percent_damage <= last_percent) // Make sure adjusted percent is not higher than previous percent, order must be maintained
			{
				percent_damage = adjusted_percent_damage;
				percent_adjustment = 0;
			}
		}
		last_percent = percent_damage;
		for (int i = 1; i <= MaxClients; i++)
		{
    		if (IsClientInGame(i))
    		{
				CPrintToChat(i, "{blue}[{default}%d{blue}] ({default}%i%%{blue}) {olive}%N", damage, percent_damage, client);
			}
		}
	}
}

void ClearTankDamage()
{
	g_iLastTankHealth = 0;
	g_iWasTankAI = 0;
	for (int i = 1; i <= MaxClients; i++) 
	{ 
		g_iDamage[i] = 0; 
		g_iWasTank[i] = 0;
	}
	g_bAnnounceTankDamage = false;
}


int GetTankClient()
{
	if (!g_bIsTankInPlay) return 0;
	
	int tankclient = g_iTankClient;
	
	if (!IsValidAndInGame(tankclient)) // If tank somehow is no longer in the game (kicked, hence events didn't fire)
	{
		tankclient = FindAliveTankClient(); // find the tank client
		if (tankclient == -1) return 0;
		g_iTankClient = tankclient;
	}
	
	return tankclient;
}

int GetDamageAsPercent(int damage)
{
	return RoundToNearest((damage / g_fMaxTankHealth) * 100.0);
}

//comparing the type of int with the float, how different is it
bool IsExactPercent(int damage)
{
	float fDamageAsPercent = (damage / g_fMaxTankHealth) * 100.0;
	float fDifference = float(GetDamageAsPercent(damage)) - fDamageAsPercent;
	return (FloatAbs(fDifference) < 0.001) ? true : false;
}

public int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	// By damage, then by client index, descending
	if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
	else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}