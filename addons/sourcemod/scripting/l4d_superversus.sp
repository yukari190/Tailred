
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#pragma semicolon 1;                // Force strict semicolon mode.
#pragma newdecls required;			// Force new style syntax.

// *********************************************************************************
// CONSTANTS
// *********************************************************************************
#define PLUGIN_VERSION		"1.8.15.5"
#define CVAR_FLAGS			FCVAR_NOTIFY
#define TEAM_SPECTATOR	1
#define TEAM_SURVIVOR	2
#define TEAM_INFECTED	3

char gameMode[16];
char gameName[16];
bool L4D1;
bool InfectedAllowed;

ConVar SurvivorLimit;
ConVar InfectedLimit;

ConVar L4DInfectedLimit;
ConVar L4DSurvivorLimit;
ConVar AfkTimeout;
ConVar GhostDelayMax;

ConVar ExtraFirstAid;
ConVar KillRes;
ConVar RespawnJoin;
ConVar MoreSiBotsVersus;
ConVar AfkMode;
ConVar AutoJoin;
ConVar Management;

ConVar AutoDifficulty;
ConVar TankHpMulti;
ConVar SiHpMulti;
ConVar CiSpMulti;
ConVar SiSpMore;
ConVar SiSpMoreDelay;

Handle MedkitTimer    				= null;
Handle SubDirector					= null;
Handle BotsUpdateTimer    			= null;
Handle DifficultyTimer              = null;
Handle TeamPanelTimer[MAXPLAYERS+1];
Handle AfkTimer[MAXPLAYERS+1];

bool MedkitsGiven = false;
bool RoundStarted = false;

bool  CheckIdle[MAXPLAYERS+1];
int   iButtons[MAXPLAYERS+1];
float fEyeAngles[MAXPLAYERS+1][3];

float SiTimes[MAXPLAYERS+1] = 0.0;

int MaxSpecials = 2;

StringMap SteamIDs;

public Plugin myinfo =
{
	name        = "Super Versus Reloaded",
	author      = "DDRKhat, Marcus101RR, Merudo and Robotex",
	description = "Allows up to 32 players on Left 4 Dead.",
	version     = PLUGIN_VERSION,
	url         = "https://forums.alliedmods.net/showthread.php?p=2405322#post2405322"
}

// *********************************************************************************
// METHODS FOR GAME START & END
// *********************************************************************************
public void OnPluginStart()
{
	GetGameFolderName(gameName, sizeof(gameName));
	L4D1 = StrEqual(gameName, "left4dead", false);

	CreateConVar("sm_superversus_version", PLUGIN_VERSION, "L4D Super Versus", CVAR_FLAGS|FCVAR_DONTRECORD);
	
	L4DSurvivorLimit = FindConVar("survivor_limit");
	L4DInfectedLimit = FindConVar("z_max_player_zombies");
	SurvivorLimit = CreateConVar("l4d_survivor_limit", "4", "Maximum amount of survivors", CVAR_FLAGS,true, 1.00, true, 24.00);
	InfectedLimit = CreateConVar("l4d_infected_limit", "4", "Max amount of infected (will not affect bots)", CVAR_FLAGS, true, 4.00, true, 24.00);

	// Remove limits for survivor/infected
	SetConVarBounds(L4DSurvivorLimit, ConVarBound_Upper, true, 24.0);
	SetConVarBounds(L4DInfectedLimit, ConVarBound_Upper, true, 24.0);	
	HookConVarChange(InfectedLimit, OnInfectedChanged);	HookConVarChange(L4DInfectedLimit, OnInfectedChanged);
	HookConVarChange(SurvivorLimit, OnSurvivorChanged);	HookConVarChange(L4DSurvivorLimit, OnSurvivorChanged);			

	KillRes = CreateConVar("l4d_killreservation","1","我们是否应该清除大厅预订? (仅用于 Left4DownTown 扩展 )", CVAR_FLAGS,true,0.0,true,1.0);
	ExtraFirstAid = CreateConVar("l4d_extra_first_aid", "0" , "允许额外的玩家使用额外的急救箱 . 0: No extra kits. 1: one extra kit per player above four", CVAR_FLAGS, true, 0.0, true, 1.0);
	RespawnJoin = CreateConVar("l4d_respawn_on_join", "0" , "作为额外的幸存者加入时复活? 0: No, 1: Yes (first time only)", CVAR_FLAGS, true, 0.0, true, 1.0);
	MoreSiBotsVersus =  CreateConVar("l4d_versus_si_more", "0" , "如果在 vs/scavenge 中受感染的玩家少于 l4d_infected_limit, 则产生 SI 机器人 ?", CVAR_FLAGS, true, 0.0, true, 1.0);
	AfkMode =  CreateConVar("l4d_versus_afk", "0" , "If player is afk on versus, 0: Do nothing, 1: Become idle, 2: Become spectator, 3: Kicked", CVAR_FLAGS, true, 0.0, true, 3.0);
	AutoJoin = CreateConVar("l4d_autojoin", "0" , "Once a player connects, 4: Put in infected team, 3: Put in survivor team, 2: Put in random team, 1: Show teammenu, 0: Do nothing", CVAR_FLAGS, true, 0.0, true, 4.0);
	Management = CreateConVar("l4d_management", "0", "3: Enable teammenu & commands, 2: commands only, 1: !infected,!survivor,!join only, 0: Nothing", CVAR_FLAGS, true, 0.0, true, 4.0);
	
	AutoDifficulty = CreateConVar("director_auto_difficulty", "0", "改变难度", CVAR_FLAGS, true, 0.0, true, 1.0);
	TankHpMulti    = CreateConVar("director_tank_hpmulti","0.25","坦克 HP 倍增器 (multi*(survivors-4)). 需要 director_auto_difficulty 1", CVAR_FLAGS,true,0.00,true,1.00);
	SiHpMulti      = CreateConVar("director_si_hpmulti","0.00","SI HP 乘数 (multi*(survivors-4)). 需要 director_auto_difficulty 1", CVAR_FLAGS,true,0.00,true,1.00);
	CiSpMulti      = CreateConVar("director_ci_multi","0.25","Infected spawning rate Multiplier (multi*(survivors-4)). Requires director_auto_difficulty 1", CVAR_FLAGS,true,0.00,true,1.00);
	SiSpMore       = CreateConVar("director_si_more","1","In coop, spawn 1 more SI per extra player? Requires director_auto_difficulty 1", CVAR_FLAGS,true,0.0,true,1.0);
	SiSpMoreDelay  = CreateConVar("director_si_more_delay","5","Delay in seconds added to z_ghost_delay_max for SI bots spawning in versus", CVAR_FLAGS);
	
	AfkTimeout = FindConVar("director_afk_timeout");	
	GhostDelayMax = FindConVar("z_ghost_delay_max");
	
	RegConsoleCmd("sm_join", Join_Game, "Join Survivor or Infected team");	
	RegConsoleCmd("sm_survivor", Join_Survivor, "Join Survivor Team");	
	RegConsoleCmd("sm_infected", Join_Infected, "Join Infected Team");
	RegConsoleCmd("sm_spectate", Join_Spectator, "Join Spectator Team");
	RegConsoleCmd("sm_afk", GO_AFK, "Go Idle (Survivor) or Join Spectator Team (Infected)");	
	RegConsoleCmd("sm_teams", TeamMenu, "Opens Team Panel with Selection");
	RegConsoleCmd("sm_changeteam", TeamMenu, "Opens Team Panel with Selection");
	RegAdminCmd("sm_createplayer", Create_Player, ADMFLAG_CONVARS, "Create Survivor Bot");

	HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
	HookEvent("player_bot_replace", Event_BotReplacedPlayer);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);	
	HookEvent("player_left_start_area", Event_PlayerLeftStartArea, EventHookMode_Post);
	HookEvent("player_left_checkpoint", Event_PlayerLeftStartArea, EventHookMode_Post);
	HookEvent("player_afk", Event_PlayerWentAFK, EventHookMode_Pre);	
	
	HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_Pre);
	HookEvent("finale_vehicle_leaving", Event_FinaleVehicleLeaving);

	AddCommandListener(Cmd_spec_next, "spec_next");
	
	SteamIDs = new StringMap();

	AutoExecConfig(true, "l4d_superversus");	
}

