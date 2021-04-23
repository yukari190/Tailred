#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <geoip>
#include <adminmenu>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>
#include <[TR]builtinvotes_native>

#define PLUGIN_TAG					"[A4D] "
#define MENU_DISPLAY_TIME		20

public Plugin myinfo =
{
	name = "Server Function",
	description = "",
	author = "",
	version = "1.0",
	url = ""
};

enum NetVarsStruct
{
	mincmdrate = 0,
	maxcmdrate,
	minupdaterate,
	maxupdaterate,
	minrate,
	maxrate
};

enum VoteType
{
	VoteType_None,
	VoteType_SetMaxPlayers,
	VoteType_RestoreHealth,
	VoteType_ChangeMap
};

Handle top_menu;
Handle admin_menu;

TopMenuObject spawn_special_infected_menu;
TopMenuObject spawn_weapons_menu;
TopMenuObject spawn_melee_weapons_menu;
TopMenuObject spawn_items_menu;
TopMenuObject respawn_menu;
TopMenuObject teleport_menu;

ConVar sv_minrate;
ConVar sv_maxrate;
ConVar sv_minupdaterate;
ConVar sv_maxupdaterate;
ConVar sv_mincmdrate;
ConVar sv_maxcmdrate;
ConVar l4d_ready_cfg_name;

float g_pos[3];

int iSlot;
int g_originClient = -1;
VoteType iVoteType;

char netvars[6][2];
bool alltp;
bool bVoteStart;

KeyValues g_hInfoKV;
char mapname[64];
char TargetMap_Code[128];

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/shared/hostname.txt");
	Handle hNameFile = OpenFile(sBuffer, "r");
	if (hNameFile == INVALID_HANDLE) LogError("找不到 <hostname.txt>.");
	char sName[128];
	ReadFileLine(hNameFile, sName, sizeof(sName));
	SetConVarString(FindConVar("hostname"), sName);
	delete hNameFile;
	
	g_hInfoKV = new KeyValues("MapLists");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "../../cfg/lgofnoc/shared/maplists.txt");
	if (!FileToKeyValues(g_hInfoKV, sBuffer)) LogMessage("找不到 <maplists.txt>.");
	
	sv_minrate = FindConVar("sv_minrate");
	sv_maxrate = FindConVar("sv_maxrate");
	sv_minupdaterate = FindConVar("sv_minupdaterate");
	sv_maxupdaterate = FindConVar("sv_maxupdaterate");
	sv_mincmdrate = FindConVar("sv_mincmdrate");
	sv_maxcmdrate = FindConVar("sv_maxcmdrate");
	l4d_ready_cfg_name = FindConVar("l4d_ready_cfg_name");
	
	sv_minrate.AddChangeHook(ConVarChange);
	sv_maxrate.AddChangeHook(ConVarChange);
	sv_minupdaterate.AddChangeHook(ConVarChange);
	sv_maxupdaterate.AddChangeHook(ConVarChange);
	sv_mincmdrate.AddChangeHook(ConVarChange);
	sv_maxcmdrate.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	RegConsoleCmd("sm_spectate", Command_Spectate);
	RegConsoleCmd("sm_spec", Command_Spectate);
	RegConsoleCmd("sm_s", Command_Spectate);
	RegConsoleCmd("sm_join", Command_JoinSurvivor);
	RegConsoleCmd("sm_j", Command_JoinSurvivor);
	RegConsoleCmd("sm_slots", SlotsRequest);
	RegConsoleCmd("sm_fixbots", FixBots);
	RegConsoleCmd("sm_zs", Command_Suicide, "玩家自杀");
	RegConsoleCmd("sm_rhp", Command_RestoreHealth);
	RegConsoleCmd("sm_vcm", ChangeMaps);
	
	if (LibraryExists("adminmenu") && ((top_menu = GetAdminTopMenu()) != INVALID_HANDLE))
	  OnAdminMenuReady(top_menu);
	
	AddCommandListener(TeamSay_Callback, "say_team");
	
	HookEvent("player_disconnect", Event_PlayerDisconnect);
	HookEvent("finale_win", FinaleWin_Event, EventHookMode_PostNoCopy);
	HookEvent("player_changename", Event_NameChange, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnectPre, EventHookMode_Pre);
	HookEvent("revive_success", EventReviveSuccess);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	SetConVarInt(sv_minrate, 30000); // Minimum value of rate.
	SetConVarInt(sv_maxrate, 60000); // Maximum Value of rate.
	SetConVarInt(sv_minupdaterate, 30); // Minimum Value of cl_updaterate.
	SetConVarInt(sv_maxupdaterate, 60); // Maximum Value of cl_updaterate.
	SetConVarInt(sv_mincmdrate, 30); // Minimum value of cl_cmdrate.
	SetConVarInt(sv_maxcmdrate, 60); // Maximum value of cl_cmdrate.
}

