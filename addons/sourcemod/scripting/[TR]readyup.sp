#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[SilverShot]left4dhooks>
#include <[TR]builtinvotes>
#include <[TR]builtinvotes_native>
#include <[TR]l4d2library>

#define MAX_FOOTERS 10
#define MAX_FOOTER_LEN 65
#define READY_DELAY 3
#define READY_TIMEOUT 60
#define SECRETS_SOUND "/level/gnomeftw.wav"

public Plugin myinfo =
{
	name = "L4D2 Auto Ready-Up",
	author = "CanadaRox, Sir, Yukari190",
	description = "New and improved ready-up plugin.",
	version = "8.5",
	url = ""
};

GlobalForward liveForward;
ConVar l4d_ready_cfg_name;
ConVar l4d_ready_countdown_sound;
ConVar l4d_ready_live_sound;
ConVar l4d_ready_mode;
ConVar god;
ConVar sb_stop;
ConVar sv_infinite_ammo;
ConVar survivor_limit;
ConVar z_max_player_zombies;
ConVar sv_maxplayers;
ConVar hostname;
Handle readyCountdownTimer;
char readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
bool hiddenPanel[MAXPLAYERS+1];
bool hiddenManually[MAXPLAYERS+1];
bool inLiveCountdown;
bool inReadyUp;
bool isPlayerReady[MAXPLAYERS+1];
bool blockSecretSpam[MAXPLAYERS+1];
bool isClientLoading[MAXPLAYERS+1];
bool bReadyUpMode;
bool bVoteStart;
char countdownSound[64];
char liveSound[64];
int clientTimeout[MAXPLAYERS+1];
int footerCounter = 0;
int readyDelay;
float g_fButtonTime[MAXPLAYERS+1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AddStringToReadyFooter", Native_AddStringToReadyFooter);
	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("GetReadyCfgName", Native_GetReadyCfgName);
	liveForward = new GlobalForward("OnRoundIsLive", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public void OnPluginStart()
{
	l4d_ready_cfg_name = CreateConVar("l4d_ready_cfg_name", "", "配置名称显示在准备好的面板上", FCVAR_NONE|FCVAR_PRINTABLEONLY);
	l4d_ready_countdown_sound = CreateConVar("l4d_ready_countdown_sound", "buttons/bell1.wav", "现场直播时播放的声音");
	l4d_ready_live_sound = CreateConVar("l4d_ready_live_sound", "ui/helpful_event_1.wav", "现场直播时播放的声音");
	l4d_ready_mode = CreateConVar("l4d_ready_mode", "0", "0-定时解锁 1-手动解锁(ready-up方式)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	l4d_ready_mode.AddChangeHook(ConVarChange);
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	god = FindConVar("god");
	sb_stop = FindConVar("sb_stop");
	sv_infinite_ammo = FindConVar("sv_infinite_ammo");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	sv_maxplayers = FindConVar("sv_maxplayers");
	hostname = FindConVar("hostname");
	
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	AddCommandListener(Vote_Callback, "Vote");
	
	RegAdminCmd("sm_forcestart", ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_hide", Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_ready", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_unready", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_return", Return_Cmd, "如果您在未解冻的准备期间卡住, 请返回有效的安全室产卵");
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	
	LoadTranslations("common.phrases");
}

public void OnPluginEnd()
{
	InitiateLive(false);
}

public int ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	bReadyUpMode = l4d_ready_mode.BoolValue;
}


public void OnMapStart()
{
	/* OnMapEnd needs this to work */
	GetConVarString(l4d_ready_countdown_sound, countdownSound, sizeof(countdownSound));
	GetConVarString(l4d_ready_live_sound, liveSound, sizeof(liveSound));
	PrecacheSound(SECRETS_SOUND);
	PrecacheSound(countdownSound);
	PrecacheSound(liveSound);
	
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		blockSecretSpam[client] = false;
	}
	readyCountdownTimer = INVALID_HANDLE;
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public void OnMapEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public void OnClientDisconnect(int client)
{
	hiddenPanel[client] = false;
	hiddenManually[client] = false;
	isPlayerReady[client] = false;
	isClientLoading[client] = false;
	clientTimeout[client] = 0;
	g_fButtonTime[client] = 0.0;
}

public Action Say_Callback(int client, const char[] command, int argc)
{
	SetEngineTime(client);
}

public Action Vote_Callback(int client, char[] command, int args)
{
	if (!bReadyUpMode || !inReadyUp) return Plugin_Continue;
	if (IsBuiltinVoteInProgress() && IsClientInBuiltinVotePool(client)) return Plugin_Continue;
	
    char buffer[4];
    GetCmdArg(1, buffer, sizeof(buffer));
    if (StrEqual(buffer, "yes", false))
	{
		Ready(client);
	}
	else
	{
		SetEngineTime(client);
		Unready(client);
	}
	return Plugin_Handled;
}

//======================================
//				NATIVE
//======================================
public int Native_AddStringToReadyFooter(Handle plugin, int numParams)
{
	char footer[MAX_FOOTER_LEN];
	GetNativeString(1, footer, sizeof(footer));
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(footer) < MAX_FOOTER_LEN)
		{
			strcopy(readyFooter[footerCounter], MAX_FOOTER_LEN, footer);
			footerCounter++;
			return view_as<int>(true);
		}
	}
	return view_as<int>(false);
}