public void OnInfectedChanged (Handle c, const char[] o, const char[] n)  {L4DInfectedLimit.IntValue = InfectedLimit.IntValue;}
public void OnSurvivorChanged (Handle c, const char[] o, const char[] n)  {L4DSurvivorLimit.IntValue = SurvivorLimit.IntValue;}

// ------------------------------------------------------------------------
// Return true if lobby unreserve is supported
// ------------------------------------------------------------------------
public void OnMapStart() 
{
	FindConVar("mp_gamemode").GetString(gameMode, sizeof(gameMode));
	InfectedAllowed = AreInfectedAllowed();
}

// ------------------------------------------------------------------------
// OnMapEnd()
// ------------------------------------------------------------------------
public void OnMapEnd()
{
	GameEnd();
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
	GameEnd();
}

// ------------------------------------------------------------------------
//  Clean up the timers at the game end
// ------------------------------------------------------------------------
void GameEnd()
{
	delete SubDirector;
	delete MedkitTimer;
	delete BotsUpdateTimer;
	delete DifficultyTimer;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		delete TeamPanelTimer[i];
		delete AfkTimer[i];
		TakeOver(i);
	}
	
	// Reset SteamIDs, so previous players who join next round can respawn alive
	SteamIDs.Clear();
	
	RoundStarted = false;
}

// ------------------------------------------------------------------------
// Event_RoundStart()
// ------------------------------------------------------------------------
public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast)
{
	MedkitsGiven = false;
	RoundStarted = true;
}

// ------------------------------------------------------------------------
//  MedKit timer. Used to spawn extra medkits in safehouse
// ------------------------------------------------------------------------
public Action Timer_SpawnExtraMedKit(Handle hTimer)
{
	MedkitTimer = null;

	int client = GetAnyAliveSurvivor();
	int amount = GetSurvivorTeam() - 4;
	
	if(amount > 0 && client > 0)
	{
		for(int i = 1; i <= amount; i++)
		{
			CheatCommand(client, "give", "first_aid_kit", "");
		}
	}
}

// ------------------------------------------------------------------------
// FinaleEnd() Thanks to Damizean for smarter method of detecting safe survivors.
// ------------------------------------------------------------------------
public void Event_FinaleVehicleLeaving(Handle event, const char[] name, bool dontBroadcast)
{
	int edict_index = FindEntityByClassname(-1, "info_survivor_position");
	if (edict_index != -1)
	{
		float pos[3];
		GetEntPropVector(edict_index, Prop_Send, "m_vecOrigin", pos);
		for(int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientConnected(i)) continue;
			if (!IsClientInGame(i)) continue;
			if (GetClientTeam(i) != TEAM_SURVIVOR) continue;
			if (!IsPlayerAlive(i)) continue;
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated", 1) == 1) continue;
			TeleportEntity(i, pos, NULL_VECTOR, NULL_VECTOR);
		}
	}
}

// *********************************************************************************
// METHODS RELATED TO PLAYER/BOT SPAWN AND KICK
// *********************************************************************************

// ------------------------------------------------------------------------
//  Each time a survivor spawns, setup timer to kick / spawn bots a bit later
// ------------------------------------------------------------------------
public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// Adds very brief invulnerability to spawned SI infected bots in versus/scavenge. Otherwise they keep respawning dead
	if (GetClientTeam(client) == TEAM_INFECTED && InfectedAllowed && MoreSiBotsVersus.BoolValue && IsFakeClient(client)) SetGodMode(client, 0.1);
	
	// Each time a new survivor spawns, check difficulty & record steam id (to prevent free respawning)
	if (GetClientTeam(client) == TEAM_SURVIVOR)
	{
		// Reset the bot check timer, if one exists	
		delete BotsUpdateTimer;
		BotsUpdateTimer = CreateTimer(2.0, Timer_BotsUpdate);
		
		if (!IsFakeClient(client) && !InfectedAllowed && IsFirstTime(client))
			RecordSteamID(client); // Record SteamID of player.
			
		SetGhostStatus(client, false); // Prevents invinsible & invisible survivor bug
	}
	
	//  If Si bot spawns, remove oldest Si in queue
	if (IsFakeClient(client) && GetClientTeam(client) == TEAM_INFECTED)
	{
		int OldestSi = GetOldestSi();
		if (OldestSi != -1) SiTimes[OldestSi] == 0.0;
	}
}

// ------------------------------------------------------------------------
// If player disconnect, set timer to spawn/kick bots as needed
// ------------------------------------------------------------------------
public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client)) return;

	delete AfkTimer[client];				//	Clean up Afk timer
	delete TeamPanelTimer[client];			//	Clean up Panel timer
	CheckIdle[client] = false;				//  Turn off idle check

	if(RoundStarted)			// if not bot or during transition
	{
		// Reset the timer, if one exists
		delete BotsUpdateTimer;
		BotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);	// re-update the bots
	}
}

// ------------------------------------------------------------------------
// Bots are kicked/spawned after every survivor spawned and every player joined
// ------------------------------------------------------------------------
public Action Timer_BotsUpdate(Handle hTimer)
{
	BotsUpdateTimer = null;

	if (AreAllInGame() == true) 
	{
		// Update the bots
		SpawnCheck();
		
		// Give medkit (start of round)
		if(MedkitTimer == null && !MedkitsGiven && ExtraFirstAid.BoolValue)
		{
			MedkitsGiven = true;
			MedkitTimer = CreateTimer(2.0, Timer_SpawnExtraMedKit);
		}
		
		// Update the difficulty
		delete DifficultyTimer;
		if(AutoDifficulty.BoolValue) DifficultyTimer = CreateTimer(5.0, Timer_Difficulty);
	}
	else
	{
		BotsUpdateTimer = CreateTimer(1.0, Timer_BotsUpdate);  // if not everyone joined, delay update
	}
}

// ------------------------------------------------------------------------
// Check the # of survivors, and kick/spawn bots as needed
// ------------------------------------------------------------------------
void SpawnCheck()
{
	if(RoundStarted != true)  return;      // if during transition, don't do anything
	
	int iSurvivor       = GetSurvivorTeam();
	int iHumanSurvivor  = InfectedAllowed ? GetTeamPlayers(TEAM_SURVIVOR, false) : GetClientCount();  // survivors excluding bots but including idles. If coop, counts spectators too (may be idles)
	int iSurvivorLim    = SurvivorLimit.IntValue;
	int iSurvivorMax    = iHumanSurvivor  >  iSurvivorLim ? iHumanSurvivor  : iSurvivorLim ;
	
	// iSurvivorMax is the maximum # of survivor we allow - we never kick human survivors
	
	if (iSurvivor > iSurvivorMax) PrintToConsoleAll("[SV] Kicking %d bot(s)", iSurvivor - iSurvivorMax);
	if (iSurvivor < iSurvivorLim) PrintToConsoleAll("[SV] Spawning %d bot(s)", iSurvivorLim - iSurvivor);

	for(; iSurvivorMax < iSurvivor; iSurvivorMax++)
	{
		KickUnusedSurvivorBot();
	}
	
	for(; iSurvivor < iSurvivorLim; iSurvivor++)
	{
		SpawnFakeSurvivorClient();  // This triggers Event_PlayerSpawn and create new timer, be careful about infinite loops
	}
}

// ------------------------------------------------------------------------
// Kick an unused survivor bot
// ------------------------------------------------------------------------
void KickUnusedSurvivorBot()
{
	int Bot = GetAnyValidSurvivorBot();
	if(Bot > 0 && IsBotValid(Bot))
		KickClient(Bot, "Kicking Useless Client.");
}

// ------------------------------------------------------------------------
// Spawn a survivor bot
// ------------------------------------------------------------------------
void SpawnFakeSurvivorClient()
{
	// Spawn bot survivor.
	int Bot = CreateFakeClient("SurvivorBot");
	if(Bot == 0)
		return;

	ChangeClientTeam(Bot, TEAM_SURVIVOR);
	if(DispatchKeyValue(Bot, "classname", "SurvivorBot") == false)
	{
		return;
	}
	DispatchSpawn(Bot);
	if(DispatchSpawn(Bot) == false)
	{
		return;
	}

	// Kick the "SurvivorBot" so it becomes a regular bot
	if(IsClientInGame(Bot) && IsFakeClient(Bot) && !GetIdlePlayer(Bot))
		KickClient(Bot, "Kicking Fake Client.");
}


