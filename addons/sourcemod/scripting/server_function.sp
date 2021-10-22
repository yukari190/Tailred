#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <geoip>
#include <builtinvotes>
#include <adminmenu>
#include <left4dhooks>
#include <colors>
#include <l4d2lib>
#include <DirectInfectedSpawn>
#include <l4d2util>
#undef REQUIRE_PLUGIN
#include <caster_system>

#define PLUGIN_TAG					"[A4D] "
#define MENU_DISPLAY_TIME		20

#define PLAYER_LIMIT 1
#define PATH_MAP "configs/Server/maplists.txt"

#define GAMEDATA "l4d2_si_ability"

public Plugin myinfo =
{
	name = "Server Function",
	description = "Yukari190",
	author = "",
	version = "1.1",
	url = ""
};

enum VoteType
{
	VoteType_None,
	VoteType_SetMaxPlayers,
	VoteType_RestoreHealth,
	VoteType_ChangeMap,
	VoteType_KickSpec,
	VoteType_AllowBots
};

VoteType
	iVoteType;
KeyValues
	g_hInfoKV;
Handle 
	top_menu = null,
	admin_menu = null;
TopMenuObject 
	spawn_special_infected_menu,
	spawn_weapons_menu,
	spawn_melee_weapons_menu,
	spawn_items_menu,
	respawn_menu,
	teleport_menu;
ConVar
	hAllowInfectedBots;
bool 
	casterSystemAvailable,
	alltp;
int 
	iSlot,
	g_originClient = -1;
char 
	TargetMap_Code[128],
	mapname[64];

void FindCasterSystem()
{
	casterSystemAvailable = LibraryExists("caster_system");
}

public void OnAllPluginsLoaded()
{
	FindCasterSystem();
}

public void OnLibraryRemoved(const char[] name)
{
	FindCasterSystem();
}

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	g_hInfoKV = new KeyValues("MapLists");
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), PATH_MAP);
	if (!FileToKeyValues(g_hInfoKV, sBuffer)) LogMessage("找不到 <%s>.", PATH_MAP);
	
	hAllowInfectedBots = FindConVar("director_allow_infected_bots");
	
	RegConsoleCmd("sm_zs", Command_Suicide, "玩家自杀");
	RegConsoleCmd("sm_vmp", SlotsRequest);
	RegConsoleCmd("sm_vhp", Command_RestoreHealth);
	RegConsoleCmd("sm_vcm", ChangeMaps);
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	RegConsoleCmd("sm_vbot", AllowInfectedBots_Cmd);
	
	if (LibraryExists("adminmenu") && ((top_menu = GetAdminTopMenu()) != null))
	  OnAdminMenuReady(top_menu);
	
	AddCommandListener(TeamSay_Callback, "say_team");
	
	HookEvent("player_changename", Event_NameChange, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnectPre, EventHookMode_Pre);
	HookEvent("revive_success", EventReviveSuccess);
	HookEvent("player_bot_replace", PlayerBotReplace);
}

public void OnMapStart()
{
	GetCurrentMap(mapname, sizeof(mapname));
}

public void OnClientPutInServer(int client)
{
	CreateTimer(30.0, Announce_Timer, client);
}

public Action Announce_Timer(Handle timer, any client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		CPrintToChat(client, "{LG}命令: !match(换模式) | !vcm(换地图) | !vmp(修改人数) | !vhp(回血) | !vbot(对抗启用机器人特感)");
	}
}

public void OnClientPostAdminCheck(int client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client) && GetClientCount(true) < MaxClients)
	{
		char rawmsg[301];
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 加入游戏.", 1, rawmsg);
		CPrintToChatAll("%s", rawmsg);
	}
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int team)
{
	if (!IsValidAndInGame(client) || IsFakeClient(client)) return;
	CreateTimer(1.0, TeamChange_Timer, client);
}

public Action TeamChange_Timer(Handle timer, any client)
{
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		if (GetClientTeam(client) == 1)
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 1);
		else
			SetEntProp(client, Prop_Send, "m_bNightVisionOn", 0);
	}
}


public Action Event_NameChange(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSpectator(client))
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
		if (!IsValidAndInGame(target)) return;
		PrintHintTextToAll("%N 黑白了!", target);
	}
}

public Action PlayerBotReplace(Event event, const char[] name, bool dontBroadcast)
{
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (IsValidInfected(bot) && GetInfectedClass(bot) == L4D2Infected_Tank)
	{
		PrintToChatAll("[!] Tank控制权丢失, 启用代打模式!");
	}
}