public void OnMapStart()
{
	GetCurrentMap(mapname, sizeof(mapname));
}

public void L4D2_OnRealRoundStart()
{
	bVoteStart = false;
}

public void L4D2_OnRealRoundEnd()
{
	if (L4D2_IsVersus() && L4D_IsMissionFinalMap() && L4D2_IsSecondRound())
	{
		CheckMapForChange();
	}
}

public void OnConfigsExecuted()
{
    GetConVarString(sv_mincmdrate, netvars[mincmdrate], sizeof(netvars));
    GetConVarString(sv_maxcmdrate, netvars[maxcmdrate], sizeof(netvars));
    GetConVarString(sv_minupdaterate, netvars[minupdaterate], sizeof(netvars));
    GetConVarString(sv_maxupdaterate, netvars[maxupdaterate], sizeof(netvars));
    GetConVarString(sv_minrate, netvars[minrate], sizeof(netvars));
    GetConVarString(sv_maxrate, netvars[maxrate], sizeof(netvars));
}

public void OnClientPutInServer(int client)
{
	CreateTimer(30.0, Announce_Timer, client);
}

public Action Announce_Timer(Handle timer, any client)
{
	if (L4D2_IsValidClient(client) && !IsFakeClient(client))
	{
		L4D2_CPrintToChat(client, "{LG}命令: !match | !vcm | !slots | !rhp");
	}
}

public void OnClientSettingsChanged(int client)
{
	if (L4D2_IsValidClient(client) && !IsFakeClient(client))
	{
		AdjustRates(client);
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (L4D2_IsValidClient(client) && !IsFakeClient(client) && GetClientCount(true) < MaxClients)
	{
		char rawmsg[301];
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 加入游戏.", 1, rawmsg);
		L4D2_CPrintToChatAll("%s", rawmsg);
	}
}

public Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!L4D2_IsValidClient(client) || IsFakeClient(client)) return;
	if (L4D2_IsSpectator(client))
	  SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1);
	else
	  SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	CreateTimer(1.0, TimerAdjustRates, client);
}

public Action TimerAdjustRates(Handle timer, any client)
{
	AdjustRates(client);
}

//Event
public Action Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!L4D2_IsValidClient(client) || IsFakeClient(client)) return;
	CreateTimer(10.0, UL_PlayerDisconnectTimer);
}

public Action UL_PlayerDisconnectTimer(Handle timer)
{
	if (!IsHumansOnServer())
	{
		char sInfo[64];
		KvRewind(g_hInfoKV);
		if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
		{
			do
			{
				KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
				if (StrContains(mapname, sInfo[3], false) != -1)
				{
					strcopy(TargetMap_Code, sizeof(TargetMap_Code), sInfo);
					CreateTimer(0.1, ChangeLevel);
					break;
				}
			}
			while (KvGotoNextKey(g_hInfoKV));
		}
	}
}

public Action FinaleWin_Event(Event event, const char[] name, bool dontBroadcast)
{
	CheckMapForChange();
}

int CheckMapForChange()
{
	char sInfo[64];
	KvRewind(g_hInfoKV);
	if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
	{
		do
		{
			KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
			if (StrContains(mapname, sInfo[3], false) != -1)
			{
				KvGetString(g_hInfoKV, "nextmap", TargetMap_Code, sizeof(TargetMap_Code));
				CreateTimer(L4D2_IsVersus() ? 6.0 : 3.0, ChangeLevel);
				break;
			}
		}
		while (KvGotoNextKey(g_hInfoKV));
	}
}

public Action Event_NameChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && L4D2_IsSpectator(client))
	{
		return Plugin_Handled;
	}
    return Plugin_Continue;
}

public Action EventReviveSuccess(Event event, const char[] name, bool dontBroadcast)
{
	if (event.GetBool("lastlife"))
	{
		int target = GetClientOfUserId(event.GetInt("subject"));
		if (!L4D2_IsValidClient(target)) return;
		PrintHintTextToAll("%N 黑白了!", target);
	}
}

public Action Event_PlayerDisconnectPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && !IsFakeClient(client))
	{
		char rawmsg[301], reason[65];
		event.GetString("reason", reason, sizeof(reason));
		ReplaceString(reason, sizeof(reason), "\n", " ");
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 断开连接. {O}原因: {W}%s", 1, rawmsg, reason);
		L4D2_CPrintToChatAll("%s", rawmsg);
	}
}

