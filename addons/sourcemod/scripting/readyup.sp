#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

#define MAX_FOOTERS 10
#define MAX_FOOTER_LEN 65

#define SECRETS_SOUND "/level/gnomeftw.wav"

public Plugin myinfo =
{
	name = "L4D2 Auto Ready-Up",
	author = "CanadaRox/趴趴酱改",
	description = "New and improved ready-up plugin.",
	version = "8.5",
	url = ""
};

ConVar l4d_ready_cfg_name, l4d_ready_max_players, l4d_ready_delay, l4d_ready_enable_sound, 
  l4d_ready_countdown_sound, l4d_ready_live_sound, l4d_ready_timeout, l4d_ready_mode, 
  god, sb_stop, sv_infinite_ammo, survivor_limit, z_max_player_zombies, sv_maxplayers;
Handle casterTrie, liveForward, menuPanel, readyCountdownTimer, allowedCastersTrie;
char readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
bool hiddenPanel[MAXPLAYERS+1], inLiveCountdown, inReadyUp, isPlayerReady[MAXPLAYERS+1], 
  blockSecretSpam[MAXPLAYERS+1], isClientLoading[MAXPLAYERS+1], bReadyUpMode;
char countdownSound[64], liveSound[64];
int clientTimeout[MAXPLAYERS+1], footerCounter = 0, readyDelay, g_Sprite, g_HaloSprite;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("AddStringToReadyFooter", Native_AddStringToReadyFooter);
	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("IsClientCaster", Native_IsClientCaster);
	CreateNative("IsIDCaster", Native_IsIDCaster);
	liveForward = CreateGlobalForward("OnRoundIsLive", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public void OnPluginStart()
{
	CreateConVar("l4d_ready_enabled", "1", "这个cvar不会做任何事情, 但如果它是0, 记录器不会记录这个游戏.", FCVAR_SS_ADDED, true, 0.0, true, 1.0);
	l4d_ready_cfg_name = CreateConVar("l4d_ready_cfg_name", "", "配置名称显示在准备好的面板上", FCVAR_SS_ADDED|FCVAR_PRINTABLEONLY);
	l4d_ready_max_players = CreateConVar("l4d_ready_max_players", "12", "在准备好的面板上显示的最大玩家人数.", FCVAR_SS_ADDED, true, 0.0, true, MAXPLAYERS+1.0);
	l4d_ready_delay = CreateConVar("l4d_ready_delay", "5", "在 Round 开始前倒数的秒数.", FCVAR_SS_ADDED, true, 0.0);
	l4d_ready_enable_sound = CreateConVar("l4d_ready_enable_sound", "1", "启动倒计时和现场声音");
	l4d_ready_countdown_sound = CreateConVar("l4d_ready_countdown_sound", "buttons/blip1.wav", "现场直播时播放的声音");
	l4d_ready_live_sound = CreateConVar("l4d_ready_live_sound", "buttons/blip2.wav", "现场直播时播放的声音");
	l4d_ready_timeout = CreateConVar("l4d_ready_timeout", "60", "地图载入成功后，等待读图慢的玩家多长时间开始倒计时");
	l4d_ready_mode = CreateConVar("l4d_ready_mode", "0", "0-定时解锁 1-手动解锁(ready-up方式)", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	
	bReadyUpMode = GetConVarBool(l4d_ready_mode);
	HookConVarChange(l4d_ready_mode, l4d_ready_mode_ValueChanged);
	
	HookEvent("bullet_impact", Event_BulletImpact);
	
	casterTrie = CreateTrie();
	allowedCastersTrie = CreateTrie();
	
	god = FindConVar("god");
	sb_stop = FindConVar("sb_stop");
	sv_infinite_ammo = FindConVar("sv_infinite_ammo");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	sv_maxplayers = FindConVar("sv_maxplayers");
	
	RegAdminCmd("sm_caster", Caster_Cmd, ADMFLAG_BAN, "Registers a player as a caster so the round will not go live unless they are ready");
	RegAdminCmd("sm_forcestart", ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	
	RegConsoleCmd("sm_hide", Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", Show_Cmd, "Shows a hidden ready-up panel");
	RegConsoleCmd("sm_notcasting", NotCasting_Cmd, "取消自己作为裁判或允许管理员取消其他玩家");
	RegConsoleCmd("sm_ready", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_unready", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_return", Return_Cmd, "如果您在未解冻的准备期间卡住, 请返回有效的安全室产卵");
	RegConsoleCmd("sm_cast", Cast_Cmd, "将呼叫玩家注册为裁判, 这样该回合将不会启动, 除非他们已经准备好");
	RegServerCmd("sm_resetcasters", ResetCaster_Cmd, "用于重置比赛之间的裁判. 这应该用在confogl_off.cfg或您的系统等效");
	RegServerCmd("sm_add_caster_id", AddCasterSteamID_Cmd, "用于将裁判添加到白名单中，即允许谁自注册为裁判");
	
	LoadTranslations("common.phrases");
}

public void OnPluginEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public int l4d_ready_mode_ValueChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	bReadyUpMode = GetConVarBool(l4d_ready_mode);
}


public void OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sun/overlay.vmt");
	
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
	isPlayerReady[client] = false;
	isClientLoading[client] = false;
	clientTimeout[client] = 0;
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

public int Native_IsClientCaster(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return view_as<int>(IsClientCaster(client));
}

public int Native_IsIDCaster(Handle plugin, int numParams)
{
	char buffer[64];
	GetNativeString(1, buffer, sizeof(buffer));
	return view_as<int>(IsIDCaster(buffer));
}

//======================================
//				CMDS
//======================================
public Action Cast_Cmd(int client, int args)
{	
	char buffer[64];
	GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer));
	int index = FindStringInArray(allowedCastersTrie, buffer);
	if (index != -1)
	{
		SetTrieValue(casterTrie, buffer, 1);
		ReplyToCommand(client, "You have registered yourself as a caster");
	}
	else
	{
		ReplyToCommand(client, "Your SteamID was not found in this server's caster whitelist. Contact the admins to get approved.");
	}
	return Plugin_Handled;
}

public Action Caster_Cmd(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_caster <player>");
		return Plugin_Handled;
	}
	
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));

	int target = FindTarget(client, buffer, true, false);
	if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
	{
		if (GetClientAuthId(target, AuthId_Steam3, buffer, sizeof(buffer)))
		{
			SetTrieValue(casterTrie, buffer, 1);
			ReplyToCommand(client, "注册 %N 作为裁判", target);
		}
		else
		{
			ReplyToCommand(client, "找不到Steam ID. 检查拼写错误并让玩家完全连接.");
		}
	}
	return Plugin_Handled;
}