// ------------------------------------------------------------------------
// If lobby full, unreserve it. Autojoin survivors if coop & spectator
// ------------------------------------------------------------------------
public void OnClientPostAdminCheck(int client)
{
	// If lobby is full, KillRes is true and l4dt is present, unreserve lobby
	if(KillRes.BoolValue && IsServerLobbyFull())
	{
		L4D_LobbyUnreserve();
	}
	
	if (IsFakeClient(client)) return;
	
	if (GetClientTeam(client) <= TEAM_SPECTATOR) // non-bot spectator or not in a team
	{
		CreateTimer(5.0, Timer_AutoJoinTeam, GetClientUserId(client));  //  Autojoin
	}
	delete AfkTimer[client];
}

// ------------------------------------------------------------------------
// If connect as spectator, either auto-join survivor or show team menu
// ------------------------------------------------------------------------
public Action Timer_AutoJoinTeam(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	// If joined the game already or not valid, don't do anything
	if (!client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) > TEAM_SPECTATOR || GetBotOfIdle(client)) return;
	
	if (BotsUpdateTimer != null || !RoundStarted || !AreAllInGame() || GetClientTeam(client) == 0)
	{
		CreateTimer(1.0, Timer_AutoJoinTeam, GetClientUserId(client)); // if during transition, delay autojoin
	}
	else
	{
		if (!InfectedAllowed && AutoJoin.BoolValue) FakeClientCommand(client, "sm_join");  // Autojoin survivors
		else if (AutoJoin.IntValue == 4) FakeClientCommand(client, "sm_infected"); // Autojoin infected
		else if (AutoJoin.IntValue == 3) FakeClientCommand(client, "sm_survivor"); // Autojoin survivors
		else if (AutoJoin.IntValue == 2) FakeClientCommand(client, "sm_join"); // Autojoin random team
		else if (AutoJoin.IntValue == 1) FakeClientCommand(client, "sm_teams"); // Show team selection menu
	}
}

// *********************************************************************************
// IDLE FIX
// *********************************************************************************

// ------------------------------------------------------------------------
// If player goes AFK, activate idle bug check
// ------------------------------------------------------------------------
public Action Event_PlayerWentAFK(Handle event, const char[] name, bool dontBroadcast)
{
	// Event is triggered when a player goes AFK
	int client = GetClientOfUserId(GetEventInt(event, "player"));
	CheckIdle[client] = true;
}

// ------------------------------------------------------------------------
// When survivor bot replace player AND player went afk, trigger fix
// ------------------------------------------------------------------------
public Action Event_BotReplacedPlayer(Handle event, const char[] name, bool dontBroadcast)
{
	// Event is triggered when a bot takes over a player
	int player = GetClientOfUserId(GetEventInt(event, "player"));
	int bot    = GetClientOfUserId(GetEventInt(event, "bot"));
	
	if (IsFakeClient(player)) return; 		// if "player" is a bot, don't do anything (side effect of creating new bots)

	// Create a datapack as we are moving 2+ pieces of data through a timer
	if(player > 0 && IsClientInGame(player) && GetClientTeam(bot)==TEAM_SURVIVOR) 
	{
		Handle datapack = CreateDataPack();
		WritePackCell(datapack, player);
		WritePackCell(datapack, bot);
		CreateTimer(0.2, Timer_ActivateFix, datapack, TIMER_FLAG_NO_MAPCHANGE);
	}
}

// ------------------------------------------------------------------------
// Fix the idle bug by setting pseudo idle mode
// ------------------------------------------------------------------------
public Action Timer_ActivateFix(Handle Timer, any datapack)
{
	// Reset the data pack
	ResetPack(datapack);

	// Retrieve values from datapack
	int player = ReadPackCell(datapack);
	int bot = ReadPackCell(datapack);

	// If  player left game, is not spectator, or is correctly idle, skip the fix
	// If  bot is occupied (should not happen unless something happened in .2 sec) , try to get another
	
	if (!IsClientInGame(player) || GetClientTeam(player) != TEAM_SPECTATOR || GetBotOfIdle(player) ||  IsFakeClient(player)) CheckIdle[player] = false;	
	if (!IsBotValid(bot) || GetClientTeam(bot) != TEAM_SURVIVOR) bot = GetAnyValidSurvivorBot(); if (bot < 1) CheckIdle[player] = false; 

	// If the player went AFK and failed, continue on
	if(CheckIdle[player])
	{
		CheckIdle[player] = false;
		SetHumanIdle(bot, player);
	}
}

// ------------------------------------------------------------------------
// When player dies, forces takeover of the bot
// ------------------------------------------------------------------------
public Action Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	// Event is triggered when a player dies
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	TakeOver(client);
}

void TakeOver(int bot)
{
	if(bot > 0 && IsClientInGame(bot) &&  IsFakeClient(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && GetIdlePlayer(bot))
	{
		int idleplayer = GetIdlePlayer(bot);
		SetHumanIdle(bot, idleplayer);
		TakeOverBot(idleplayer);		
	}
}

// ------------------------------------------------------------------------
// Store vision angle & button, if changed reset afk timer
// ------------------------------------------------------------------------
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
	if (IsFakeClient(client)) return;

	if (InfectedAllowed && AfkMode.BoolValue && GetClientTeam(client) > TEAM_SPECTATOR && IsPlayerAlive(client) && RoundStarted)
	{	
		if ( (iButtons[client] != buttons) ||  (FloatAbs(angles[0] - fEyeAngles[client][0]) > 2.0) || (FloatAbs(angles[1] - fEyeAngles[client][1]) > 2.0) || (FloatAbs(angles[2] - fEyeAngles[client][2]) > 2.0) ) 
		{
			delete AfkTimer[client];  // Reset timer
		}
		if (AfkTimer[client] == null) AfkTimer[client] = CreateTimer( AfkTimeout.FloatValue, Timer_AFK, client); 
		
		iButtons[client]   = buttons;
		fEyeAngles[client] = angles; 
	} else delete AfkTimer[client];
}

// ------------------------------------------------------------------------
// Reset timer if client say something in chat
// ------------------------------------------------------------------------
public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) // Player Chat
{
	if (!client || IsFakeClient(client)) return;
	
	delete AfkTimer[client];	
	
	if (InfectedAllowed && AfkMode.BoolValue && GetClientTeam(client) > TEAM_SPECTATOR && IsPlayerAlive(client) && RoundStarted)
	{
		AfkTimer[client] = CreateTimer( AfkTimeout.FloatValue, Timer_AFK, client);
	}
}

// ------------------------------------------------------------------------
// If afk timer ran out, deal with afk client
// ------------------------------------------------------------------------
public Action Timer_AFK(Handle Timer, int client)
{
	AfkTimer[client] = null;

	if (IsClientInGame(client) && InfectedAllowed && AfkMode.BoolValue && GetClientTeam(client) > TEAM_SPECTATOR && IsPlayerAlive(client) && RoundStarted)
	{
		if ( GetTeamPlayers(GetClientTeam(client), false) > 0) // if more than 1 human player on the team
		{
			if (AfkMode.IntValue == 1) FakeClientCommand(client, "sm_afk");
			if (AfkMode.IntValue == 2) FakeClientCommand(client, "sm_spectate");
			if (AfkMode.IntValue == 3) KickClient(client, "Afk");
		}
	}
}

// *********************************************************************************
// COMMANDS FOR JOINING TEAMS
// *********************************************************************************

// ------------------------------------------------------------------------
// If press left mouse button as spectator, show menu to join game. Useful in case of idle bug
// ------------------------------------------------------------------------
public Action Cmd_spec_next(int client, char[] command, int argc)
{
	if (IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR && !GetBotOfIdle(client))
	{
		FakeClientCommand(client, "sm_teams");
	}
	return Plugin_Continue;	
}