// Command
public Action TeamSay_Callback(int client, char[] command, int args)
{
    if (L4D2_IsValidClient(client) && (L4D2_IsSurvivor(client) || L4D2_IsInfected(client)))
    {
        char sChat[256];
        GetCmdArgString(sChat, sizeof(sChat));
        StripQuotes(sChat);
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsClientInGame(i) && L4D2_IsSpectator(i))
            {
                L4D2_CPrintToChat(i, "{W}%s%N {W}: %s", L4D2_IsSurvivor(client) ? "(生还者) {B}" : "(感染者) {R}", client, sChat);
            }
        }
    }
    return Plugin_Continue;
}


public Action FixBots(int client, int args)
{
	L4D2_FillBots();
	return Plugin_Handled;
}

public Action Command_Spectate(int client, int args)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Handled;
	L4D2_Team team = view_as<L4D2_Team>(GetClientTeam(client));
	if (team == L4D2Team_Survivor)
	{
		L4D2_ChangeClientTeam(client, L4D2Team_Spectator, true);
		PrintToChatAll("\x01玩家 \x03%N\x01 表示要去趴会_(:зゝ∠)_", client);
	}
	else if (team == L4D2Team_Infected)
	{
		if (L4D2_GetInfectedClass(client) != L4D2Infected_Tank)
		{
			ForcePlayerSuicide(client);
		}
		L4D2_ChangeClientTeam(client, L4D2Team_Spectator, true);
		PrintToChatAll("\x01玩家 \x03%N\x01 表示要去趴会_(:зゝ∠)_", client);
	}
	else if (team == L4D2Team_Spectator)
	{
		L4D2_ChangeClientTeam(client, L4D2Team_Infected, true);
		CreateTimer(0.1, RespecDelay_Timer, client);
	}
	return Plugin_Handled;
}

public Action RespecDelay_Timer(Handle timer, any client)
{
	L4D2_ChangeClientTeam(client, L4D2Team_Spectator, true);
}

public Action Command_JoinSurvivor(int client, int args)
{
	if (!L4D2_IsValidClient(client)) return Plugin_Handled;
	L4D2_ChangeClientTeam(client, L4D2Team_Survivor, false);
	return Plugin_Handled;
}

public Action SlotsRequest(int client, int args)
{
	if (args < 1) return Plugin_Handled;
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	iSlot = StringToInt(buffer);
	if (iSlot < 0 || iSlot > 24)
	{
		PrintToServer("[Slots]有效范围 0 - 24");
		L4D2_CPrintToChatAll("{B}[{W}Slots{B}] {W}有效范围 0 - 24");
		return Plugin_Handled;
	}
	if (!L4D2_IsValidClient(client)) L4D2_SetMaxPlayers(iSlot);
	else
	{
		iVoteType = VoteType_SetMaxPlayers;
		Format(buffer, sizeof(buffer), "将人数设置为 '%s'?");
		bVoteStart = true;
		BuiltinVotes_StartVoteAllTeam(client, buffer);
	}
	return Plugin_Handled;
}

public Action Command_RestoreHealth(int client, int args)
{
	if (!client) return Plugin_Handled;
	iVoteType = VoteType_RestoreHealth;
	bVoteStart = true;
	BuiltinVotes_StartVoteAllTeam(client, "是否恢复生还者生命值?");
	return Plugin_Handled;
}

public Action ChangeMaps(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (g_hInfoKV == INVALID_HANDLE)
	{
		LogError("[NativeVotes] 初始化投票失败, 找不到 <%s>.", "configs/maplists.txt");
		return Plugin_Handled;
	}
	
	char sInfo[64], map_name[64];
	KvRewind(g_hInfoKV);
	if (KvJumpToKey(g_hInfoKV, sInfo) && KvGotoFirstSubKey(g_hInfoKV))
	{
		Handle hMenu = CreateMenu(Start_Menu);
		SetMenuTitle(hMenu, "请选择地图:");
		do
		{
			KvGetSectionName(g_hInfoKV, sInfo, sizeof(sInfo));
			if (IsMapValid(sInfo))
			{
				KvGetString(g_hInfoKV, "name", map_name, sizeof(map_name));
				AddMenuItem(hMenu, sInfo, map_name);
			}
		}
		while (KvGotoNextKey(g_hInfoKV));
		SetMenuExitBackButton(hMenu, true);
		SetMenuExitButton(hMenu, true);
		DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
	}
	return Plugin_Handled;
}

