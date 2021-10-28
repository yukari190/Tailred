#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#undef REQUIRE_PLUGIN
#include <lgofnoc>

#define LIBRARYNAME "l4d2lib"

public Plugin myinfo =
{
	name = "l4d2lib",
	description = "Useful natives and fowards for L4D2 Plugins",
	author = "Confogl Team, Yukari190",
	version = "1.2",
	url = ""
};

enum Saferoom
{
	Saferoom_Neither = 0,
	Saferoom_Start = 1,
	Saferoom_End = 2,
	Saferoom_Both = 3
};

enum SurvivorCharacter
{
	SurvivorCharacter_Invalid = -1,

	SurvivorCharacter_Nick = 0,
	SurvivorCharacter_Rochelle,
	SurvivorCharacter_Coach,
	SurvivorCharacter_Ellis,
	SurvivorCharacter_Bill,
	SurvivorCharacter_Zoey,
	SurvivorCharacter_Louis,
	SurvivorCharacter_Francis,

	SurvivorCharacter_Size //8 size
};

static const char SurvivorModels[view_as<int>(SurvivorCharacter_Size)][] =
{
	"models/survivors/survivor_gambler.mdl",	//MODEL_NICK
	"models/survivors/survivor_producer.mdl",	//MODEL_ROCHELLE
	"models/survivors/survivor_coach.mdl",		//MODEL_COACH
	"models/survivors/survivor_mechanic.mdl",	//MODEL_ELLIS
	"models/survivors/survivor_namvet.mdl",		//MODEL_BILL
	"models/survivors/survivor_teenangst.mdl",	//MODEL_ZOEY
	"models/survivors/survivor_manager.mdl",	//MODEL_LOUIS
	"models/survivors/survivor_biker.mdl"		//MODEL_FRANCIS
};

enum WeaponId
{
	WEPID_NONE,             // 0
	WEPID_PISTOL,           // 1
	WEPID_SMG,              // 2
	WEPID_PUMPSHOTGUN,      // 3
	WEPID_AUTOSHOTGUN,      // 4
	WEPID_RIFLE,            // 5
	WEPID_HUNTING_RIFLE,    // 6
	WEPID_SMG_SILENCED,     // 7
	WEPID_SHOTGUN_CHROME,   // 8
	WEPID_RIFLE_DESERT,     // 9
	WEPID_SNIPER_MILITARY,  // 10
	WEPID_SHOTGUN_SPAS,     // 11
	WEPID_FIRST_AID_KIT,    // 12
	WEPID_MOLOTOV,          // 13
	WEPID_PIPE_BOMB,        // 14
	WEPID_PAIN_PILLS,       // 15
	WEPID_GASCAN,           // 16
	WEPID_PROPANE_TANK,     // 17
	WEPID_OXYGEN_TANK,      // 18
	WEPID_MELEE,            // 19
	WEPID_CHAINSAW,         // 20
	WEPID_GRENADE_LAUNCHER, // 21
	WEPID_AMMO_PACK,        // 22
	WEPID_ADRENALINE,       // 23
	WEPID_DEFIBRILLATOR,    // 24
	WEPID_VOMITJAR,         // 25
	WEPID_RIFLE_AK47,       // 26
	WEPID_GNOME_CHOMPSKI,   // 27
	WEPID_COLA_BOTTLES,     // 28
	WEPID_FIREWORKS_BOX,    // 29
	WEPID_INCENDIARY_AMMO,  // 30
	WEPID_FRAG_AMMO,        // 31
	WEPID_PISTOL_MAGNUM,    // 32
	WEPID_SMG_MP5,          // 33
	WEPID_RIFLE_SG552,      // 34
	WEPID_SNIPER_AWP,       // 35
	WEPID_SNIPER_SCOUT,     // 36
	WEPID_RIFLE_M60,        // 37
	WEPID_TANK_CLAW,        // 38
	WEPID_HUNTER_CLAW,      // 39
	WEPID_CHARGER_CLAW,     // 40
	WEPID_BOOMER_CLAW,      // 41
	WEPID_SMOKER_CLAW,      // 42
	WEPID_SPITTER_CLAW,     // 43
	WEPID_JOCKEY_CLAW,      // 44
	WEPID_MACHINEGUN,       // 45
	WEPID_VOMIT,            // 46
	WEPID_SPLAT,            // 47
	WEPID_POUNCE,           // 48
	WEPID_LOUNGE,           // 49
	WEPID_PULL,             // 50
	WEPID_CHOKE,            // 51
	WEPID_ROCK,             // 52
	WEPID_PHYSICS,          // 53
	WEPID_AMMO,             // 54
	WEPID_UPGRADE_ITEM,     // 55