// ------------------------------------------------------------------------
// Join survivor or infected
// ------------------------------------------------------------------------
public Action Join_Game(int client, int args)
{
	if (!Management.BoolValue) return Plugin_Continue;

	if (!InfectedAllowed || GetBotOfIdle(client) || GetClientTeam(client) == TEAM_SURVIVOR) FakeClientCommand(client,"sm_survivor"); 
	else if (GetClientTeam(client) == TEAM_INFECTED) FakeClientCommand(client,"sm_infected");
	else if (InfectedLimit.IntValue <= GetTeamPlayers(TEAM_INFECTED, false) && SurvivorLimit.IntValue <= GetTeamPlayers(TEAM_SURVIVOR, false))
	{
		PrintToChat(client, "Both teams are full.");
	}
	else if (InfectedLimit.IntValue <= GetTeamPlayers(TEAM_INFECTED, false)) FakeClientCommand(client,"sm_survivor");
	else if (SurvivorLimit.IntValue <= GetTeamPlayers(TEAM_SURVIVOR, false)) FakeClientCommand(client,"sm_infected");
	else if (GetTeamPlayers(TEAM_INFECTED, false) > GetTeamPlayers(TEAM_SURVIVOR, false) ) FakeClientCommand(client,"sm_survivor");
	else if (GetTeamPlayers(TEAM_INFECTED, false) < GetTeamPlayers(TEAM_SURVIVOR, false) ) FakeClientCommand(client,"sm_infected");
	else if (GetRandomInt(0, 1)) FakeClientCommand(client,"sm_survivor");
	else FakeClientCommand(client,"sm_infected");
	return Plugin_Handled;
}

public Action Join_Spectator(int client, int args)
{
	if (Management.IntValue < 2) return Plugin_Continue;

	ChangeClientTeam(client,TEAM_SPECTATOR);
	return Plugin_Handled;
}

public Action Join_Survivor(int client, int args)
{
	if (!Management.BoolValue) return Plugin_Continue;

	if(!IsClientInGame(client)) return Plugin_Handled;
	
	if(GetClientTeam(client) != TEAM_SURVIVOR && !GetBotOfIdle(client))
	{
		if(CountAvailableBots(TEAM_SURVIVOR) == 0 && !InfectedAllowed)
		{
			bool canRespawn = (RespawnJoin.BoolValue && IsFirstTime(client)) ;
			
			ChangeClientTeam(client, TEAM_SURVIVOR);  // Add extra survivor. Triggers player_spawn, which makes IsFirstTime false
			
			if (!IsPlayerAlive(client) && !GetBotOfIdle(client) && canRespawn)
			{
				Respawn(client);
				TeleportToSurvivor(client);
				SetGodMode(client, 1.0); // 1 sec of god mode after spawning
				
				GiveAverageWeapon(client);				
				if(ExtraFirstAid.BoolValue && MedkitsGiven && MedkitTimer == null) // if medkits already given				
					CheatCommand(client, "give", "first_aid_kit", "");
			} else if (!IsPlayerAlive(client) && !GetBotOfIdle(client) && RespawnJoin.BoolValue)
			{
				PrintToChat(client, "\x03[Yandere!] \x01You already played on the \x04Survivor Team\x01 this round. You will spawn dead.");
			}
		}
		else
		{
			FakeClientCommand(client,"jointeam 2");
		}
	}
	
	if(GetBotOfIdle(client))  TakeOver(GetBotOfIdle(client));
	
	if(GetClientTeam(client) == TEAM_SURVIVOR)
	{		
		if(IsPlayerAlive(client) == true)
		{
			PrintToChat(client, "\x03[Yandere!] \x01You are on the \x04Survivor Team\x01.");
		}
		else if(IsPlayerAlive(client) == false && CountAvailableBots(TEAM_SURVIVOR) != 0)  // Takeover a bot
		{
			ChangeClientTeam(client, TEAM_SPECTATOR);
			FakeClientCommand(client,"jointeam 2");
		}
		else if(IsPlayerAlive(client) == false && CountAvailableBots(TEAM_SURVIVOR) == 0)
		{
			PrintToChat(client, "\x03[Yandere!] \x01You are \x04Dead\x01. No \x05Bot(s) \x01Available.");
		}
	}
	return Plugin_Handled;
}

public Action Join_Infected(int client, int args)
{	
	if (!Management.BoolValue) return Plugin_Continue;

	if (GetClientTeam(client) == TEAM_INFECTED) 
	{
		PrintToChat(client, "\x03[Yandere!] \x01You are on the \x05Infected Team\x01.");
	}
	else if(!InfectedAllowed)
	{
		PrintToChat(client, "\x03[Yandere!] \x01[\x04ERROR\x01] The \x05Infected Team\x01 is not available in %s.", gameMode);
	}
	else if(InfectedLimit.IntValue <= GetTeamPlayers(TEAM_INFECTED, false))
	{
		PrintToChat(client, "\x03[Yandere!] \x01[\x04ERROR\x01] The \x05Infected Team\x01 is Full.");
	}
	else
	{
		ChangeClientTeam(client, TEAM_INFECTED);
	}
	return Plugin_Handled;
}

public Action GO_AFK(int client, int args)
{
	if (Management.IntValue < 2) return Plugin_Continue;

	if (GetClientTeam(client) == TEAM_SURVIVOR)  // Infected can't go idle, they spectate instead
	{
		CheckIdle[client] = true; // Check for fix
		FakeClientCommand(client, "go_away_from_keyboard");	
	}
	if (GetClientTeam(client) != TEAM_SPECTATOR) FakeClientCommand(client, "sm_spectate");
	return Plugin_Handled;
}

// ------------------------------------------------------------------------
// Create a bot. Useful if less bots than SurvivorLimit because the later got increased
// ------------------------------------------------------------------------
public Action Create_Player(int client, int args)
{
	if (Management.IntValue < 2) return Plugin_Continue;

	char arg[MAX_NAME_LENGTH];
	if (args > 0)
	{
		GetCmdArg(1, arg, sizeof(arg));	
		PrintToChatAll("\x03[Yandere!] \x01Player %s has joined the game", arg);	
		CreateFakeClient(arg);
	}
	else
	{
		int Bot = CreateFakeClient("SurvivorBot");
		if(Bot == 0)
			return Plugin_Handled;

		ChangeClientTeam(Bot, TEAM_SURVIVOR);
		if (!DispatchKeyValue(Bot, "classname", "survivorbot"))
			return Plugin_Handled;
			
		if (!DispatchSpawn(Bot))
			return Plugin_Handled; // if dispatch failed		

		if(!IsPlayerAlive(Bot))
			Respawn(Bot);

		TeleportToSurvivor(Bot);
		GiveAverageWeapon(Bot);
		
		if(ExtraFirstAid.BoolValue)				
			CheatCommand(Bot, "give", "first_aid_kit", "");
					
		if(IsClientInGame(Bot) && IsFakeClient(Bot) && !GetIdlePlayer(Bot))
			KickClient(Bot, "Kicking Fake Client.");

	}
	return Plugin_Handled;
}

public Action TeamMenu(int client, int args)
{
	if (Management.IntValue < 3) return Plugin_Continue;

	if(TeamPanelTimer[client] == null)
	{
		DisplayTeamMenu(client);
	}
	return Plugin_Handled;
}

// *********************************************************************************
// RETURN PROPERTIES OF INFECTED/SURVIVOR TEAMS, BOTS, & PLAYERS
// *********************************************************************************

char survivor_only_modes[23][] =
{
	"coop", "realism", "survival",
	"m60s", "hardcore", "l4d1coop",
	"mutation1",	"mutation2",	"mutation3",	"mutation4",
	"mutation5",	"mutation6",	"mutation7",	"mutation8",
	"mutation9",	"mutation10",	"mutation16",	"mutation17", "mutation20",
	"community1",	"community2",	"community4",	"community5"
};

// ------------------------------------------------------------------------
// Returns true if players in team infected are allowed
// ------------------------------------------------------------------------
bool AreInfectedAllowed()
{	
	for (int i = 0; i < sizeof(survivor_only_modes); i++)
	{
		if (StrEqual(gameMode, survivor_only_modes[i], false))
		{
			return false;
		}
	}
	return true;   // includes versus, realism versus, scavenge, & some mutations
}

// ------------------------------------------------------------------------
// Returns true if all connected players are in the game
// ------------------------------------------------------------------------
bool AreAllInGame()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
		{
			if (!IsClientInGame(i)) return false;
		}
	}
	return true;
}