public Action Event_PlayerDisconnectPre(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidAndInGame(client) && !IsFakeClient(client))
	{
		char rawmsg[301], reason[65];
		event.GetString("reason", reason, sizeof(reason));
		ReplaceString(reason, sizeof(reason), "\n", " ");
		PrintFormattedMessageToAll(rawmsg, client);
		Format(rawmsg, sizeof(rawmsg), "%c%s @ 断开连接. {O}原因: {W}%s", 1, rawmsg, reason);
		CPrintToChatAll("%s", rawmsg);
	}
}


public Action TeamSay_Callback(int client, char[] command, int args)
{
	if (!IsValidAndInGame(client)) return Plugin_Continue;
	
	L4D2_Team team = view_as<L4D2_Team>(GetClientTeam(client));
    if (team == L4D2Team_Survivor || team == L4D2Team_Infected)
    {
        char sChat[256];
        GetCmdArgString(sChat, sizeof(sChat));
        StripQuotes(sChat);
        for (int i = 1; i <= MaxClients; i++)
        {
            if (IsSpectator(i))
            {
                CPrintToChat(i, "{W}%s%N {W}: %s", (team == L4D2Team_Survivor ? "(生还者) {B}" : team == L4D2Team_Infected ? "(感染者) {R}" : "(观众) {W}"), client, sChat);
            }
        }
    }
    return Plugin_Continue;
}

public Action Command_Suicide(int client, int args)
{
	if (!client || L4D_IsVersusMode()) return Plugin_Handled;
	ServerCommand("sm_slay \"%N\"", client);
	PrintToChatAll("\x01玩家 \x03%N\x01 自爆菊花而死_(:зゝ∠❀)_", client);
	PrintHintTextToAll("玩家 %N 自爆菊花而死_(:зゝ∠❀)_", client);
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
		CPrintToChatAll("{B}[{W}Slots{B}] {W}有效范围 0 - 24");
		return Plugin_Handled;
	}
	if (!IsValidAndInGame(client)) SetMaxPlayers(iSlot);
	else
	{
		iVoteType = VoteType_SetMaxPlayers;
		Format(buffer, sizeof(buffer), "将人数设置为 '%s'?");
		BuiltinVotes_StartVoteAllTeam(client, buffer);
	}
	return Plugin_Handled;
}

public Action Command_RestoreHealth(int client, int args)
{
	if (!client) return Plugin_Handled;
	iVoteType = VoteType_RestoreHealth;
	BuiltinVotes_StartVoteAllTeam(client, "是否恢复生还者生命值?");
	return Plugin_Handled;
}

public Action ChangeMaps(int client, int args)
{
	if (!client) return Plugin_Handled;
	
	if (g_hInfoKV == null)
	{
		LogError("[NativeVotes] 初始化投票失败, 找不到 <%s>.", PATH_MAP);
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
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	if (action == MenuAction_End) CloseHandle(menu);
}

public Action KickSpecs_Cmd(int client, int args)
{
	if (IsValidAndInGame(client))
	{
		char sBuffer[64];
		iVoteType = VoteType_KickSpec;
		Format(sBuffer, sizeof(sBuffer), "踢非管理员和非强制性观众?");
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	return Plugin_Handled;
}

public Action AllowInfectedBots_Cmd(int client, int args)
{
	if (IsValidAndInGame(client))
	{
		char sBuffer[64];
		iVoteType = VoteType_AllowBots;
		Format(sBuffer, sizeof(sBuffer), "启用特感机器人?");
		BuiltinVotes_StartVoteAllTeam(client, sBuffer);
	}
	return Plugin_Handled;
}


void PrintFormattedMessageToAll(char rawmsg[301], int client)
{
	char steamid[256], ip[16], country[46];
	bool bIsLanIp;
	
	GetClientAuthId(client, AuthId_Steam3, steamid, sizeof(steamid));
	GetClientIP(client, ip, sizeof(ip)); 
	bIsLanIp = IsLanIP(ip);
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
	
	Format(rawmsg, sizeof(rawmsg), "%s {O}%N {G}%s{W} ({O}%s{W}), ", IsClientAdmin(client) ? "管理员" : "玩家", 
	client, steamid, country);
}

void RespawnPlayer(int player_id)
{
	//bool canTeleport = SetTeleportEndPoint(client);
	L4D_RespawnPlayer(player_id);
	/*Do_SpawnItem(player_id, "smg");
	
	if(canTeleport)
		PerformTeleport(client,player_id,g_pos);*/
	float g_pos[3];
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || index == player_id) continue;
		GetClientAbsOrigin(index, g_pos);
		g_pos[2]+=40.0;
		TeleportEntity(player_id, g_pos, NULL_VECTOR, NULL_VECTOR);
	}
}