public int Native_IsInReady(Handle plugin, int numParams)
{
	return view_as<int>(inReadyUp);
}

public int Native_GetReadyCfgName(Handle plugin, int numParams)
{
	int len = GetNativeCell(2);
	char[] cfgBuf = new char[len];
	GetConVarString(l4d_ready_cfg_name, cfgBuf, len);
	SetNativeString(1, cfgBuf, len);
}

//======================================
//				CMDS
//======================================
public Action Hide_Cmd(int client, int args)
{
	hiddenPanel[client] = true;
	hiddenManually[client] = true;
	return Plugin_Handled;
}

public Action Show_Cmd(int client, int args)
{
	hiddenPanel[client] = false;
	hiddenManually[client] = false;
	return Plugin_Handled;
}

public Action ForceStart_Cmd(int client, int args)
{
	if (inReadyUp)
	{
		InitiateLiveCountdown();
	}
	return Plugin_Handled;
}

public Action Ready_Cmd(int client, int args)
{
	if (bReadyUpMode && inReadyUp)
	{
		Ready(client);
	}
	return Plugin_Handled;
}

public Action Unready_Cmd(int client, int args)
{
	if (bReadyUpMode && inReadyUp)
	{
		SetEngineTime(client);
		Unready(client);
	}
	return Plugin_Handled;
}

public Action Return_Cmd(int client, int args)
{
	if (client > 0
			&& inReadyUp
			&& GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client);
	}
	return Plugin_Handled;
}