	WEPID_SIZE //56 size
};

enum MeleeWeaponId
{
	WEPID_MELEE_NONE,
	WEPID_KNIFE,
	WEPID_BASEBALL_BAT,
	WEPID_MELEE_CHAINSAW,
	WEPID_CRICKET_BAT,
	WEPID_CROWBAR,
	WEPID_DIDGERIDOO,
	WEPID_ELECTRIC_GUITAR,
	WEPID_FIREAXE,
	WEPID_FRYING_PAN,
	WEPID_GOLF_CLUB,
	WEPID_KATANA,
	WEPID_MACHETE,
	WEPID_RIOT_SHIELD,
	WEPID_TONFA,
	WEPID_SHOVEL,
	WEPID_PITCHFORK,
	
	WEPID_MELEES_SIZE //15 size
};

static const char WeaponNames[view_as<int>(WEPID_SIZE)][] =
{
	"weapon_none", "weapon_pistol", "weapon_smg",                                            // 0
	"weapon_pumpshotgun", "weapon_autoshotgun", "weapon_rifle",                              // 3
	"weapon_hunting_rifle", "weapon_smg_silenced", "weapon_shotgun_chrome",                  // 6
	"weapon_rifle_desert", "weapon_sniper_military", "weapon_shotgun_spas",                  // 9
	"weapon_first_aid_kit", "weapon_molotov", "weapon_pipe_bomb",                            // 12
	"weapon_pain_pills", "weapon_gascan", "weapon_propanetank",                              // 15
	"weapon_oxygentank", "weapon_melee", "weapon_chainsaw",                                  // 18
	"weapon_grenade_launcher", "weapon_ammo_pack", "weapon_adrenaline",                      // 21
	"weapon_defibrillator", "weapon_vomitjar", "weapon_rifle_ak47",                          // 24
	"weapon_gnome", "weapon_cola_bottles", "weapon_fireworkcrate",                           // 27
	"weapon_upgradepack_incendiary", "weapon_upgradepack_explosive", "weapon_pistol_magnum", // 30
	"weapon_smg_mp5", "weapon_rifle_sg552", "weapon_sniper_awp",                             // 33
	"weapon_sniper_scout", "weapon_rifle_m60", "weapon_tank_claw",                           // 36
	"weapon_hunter_claw", "weapon_charger_claw", "weapon_boomer_claw",                       // 39
	"weapon_smoker_claw", "weapon_spitter_claw", "weapon_jockey_claw",                       // 42
	"weapon_machinegun", "vomit", "splat",                                                   // 45
	"pounce", "lounge", "pull",                                                              // 48
	"choke", "rock", "physics",                                                              // 51
	"ammo", "upgrade_item"                                                                   // 54
};

static const char MeleeWeaponNames[view_as<int>(WEPID_MELEES_SIZE)][] =
{
	"",
	"knife",
	"baseball_bat",
	"chainsaw",
	"cricket_bat",
	"crowbar",
	"didgeridoo",
	"electric_guitar",
	"fireaxe",
	"frying_pan",
	"golfclub",
	"katana",
	"machete",
	"riotshield",
	"tonfa",
	"shovel",
	"pitchfork"
};

static const char MeleeWeaponModels[view_as<int>(WEPID_MELEES_SIZE)][] =
{
	"",
	"/w_models/weapons/w_knife_t.mdl",
	"/weapons/melee/w_bat.mdl",
	"/weapons/melee/w_chainsaw.mdl",
	"/weapons/melee/w_cricket_bat.mdl",
	"/weapons/melee/w_crowbar.mdl",
	"/weapons/melee/w_didgeridoo.mdl",
	"/weapons/melee/w_electric_guitar.mdl",
	"/weapons/melee/w_fireaxe.mdl",
	"/weapons/melee/w_frying_pan.mdl",
	"/weapons/melee/w_golfclub.mdl",
	"/weapons/melee/w_katana.mdl",
	"/weapons/melee/w_machete.mdl",
	"/weapons/melee/w_riotshield.mdl",
	"/weapons/melee/w_tonfa.mdl",
	"/weapons/melee/w_shovel.mdl",
	"/weapons/melee/w_pitchfork.mdl"
};

const int
	NUM_OF_SURVIVORS = 4;
KeyValues
	kvMapInfo,
	kvSafeRoomInfo;
Handle
	hTankDeathTimer = null;
GlobalForward
	hFwdRoundStart,
	hFwdRoundEnd,
	hFwdFirstTankSpawn,
	hFwdTankPassControl,
	hFwdTankDeath,
	hFwdPlayerHurt,
	hFwdTeamChanged,
	hFwdOnTakeDamage;