public int Start_Menu(Handle menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char sInfo[64], sBuffer[64];
		GetMenuItem(menu, itemNum, sInfo, sizeof(sInfo), _, sBuffer, sizeof(sBuffer));
		strcopy(TargetMap_Code, sizeof(TargetMap_Code), sInfo);
		iVoteType = VoteType_ChangeMap;
		Format(sBuffer, sizeof(sBuffer), "将地图更改为 %s ?", sBuffer);
		bVoteStart = true;
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

public void BuiltinVotes_VoteResult()
{
	if (bVoteStart)
	{
		switch (iVoteType)
		{
			case VoteType_SetMaxPlayers: L4D2_SetMaxPlayers(iSlot);
			case VoteType_RestoreHealth: RestoreHealth();
			case VoteType_ChangeMap: CreateTimer(2.5, ChangeLevel);
		}
		iVoteType = VoteType_None;
	}
	bVoteStart = false;
}

public Action Command_Suicide(int client, int args)
{
	if (!client || L4D2_IsVersus()) return Plugin_Handled;
	ServerCommand("sm_slay \"%N\"", client);
	PrintToChatAll("\x01玩家 \x03%N\x01 自爆菊花而死_(:зゝ∠❀)_", client);
	PrintHintTextToAll("玩家 %N 自爆菊花而死_(:зゝ∠❀)_", client);
	return Plugin_Handled;
}

//Utility
void AdjustRates(int client)
{
	if (GetClientTeam(client) <= 1)
	{
		SendConVarValue(client, sv_mincmdrate, "30");
		SendConVarValue(client, sv_maxcmdrate, "30");
		SendConVarValue(client, sv_minupdaterate, "30");
		SendConVarValue(client, sv_maxupdaterate, "30");
		SendConVarValue(client, sv_minrate, "10000");
		SendConVarValue(client, sv_maxrate, "10000");
		SetClientInfo(client, "cl_updaterate", "30");
		SetClientInfo(client, "cl_cmdrate", "30");
		SetClientInfo(client, "rate", "10000");
	}
	else
	{
		SendConVarValue(client, sv_mincmdrate, netvars[maxcmdrate]);
		SendConVarValue(client, sv_maxcmdrate, netvars[maxcmdrate]);
		SendConVarValue(client, sv_minupdaterate, netvars[maxupdaterate]);
		SendConVarValue(client, sv_maxupdaterate, netvars[maxupdaterate]);
		SendConVarValue(client, sv_minrate, netvars[maxrate]);
		SendConVarValue(client, sv_maxrate, netvars[maxrate]);
		SetClientInfo(client, "cl_updaterate", netvars[maxupdaterate]);
		SetClientInfo(client, "cl_cmdrate", netvars[maxcmdrate]);
		SetClientInfo(client, "rate", netvars[maxrate]);
	}
}

void PrintFormattedMessageToAll(char rawmsg[301], int client)
{
	char steamid[256], ip[16], country[46];
	bool bIsLanIp;
	
	GetClientAuthId(client, AuthId_Steam3, steamid, sizeof(steamid));
	GetClientIP(client, ip, sizeof(ip)); 
	bIsLanIp = L4D2_IsLanIP(ip);
	if (!GeoipCountry(ip, country, sizeof(country)))
	{
		if (bIsLanIp) Format(country, sizeof(country), "%s", "局域网", LANG_SERVER);
		else Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	}
	if (StrEqual(country, "")) Format(country, sizeof(country), "%s", "未知的国家", LANG_SERVER);
	if (StrContains(country, "United", false) != -1 || StrContains(country, "Republic", false) != -1 || 
	StrContains(country, "Federation", false) != -1 || StrContains(country, "Island", false) != -1 || 
	StrContains(country, "Netherlands", false) != -1 || StrContains(country, "Isle", false) != -1 || 
	StrContains(country, "Bahamas", false) != -1 || StrContains(country, "Maldives", false) != -1 || 
	StrContains(country, "Philippines", false) != -1 || 
	StrContains(country, "Vatican", false) != -1) Format(country, sizeof(country), "The %s", country);
	
	Format(rawmsg, sizeof(rawmsg), "%s {O}%N {G}%s{W} ({O}%s{W}), ", L4D2_IsClientAdmin(client) ? "管理员" : "玩家", 
	client, steamid, country);
}

void RespawnPlayer(int client, int player_id)
{
	//bool canTeleport = SetTeleportEndPoint(client);
	L4D2_SetPlayerRespawn(player_id);
	/*Do_SpawnItem(player_id, "smg");
	
	if(canTeleport)
		PerformTeleport(client,player_id,g_pos);*/
	GetClientAbsOrigin(client, g_pos);
	g_pos[2]+=40.0;
	TeleportEntity(player_id, g_pos, NULL_VECTOR, NULL_VECTOR);
}

void Do_SpawnInfected(int client, const char[] type)
{
	char arguments[16];
	char feedback[64];
	Format(feedback, sizeof(feedback), "A %s has been spawned", type);
	Format(arguments, sizeof(arguments), "%s", type);
	L4D2_CheatCommand(client, "z_spawn", arguments);
	NotifyPlayers(client, feedback);
	LogAction(client, -1, "[NOTICE]: (%L) has spawned a %s", client, type);
}

void Do_SpawnItem(int client, const char[] type)
{
	char feedback[64], buffer[24];
	Format(feedback, sizeof(feedback), "A %s has been spawned", type);
	if (client == 0) ReplyToCommand(client, "Can not use this command from the console."); 
	else
	{
		Format(buffer, sizeof(buffer), "%s", type);
		L4D2_CheatCommand(client, "give", buffer);
		NotifyPlayers(client, feedback);
		LogAction(client, -1, "[NOTICE]: (%L) has spawned a %s", client, type);
	}
}

void Do_CreateEntity(int client, const char[] name, const char[] model, float location[3], const bool zombie)
{
	int entity = CreateEntityByName(name);
	if (StrEqual(model, "PROVIDED") == false)
		SetEntityModel(entity, model);
	DispatchSpawn(entity);
	if (zombie)
	{
		int ticktime = RoundToNearest(  GetGameTime() / GetTickInterval()  ) + 5;
		SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
		location[2] -= 25.0; // reduce the 'drop' effect
	}
	ActivateEntity(entity);
	TeleportEntity(entity, location, NULL_VECTOR, NULL_VECTOR);
	LogAction(client, -1, "[NOTICE]: (%L) has created a %s (%s)", client, name, model);
}

void RestoreHealth()
{
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			L4D2_CheatCommand(index, "give", "health");
			SetEntPropFloat(index, Prop_Send, "m_healthBuffer", 0.0);		
			SetEntProp(index, Prop_Send, "m_currentReviveCount", 0); //reset incaps
			SetEntProp(index, Prop_Send, "m_bIsOnThirdStrike", false);
		}
	}
}