public Action ResetCaster_Cmd(int args)
{
	ClearTrie(casterTrie);
	return Plugin_Handled;
}

public Action AddCasterSteamID_Cmd(int args)
{
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] != EOS) 
	{
		int index = FindStringInArray(allowedCastersTrie, buffer);
		if (index == -1)
		{
			PushArrayString(allowedCastersTrie, buffer);
			PrintToServer("[casters_database] Added '%s'", buffer);
		}
		else PrintToServer("[casters_database] '%s' 已经存在", buffer);
	}
	else PrintToServer("[casters_database] No args specified / empty buffer");
	return Plugin_Handled;
}

public Action Hide_Cmd(int client, int args)
{
	hiddenPanel[client] = true;
	return Plugin_Handled;
}

public Action Show_Cmd(int client, int args)
{
	hiddenPanel[client] = false;
	return Plugin_Handled;
}

public Action NotCasting_Cmd(int client, int args)
{
	char buffer[64];
	
	if (args < 1) // If no target is specified
	{
		GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer));
		RemoveFromTrie(casterTrie, buffer);
		return Plugin_Handled;
	}
	else // If a target is specified
	{
		AdminId id;
		id = GetUserAdmin(client);
		bool hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		
		if (!hasFlag)
		{
			ReplyToCommand(client, "只有管理员可以删除其他裁判. 如果您想删除自己, 请使用不带参数的sm_notcasting.");
			return Plugin_Handled;
		}
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		int target = FindTarget(client, buffer, true, false);
		if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
		{
			if (GetClientAuthId(target, AuthId_Steam3, buffer, sizeof(buffer)))
			{
				RemoveFromTrie(casterTrie, buffer);
				ReplyToCommand(client, "%N 不再是裁判", target);
			}
			else
			{
				ReplyToCommand(client, "找不到Steam ID. 检查拼写错误并让玩家完全连接.");
			}
		}
		return Plugin_Handled;
	}
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
	if (inReadyUp)
	{
		DoSecrets(client);
		isPlayerReady[client] = true;
		if (CheckFullReady())
			InitiateLiveCountdown();
	}
	return Plugin_Handled;
}