StringMap
	hSurvivorModelsTrie,
	hWeaponNamesTrie,
	hMeleeWeaponNamesTrie,
	hMeleeWeaponModelsTrie;
int
	iRoundNumber = 0,
	iSurvivorIndex[NUM_OF_SURVIVORS],
	iTank,
	iTankPassCount;
bool
	bIsMapActive,
	bInSecondRound,
	bRoundEnd,
	bInRound,
	bIsTankActive,
	bExpectTankSpawn,
	g_bHasStart,
	g_bHasStartExtra,
	g_bHasEnd,
	g_bHasEndExtra,
	MapDataAvailable,
	SaferoomDataAvailable;
float
	g_fStartLocA[3],
	g_fStartLocB[3],
	g_fStartLocC[3],
	g_fStartLocD[3],
	g_fStartRotate,
	g_fEndLocA[3],
	g_fEndLocB[3],
	g_fEndLocC[3],
	g_fEndLocD[3],
	g_fEndRotate,
	Start_Point[3],
	Start_Dist,
	Start_Extra_Dist;
char
	g_sMapname[64];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	/* Plugin Native Declarations */
	CreateNative("L4D2_GetCurrentRound", _native_GetCurrentRound);
	CreateNative("L4D2_CurrentlyInRound", _native_CurrentlyInRound);
	CreateNative("L4D2_GetSurvivorCount", _native_GetSurvivorCount);
	CreateNative("L4D2_GetSurvivorOfIndex", _native_GetSurvivorOfIndex);
	CreateNative("L4D2_IsMapDataAvailable", _native_IsMapDataAvailable);
	CreateNative("L4D2_IsEntityInSaferoom", _native_IsEntityInSaferoom);
	CreateNative("L4D2_GetMapValueInt", _native_GetMapValueInt);
	CreateNative("L4D2_GetMapValueFloat", _native_GetMapValueFloat);
	CreateNative("L4D2_GetMapValueVector", _native_GetMapValueVector);
	CreateNative("L4D2_GetMapValueString", _native_GetMapValueString);
	CreateNative("L4D2_CopyMapSubsection", _native_CopyMapSubsection);
	
	CreateNative("ClientModelToSC", _native_ClientModelToSC);
	CreateNative("WeaponNameToId", _native_WeaponNameToId);
	CreateNative("GetMeleeWeaponIdFromName", _native_GetMeleeWeaponIdFromName);
	CreateNative("GetMeleeWeaponNameFromModel", _native_GetMeleeWeaponNameFromModel);
	
	CreateNative("InSecondHalfOfRound", _native_InSecondHalfOfRound);
	CreateNative("IsInTransition", _native_IsInTransition);
	
	
	/* Plugin Forward Declarations */
	hFwdRoundStart = new GlobalForward("L4D2_OnRealRoundStart", ET_Ignore, Param_Cell);
	hFwdRoundEnd = new GlobalForward("L4D2_OnRealRoundEnd", ET_Ignore, Param_Cell);
	hFwdFirstTankSpawn = new GlobalForward("L4D2_OnTankFirstSpawn", ET_Ignore, Param_Cell);
	hFwdTankPassControl = new GlobalForward("L4D2_OnTankPassControl", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	hFwdTankDeath = new GlobalForward("L4D2_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell);
	
	hFwdPlayerHurt = new GlobalForward("L4D2_OnPlayerHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	hFwdTeamChanged = new GlobalForward("L4D2_OnPlayerTeamChanged", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	hFwdOnTakeDamage = new GlobalForward("L4D2_OnTakeDamage", ET_Event, Param_Cell, Param_CellByRef, Param_CellByRef, Param_FloatByRef, Param_CellByRef, Param_CellByRef, Param_Array, Param_Array);
	
	/* Register our library */
	RegPluginLibrary(LIBRARYNAME);
	return APLRes_Success;
}

public void OnPluginStart()
{
	char sNameBuff[PLATFORM_MAX_PATH];
	kvSafeRoomInfo = new KeyValues("SaferoomInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/l4d2lib/saferoominfo.txt");
	if (!FileToKeyValues(kvSafeRoomInfo, sNameBuff))
	{
		LogError("[MI] 找不到 saferoominfo.txt 文件信息");
		delete kvSafeRoomInfo;
	}
	
	kvMapInfo = new KeyValues("MapInfo");
	LGO_BuildConfigPath(sNameBuff, sizeof(sNameBuff), "mapinfo.txt"); //Build our filepath
	if (!FileToKeyValues(kvMapInfo, sNameBuff))
	{
		BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/l4d2lib/mapinfo.txt");
		if (!FileToKeyValues(kvMapInfo, sNameBuff))
		{
			LogError("[MI] 找不到 mapinfo.txt 文件信息");
			delete kvMapInfo;
		}
	}
	
	hSurvivorModelsTrie = new StringMap();
	for (int i = 0; i < view_as<int>(SurvivorCharacter_Size); i++) { hSurvivorModelsTrie.SetValue(SurvivorModels[i], i); }
	
	hWeaponNamesTrie = new StringMap();
	for (int i = 0; i < view_as<int>(WEPID_SIZE); i++) { hWeaponNamesTrie.SetValue(WeaponNames[i], i); }
	
	hMeleeWeaponNamesTrie = new StringMap();
	hMeleeWeaponModelsTrie = new StringMap();
    for (int i = 0; i < view_as<int>(WEPID_MELEES_SIZE); ++i)
    {
        hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[i], i);
        hMeleeWeaponModelsTrie.SetString(MeleeWeaponModels[i], MeleeWeaponNames[i]);
    }
	
	FindConVar("director_no_bosses").SetBool(true);
	
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
	
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	
	HookEvent("tank_spawn", TankSpawn_Event, EventHookMode_Post);
	HookEvent("item_pickup", ItemPickup_Event, EventHookMode_Post);
	HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	
	HookEvent("round_start", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("round_end", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_disconnect", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_death", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("defibrillator_used", BuildIndex_Event, EventHookMode_PostNoCopy);
	
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
	HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);
}

public void OnPluginEnd()
{
	delete kvMapInfo;
	delete kvSafeRoomInfo;
	FindConVar("director_no_bosses").RestoreDefault();
}

public void OnMapStart()
{
	GetCurrentMap(g_sMapname, 64);
	
	Update_MapInfo();
	
	bRoundEnd = false;
	bInSecondRound = false;
	bIsMapActive = true;
}

public void OnMapEnd()
{
	RoundEnd_Event(null, "", false);
	
	bIsMapActive = false;
	KvRewind(kvMapInfo);
	KvRewind(kvSafeRoomInfo);
	bRoundEnd = false;
	bInSecondRound = false;
	bInRound = false;
	iRoundNumber = 0;
	MapDataAvailable = false;
	SaferoomDataAvailable = false;
}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if (L4D2Direct_GetTankCount() > 0)
	{
		return Plugin_Handled;
	}
	bExpectTankSpawn = true;
	return Plugin_Continue;
}



/* Events */
public void RoundEnd_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (bInRound)
	{
		bInRound = false;
		bRoundEnd = true;
		Call_StartForward(hFwdRoundEnd);
		Call_PushCell(iRoundNumber);
		Call_Finish();
	}
}