void SpawnTank(int client)
{
	char feedback[64];
	Format(feedback, sizeof(feedback), "A Tank has been spawned");
	float location[3];
	if (!Misc_TraceClientViewToLocation(client, location)) {
		GetClientAbsOrigin(client, location);
	}
	L4D2_SpawnTank(location, NULL_VECTOR);
	NotifyPlayers(client, feedback);
	LogAction(client, -1, "[NOTICE]: (%L) has spawned a Tank", client);
}

void Do_SpawnInfected(int client, L4D2_Infected class)
{
	char arguments[16];
	char feedback[64];
	GetInfectedClassName(class, arguments, 16);
	Format(feedback, sizeof(feedback), "A %s has been spawned", arguments);
	float location[3];
	if (!Misc_TraceClientViewToLocation(client, location)) {
		GetClientAbsOrigin(client, location);
	}
	TriggerSpawn(class, location);
	NotifyPlayers(client, feedback);
	LogAction(client, -1, "[NOTICE]: (%L) has spawned a %s", client, arguments);
}

void Do_SpawnItem(int client, const char[] type)
{
	char feedback[64], buffer[24];
	Format(feedback, sizeof(feedback), "A %s has been spawned", type);
	if (client == 0) ReplyToCommand(client, "Can not use this command from the console."); 
	else
	{
		Format(buffer, sizeof(buffer), "%s", type);
		CheatCommand(client, "give", buffer);
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

public void TeleportEntityEx(int originClient, int targetClient)
{
	float targetPos[3];
	GetClientAbsOrigin(targetClient, targetPos);
	TeleportEntity(originClient, targetPos, NULL_VECTOR, NULL_VECTOR);
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
				SpawnTank(cindex);
			case 1:
				Do_SpawnInfected(cindex, L4D2Infected_Witch);
			case 2:
				Do_SpawnInfected(cindex, L4D2Infected_Boomer);
			case 3:
				Do_SpawnInfected(cindex, L4D2Infected_Hunter);
			case 4:
				Do_SpawnInfected(cindex, L4D2Infected_Smoker);
			case 5:
				Do_SpawnInfected(cindex, L4D2Infected_Spitter);
			case 6:
				Do_SpawnInfected(cindex, L4D2Infected_Jockey);
			case 7:
				Do_SpawnInfected(cindex, L4D2Infected_Charger);
			case 8:
				CheatCommand(cindex, "z_spawn", "mob");
		}
		Menu_CreateSpecialInfectedMenu(cindex, false);
	}
	else if (action == MenuAction_End) CloseHandle(menu);
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != null) DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
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
		if (itempos == MenuCancel_ExitBack && admin_menu != null) DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
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
		if (itempos == MenuCancel_ExitBack && admin_menu != null)
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
		if (itempos == MenuCancel_ExitBack && admin_menu != null)
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
		if (itempos == MenuCancel_ExitBack && admin_menu != null)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}

public int Menu_TPMenuHandler2(Handle menu, MenuAction action, int cindex, int itempos)
{
	if (action == MenuAction_Select)
	{
		char sInfo[64];
		GetMenuItem(menu, itempos, sInfo, sizeof(sInfo));
		int targetClient = GetClientOfUserId(StringToInt(sInfo));
		if (!alltp)
		{
			TeleportEntityEx(g_originClient, targetClient);
			g_originClient = -1;
		}
		else
		{
			for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
			{
				int index = L4D2_GetSurvivorOfIndex(i);
				if (index == 0) continue;
				if (index == targetClient) continue;
				TeleportEntityEx(index, targetClient);
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
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && !IsPlayerAlive(i))
		{
			IntToString(GetClientUserId(i), userid, sizeof(userid));
			GetClientName(i, name, sizeof(name));
			AddMenuItem(hMenu, userid, name);
		}
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
		RespawnPlayer(client);
		ShowActivity2(cindex, "[SM] ", "Respawned target '%s'", name);
		Menu_CreateRespawnMenu(cindex, false);
	}
	else if (action == MenuAction_Cancel)
	{
		if (itempos == MenuCancel_ExitBack && admin_menu != null)
			DisplayTopMenu(admin_menu, cindex, TopMenuPosition_LastCategory);
	}
}

bool IsLanIP(char[] src)
{
	char ip4[4][4];
	int ipnum;
	if (ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		if (
			(ipnum >= 655360 && ipnum < 655360+65535) || 
			(ipnum >= 11276288 && ipnum < 11276288+4095) || 
			(ipnum >= 12625920 && ipnum < 12625920+255)
		)
		{
			return true;
		}
	}
	return false;
}

bool IsClientAdmin(int client)
{
	AdminId id = GetUserAdmin(client);
	if (id == INVALID_ADMIN_ID) return false;
	if (
		GetAdminFlag(id, Admin_Reservation) || 
		GetAdminFlag(id, Admin_Root) || 
		GetAdminFlag(id, Admin_Kick) || 
		GetAdminFlag(id, Admin_Generic)
	) return true;
	return false;
}

public Action ChangeLevel(Handle timer)
{
	if (IsMapValid(TargetMap_Code)) ForceChangeLevel(TargetMap_Code, "");
	else ForceChangeLevel("c1m1_hotel", "");
}

void RestoreHealth()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		
		CheatCommand(index, "give", "health");
		SetEntPropFloat(index, Prop_Send, "m_healthBuffer", 0.0);		
		SetEntProp(index, Prop_Send, "m_currentReviveCount", 0); //reset incaps
		SetEntProp(index, Prop_Send, "m_bIsOnThirdStrike", false);
	}
}