public Action KickSpecs_Cmd(int client, int args)
{
	if (L4D2_IsValidClient(client))
	{
		char sBuffer[64];
		Format(sBuffer, sizeof(sBuffer), "踢非管理员和非强制性观众?");
		bVoteStart = true;
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	return Plugin_Handled;
}

public void BuiltinVotes_VoteResult()
{
	if (bVoteStart)
	{
		for (int c=1; c<=MaxClients; c++)
		{
			if (IsClientInGame(c) && (GetClientTeam(c) == 1) && !L4D2_IsClientCaster(c) && !L4D2_IsClientAdmin(c))
			{
				KickClient(c, "No Spectators, please!");
			}
		}
	}
	bVoteStart = false;
}

//======================================
//				L4DT
//======================================
public Action L4D_OnFirstSurvivorLeftSafeArea(int client)
{
	if (inReadyUp)
	{
		ReturnPlayerToSaferoom(client);
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//======================================
//				EVENT
//======================================
public void OnBossVote()
{
	readyFooter[1] = "";
	footerCounter = 1;
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	inReadyUp = true;
	inLiveCountdown = false;
	bVoteStart = false;
	
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	

	
	readyCountdownTimer = INVALID_HANDLE;
	
	SurvivorsLock(true);
	DisableEntities();
	
	if (!bReadyUpMode)
	{
		CreateTimer(10.0, LoadingTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
}

public Action MenuRefresh_Timer(Handle timer)
{
	if (inReadyUp)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				if (IsBuiltinVoteInProgress())
				{
					if (IsClientInBuiltinVotePool(i))
					  hiddenPanel[i] = true;
				}
				else
				{
					if (!hiddenManually[i])
					  hiddenPanel[i] = false;
				}
			}
		}
		
		Handle menuPanel = CreatePanel();
		char ServerBuffer[128];
		char ServerName[32];
		char cfgBuf[128];
		char ReadyModeBuffer[32];
		char survivorBuffer[800] = "";
		char infectedBuffer[800] = "";
		char casterBuffer[800] = "";
		
		int casterCount = 0;
		int timelimit = READY_TIMEOUT;
		
		GetConVarString(hostname, ServerName, sizeof(ServerName));
		GetConVarString(l4d_ready_cfg_name, cfgBuf, sizeof(cfgBuf));
		Format(ServerBuffer, sizeof(ServerBuffer), "▶ Server: %s \n▶ Slots: %d/%d \n▶ Config: %s", ServerName, GetSeriousClientCount(), GetConVarInt(sv_maxplayers), cfgBuf);
		DrawPanelText(menuPanel, ServerBuffer);
		Format(ReadyModeBuffer, sizeof(ReadyModeBuffer), "▶ Ready Mode: %s", (bReadyUpMode ? "Ready-Up" : "Auto-Start"));
		DrawPanelText(menuPanel, ReadyModeBuffer);
		DrawPanelText(menuPanel, " ");
		
		char nameBuf[MAX_NAME_LENGTH*2];
		float fTime = GetEngineTime();
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client))
			{
				GetClientName(client, nameBuf, sizeof(nameBuf));
				
				int team = GetClientTeam(client);
				
				if (!bReadyUpMode)
				{
					if(isClientLoading[client])
					{
						Format(nameBuf, sizeof(nameBuf), "->☐ %s\n", nameBuf);
					}
					else if (clientTimeout[client] >= timelimit)
					{
						Format(nameBuf, sizeof(nameBuf), "->☒ %s\n", nameBuf);
					}
					else if (clientTimeout[client] < timelimit)
					{
						Format(nameBuf, sizeof(nameBuf), "->☑ %s\n", nameBuf);
					}
					
					if (team == 2)
					{
						StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
					}
					else if (team == 3)
					{
						StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
					}
				}
				else
				{
					if (IsPlayer(client))
					{
						if (isPlayerReady[client])
						{
							if (!inLiveCountdown) PrintHintText(client, "你已经准备.\n按 F2 取消准备.");
							Format(nameBuf, sizeof(nameBuf), "->☑ %s\n", nameBuf);
						}
						else
						{
							if (!inLiveCountdown) PrintHintText(client, "你还没准备.\n按 F2 准备.");
							if ((fTime - g_fButtonTime[client]) > 15.0) Format(nameBuf, sizeof(nameBuf), "->☐ %s [AFK]\n", nameBuf);
							else Format(nameBuf, sizeof(nameBuf), "->☐ %s\n", nameBuf);
						}
						
						if (team == 2)
						{
							StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
						}
						else if (team == 3)
						{
							StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
						}
					}
					else if (L4D2_IsClientCaster(client))
					{
						++casterCount;
						Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
						StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
					}
				}
			}
		}
		
		int bufLen = strlen(survivorBuffer);
		if (bufLen != 0)
		{
			survivorBuffer[bufLen] = '\0';
			ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#buy", "<- TROLL");
			ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
			DrawPanelItem(menuPanel, "->1. 生还者");
			DrawPanelText(menuPanel, survivorBuffer);
		}
		
		bufLen = strlen(infectedBuffer);
		if (bufLen != 0)
		{
			infectedBuffer[bufLen] = '\0';
			ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#buy", "<- TROLL");
			ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
			DrawPanelItem(menuPanel, "->2. 感染者");
			DrawPanelText(menuPanel, infectedBuffer);
		}
		
		if (casterCount > 0) DrawPanelText(menuPanel, " ");
		
		bufLen = strlen(casterBuffer);
		if (bufLen != 0)
		{
			casterBuffer[bufLen] = '\0';
			ReplaceString(casterBuffer, sizeof(casterBuffer), "#buy", "<- TROLL");
			ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_");
			DrawPanelItem(menuPanel, "->3. 裁判");
			DrawPanelText(menuPanel, casterBuffer);
		}
		DrawPanelText(menuPanel, " \n");
		
		for (int i = 0; i < MAX_FOOTERS; i++)
		{
			DrawPanelText(menuPanel, readyFooter[i]);
		}
		
		for (int client = 1; client <= MaxClients; client++)
		{
			if (IsClientInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
			{
				SendPanelToClient(menuPanel, client, DummyHandler, 1);
			}
		}
		delete menuPanel;
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { }

public Action LoadingTimer(Handle timer)
{
	if (!isFinishedLoading())
	{
		return Plugin_Continue;
	}
	InitiateLiveCountdown();
	return Plugin_Stop;
}

public Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (!inReadyUp) return;
	if (!IsFakeClient(client))
	{
		SetEngineTime(client);
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}
	
	if (bReadyUpMode)
	{
		if (oldteam > 1 || team > 1)
		{
			CancelFullReady();
		}
	}
}

void InitiateLiveCountdown()
{
	if (readyCountdownTimer == INVALID_HANDLE)
	{
		ReturnTeamToSaferoom();
		SetTeamFrozen(true);
		PrintHintTextToAll("即将开始!", (bReadyUpMode ? "\n按 F2 取消准备" : ""));
		inLiveCountdown = true;
		readyDelay = READY_DELAY;
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action ReadyCountdownDelay_Timer(Handle timer)
{
	if (readyDelay == 0)
	{
		PrintHintTextToAll("Battle!");
		InitiateLive();
		readyCountdownTimer = INVALID_HANDLE;
		EmitSoundToAll(liveSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("请等待: %d秒%s", readyDelay, (bReadyUpMode ? "\n按 F2 取消准备" : ""));
		EmitSoundToAll(countdownSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		readyDelay--;
	}
	return Plugin_Continue;
}

void CancelFullReady()
{
	if (readyCountdownTimer != INVALID_HANDLE)
	{
		SetTeamFrozen(false);
		inLiveCountdown = false;
		CloseHandle(readyCountdownTimer);
		readyCountdownTimer = INVALID_HANDLE;
		PrintHintTextToAll("倒计时已取消!");
	}
}

void InitiateLive(bool real = true)
{
	inReadyUp = false;
	inLiveCountdown = false;
	
	SetTeamFrozen(false);
	
	EnableEntities();
	SurvivorsLock(false);
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 60.0);
	
	for (int i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}
	
	for (int i = 0; i < MAX_FOOTERS; i++)
	{
		readyFooter[i] = "";
	}
	
	footerCounter = 0;
	if (real)
	{
		Call_StartForward(liveForward);
		Call_Finish();
	}
}

//======================================
//				Actions
//======================================
/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (inReadyUp)
	{
		if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client))
		{
			if (buttons && !IsFakeClient(client)) SetEngineTime(client);
			if (GetEntityFlags(client) & FL_INWATER)
			{
				ReturnPlayerToSaferoom(client);
			}
		}
	}
	return Plugin_Continue;
}

//======================================
//				Other
//======================================
void Ready(int client)
{
	DoSecrets(client);
	isPlayerReady[client] = true;
	if (CheckFullReady())
		InitiateLiveCountdown();
}

void DoSecrets(int client)
{
	PrintCenterTextAll("\x42\x4f\x4e\x45\x53\x41\x57\x20\x49\x53\x20\x52\x45\x41\x44\x59\x21");
	if (GetClientTeam(client) == 2 && !blockSecretSpam[client])
	{
		int particle = CreateEntityByName("info_particle_system");
		float pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 50;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", "achieved");
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(10.0, killParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll(SECRETS_SOUND, client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		CreateTimer(2.5, killSound);
		CreateTimer(2.0, SecretSpamDelay, client);
		blockSecretSpam[client] = true;
	}
}

public Action killParticle(Handle timer, any entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action killSound(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && !IsFakeClient(i))
	StopSound(i, SNDCHAN_AUTO, SECRETS_SOUND);
}

public Action SecretSpamDelay(Handle timer, any client)
{
	blockSecretSpam[client] = false;
}

void Unready(int client)
{
	isPlayerReady[client] = false;
	CancelFullReady();
}

void ReturnTeamToSaferoom()
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		ReturnPlayerToSaferoom(index);
	}
}

void ReturnPlayerToSaferoom(int client)
{
	if (L4D2_IsHangingFromLedge(client))
	{
		L4D2_CheatCommand(client, "give", "health");
	}
	L4D2_CheatCommand(client, "warp_to_start_area");
}

void SurvivorsLock(bool e)
{
	SetConVarBool(god, e);
	SetConVarBool(sv_infinite_ammo, e);
	SetConVarBool(sb_stop, e);
}

void SetTeamFrozen(bool freezeStatus)
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		SetEntityMoveType(index, freezeStatus ? MOVETYPE_NONE : MOVETYPE_WALK);
	}
}