public void RoundStart_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (bRoundEnd)
	{
		bInSecondRound = true;
	}
	CreateTimer(0.25, RoundStart_Delay, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action RoundStart_Delay(Handle timer)
{
	if (bIsMapActive)
	{
		if (!bInRound)
		{
			bInRound = true;
			iRoundNumber++;
			
			ResetStatus();
			PrintToServer("%s", g_sMapname);
			
			Call_StartForward(hFwdRoundStart);
			Call_PushCell(iRoundNumber);
			Call_Finish();
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public void TankSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bExpectTankSpawn) return;
	bExpectTankSpawn = false;
	if (bIsTankActive) return;
	bIsTankActive = true;
	
	iTank = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(iTank) || GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8) return;
	
	Call_StartForward(hFwdFirstTankSpawn);
	Call_PushCell(iTank);
	Call_Finish();
}

public void ItemPickup_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive)
	{
		return;
	}
	char item[64];
	event.GetString("item", item, 64);
	if (StrEqual(item, "tank_claw"))
	{
		int iPrevTank = iTank;
		iTank = GetClientOfUserId(event.GetInt("userid"));
		if (!IsValidAndInGame(iTank) || GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8) return;
		
		if (hTankDeathTimer != null)
		{
			KillTimer(hTankDeathTimer);
			hTankDeathTimer = null;
		}
		
		Call_StartForward(hFwdTankPassControl);
		Call_PushCell(iPrevTank);
		Call_PushCell(iTank);
		Call_PushCell(iTankPassCount);
		Call_Finish();
		iTankPassCount += 1;
	}
}

public void PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
	if (!bIsTankActive)
	{
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidAndInGame(client)) return;
	if (iTank != client) return;
	
	hTankDeathTimer = CreateTimer(0.5, TankDeath_Timer, attacker);
}

public Action TankDeath_Timer(Handle timer, any attacker)
{
	Call_StartForward(hFwdTankDeath);
	Call_PushCell(iTank);
	Call_PushCell(attacker);
	Call_Finish();
	ResetStatus();
}