// ------------------------------------------------------------------------
// Returns true if lobby full. Used to unreserve the lobby
// ------------------------------------------------------------------------
#define L4D_MAXHUMANS_LOBBY_VERSUS 8
#define L4D_MAXHUMANS_LOBBY_OTHER 4

bool IsServerLobbyFull()
{
	int humans = GetClientCount();

	if (humans >= L4D_MAXHUMANS_LOBBY_VERSUS) return true;
	if( !InfectedAllowed && humans >= L4D_MAXHUMANS_LOBBY_OTHER) return true;
	return false;
}

// ------------------------------------------------------------------------
// Returns true if client never spawned as survivor this game. Used to allow 1 free spawn
// ------------------------------------------------------------------------
bool IsFirstTime(int client)
{
	if(!IsClientInGame(client) || IsFakeClient(client)) return false;
	
	char SteamID[64];
	bool valid = GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));		
	
	if (valid == false) return false;

	bool Allowed;
	if (!SteamIDs.GetValue(SteamID, Allowed))  // If can't find the entry in map
	{
		SteamIDs.SetValue(SteamID, true, true);
		Allowed = true;
	}
	return Allowed;
}

// ------------------------------------------------------------------------
// Stores the Steam ID, so if reconnect we don't allow free respawn
// ------------------------------------------------------------------------
void RecordSteamID(int client)
{
	// Stores the Steam ID, so if reconnect we don't allow free respawn
	char SteamID[64];
	bool valid = GetClientAuthId(client, AuthId_Steam2, SteamID, sizeof(SteamID));
	if (valid) SteamIDs.SetValue(SteamID, false, true);
}

// ------------------------------------------------------------------------
// Returns the idle player of the bot, returns 0 if none
// ------------------------------------------------------------------------
int GetIdlePlayer(int bot)
{
	if(IsClientInGame(bot) && GetClientTeam(bot) == TEAM_SURVIVOR && IsPlayerAlive(bot) && IsFakeClient(bot))
	{
		char sNetClass[12];
		GetEntityNetClass(bot, sNetClass, sizeof(sNetClass));

		if(strcmp(sNetClass, "SurvivorBot") == 0)
		{
			int client = GetClientOfUserId(GetEntProp(bot, Prop_Send, "m_humanSpectatorUserID"));			
			if(client > 0 && IsClientInGame(client) && GetClientTeam(client) == TEAM_SPECTATOR)
			{
				return client;
			}
		}
	}
	return 0;
}

// ------------------------------------------------------------------------
// Returns the bot of the idle client, returns 0 if none 
// ------------------------------------------------------------------------
int GetBotOfIdle(int client)
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if (GetIdlePlayer(i) == client) return i;
	}
	return 0;
}

// ------------------------------------------------------------------------
// Get the number of players on the team (includes idles)
// includeBots == true : counts bots
// ------------------------------------------------------------------------
int GetTeamPlayers(int team, bool includeBots)
{
	int players = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == team)
		{
			if(IsFakeClient(i) && !includeBots && !GetIdlePlayer(i))
				continue;
			players++;
		}
	}
	return players;
}

// ------------------------------------------------------------------------
// Get the number of survivors on the team, including bots
// ------------------------------------------------------------------------
int GetSurvivorTeam()
{
	return GetTeamPlayers(TEAM_SURVIVOR, true);
}

// ------------------------------------------------------------------------
// Is the bot valid? (either survivor or infected)
// ------------------------------------------------------------------------
bool IsBotValid(int client)
{
	if(client > 0 && IsClientInGame(client) && IsFakeClient(client) && !GetIdlePlayer(client) && !IsClientInKickQueue(client))
		return true;
	return false;
}

// ------------------------------------------------------------------------
// Get any valid survivor bot (may be dead). Last bot created is found first
// ------------------------------------------------------------------------
int GetAnyValidSurvivorBot()
{
	for(int i = MaxClients ; i >= 1; i--)  // kick bots in reverse order they have been spawned
	{
		if (IsBotValid(i) && GetClientTeam(i) == TEAM_SURVIVOR)
			return i;
	}
	return -1;
}

// ------------------------------------------------------------------------
// Check if how many alive bots without an idle are available in a team
// ------------------------------------------------------------------------
int CountAvailableBots(int team)
{
	int num = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsBotValid(i) && GetClientTeam(i) == team && IsPlayerAlive(i))
					num++;
	}
	return num;
}

// ------------------------------------------------------------------------
// Check if how many bots are in a team without idle. Can be dead
// ------------------------------------------------------------------------
stock int CountBots(int team)
{
	int num = 0;
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsBotValid(i) && GetClientTeam(i) == team)
					num++;
	}
	return num;
}

int GetAnyValidClient()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) )
			return i;
	} 
	return -1;
}

int GetAnyAliveSurvivor()
{
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsClientInKickQueue(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i))
		{
			return i;
		}
	}
	return -1;
}

bool AnySurvivorLeftSafeArea()
{
	int ent = -1, maxents = GetMaxEntities();
	for (int i = MaxClients+1; i <= maxents; i++)
	{
		if (IsValidEntity(i))
		{
			char netclass[64];
			GetEntityNetClass(i, netclass, sizeof(netclass));
			
			if (StrEqual(netclass, "CTerrorPlayerResource", false))
			{
				ent = i;
				break;
			}
		}
	}
	
	if (ent > -1)
	{
		if(GetEntProp(ent, Prop_Send, "m_hasAnySurvivorLeftSafeArea"))
		{
			return true;
		}
	}
	return false;
}

// *********************************************************************************
// TEAM MENU
// *********************************************************************************