bool isAnyClientLoading()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (isClientLoading[i]) return true;
	}
	return false;
}

bool isFinishedLoading()
{
	if (!IsServerProcessing()) return false;
	bool IsHumansOnServer;
	for (int x = 1; x <= GetClientCount(true); x++)
	{
		if (IsClientInGame(x) && !IsFakeClient(x))
		{
			IsHumansOnServer = true;
			break;
		}
	}
	if (!IsHumansOnServer) return false;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i))
		{
			if (!IsClientInGame(i) && !IsFakeClient(i))
			{
				clientTimeout[i]++;
				if (isClientLoading[i])
				{
					if (clientTimeout[i] == 1)
					{
						isClientLoading[i] = true;
					}
				}
				
				if (clientTimeout[i] == READY_TIMEOUT)
				{
					isClientLoading[i] = false;
				}
			}
			else
			{
				isClientLoading[i] = false;
			}
		}
		else
			isClientLoading[i] = false;
	}
	return !isAnyClientLoading();
}

bool CheckFullReady()
{
	int readyCount = 0;
	int casterCount = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			if (L4D2_IsClientCaster(client))
			{
				casterCount++;
			}

			if ((IsPlayer(client) || L4D2_IsClientCaster(client)) && isPlayerReady[client])
			{
				readyCount++;
			}
		}
	}
	return readyCount >= GetConVarInt(survivor_limit) + GetConVarInt(z_max_player_zombies) + casterCount;
}