public void PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker;
	int health = event.GetInt("health");
	char weapon[256];
	event.GetString("weapon", weapon, 256);
	int damage = event.GetInt("dmg_health");
	int dmgtype = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	if (!IsValidAndInGame(victim) || !IsPlayerAlive(victim)) return;
	
	Call_StartForward(hFwdPlayerHurt);
	Call_PushCell(victim);
	int attackerid = event.GetInt("attacker");
	if (attackerid == 0)
	{
		attacker = event.GetInt("attackerentid");
	}
	else 
	{
		attacker = GetClientOfUserId(attackerid);
	}
	Call_PushCell(attacker);
	Call_PushCell(health);
	Call_PushString(weapon);
	Call_PushCell(damage);
	Call_PushCell(dmgtype);
	Call_PushCell(hitgroup);
	Call_Finish();
}

public Action PlayerTeam_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");
	if (!IsValidAndInGame(client)) return;
	
	Call_StartForward(hFwdTeamChanged);
	Call_PushCell(client);
	Call_PushCell(oldteam);
	Call_PushCell(team);
	Call_Finish();
	
	if (team > 1 && oldteam <= 1)
	{
		SDKHook(client, SDKHook_OnTakeDamage, fOnTakeDamage);
	}
	else if (team <= 1 && oldteam > 1)
	{
		SDKUnhook(client, SDKHook_OnTakeDamage, fOnTakeDamage);
	}
	
	if (oldteam == 2 || team == 2)
	{
		CreateTimer(0.3, BuildArray_Timer);
	}
}

public Action fOnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3])
{
	if (!IsValidAndInGame(victim))
	{
		return Plugin_Continue;
	}
	
	Action aResult = Plugin_Continue;
    Call_StartForward(hFwdOnTakeDamage);
    Call_PushCell(victim);
	Call_PushCellRef(attacker);
	Call_PushCellRef(inflictor);
	Call_PushFloatRef(damage);
	Call_PushCellRef(damageType);
	Call_PushCellRef(weapon);
	Call_PushArray(damageForce, 3);
	Call_PushArray(damagePosition, 3);
    Call_Finish(aResult);
	
	return aResult;
}

public Action BuildArray_Timer(Handle timer)
{
	Survivors_RebuildArray();
}

public void BuildIndex_Event(Event event, const char[] name, bool dontBroadcast)
{
	Survivors_RebuildArray();
}

public Action Event_ServerConVar(Event event, const char[] name, bool dontBroadcast)
{
	return Plugin_Handled;
}



/* Commands */
public Action Say_Callback(int client, char[] command, int args)
{
    char sayWord[MAX_NAME_LENGTH];
    GetCmdArg(1, sayWord, sizeof(sayWord));
    if (sayWord[0] == '!' || sayWord[0] == '/') return Plugin_Handled;
    return Plugin_Continue; 
}



/* Plugin Natives */
public any _native_GetCurrentRound(Handle plugin, int numParams)
{
	return iRoundNumber;
}

public any _native_CurrentlyInRound(Handle plugin, int numParams)
{
	return bInRound;
}

public any _native_GetSurvivorCount(Handle plugin, int numParams)
{
	return NUM_OF_SURVIVORS;
}

public any _native_GetSurvivorOfIndex(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	if (index < 0 || index > 3)
	{
		return 0;
	}
	return iSurvivorIndex[index];
}

public any _native_IsMapDataAvailable(Handle plugin, int numParams)
{
	return MapDataAvailable;
}

public any _native_IsEntityInSaferoom(Handle plugin, int numParams)
{
    int entity = GetNativeCell(1);
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) return false;
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	Saferoom result = Saferoom_Neither;
	if (SaferoomDataAvailable)
	{
		if (IsPointInStartSaferoom(location))
		{
			result |= Saferoom_Start;
		}
		if (IsPointInEndSaferoom(location))
		{
			result |= Saferoom_End;
		}
	}
	else
	{
		if ((GetVectorDistance(location, Start_Point) <= (Start_Extra_Dist > Start_Dist ? Start_Extra_Dist : Start_Dist)))
		{
			result |= Saferoom_Start;
		}
	}
	return result;
}

public any _native_GetMapValueInt(Handle plugin, int numParams)
{
	int len, defval;
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	defval = GetNativeCell(2);
	
	return KvGetNum(kvMapInfo, key, defval); 
}

public any _native_GetMapValueFloat(Handle plugin, int numParams)
{
	int len;
	float defval;
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	defval = GetNativeCell(2);
	
	return KvGetFloat(kvMapInfo, key, defval); 
}

public any _native_GetMapValueVector(Handle plugin, int numParams)
{
	int len;
	float defval[3], value[3];
	
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	
	GetNativeArray(3, defval, 3);
	
	KvGetVector(kvMapInfo, key, value, defval);
	
	SetNativeArray(2, value, 3);
}