void SetMaxPlayers(int amount)
{
	FindConVar("sv_maxplayers").SetInt(amount);
	FindConVar("sv_visiblemaxplayers").SetInt(amount);
	PrintToServer("服务器人数设置为 %i", amount);
	PrintToChatAll("服务器人数设置为 %i", amount);
}

void CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (IsValidAndInGame(client))
		{
		    int originalUserFlags = GetUserFlagBits(client);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(client, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(client, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(client, originalUserFlags);
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(null, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}


public void BuiltinVotes_VoteResult()
{
	switch (iVoteType)
	{
		case VoteType_SetMaxPlayers: SetMaxPlayers(iSlot);
		case VoteType_RestoreHealth: RestoreHealth();
		case VoteType_ChangeMap: CreateTimer(2.5, ChangeLevel);
		case VoteType_KickSpec:
		{
			for (int c=1; c<=MaxClients; c++)
			{
				if (IsClientInGame(c) && (GetClientTeam(c) == 1) && !(casterSystemAvailable && IsClientCaster(c)) && !IsClientAdmin(c))
				{
					KickClient(c, "No Spectators, please!");
				}
			}
		}
		case VoteType_AllowBots: hAllowInfectedBots.SetInt(1);
	}
	iVoteType = VoteType_None;
}


bool BuiltinVotes_StartVoteAllTeam(int client, char[] sArgument)
{
	if (IsClientAdmin(client))
	{
		BuiltinVotes_VoteResult();
		return true;
	}
	if (!IsNewBuiltinVoteAllowed())
	{
		PrintToChat(client, "无法开始投票.");
		return false;
	}
	if (!(casterSystemAvailable && IsClientCaster(client)) && GetClientTeam(client) <= 1)
	{
		CPrintToChat(client, "{B}[{W}SM{B}] {W}观众不允许投票.");
		return false;
	}
	if (!IsBuiltinVoteInProgress())
	{
		int iNumPlayers;
		int[] iPlayers = new int[MaxClients];
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || IsFakeClient(i) || (!(casterSystemAvailable && IsClientCaster(i)) && GetClientTeam(i) <= 1)) continue;
			iPlayers[iNumPlayers++] = i;
		}
		if (iNumPlayers < PLAYER_LIMIT)
		{
			CPrintToChat(client, "{B}[{W}SM{B}] {W}没有足够的玩家无法开始投票.");
			return false;
		}
		Handle hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);
		SetBuiltinVoteArgument(hVote, sArgument);
		SetBuiltinVoteInitiator(hVote, client);
		SetBuiltinVoteResultCallback(hVote, VoteResultHandler);
		DisplayBuiltinVote(hVote, iPlayers, iNumPlayers, 30);
		FakeClientCommand(client, "Vote Yes");
		return true;
	}
	CPrintToChat(client, "{B}[{W}SM{B}] {W}现在无法开始投票.");
	return false;
}

public int VoteActionHandler(Handle vote, BuiltinVoteAction action, int param1, int param2)
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

public int VoteResultHandler(Handle vote, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
	for (int i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_votes / 2))
			{
				DisplayBuiltinVotePass(vote, " ");
				BuiltinVotes_VoteResult();
				return;
			}
		}
	}
	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}