stock void DoSecrets(int client)
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

public Action SecretSpamDelay(Handle timer, any client)
{
	blockSecretSpam[client] = false;
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
	if (IsConnectedAndInGame(i) && !IsFakeClient(i))
	StopSound(i, SNDCHAN_AUTO, SECRETS_SOUND);
}

public Action Unready_Cmd(int client, int args)
{
	if (bReadyUpMode && inReadyUp)
	{
		isPlayerReady[client] = false;
		CancelFullReady();
	}
	return Plugin_Handled;
}

public Action Return_Cmd(int client, int args)
{
	if (client > 0
			&& inReadyUp
			&& GetClientTeam(client) == 2)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

//======================================
//				L4DT
//======================================
public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	if (inReadyUp)
	{
		ReturnTeamToSaferoom();
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//======================================
//				EVENT
//======================================
public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!inReadyUp) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if(GetClientTeam(client) != 2 || IsFakeClient(client)) return;
	
	// Check if the weapon is an enabled weapon type to tag
	if(GetWeaponType(client))
	{
		int Color[4];
		Color[3] = 100;
		Color[0] = GetRandomInt(0, 255);
		Color[1] = GetRandomInt(0, 255);
		Color[2] = GetRandomInt(0, 255);
		float Origin[3], Direction[3];
	
		Origin[0] = GetEventFloat(event, "x");
		Origin[1] = GetEventFloat(event, "y");
		Origin[2] = GetEventFloat(event, "z");
		
		float startPos[3];
		startPos[0] = Origin[0] ;
		startPos[1] = Origin[1];
		startPos[2] = Origin[2];
		
		float bulletPos[3];
		bulletPos = startPos;
		
		float LaserLife = 0.80, LaserWidth = 1.0, LaserOffset = 36.0;
	
		// Current player's EYE position
		float playerPos[3];
		GetClientEyePosition(client, playerPos);
		
		float lineVector[3];
		SubtractVectors(playerPos, startPos, lineVector);
		NormalizeVector(lineVector, lineVector);
		
		// Offset
		ScaleVector(lineVector, LaserOffset);
		// Find starting point to draw line from
		SubtractVectors(playerPos, lineVector, startPos);
		
		// Draw the line
		TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, LaserLife, LaserWidth, LaserWidth, 1, 0.0, Color, 0);
		
		TE_SendToAll();
		
		Direction[0] = GetRandomFloat(-1.0, 1.0);
		Direction[1] = GetRandomFloat(-1.0, 1.0);
		Direction[2] = GetRandomFloat(-1.0, 1.0);
		TE_SetupBloodSprite(Origin, Direction, Color, 5000, g_Sprite, g_HaloSprite);
		
		TE_SendToAll(0.0);
	}
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
		isClientLoading[i] = true;
		clientTimeout[i] = 0;
	}
	
	UpdatePanel();
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	
	inReadyUp = true;
	inLiveCountdown = false;
	
	readyCountdownTimer = INVALID_HANDLE;
	
	SurvivorsLock(true);
	
	if (!bReadyUpMode)
	{
		CreateTimer(10.0, LoadingTimer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	
	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (IsValidInGame(client) && !IsFakeClient(client))
	{
		isClientLoading[client] = false;
		clientTimeout[client] = 0;
	}
	
	if (bReadyUpMode)
	{
		if (oldteam > 1 || nowteam > 1)
		{
			CancelFullReady();
		}
	}
}

public Action MenuRefresh_Timer(Handle timer)
{
	if (inReadyUp)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action LoadingTimer(Handle timer)
{
	if (!isFinishedLoading())
	{
		return Plugin_Continue;
	}
	InitiateLiveCountdown();
	return Plugin_Stop;
}

void InitiateLiveCountdown()
{
	if (readyCountdownTimer == INVALID_HANDLE)
	{
		ReturnTeamToSaferoom();
		SetTeamFrozen(true);
		PrintHintTextToAll("即将开始!", (bReadyUpMode ? "\n输入 !unready 取消准备" : ""));
		inLiveCountdown = true;
		readyDelay = GetConVarInt(l4d_ready_delay);
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
		if (GetConVarBool(l4d_ready_enable_sound))
		{
			EmitSoundToAll(liveSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("请等待: %d秒%s", readyDelay, (bReadyUpMode ? "\n输入 !unready 取消准备" : ""));
		if (GetConVarBool(l4d_ready_enable_sound))
		{
			EmitSoundToAll(countdownSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
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

void UpdatePanel()
{
	if (menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
		menuPanel = INVALID_HANDLE;
	}
	
	menuPanel = CreatePanel();
	
	char ServerBuffer[128];
	char ServerName[32];
	char cfgBuf[128];
	char ReadyModeBuffer[32];
	
	GetConVarString(FindConVar("hostname"), ServerName, sizeof(ServerName));
	GetConVarString(l4d_ready_cfg_name, cfgBuf, sizeof(cfgBuf));
	Format(ServerBuffer, sizeof(ServerBuffer), "▶ Server: %s \n▶ Slots: %d/%d \n▶ Config: %s", ServerName, GetHumanCount(), GetConVarInt(sv_maxplayers), cfgBuf);
	DrawPanelText(menuPanel, ServerBuffer);
	
	Format(ReadyModeBuffer, sizeof(ReadyModeBuffer), "▶ Ready Mode: %s", (bReadyUpMode ? "Ready-Up" : "Auto-Start"));
	DrawPanelText(menuPanel, ReadyModeBuffer);
	
	DrawPanelText(menuPanel, "▶ Cmds: !help");
	
	//DrawPanelText(menuPanel, sCmd);
	
	DrawPanelText(menuPanel, " \n");
	
	char survivorBuffer[800] = "";
	char infectedBuffer[800] = "";
	char casterBuffer[800] = "";
	char specBuffer[800] = "";
	
	int playerCount = 0;
	int specCount = 0;
	int timelimit = GetConVarInt(l4d_ready_timeout);
	
	char nameBuf[MAX_NAME_LENGTH*2];
	char authBuffer[64];
	bool caster;
	int dummy;
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client))
		{
			GetClientName(client, nameBuf, sizeof(nameBuf));
			
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
				
				if (GetClientTeam(client) == 2)
				{
					StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
				}
				else if (GetClientTeam(client) == 3)
				{
					StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
				}
				else
				{
					StrCat(specBuffer, sizeof(specBuffer), nameBuf);
				}
			}
			else
			{
				++playerCount;
				GetClientAuthId(client, AuthId_Steam3, authBuffer, sizeof(authBuffer));
				caster = GetTrieValue(casterTrie, authBuffer, dummy);
				if (IsPlayer(client) || caster)
				{
					if (isPlayerReady[client])
					{
						if (!inLiveCountdown) PrintHintText(client, "你已经准备.\n输入 !unready 取消准备.");
						Format(nameBuf, sizeof(nameBuf), "->☑ %s%s\n", nameBuf, caster ? " [Caster]" : "");
					}
					else
					{
						if (!inLiveCountdown) PrintHintText(client, "你还没准备.\n输入 !ready 准备.");
						Format(nameBuf, sizeof(nameBuf), "->☐ %s%s\n", nameBuf, caster ? " [Caster]" : "");
					}
					
					if (GetClientTeam(client) == 2)
					{
						StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
					}
					else if (GetClientTeam(client) == 3)
					{
						StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
					}
					else
					{
						StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
					}
				}
				else
				{
					++specCount;
					if (playerCount <= GetConVarInt(l4d_ready_max_players))
					{
						Format(nameBuf, sizeof(nameBuf), "->%d. %s\n", specCount, nameBuf);
						StrCat(specBuffer, sizeof(specBuffer), nameBuf);
					}
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
		DrawPanelItem(menuPanel, "生还者");
		DrawPanelText(menuPanel, survivorBuffer);
	}
	
	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#buy", "<- TROLL");
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		DrawPanelItem(menuPanel, "感染者");
		DrawPanelText(menuPanel, infectedBuffer);
	}
	
	bufLen = strlen(casterBuffer);
	if (bufLen != 0)
	{
		casterBuffer[bufLen] = '\0';
		ReplaceString(casterBuffer, sizeof(casterBuffer), "#buy", "<- TROLL");
		ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_");
		DrawPanelItem(menuPanel, "裁判");
		DrawPanelText(menuPanel, casterBuffer);
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		DrawPanelItem(menuPanel, "观众");
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (playerCount > GetConVarInt(l4d_ready_max_players))
			FormatEx(specBuffer, sizeof(specBuffer), "->1. Many (%d)", specCount);
		DrawPanelText(menuPanel, specBuffer);
	}
	
	DrawPanelText(menuPanel, " \n");
	
	for (int i = 0; i < MAX_FOOTERS; i++)
	{
		DrawPanelText(menuPanel, readyFooter[i]);
	}
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsConnectedAndInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
		{
			SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

public int DummyHandler(Handle menu, MenuAction action, int param1, int param2) { }

//======================================
//				Actions
//======================================
/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (inReadyUp)
	{
		if (client != 0 && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			if (GetEntityFlags(client) & FL_INWATER)
			{
				ReturnPlayerToSaferoom(client, false);
			}
		}
	}
}

//======================================
//				Other
//======================================
void ReturnTeamToSaferoom()
{
	int warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	int give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}

void ReturnPlayerToSaferoom(int client, bool flagsSet = true)
{
	int warp_flags;
	int give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

void SurvivorsLock(bool e)
{
	SetConVarFlags(god, GetConVarFlags(god) & ~FCVAR_NOTIFY);
	SetConVarBool(god, e);
	SetConVarFlags(god, GetConVarFlags(god) | FCVAR_NOTIFY);
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(sv_infinite_ammo) & ~FCVAR_NOTIFY);
	SetConVarBool(sv_infinite_ammo, e);
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(sv_infinite_ammo) | FCVAR_NOTIFY);
	SetConVarBool(sb_stop, e);
}

void SetTeamFrozen(bool freezeStatus)
{
	for (int client = 1; client <= MaxClients; client++)
	{
		if (IsClientConnected(client) && IsClientInGame(client) && GetClientTeam(client) == 2)
		{
			SetEntityMoveType(client, freezeStatus ? MOVETYPE_NONE : MOVETYPE_WALK);
		}
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
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i))
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
				
				if (clientTimeout[i] == GetConVarInt(l4d_ready_timeout))
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
		if (IsConnectedAndInGame(client))
		{
			if (IsClientCaster(client))
			{
				casterCount++;
			}

			if ((IsPlayer(client) || IsClientCaster(client)) && isPlayerReady[client])
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

bool IsClientCaster(int client)
{
	char buffer[64];
	GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer));
	return IsIDCaster(buffer);
}

bool IsIDCaster(const char[] AuthID)
{
	int dummy;
	return GetTrieValue(casterTrie, AuthID, dummy);
}

int GetHumanCount()
{
	int humans = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i) && !IsFakeClient(i))
		{
			humans++;
		}
	}
	return humans;
}

bool GetWeaponType(int client)
{
	// Get current weapon
	char weapon[32];
	GetClientWeapon(client, weapon, 32);
	
	if(StrEqual(weapon, "weapon_hunting_rifle") || StrContains(weapon, "sniper") >= 0) return true;
	if(StrContains(weapon, "weapon_rifle") >= 0) return true;
	if(StrContains(weapon, "pistol") >= 0) return true;
	if(StrContains(weapon, "smg") >= 0) return true;
	if(StrContains(weapon, "shotgun") >=0) return true;
	
	return false;
}