public any _native_GetMapValueString(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	char[] key = new char[len+1];
	GetNativeString(1, key, len+1);
	
	GetNativeStringLength(4, len);
	char[] defval = new char[len+1];
	GetNativeString(4, defval, len+1);
	
	len = GetNativeCell(3);
	char[] buf = new char[len+1];
	
	KvGetString(kvMapInfo, key, buf, len, defval);
	
	SetNativeString(2, buf, len);
}

public any _native_CopyMapSubsection(Handle plugin, int numParams)
{
	int len;
	Handle kv;
	GetNativeStringLength(2, len);
	char[] key = new char[len+1];
	GetNativeString(2, key, len+1);
	
	kv = GetNativeCell(1);
	
	if (KvJumpToKey(kvMapInfo, key, false))
	{
		KvCopySubkeys(kvMapInfo, kv);
		KvGoBack(kvMapInfo);
	}
}


public any _native_ClientModelToSC(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] model = new char[len];
	GetNativeString(1, model, len);
	
	SurvivorCharacter sc;
	if (hSurvivorModelsTrie.GetValue(model, sc))
	{
		return sc;
	}

	return SurvivorCharacter_Invalid;
}

public any _native_WeaponNameToId(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] weaponName = new char[len];
	GetNativeString(1, weaponName, len);
    WeaponId id;
    if (hWeaponNamesTrie.GetValue(weaponName, id))
    {
        return id;
    }
    return WEPID_NONE;
}

public any _native_GetMeleeWeaponIdFromName(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] sName = new char[len];
	GetNativeString(1, sName, len);
	
    int id;
    if (hMeleeWeaponNamesTrie.GetValue(sName, id))
    {
        return id;
    }
	return WEPID_MELEE_NONE;
}

public any _native_GetMeleeWeaponNameFromModel(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] sModelName = new char[len];
	GetNativeString(1, sModelName, len);

	len = GetNativeCell(3);
	char[] buffer = new char[len];
	
	if (hMeleeWeaponModelsTrie.GetString(sModelName, buffer, len))
	{
		SetNativeString(2, buffer, len);
		return true;
	}
	return false;
}


public any _native_InSecondHalfOfRound(Handle plugin, int numParams)
{
	return (L4D2_IsScavengeMode() || L4D_IsVersusMode()) ? view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound")) : bInSecondRound;
}

public any _native_IsInTransition(Handle plugin, int numParams)
{
	return !bIsMapActive;
}


/* NATIVE FUNCTIONS */
// New Super Awesome Functions!!!