void NotifyPlayers(int client, const char[] message)
{
	ShowActivity2(client, PLUGIN_TAG, message);
}

bool Misc_TraceClientViewToLocation(int client, float location[3])
{
	float vAngles[3], vOrigin[3];
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);
	// PrintToChatAll("Running Code %f %f %f | %f %f %f", vOrigin[0], vOrigin[1], vOrigin[2], vAngles[0], vAngles[1], vAngles[2]);
	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitSelf, client);
	if(TR_DidHit(trace))
	{
		TR_GetEndPosition(location, trace);
		CloseHandle(trace);
		// PrintToChatAll("Collision at %f %f %f", location[0], location[1], location[2]);
		return true;
	}
	CloseHandle(trace);
	return false;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	if(entity == data) // Check if the TraceRay hit the itself.
	{
		return false; // Don't let the entity be hit
	}
	return true; // It didn't hit itself
}

public void TeleportEntityEx(int originClient, int targetClient, float targetPos[3])
{
	GetClientAbsOrigin(targetClient, targetPos);
	TeleportEntity(originClient, targetPos, NULL_VECTOR, NULL_VECTOR);
}

public Action ChangeLevel(Handle timer)
{
	if (IsMapValid(TargetMap_Code)) ForceChangeLevel(TargetMap_Code, "");
	else ForceChangeLevel("c1m1_hotel", "");
}

bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}


//AdminMenu
public void OnAdminMenuReady(Handle menu)
{
	if (menu == admin_menu) return;
	admin_menu = menu;
	AddToTopMenu(admin_menu, "All4Dead 命令", TopMenuObject_Category, Menu_CategoryHandler, INVALID_TOPMENUOBJECT);
	TopMenuObject a4d_menu = FindTopMenuCategory(admin_menu, "All4Dead 命令");
	if (a4d_menu == INVALID_TOPMENUOBJECT) return;
	teleport_menu = AddToTopMenu(admin_menu, "a4d_teleport_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_teleport_menu", ADMFLAG_CHEATS);
	respawn_menu = AddToTopMenu(admin_menu, "a4d_respawn_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_respawn_menu", ADMFLAG_CHEATS);
	spawn_special_infected_menu = AddToTopMenu(admin_menu, "a4d_spawn_special_infected_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_spawn_special_infected_menu", ADMFLAG_CHEATS);
	spawn_melee_weapons_menu = AddToTopMenu(admin_menu, "a4d_spawn_melee_weapons_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_spawn_melee_weapons_menu", ADMFLAG_CHEATS);
	spawn_weapons_menu = AddToTopMenu(admin_menu, "a4d_spawn_weapons_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_spawn_weapons_menu", ADMFLAG_CHEATS);
	spawn_items_menu = AddToTopMenu(admin_menu, "a4d_spawn_items_menu", TopMenuObject_Item, Menu_TopItemHandler, a4d_menu, "a4d_spawn_items_menu", ADMFLAG_CHEATS);
}