void DisplayTeamMenu(int client)
{
	Handle TeamPanel = CreatePanel();

	SetPanelTitle(TeamPanel, "SuperVersus Team Panel");

	char title_spectator[32];
	Format(title_spectator, sizeof(title_spectator), "Spectator (%d)", GetTeamPlayers(TEAM_SPECTATOR, false));
	DrawPanelItem(TeamPanel, title_spectator);
		
	// Draw Spectator Group
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SPECTATOR)
		{
			char text_client[32];
			char ClientUserName[MAX_TARGET_LENGTH];
			GetClientName(i, ClientUserName, sizeof(ClientUserName));
			ReplaceString(ClientUserName, sizeof(ClientUserName), "[", "");

			Format(text_client, sizeof(text_client), "%s", ClientUserName);
			DrawPanelText(TeamPanel, text_client);
		}
	}

	char title_survivor[32];
	Format(title_survivor, sizeof(title_survivor), "Survivors (%d/%d) - %d Bot(s)", GetTeamPlayers(TEAM_SURVIVOR, false), SurvivorLimit.IntValue, CountAvailableBots(TEAM_SURVIVOR));
	DrawPanelItem(TeamPanel, title_survivor);
	
	// Draw Survivor Group
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR)
		{
			char text_client[32];
			char ClientUserName[MAX_TARGET_LENGTH];

			GetClientName(i, ClientUserName, sizeof(ClientUserName));
			ReplaceString(ClientUserName, sizeof(ClientUserName), "[", "");

			char m_iHealth[MAX_TARGET_LENGTH];
			if(IsPlayerAlive(i))
			{
				if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				{
					Format(m_iHealth, sizeof(m_iHealth), "DOWN - %d HP - ", GetEntData(i, FindDataMapInfo(i, "m_iHealth"), 4));
				}
				else if(GetEntProp(i, Prop_Send, "m_currentReviveCount") == FindConVar("survivor_max_incapacitated_count").IntValue)
				{
					Format(m_iHealth, sizeof(m_iHealth), "BLWH - ");
				}
				else
				{
					Format(m_iHealth, sizeof(m_iHealth), "%d HP - ", GetClientRealHealth(i));
				}
	
			}
			else
			{
				Format(m_iHealth, sizeof(m_iHealth), "DEAD - ");
			}

			Format(text_client, sizeof(text_client), "%s%s", m_iHealth, ClientUserName);
			DrawPanelText(TeamPanel, text_client);
		}
	}

	char title_infected[32];
	
	if (GetClientTeam(client) == TEAM_INFECTED || Management.IntValue == 4)
	{
		if ( InfectedAllowed) Format(title_infected, sizeof(title_infected), "Infected (%d/%d) - %d Bot(s)", GetTeamPlayers(TEAM_INFECTED, false), InfectedLimit.IntValue, CountAvailableBots(TEAM_INFECTED));
		if (!InfectedAllowed) Format(title_infected, sizeof(title_infected), "Infected - %d Bot(s)", CountAvailableBots(TEAM_INFECTED));
	}
	else if (!InfectedAllowed)
	{
		if (SiSpMore.BoolValue && AutoDifficulty.BoolValue)
			Format(title_infected, sizeof(title_infected), "Infected - Max %d Bot(s)", MaxSpecials);  // doesn't show how many bots are alive, but show max bots
		else Format(title_infected, sizeof(title_infected), "Infected");  // don't show max bots if not known
	}
	else if ( InfectedAllowed)
	{
		Format(title_infected, sizeof(title_infected), "Infected (%d/%d)", GetTeamPlayers(TEAM_INFECTED, false), InfectedLimit.IntValue);  // doesn't show how many bots are alive
	}
	
	DrawPanelItem(TeamPanel, title_infected);
		
	// Draw Infected Group
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (GetClientTeam(client) != TEAM_INFECTED && IsFakeClient(i) &&  Management.IntValue != 4) continue ;    // Don't show anything about infected bots to survivors
		
			char text_client[32];
			char ClientUserName[MAX_TARGET_LENGTH];
			
			GetClientName(i, ClientUserName, sizeof(ClientUserName));
			ReplaceString(ClientUserName, sizeof(ClientUserName), "[", "");

			if (GetClientTeam(client) == TEAM_INFECTED || Management.IntValue == 4) // Only show HP of infected to infected
			{
				char m_iHealth[MAX_TARGET_LENGTH];
				if(IsPlayerAlive(i))
				{
					if(GetEntProp(i, Prop_Send, "m_isIncapacitated"))
					{
						Format(m_iHealth, sizeof(m_iHealth), "DOWN - %d HP - ", GetEntData(i, FindDataMapInfo(i, "m_iHealth"), 4));
					}
					if(GetEntProp(i, Prop_Send, "m_isGhost"))
					{
						Format(m_iHealth, sizeof(m_iHealth), "GHOST - ");
					}
					else
					{
						Format(m_iHealth, sizeof(m_iHealth), "%d HP - ", GetEntData(i,  FindDataMapInfo(i, "m_iHealth"), 4));
					}
				}
				else
				{
					Format(m_iHealth, sizeof(m_iHealth), "DEAD - ");
				}
				Format(text_client, sizeof(text_client), "%s%s", m_iHealth, ClientUserName);
			}
			else Format(text_client, sizeof(text_client), "%s", ClientUserName);
			
			DrawPanelText(TeamPanel, text_client);
		}
	}

	DrawPanelItem(TeamPanel, "Close");
		
	SendPanelToClient(TeamPanel, client, TeamMenuHandler, 30);
	CloseHandle(TeamPanel);
	TeamPanelTimer[client] = CreateTimer(1.0, Timer_TeamMenuHandler, client);
}

public int TeamMenuHandler(Handle UpgradePanel, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if(param2 == 1)
		{
			FakeClientCommand(client, "sm_spectate");
		}
		else if(param2 == 2)
		{
			FakeClientCommand(client, "sm_survivor");
		}
		else if(param2 == 3)
		{
			FakeClientCommand(client, "sm_infected");
		}
		else if(param2 == 4)
		{
			delete TeamPanelTimer[client];
		}
	}
	else if(action == MenuAction_Cancel)
	{
		// Nothing
	}
}

public Action Timer_TeamMenuHandler(Handle hTimer, int client)
{
	DisplayTeamMenu(client);
}

int GetClientRealHealth(int client)
{
	if(!client || !IsValidEntity(client) || !IsClientInGame(client) || !IsPlayerAlive(client) || IsClientObserver(client))
	{
		return -1;
	}
	if(GetClientTeam(client) != TEAM_SURVIVOR)
	{
		return GetClientHealth(client);
	}
  
	float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float TempHealth;
	int PermHealth = GetClientHealth(client);
	if(buffer <= 0.0)
	{
		TempHealth = 0.0;
	}
	else
	{
		float difference = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
		float decay = FindConVar("pain_pills_decay_rate").FloatValue;
		float constant = 1.0/decay;	TempHealth = buffer - (difference / constant);
	}
	
	if(TempHealth < 0.0)
	{
		TempHealth = 0.0;
	}
	return RoundToFloor(PermHealth + TempHealth);
}

// *********************************************************************************
// DIRECTOR DIFFICULTY METHODS
// *********************************************************************************