void Update_MapInfo()
{
    g_bHasStart = false;        g_bHasStartExtra = false;
    g_bHasEnd = false;          g_bHasEndExtra = false;
    g_fStartLocA = NULL_VECTOR; g_fStartLocB = NULL_VECTOR; g_fStartLocC = NULL_VECTOR; g_fStartLocD = NULL_VECTOR;
    g_fEndLocA = NULL_VECTOR;   g_fEndLocB = NULL_VECTOR;   g_fEndLocC = NULL_VECTOR;   g_fEndLocD = NULL_VECTOR;
    g_fStartRotate = 0.0;       g_fEndRotate = 0.0;
	
	if (KvJumpToKey(kvMapInfo, g_sMapname))
	{
		MapDataAvailable = true;
	}
	else
	{
		MapDataAvailable = false;
		LogMessage("[MI] MapInfo for %s is missing.", g_sMapname);
	}
	
    if (KvJumpToKey(kvSafeRoomInfo, g_sMapname))
    {
        KvGetVector(kvSafeRoomInfo, "start_loc_a", g_fStartLocA);
        KvGetVector(kvSafeRoomInfo, "start_loc_b", g_fStartLocB);
        KvGetVector(kvSafeRoomInfo, "start_loc_c", g_fStartLocC);
        KvGetVector(kvSafeRoomInfo, "start_loc_d", g_fStartLocD);
        g_fStartRotate = KvGetFloat(kvSafeRoomInfo, "start_rotate", g_fStartRotate);
        KvGetVector(kvSafeRoomInfo, "end_loc_a", g_fEndLocA);
        KvGetVector(kvSafeRoomInfo, "end_loc_b", g_fEndLocB);
        KvGetVector(kvSafeRoomInfo, "end_loc_c", g_fEndLocC);
        KvGetVector(kvSafeRoomInfo, "end_loc_d", g_fEndLocD);
        g_fEndRotate = KvGetFloat(kvSafeRoomInfo, "end_rotate", g_fEndRotate);
        
        if (g_fStartLocA[0] != 0.0 && g_fStartLocA[1] != 0.0 && g_fStartLocA[2] != 0.0 && g_fStartLocB[0] != 0.0 && g_fStartLocB[1] != 0.0 && g_fStartLocB[2] != 0.0) { g_bHasStart = true; }
        if (g_fStartLocC[0] != 0.0 && g_fStartLocC[1] != 0.0 && g_fStartLocC[2] != 0.0 && g_fStartLocD[0] != 0.0 && g_fStartLocD[1] != 0.0 && g_fStartLocD[2] != 0.0) { g_bHasStartExtra = true; }
        if (g_fEndLocA[0] != 0.0 && g_fEndLocA[1] != 0.0 && g_fEndLocA[2] != 0.0 && g_fEndLocB[0] != 0.0 && g_fEndLocB[1] != 0.0 && g_fEndLocB[2] != 0.0) { g_bHasEnd = true; }
        if (g_fEndLocC[0] != 0.0 && g_fEndLocC[1] != 0.0 && g_fEndLocC[2] != 0.0 && g_fEndLocD[0] != 0.0 && g_fEndLocD[1] != 0.0 && g_fEndLocD[2] != 0.0) { g_bHasEndExtra = true; }
        
        if (g_fStartRotate != 0.0)
		{
            RotatePoint(g_fStartLocA, g_fStartLocB[0], g_fStartLocB[1], g_fStartRotate);
            if (g_bHasStartExtra)
			{
                RotatePoint(g_fStartLocA, g_fStartLocC[0], g_fStartLocC[1], g_fStartRotate);
                RotatePoint(g_fStartLocA, g_fStartLocD[0], g_fStartLocD[1], g_fStartRotate);
            }
        }
        if (g_fEndRotate != 0.0)
		{
            RotatePoint(g_fEndLocA, g_fEndLocB[0], g_fEndLocB[1], g_fEndRotate);
            if (g_bHasEndExtra)
			{
                RotatePoint(g_fEndLocA, g_fEndLocC[0], g_fEndLocC[1], g_fEndRotate);
                RotatePoint(g_fEndLocA, g_fEndLocD[0], g_fEndLocD[1], g_fEndRotate);
            }
        }
		SaferoomDataAvailable = true;
    }
    else
    {
		SaferoomDataAvailable = false;
		Start_Dist = FindStartPointHeuristic(Start_Point);
		if(Start_Dist > 0.0)
		{
			Start_Extra_Dist = 500.0;
		}
		else
		{
			Start_Point = NULL_VECTOR;
			Start_Dist = -1.0;
			Start_Extra_Dist = -1.0;
		}
		
        LogMessage("[SI] SaferoomInfo for %s is missing.", g_sMapname);
    }
}

void RotatePoint(float origin[3], float &pointX, float &pointY, float angle)
{
    float newPoint[2];
    angle = angle / 57.2957795130823;
    
    newPoint[0] = (Cosine(angle) * (pointX - origin[0])) - (Sine(angle) * (pointY - origin[1]))   + origin[0];
    newPoint[1] = (Sine(angle) * (pointX - origin[0]))   + (Cosine(angle) * (pointY - origin[1])) + origin[1];
    
    pointX = newPoint[0];
    pointY = newPoint[1];
}