public void Menu_CategoryHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength) {
	if (action == TopMenuAction_DisplayTitle) Format(buffer, maxlength, "All4Dead 命令:");
	else if (action == TopMenuAction_DisplayOption) Format(buffer, maxlength, "All4Dead 命令");
}

public void Menu_TopItemHandler(Handle topmenu, TopMenuAction action, TopMenuObject object_id, int client, char[] buffer, int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		if (object_id == teleport_menu)
			Format(buffer, maxlength, "传送 玩家");
		else if (object_id == respawn_menu)
			Format(buffer, maxlength, "复活 玩家");
		else if (object_id == spawn_special_infected_menu)
			Format(buffer, maxlength, "创建 特殊感染者");
		else if (object_id == spawn_melee_weapons_menu)
			Format(buffer, maxlength, "创建 近战武器");
		else if (object_id == spawn_weapons_menu)
			Format(buffer, maxlength, "创建 武器");
		else if (object_id == spawn_items_menu)
			Format(buffer, maxlength, "创建 物品");
	}
	else if (action == TopMenuAction_SelectOption)
	{
		if (object_id == teleport_menu)
			Menu_CreateTeleportMenu(client, false);
		else if (object_id == respawn_menu)
			Menu_CreateRespawnMenu(client, false);
		else if (object_id == spawn_special_infected_menu)
			Menu_CreateSpecialInfectedMenu(client, false);
		else if (object_id == spawn_melee_weapons_menu)
			Menu_CreateMeleeWeaponMenu(client, false);
		else if (object_id == spawn_weapons_menu)
			Menu_CreateWeaponMenu(client, false);
		else if (object_id == spawn_items_menu)
			Menu_CreateItemMenu(client, false);
	}
}

public Action Menu_CreateSpecialInfectedMenu(int client, int args)
{
	Handle menu = CreateMenu(Menu_SpawnSInfectedHandler);
	SetMenuTitle(menu, "创建 特殊感染者");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "st", "创建 tank");
	AddMenuItem(menu, "sw", "创建 witch");
	AddMenuItem(menu, "sb", "创建 boomer");
	AddMenuItem(menu, "sh", "创建 hunter");
	AddMenuItem(menu, "ss", "创建 smoker");
	AddMenuItem(menu, "sp", "创建 spitter");
	AddMenuItem(menu, "sj", "创建 jockey");
	AddMenuItem(menu, "sc", "创建 charger");
	AddMenuItem(menu, "sb", "创建 mob");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SpawnSInfectedHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		switch (itempos)
		{
			case 0:
				Do_SpawnInfected(cindex, "tank");
			case 1:
				Do_SpawnInfected(cindex, "witch");
			case 2:
				Do_SpawnInfected(cindex, "boomer");
			case 3:
				Do_SpawnInfected(cindex, "hunter");
			case 4:
				Do_SpawnInfected(cindex, "smoker");
			case 5:
				Do_SpawnInfected(cindex, "spitter");
			case 6:
				Do_SpawnInfected(cindex, "jockey");
			case 7:
				Do_SpawnInfected(cindex, "charger");
			case 8:
				Do_SpawnInfected(cindex, "mob");
		}
		Menu_CreateSpecialInfectedMenu(cindex, false);
	}
	else if (action == MenuAction_End) CloseHandle(menu);
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}