// ------------------------------------------------------------------------
//  Change the director variable MaxSpecials. Won't do anything unless l4dt present
// ------------------------------------------------------------------------
public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (!InfectedAllowed && StrEqual(key, "MaxSpecials") && SiSpMore.BoolValue && AutoDifficulty.BoolValue)
	{
		retVal = MaxSpecials;
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

// ------------------------------------------------------------------------
//  Difficulty timer. Triggered by Timer_BotsUpdate
// ------------------------------------------------------------------------
public Action Timer_Difficulty(Handle hTimer)
{
	DifficultyTimer = null;
	AutoDifficultyCheck();
}

void AutoDifficultyCheck()
{
	int extrasurvivors = GetSurvivorTeam() - 4;
	extrasurvivors = (extrasurvivors > 0) ? extrasurvivors : 0;  // Don't make game easier if less than 4 survivors 

	float TankHp_Multi = 1 + TankHpMulti.FloatValue*extrasurvivors;
	if (TankHpMulti.BoolValue){   // if not 0
			int TankHP = RoundFloat(4000.0*TankHp_Multi);
			FindConVar("z_tank_health").IntValue = TankHP;
	}
	
	// Spawn more zombie the more survivors there are 
	float spawn_multi = 1 + CiSpMulti.FloatValue * extrasurvivors ;	
	if (CiSpMulti.BoolValue){	 
		FindConVar("z_mob_spawn_finale_size").IntValue	= RoundToNearest(20 * spawn_multi);
		FindConVar("z_mob_spawn_max_size").IntValue 	= RoundToNearest(30 * spawn_multi);
		FindConVar("z_mob_spawn_min_size").IntValue		= RoundToNearest(10 * spawn_multi);
		FindConVar("z_mob_spawn_finale_size").IntValue	= RoundToNearest(20 * spawn_multi);
		FindConVar("z_mega_mob_size").IntValue			= RoundToNearest(50 * spawn_multi);
		FindConVar("z_common_limit").IntValue			= RoundToNearest(30 * spawn_multi);
	  //FindConVar("z_health").IntValue					= RoundToNearest(50 * spawn_multi);
	
		FindConVar("z_mob_spawn_max_interval_easy").IntValue	= RoundToFloor(240.0 / spawn_multi);
		FindConVar("z_mob_spawn_max_interval_normal").IntValue	= RoundToFloor(180.0 / spawn_multi);
		FindConVar("z_mob_spawn_max_interval_hard").IntValue	= RoundToFloor(180.0 / spawn_multi);
		FindConVar("z_mob_spawn_max_interval_expert").IntValue	= RoundToFloor(180.0 / spawn_multi);
		FindConVar("z_mob_spawn_min_interval_easy").IntValue	= RoundToFloor(120.0 / spawn_multi);
		FindConVar("z_mob_spawn_min_interval_normal").IntValue	= RoundToFloor( 90.0 / spawn_multi);		
		FindConVar("z_mob_spawn_min_interval_hard").IntValue	= RoundToFloor( 90.0 / spawn_multi);
		FindConVar("z_mob_spawn_min_interval_expert").IntValue	= RoundToFloor( 90.0 / spawn_multi);
		
		FindConVar("z_mega_mob_spawn_max_interval").IntValue					= RoundToFloor(900.0 / spawn_multi);
		FindConVar("z_mega_mob_spawn_min_interval").IntValue					= RoundToFloor(420.0 / spawn_multi);
		FindConVar("director_special_respawn_interval").IntValue				= RoundToFloor( 45.0 / spawn_multi);
		FindConVar("director_special_battlefield_respawn_interval").IntValue	= RoundToFloor( 10.0 / spawn_multi);
		FindConVar("director_special_finale_offer_length").IntValue				= RoundToFloor( 10.0 / spawn_multi);
		FindConVar("director_special_initial_spawn_delay_max").IntValue			= RoundToFloor( 60.0 / spawn_multi);
		FindConVar("director_special_initial_spawn_delay_max_extra").IntValue	= RoundToFloor(180.0 / spawn_multi);
		FindConVar("director_special_initial_spawn_delay_min").IntValue			= RoundToFloor( 30.0 / spawn_multi);
		FindConVar("director_special_original_offer_length").IntValue			= RoundToFloor( 30.0 / spawn_multi);
	}

	// More survivors = more SI health
	float sihp_Multi = 1 + GetConVarFloat(SiHpMulti)*extrasurvivors;
	if (SiHpMulti.BoolValue){		
		FindConVar("z_gas_health").IntValue			= RoundToCeil(   250.0 * sihp_Multi);
		FindConVar("z_hunter_health").IntValue		= RoundToNearest(250.0 * sihp_Multi);
		FindConVar("z_exploding_health").IntValue	= RoundToNearest( 50.0 * sihp_Multi);
		FindConVar("z_spitter_health").IntValue		= RoundToCeil(   100.0 * sihp_Multi);
		FindConVar("z_charger_health").IntValue		= RoundToNearest(600.0 * sihp_Multi);
		FindConVar("z_jockey_health").IntValue		= RoundToNearest(325.0 * sihp_Multi);
	}

	// Increase limit of special infected as bots. 
	if(!InfectedAllowed && SiSpMore.BoolValue && !StrEqual(gameMode, "survival"))    // Not in survival, versus, scavenge or realism versus, l4dt required
	{
		// Increase overall infected limit
		MaxSpecials = 2 + RoundToNearest(extrasurvivors * SiSpMore.FloatValue);
		FindConVar("z_minion_limit").IntValue = MaxSpecials; 	// For L4D1?
		
		// Increase limits of infected classes
		char iType[6][24] = {"z_smoker_limit", "z_boomer_limit", "z_hunter_limit", "z_spitter_limit", "z_charger_limit", "z_jockey_limit"};
		int maxTypes = L4D1 ? 3 : 6;
		if(L4D1)
		{
			ReplaceString(iType[0], sizeof(iType[]), "smoker", "gas", false);
			ReplaceString(iType[1], sizeof(iType[]), "boomer", "exploding", false);		
		}

		int SIperclass = RoundToCeil(MaxSpecials/3.0);  // 0 to 3 SI: 1 per class, 4 to 6 SI: 2 per class, 7 to 9 SI: 3 per class, etc

		for(int i = 0; i < maxTypes; i++)
		{
			FindConVar(iType[i]).IntValue = SIperclass;  // Increase each SI class limit
		}
	}
	PrintToConsoleAll("[SV] - Tank HP: %.0f%%\tSI HP: %.0f%%\tCI spawn rate: %.0f%%\tMaxSpecials: %d", 100.0*TankHp_Multi, 100.0*sihp_Multi, 100.0*spawn_multi, MaxSpecials);
}

// *********************************************************************************
// INFECTED COUNTER, for Versus / Scavenge
// *********************************************************************************

// ------------------------------------------------------------------------
//  Start counter when a survivor leaves safe area
// ------------------------------------------------------------------------
public void Event_PlayerLeftStartArea(Handle event, const char[] name, bool dontBroadcast)
{ 
	if(SubDirector == null && InfectedAllowed && AnySurvivorLeftSafeArea())
	{
		SubDirector = CreateTimer(5.0, BotInfectedCounter, true);
	}
}

// ------------------------------------------------------------------------
//  Counter periodically checks if need to add SI to queue, or spawn extra SI
// ------------------------------------------------------------------------
public Action BotInfectedCounter(Handle timer, bool recheck)
{
	SubDirector = null;

	if (recheck && !AnySurvivorLeftSafeArea()) return;  // Disable counter if false start due to round restart
	
	if (!MoreSiBotsVersus.BoolValue || GetTeamPlayers(TEAM_INFECTED, false) >= InfectedLimit.IntValue) // if no extra bots wanted
	{
		SubDirector = CreateTimer(10.0, BotInfectedCounter, false); // check back in 10 secs to see if setting changed
		return ;
	}
	
	SiSpawnCheck();
	
	SubDirector = CreateTimer(2.0, BotInfectedCounter, false);
}

// ------------------------------------------------------------------------
//  Check if Si to be added to respawn Queue, or spawn a Si
// ------------------------------------------------------------------------
void SiSpawnCheck()
{
	// For each missing SI, add to queue
	for (int i = GetTeamPlayers(TEAM_INFECTED, true) + CountSiQueue(); i < InfectedLimit.IntValue; i++)
	{
		AddSiToQueue();
	}
	
	// For each Si over the limit, remove youngest in queue
	for (int i = GetTeamPlayers(TEAM_INFECTED, true) + CountSiQueue(); i > InfectedLimit.IntValue; i--)
	{
		int YoungestSi = GetYoungestSi();
		if (YoungestSi != -1)  	SiTimes[YoungestSi] = 0.0;		
	}
	
	// For each Si over the limit, spawn it
	int OldestSi = GetOldestSi();
	if (OldestSi != -1 && (GetGameTime() - SiTimes[OldestSi]) > GhostDelayMax.FloatValue + SiSpMoreDelay.FloatValue)
	{
		SiSpawn();
	}
}

// ------------------------------------------------------------------------
//  Get Si that has been in the spawn queue the longest
// ------------------------------------------------------------------------
int GetOldestSi()
{
	float fOldest     =  GetGameTime()+1.0; // More recent that any can be
	int   iOldest     =   			    -1;
	for (int i = 0; i < InfectedLimit.IntValue; i++)
	{
		if (SiTimes[i] > 0.0 && SiTimes[i] < fOldest)
		{
			iOldest   = i;
			fOldest   = SiTimes[i];
		}
	}
	return iOldest;
}

// ------------------------------------------------------------------------
//  Get Si that has been in the spawn queue the shortest
// ------------------------------------------------------------------------
int GetYoungestSi()
{
	float fYoungest     =                  0.0; // Older than any can be
	int   iYoungest     =   			    -1;
	for (int i = 0; i < InfectedLimit.IntValue; i++)
	{
		if (SiTimes[i] > fYoungest)
		{
			iYoungest   = i;
			fYoungest   = SiTimes[i];
		}
	}
	return iYoungest;
}

// ------------------------------------------------------------------------
//  Add new Si to spawn queue
// ------------------------------------------------------------------------
void AddSiToQueue()
{
	for (int i = 0; i < InfectedLimit.IntValue; i++)
	{
		if (SiTimes[i] == 0.0)
		{
			SiTimes[i] = GetGameTime();
			return;
		}
	}
}

// ------------------------------------------------------------------------
// Count how many SI are in the queue
// ------------------------------------------------------------------------
int CountSiQueue()
{
	int count = 0;
	for (int i = 0; i < InfectedLimit.IntValue; i++)
	{
		if (SiTimes[i] > 0.0)
		{
			count = count + 1;
		}
	}
	return count;
}

// ------------------------------------------------------------------------
//  Spawn a Special Infected bot
// ------------------------------------------------------------------------
void SetGhostStatus(int client, bool ghost) { SetEntProp(client, Prop_Send, "m_isGhost",   ghost); }
void SetLifeState  (int client, bool ready) { SetEntProp(client, Prop_Send, "m_lifeState", ready); }
bool IsPlayerGhost (int client) 			{ return GetEntProp(client, Prop_Send, "m_isGhost") ? true : false;}
char SiNames[9][] = {"none", "smoker", "boomer", "hunter", "spitter", "jockey", "charger", "witch", "tank"};

int GetSiType(int client)
{
	char modelName[32];
	GetClientModel(client, modelName, sizeof(modelName));
	for (int type = 1; type <= 8; type++)
	{
		if (StrEqual(modelName, SiNames[type])) return type;
	}
	return 0;
}

void SiSpawn(int type = -1)
{
	if (type == -1) type = PickSiType();
	if (type == -1) return;

	// Stores Ghost / Life, & set to nonghost/not alive. Otherwise players may autospawn
	/////////////////////////////////////////////////////
	bool resetGhost[MAXPLAYERS+1];
	bool resetLife[MAXPLAYERS+1];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if(IsPlayerGhost(i))
			{
				resetGhost[i] = true;
				SetGhostStatus(i, false);
			}
			else if(!IsPlayerAlive(i))
			{
				resetLife[i] = true;
				SetLifeState(i, false);
			}
		}
	}

	int client = GetAnyValidClient();
	if (client > 0) 
	{
		int Bot = CreateFakeClient("InfectedBot");
		if(Bot != 0)
		{
			ChangeClientTeam(Bot, TEAM_INFECTED);
			DispatchKeyValue(Bot, "classname", "InfectedBot");
			if (L4D1) CheatCommand(client, "z_spawn", SiNames[type], "auto");
			else  CheatCommand(client, "z_spawn_old", SiNames[type], "auto"); // z_spawn_old required or they spawn in front of survivors
			KickClient(Bot, "Kicked Fake Bot");
		}
	}
	
	// We restore the player's status
	/////////////////////////////////
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_INFECTED)
		{
			if (resetGhost[i]) SetGhostStatus(i, true); 
			if ( resetLife[i]) SetLifeState(i, true);
		}
	}
}