bool IsPlayer(int client)
{
	int team = GetClientTeam(client);
	return (team == 2 || team == 3);
}

int GetSeriousClientCount()
{
	int humans = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			humans++;
		}
	}
	return humans;
}

void SetEngineTime(int client)
{
	g_fButtonTime[client] = GetEngineTime();
}

void DisableEntities() 
{
	ActivateEntities("prop_door_rotating", "SetUnbreakable");
	MakePropsUnbreakable();
}

void EnableEntities() 
{	
	ActivateEntities("prop_door_rotating", "SetBreakable");
	MakePropsBreakable();
}

void ActivateEntities(char[] className, char[] inputName)
{
	int iEntity;
	while ((iEntity = FindEntityByClassname(iEntity, className)) != -1)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity))
		{
			continue;
		}
		if (GetEntProp(iEntity, Prop_Data, "m_spawnflags") & (1 << 19))
		{
			continue;
		}
		AcceptEntityInput(iEntity, inputName);
	}
}

void MakePropsUnbreakable()
{
	int iEntity;
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity))
		{
			continue;
		}
		DispatchKeyValueFloat(iEntity, "minhealthdmg", 10000.0);
	}
}

void MakePropsBreakable()
{
	int iEntity;
	while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity))
		{
			continue;
		}
		DispatchKeyValueFloat(iEntity, "minhealthdmg", 5.0);
	}
}