public Action Menu_CreateItemMenu(int client, int args)
{
	Handle menu = CreateMenu(Menu_SpawnItemsHandler);
	SetMenuTitle(menu, "创建 物品");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "sd", "创建 除颤器");
	AddMenuItem(menu, "sm", "创建 急救包");
	AddMenuItem(menu, "sp", "创建 药丸");
	AddMenuItem(menu, "sa", "创建 肾上腺素");
	AddMenuItem(menu, "sv", "创建 燃烧弹");
	AddMenuItem(menu, "sb", "创建 土制炸弹");
	AddMenuItem(menu, "sb", "创建 胆汁罐");
	AddMenuItem(menu, "sg", "创建 汽油桶");
	AddMenuItem(menu, "st", "创建 丙烷罐");
	AddMenuItem(menu, "so", "创建 氧气罐");
	AddMenuItem(menu, "sa", "创建 弹药堆");
	AddMenuItem(menu, "si", "创建 燃烧弹包");
	AddMenuItem(menu, "se", "创建 高爆弹包");
	AddMenuItem(menu, "lp", "创建 激光瞄准包");
	AddMenuItem(menu, "gn", "创建 地精玩偶");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SpawnItemsHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		switch (itempos)
		{
			case 0: Do_SpawnItem(cindex, "defibrillator");
			case 1: Do_SpawnItem(cindex, "first_aid_kit");
			case 2: Do_SpawnItem(cindex, "pain_pills");
			case 3: Do_SpawnItem(cindex, "adrenaline");
			case 4: Do_SpawnItem(cindex, "molotov");
			case 5: Do_SpawnItem(cindex, "pipe_bomb");
			case 6: Do_SpawnItem(cindex, "vomitjar");
			case 7: Do_SpawnItem(cindex, "gascan");
			case 8: Do_SpawnItem(cindex, "propanetank");
			case 9: Do_SpawnItem(cindex, "oxygentank");
			case 10:
			{
				float location[3];
				if (!Misc_TraceClientViewToLocation(cindex, location)) {
					GetClientAbsOrigin(cindex, location);
				}
				Do_CreateEntity(cindex, "weapon_ammo_spawn", "models/props/terror/ammo_stack.mdl", location, false);
			}
			case 11: Do_SpawnItem(cindex, "weapon_upgradepack_incendiary");
			case 12: Do_SpawnItem(cindex, "weapon_upgradepack_explosive");
			case 13:
			{
				float location[3];
				if (!Misc_TraceClientViewToLocation(cindex, location)) {
					GetClientAbsOrigin(cindex, location);
				}
				Do_CreateEntity(cindex, "upgrade_laser_sight", "PROVIDED", location, false);
			}
			case 14: Do_SpawnItem(cindex, "gnome");
		}
		Menu_CreateItemMenu(cindex, false);
	}
	else if (action == MenuAction_End) CloseHandle(menu);
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE) DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}

public Action Menu_CreateWeaponMenu(int client, int args)
{
	Handle menu = CreateMenu(Menu_SpawnWeaponHandler);
	SetMenuTitle(menu, "创建 武器");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "sp", "创建 手枪");
	AddMenuItem(menu, "sg", "创建 沙鹰");
	AddMenuItem(menu, "ss", "创建 霰弹枪");
	AddMenuItem(menu, "sa", "创建 自动霰弹枪");
	AddMenuItem(menu, "sm", "创建 冲锋枪");
	AddMenuItem(menu, "s3", "创建 消声冲锋枪");
	AddMenuItem(menu, "sr", "创建 突击步枪");
	AddMenuItem(menu, "s1", "创建 AK74");
	AddMenuItem(menu, "s2", "创建 沙漠步枪");
	AddMenuItem(menu, "sh", "创建 猎枪");
	AddMenuItem(menu, "s4", "创建 军用狙击");
	AddMenuItem(menu, "s5", "创建 榴弹发射器");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SpawnWeaponHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		switch (itempos)
		{
			case 0: Do_SpawnItem(cindex, "pistol");
			case 1: Do_SpawnItem(cindex, "pistol_magnum");
			case 2: Do_SpawnItem(cindex, "pumpshotgun");
			case 3: Do_SpawnItem(cindex, "autoshotgun");
			case 4: Do_SpawnItem(cindex, "smg");
			case 5: Do_SpawnItem(cindex, "smg_silenced");
			case 6: Do_SpawnItem(cindex, "rifle");
			case 7: Do_SpawnItem(cindex, "rifle_ak47");
			case 8: Do_SpawnItem(cindex, "rifle_desert");
			case 9: Do_SpawnItem(cindex, "hunting_rifle");
			case 10: Do_SpawnItem(cindex, "sniper_military");
			case 11: Do_SpawnItem(cindex, "grenade_launcher");
		}
		Menu_CreateWeaponMenu(cindex, false);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Cancel)
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
}

public Action Menu_CreateMeleeWeaponMenu(int client, int args)
{
	Handle menu = CreateMenu(Menu_SpawnMeleeWeaponHandler);
	SetMenuTitle(menu, "创建 近战武器");
	SetMenuExitBackButton(menu, true);
	SetMenuExitButton(menu, true);
	AddMenuItem(menu, "ma", "创建 棒球棒");
	AddMenuItem(menu, "mb", "创建 电锯");
	AddMenuItem(menu, "mc", "创建 板球拍");
	AddMenuItem(menu, "md", "创建 撬棍");
	AddMenuItem(menu, "me", "创建 电吉他");
	AddMenuItem(menu, "mf", "创建 消防斧");
	AddMenuItem(menu, "mg", "创建 平底锅");
	AddMenuItem(menu, "mh", "创建 武士刀");
	AddMenuItem(menu, "mi", "创建 砍刀");
	AddMenuItem(menu, "mj", "创建 警棍");
	DisplayMenu(menu, client, MENU_DISPLAY_TIME);
	return Plugin_Handled;
}

public int Menu_SpawnMeleeWeaponHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		switch (itempos)
		{
			case 0: Do_SpawnItem(cindex, "baseball_bat");
			case 1: Do_SpawnItem(cindex, "chainsaw");
			case 2: Do_SpawnItem(cindex, "cricket_bat");
			case 3: Do_SpawnItem(cindex, "crowbar");
			case 4: Do_SpawnItem(cindex, "electric_guitar");
			case 5: Do_SpawnItem(cindex, "fireaxe");
			case 6: Do_SpawnItem(cindex, "frying_pan");
			case 7: Do_SpawnItem(cindex, "katana");
			case 8: Do_SpawnItem(cindex, "machete");
			case 9: Do_SpawnItem(cindex, "tonfa");
		}
		Menu_CreateMeleeWeaponMenu(cindex, false);
	}
	else if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Cancel)
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
}

public Action Menu_CreateTeleportMenu(int client, int args)
{
	g_originClient = -1;
	
	Handle hMenu = CreateMenu(Menu_TPMenuHandler);
	SetMenuTitle(hMenu, "你想传送谁?");
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, true);
	AddMenuItem(hMenu, "0", "所有生还者");
	int userid;
	char name[MAX_NAME_LENGTH], number[10];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || GetClientTeam(i) < 2 || !IsPlayerAlive(i)) continue;
		
		userid = GetClientUserId(i);
		Format(number, sizeof(number), "%i", userid);
		Format(name, sizeof(name)-13, "%N", i);
		Format(name, sizeof(name), "%s (%i)", name, userid);
		
		AddMenuItem(hMenu, number, name);
    }
	DisplayMenu(hMenu, client, MENU_DISPLAY_TIME);
}

public int Menu_TPMenuHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		Handle hMenu = CreateMenu(Menu_TPMenuHandler2);
		SetMenuTitle(hMenu, "传送到谁身边?");
		SetMenuExitBackButton(hMenu, true);
		SetMenuExitButton(hMenu, true);
		int userid;
		char name[MAX_NAME_LENGTH], number[10];
		
		if (itempos != 0)
		{
			char sInfo[64];
			GetMenuItem(menu, itempos, sInfo, sizeof(sInfo));
			g_originClient = GetClientOfUserId(StringToInt(sInfo));
			alltp = false;
		}
		else
		{
			alltp = true;
		}
		
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i)) continue;
			if (!alltp && i == g_originClient) continue;
			
			userid = GetClientUserId(i);
			Format(number, sizeof(number), "%i", userid);
			Format(name, sizeof(name)-13, "%N", i);
			Format(name, sizeof(name), "%s (%i)", name, userid);
			AddMenuItem(hMenu, number, name);
		}
		DisplayMenu(hMenu, cindex, MENU_DISPLAY_TIME);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}

public int Menu_TPMenuHandler2(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		float pos[3];
		char sInfo[64];
		GetMenuItem(menu, itempos, sInfo, sizeof(sInfo));
		int targetClient = GetClientOfUserId(StringToInt(sInfo));
		if (!alltp)
		{
			TeleportEntityEx(g_originClient, targetClient, pos);
			g_originClient = -1;
		}
		else
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i) || !L4D2_IsSurvivor(i)) continue;
				if (i == targetClient) continue;
				TeleportEntityEx(i, targetClient, pos);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		Menu_CreateTeleportMenu(cindex, false);
	}
	else if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
}

public Action Menu_CreateRespawnMenu(int client, int args)
{
	Handle hMenu = CreateMenu(Menu_RespawnMenuHandler);
	SetMenuTitle(hMenu, "你想复活谁?");
	SetMenuExitBackButton(hMenu, true);
	SetMenuExitButton(hMenu, true);
	
	char userid[12];
	char name[MAX_NAME_LENGTH];
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || IsPlayerAlive(index)) continue;
		
		IntToString(GetClientUserId(index), userid, sizeof(userid));
		GetClientName(index, name, sizeof(name));
		AddMenuItem(hMenu, userid, name);
	}
	DisplayMenu(hMenu, client, MENU_TIME_FOREVER);
}

public int Menu_RespawnMenuHandler(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
	}
	else if (action == MenuAction_Select)
	{
		char sInfo[64], name[MAX_NAME_LENGTH];
		GetMenuItem(menu, itempos, sInfo, sizeof(sInfo));
		int client = GetClientOfUserId(StringToInt(sInfo));
		Format(name, sizeof(name)-13, "%N", client);
		
		if (GetClientTeam(client) != 2 || IsPlayerAlive(client)) return;
		RespawnPlayer(cindex, client);
		ShowActivity2(cindex, "[SM] ", "Respawned target '%s'", name);
		Menu_CreateRespawnMenu(cindex, false);
	}
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != INVALID_HANDLE)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}