bool IsPointInStartSaferoom(float location[3])
{
	if (!g_bHasStart) { return false; }
	
	bool inSaferoom = false;
	
	if (g_fStartRotate)
	{
		RotatePoint(g_fStartLocA, location[0], location[1], g_fStartRotate);
	}
	
	float xMin, xMax, yMin, yMax, zMin, zMax;
	
	if (g_fStartLocA[0] < g_fStartLocB[0]) { xMin = g_fStartLocA[0]; xMax = g_fStartLocB[0]; } else { xMin = g_fStartLocB[0]; xMax = g_fStartLocA[0]; }
	if (g_fStartLocA[1] < g_fStartLocB[1]) { yMin = g_fStartLocA[1]; yMax = g_fStartLocB[1]; } else { yMin = g_fStartLocB[1]; yMax = g_fStartLocA[1]; }
	if (g_fStartLocA[2] < g_fStartLocB[2]) { zMin = g_fStartLocA[2]; zMax = g_fStartLocB[2]; } else { zMin = g_fStartLocB[2]; zMax = g_fStartLocA[2]; }
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
		
	if (!inSaferoom && g_bHasStartExtra)
	{
		if (g_fStartLocC[0] < g_fStartLocD[0]) { xMin = g_fStartLocC[0]; xMax = g_fStartLocD[0]; } else { xMin = g_fStartLocD[0]; xMax = g_fStartLocC[0]; }
		if (g_fStartLocC[1] < g_fStartLocD[1]) { yMin = g_fStartLocC[1]; yMax = g_fStartLocD[1]; } else { yMin = g_fStartLocD[1]; yMax = g_fStartLocC[1]; }
		if (g_fStartLocC[2] < g_fStartLocD[2]) { zMin = g_fStartLocC[2]; zMax = g_fStartLocD[2]; } else { zMin = g_fStartLocD[2]; zMax = g_fStartLocC[2]; }
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	
	return inSaferoom;
}

bool IsPointInEndSaferoom(float location[3])
{    
	if (!g_bHasEnd) { return false; }
	
	bool inSaferoom = false;
	
	if (g_fEndRotate)
	{
		RotatePoint(g_fEndLocA, location[0], location[1], g_fEndRotate);
	}
	
	float xMin, xMax, yMin, yMax, zMin, zMax;
	
	if (g_fEndLocA[0] < g_fEndLocB[0]) { xMin = g_fEndLocA[0]; xMax = g_fEndLocB[0]; } else { xMin = g_fEndLocB[0]; xMax = g_fEndLocA[0]; }
	if (g_fEndLocA[1] < g_fEndLocB[1]) { yMin = g_fEndLocA[1]; yMax = g_fEndLocB[1]; } else { yMin = g_fEndLocB[1]; yMax = g_fEndLocA[1]; }
	if (g_fEndLocA[2] < g_fEndLocB[2]) { zMin = g_fEndLocA[2]; zMax = g_fEndLocB[2]; } else { zMin = g_fEndLocB[2]; zMax = g_fEndLocA[2]; }
	
	inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	
	if (!inSaferoom && g_bHasEndExtra)
	{
		if (g_fEndLocC[0] < g_fEndLocD[0]) { xMin = g_fEndLocC[0]; xMax = g_fEndLocD[0]; } else { xMin = g_fEndLocD[0]; xMax = g_fEndLocC[0]; }
		if (g_fEndLocC[1] < g_fEndLocD[1]) { yMin = g_fEndLocC[1]; yMax = g_fEndLocD[1]; } else { yMin = g_fEndLocD[1]; yMax = g_fEndLocC[1]; }
		if (g_fEndLocC[2] < g_fEndLocD[2]) { zMin = g_fEndLocC[2]; zMax = g_fEndLocD[2]; } else { zMin = g_fEndLocD[2]; zMax = g_fEndLocC[2]; }
		
		inSaferoom = view_as<bool>(location[0] >= xMin && location[0] <= xMax && location[1] >= yMin && location[1] <= yMax && location[2] >= zMin && location[2] <= zMax);
	}
	
	return inSaferoom;
}

void ResetStatus()
{
	bExpectTankSpawn = false;
	bIsTankActive = false;
	iTank = -1;
	iTankPassCount = 0;
	if (hTankDeathTimer != null)
	{
		KillTimer(hTankDeathTimer);
		hTankDeathTimer = null;
	}
}

void Survivors_RebuildArray()
{
	if (!IsServerProcessing()) return;
	int iSurvivorCount = 0;
	int charz;
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++) iSurvivorIndex[i] = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (iSurvivorCount == NUM_OF_SURVIVORS) break;
		
		if (!IsClientInGame(i) || GetClientTeam(i) != 2) continue;
		
		charz = GetEntProp(i, Prop_Send, "m_survivorCharacter");
		iSurvivorCount++;
		
		if (charz > 3 || charz < 0) continue;
		
		iSurvivorIndex[charz] = 0;
		
		if (!IsPlayerAlive(i)) continue;
		
		iSurvivorIndex[charz] = i;
	}
}

float FindStartPointHeuristic(float result[3])
{
	int kits, entcount = GetEntityCount();
	float kitOrigin[4][3], averageOrigin[3];
	char entclass[128];
	for (int iEntity = 1;iEntity<=entcount && kits <4;iEntity++)
	{
		if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) continue;
		GetEdictClassname(iEntity,entclass,sizeof(entclass));
		if (StrEqual(entclass, "weapon_first_aid_kit_spawn"))
		{
			GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", kitOrigin[kits]);
			averageOrigin[0] += kitOrigin[kits][0];
			averageOrigin[1] += kitOrigin[kits][1];
			averageOrigin[2] += kitOrigin[kits][2];
			kits++;
		}
	}
	if (kits < 4) return -1.0;
	ScaleVector(averageOrigin, 0.25);
	
	float greatestDist, tempDist;
	for (int i; i < 4; i++)
	{
		tempDist = GetVectorDistance(averageOrigin, kitOrigin[i]);
		if (tempDist > greatestDist) greatestDist = tempDist;
	}
	result = averageOrigin;
	return greatestDist+1.0;
}

bool IsValidAndInGame(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}