char L4D1_limits[4][] = {"none", "z_gas_limit",			  "z_exploding_limit",	   "z_hunter_limit"};
char L4D2_limits[7][] = {"none", "z_versus_smoker_limit", "z_versus_boomer_limit", "z_versus_hunter_limit", "z_versus_spitter_limit", "z_versus_charger_limit", "z_versus_jockey_limit"};

// ------------------------------------------------------------------------
//  Find which SI should be spawned
// ------------------------------------------------------------------------
int PickSiType()
{
	// first element is nothing, to simplify since enum starts at 1
	//////////////////////////////////////////////////////////////
	int SIleft[7] = {-1,  0,0,0, 0,0,0};
	int maxTypes = L4D1 ? 3 : 6;
	
	// Record SI type limits
	////////////////////////
	int SIfromTypes = 0; // 
	for (int type = 1; type <= maxTypes; type++)
	{
		SIleft[type] = L4D1? FindConVar(L4D1_limits[type]).IntValue : FindConVar(L4D2_limits[type]).IntValue;
		SIfromTypes  = SIfromTypes + SIleft[type] ;
	}

	int iInfected = InfectedLimit.IntValue;
	FindConVar("z_minion_limit").IntValue = iInfected; 

	// Check if SI from types are enough
	///////////////////////////////////////
	if (SIfromTypes < iInfected)   // if not enough 
	{
		int extraSiPerType =  RoundToCeil((iInfected - SIfromTypes)/3.0);
		
		for(int i = 1; i <= maxTypes; i++)
		{
			SIleft[i] = SIleft[i] + extraSiPerType;
			if (L4D1) FindConVar(L4D1_limits[i]).IntValue = SIleft[i];  // Increase each SI class limit
			else      FindConVar(L4D2_limits[i]).IntValue = SIleft[i];
		}
	}
	
	// counts infected left that can be spawned.
	//////////////////////////////////////////			
	for(int i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && GetClientTeam(i) == TEAM_INFECTED)
		{			
			SIleft[GetSiType(i)]--;
		}
	}
	
	// Pick available types;
	int nmax = 0;
	int SIfree[7];
	
	for (int type = 1; type <= 6; type++)
	{
		if (SIleft[type] > 0)
		{
			nmax++;
			SIfree[nmax] = type;
		}
	}
		
	if (nmax != 0)  return SIfree[GetRandomInt(1, nmax)];
	else 			return -1;
}

// *********************************************************************************
// SIGNATURE METHODS
// *********************************************************************************

void Respawn(int client)
{
	static Handle hRoundRespawn = INVALID_HANDLE;
	if (hRoundRespawn == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("l4d_superversus");
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "RoundRespawn");
		hRoundRespawn = EndPrepSDKCall();
		if(hRoundRespawn == INVALID_HANDLE)
		{
			PrintToChatAll("\x03[SV] \x01RoundRespawn Signature broken. Make sure l4d_superversus.txt is in /gamedata/");
		}
  	}
	SDKCall(hRoundRespawn, client);
}

void SetHumanIdle(int bot, int client)
{
	static Handle hSpec = INVALID_HANDLE;
	if (hSpec == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("l4d_superversus");
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "SetHumanSpec");
		PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
		hSpec = EndPrepSDKCall();
		if(hSpec == INVALID_HANDLE)
		{
			PrintToChatAll("\x03[SV] \x01SetHumanSpec Signature broken. Make sure l4d_superversus.txt is in /gamedata/");		
		}
	}

	SDKCall(hSpec, bot, client);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void TakeOverBot(int client)
{
	static Handle hSwitch = INVALID_HANDLE;
	if (hSwitch == INVALID_HANDLE)
	{
		Handle hGameConf = LoadGameConfigFile("l4d_superversus");
		StartPrepSDKCall(SDKCall_Player);
		PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "TakeOverBot");
		PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
		hSwitch = EndPrepSDKCall();
		if (hSwitch == INVALID_HANDLE)
		{
			PrintToChatAll("\x03[SV] \x01 TakeOverBot Signature broken. Make sure l4d_superversus.txt is in /gamedata/");	
		}	
	}
	SDKCall(hSwitch, client, true);
}

// *********************************************************************************
// CHEAT METHODS
// *********************************************************************************

void CheatCommand(int client, const char[] command, const char[] argument1, const char[] argument2)
{
	int userFlags = GetUserFlagBits(client);
	SetUserFlagBits(client, ADMFLAG_ROOT);
	int flags = GetCommandFlags(command);
	SetCommandFlags(command, flags & ~FCVAR_CHEAT);
	FakeClientCommand(client, "%s %s %s", command, argument1, argument2);
	SetCommandFlags(command, flags);
	SetUserFlagBits(client, userFlags);
}

// ------------------------------------------------------------------------
// Teleport client to survivor
// ------------------------------------------------------------------------
void TeleportToSurvivor(int client) 
{
	if (IsClientInGame(client) && IsPlayerAlive(client) && !GetBotOfIdle(client))
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i) && client != i)
			{
				float pos[3] = 0.0;
				GetClientAbsOrigin(i, pos);
				TeleportEntity(client, pos, NULL_VECTOR, NULL_VECTOR);
				return;
			}
		}
	}
}

// ------------------------------------------------------------------------
// Get the average weapon tier of survivors, and give a weapon of that tier to client
// ------------------------------------------------------------------------
char tier1_weapons[5][] =
{
	"weapon_smg",
	"weapon_pumpshotgun",
	"weapon_smg_silenced",		// L4D2 only
	"weapon_shotgun_chrome",	// L4D2 only
	"weapon_smg_mp5"			// International only
};
bool IsWeaponTier1(int iWeapon)
{
	char sWeapon[128];
	GetEdictClassname(iWeapon, sWeapon, sizeof(sWeapon));
	for (int i = 0; i < sizeof(tier1_weapons); i++)
	{
		if (StrEqual(sWeapon, tier1_weapons[i], false)) return true;
	}
	return false;
}
void GiveAverageWeapon(int client)
{
	if (!IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client)) return;

	int iWeapon;
	int wtotal=0; int total=0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && IsPlayerAlive(i) && client != i)
		{
			total = total+1;	
			iWeapon = GetPlayerWeaponSlot(i, 0);
			if (iWeapon < 0 || !IsValidEntity(iWeapon) || !IsValidEdict(iWeapon)) continue; // no primary weapon

			if (IsWeaponTier1(iWeapon)) wtotal = wtotal + 1;  // tier 1
			else wtotal = wtotal + 2; // tier 2 or more
		}
	}
	int average = total > 0 ? RoundToNearest(1.0 * wtotal/total) : 0;
	switch(average)
	{
		case 0: CheatCommand(client, "give", "pistol", "");	
		case 1: CheatCommand(client, "give", "smg", "");
		case 2: CheatCommand(client, "give", "weapon_rifle", "");
	}
}

void SetGodMode(int client, float duration)
{
	if (!IsClientInGame(client)) return;
	
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1); // god mode
	
	if (duration > 0.0) CreateTimer(duration, Timer_mortal, GetClientUserId(client));
}

public Action Timer_mortal(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client)) return;
	SetEntProp(client, Prop_Data, "m_takedamage", 2, 1); // mortal
}
