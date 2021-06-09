/*
*	l4d2library
*	Copyright (C) 2020 Yukari190
*
*	This program is free software: you can redistribute it and/or modify
*	it under the terms of the GNU General Public License as published by
*	the Free Software Foundation, either version 3 of the License, or
*	(at your option) any later version.
*
*	This program is distributed in the hope that it will be useful,
*	but WITHOUT ANY WARRANTY; without even the implied warranty of
*	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*	GNU General Public License for more details.
*
*	You should have received a copy of the GNU General Public License
*	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/



#define PLUGIN_VERSION		"1.1"



#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

#define MAX_MESSAGE_LENGTH 250
#define MAX_COLORS 6

#define SERVER_INDEX 0
#define NO_INDEX -1
#define NO_PLAYER -2

#define MOVESPEED_MAX     1000

#define UNINITIALISED_FLOAT -1.42424
#define NAV_MESH_HEIGHT 20.0
#define COORD_X 0
#define COORD_Y 1
#define COORD_Z 2
#define X_MIN 0
#define X_MAX 1
#define Y_MIN 2
#define Y_MAX 3
#define PITCH 0
#define YAW 1
#define ROLL 2
#define MAX_ANGLE 89.0

// FORWARDS
GlobalForward hFwdRoundStart;
GlobalForward hFwdRoundEnd;
GlobalForward hFwdFirstTankSpawn;
GlobalForward hFwdTankPassControl;
GlobalForward hFwdTankDeath;
GlobalForward hFwd_PlayerHurt;
GlobalForward hFwdJoinSurvivor;
GlobalForward hFwdAwaySurvivor;
GlobalForward hFwdJoinInfected;
GlobalForward hFwdAwayInfected;
GlobalForward hFwdTeamChanged;
GlobalForward hFwdInfectedSpawn;
GlobalForward hFwdTankRunCmd;
GlobalForward hFwdSmokerRunCmd;
GlobalForward hFwdHunterRunCmd;
GlobalForward hFwdJockeyRunCmd;
GlobalForward hFwdBoomerRunCmd;
GlobalForward hFwdSpitterRunCmd;
GlobalForward hFwdChargerRunCmd;
GlobalForward hFwdEntitySpawned;

Handle hRoundRespawn;
Handle sdkCallFling;
Handle hSDKGiveDefaultAmmo;

// l4d2lib
StringMap hSurvivorModelsTrie;
StringMap casterTrie;
StringMap allowedCastersTrie;
float fTankFlow;
float fVsBossBuffer;
float fDecayRate;
float g_move_grad[MAXPLAYERS+1][3];
float g_move_speed[MAXPLAYERS+1];
float g_pos[MAXPLAYERS+1][3];
float g_delay[MAXPLAYERS+1][8];
float fTankLotterySelectionTime;
int iGameMode;
int g_state[MAXPLAYERS+1][8];
int iSurvivorLimit;
int iMaxPlayerZombies;
int iAmmoPile;
bool bPause[MAXPLAYERS+1];
bool IsMapInStart;
bool bTankSpawn;
ConVar hGameMode;
ConVar g_hVsBossBuffer;
ConVar hDecayRate;
ConVar hMaxPlayers;
ConVar hVisibleMaxPlayers;
ConVar hSurvivorLimit;
ConVar hMaxPlayerZombies;
ConVar hTankLotterySelectionTime;
char g_sMapname[64];
char SurvivorNames[8][128] =
{
    "Coach",
    "Nick",
    "Rochelle",
    "Ellis",
    "Louis",
    "Zoey",
    "Bill",
    "Francis"
};
char SurvivorModels[8][128] =
{
    "models/survivors/survivor_coach.mdl",
    "models/survivors/survivor_gambler.mdl",
    "models/survivors/survivor_producer.mdl",
    "models/survivors/survivor_mechanic.mdl",
    "models/survivors/survivor_manager.mdl",
    "models/survivors/survivor_teenangst.mdl",
    "models/survivors/survivor_namvet.mdl",
    "models/survivors/survivor_biker.mdl"
};
char InfectedVictimNetprops[][] =
{
	"",
    "m_tongueVictim",
    "",
    "m_pounceVictim",
    "",
    "m_jockeyVictim",
    "m_pummelVictim",
    "",
    ""
};
char SI_DOMINATION_OFFSETS[][] = 
{
    "m_tongueOwner",
    "m_pounceAttacker",
    "m_jockeyAttacker",
    "m_pummelAttacker"
};
char InfectedNames[][] =
{
    "",
    "Smoker",
    "Boomer",
    "Hunter",
    "Spitter",
    "Jockey",
    "Charger",
    "Witch",
    "Tank"
};

bool bSecondRound;
bool bRoundEnd;
bool bInRound;
int iSurvivorIndex[NUM_OF_SURVIVORS];
int iSurvivorCount;

Handle hTankDeathTimer;
bool bIsTankActive;
bool bExpectTankSpawn;
int iTank;
int iTankPassCount;

KeyValues kvData;

bool g_bHasStart;
bool g_bHasStartExtra;
float g_fStartLocA[3];
float g_fStartLocB[3];
float g_fStartLocC[3];
float g_fStartLocD[3];
float g_fStartRotate;
bool g_bHasEnd;
bool g_bHasEndExtra;
float g_fEndLocA[3];
float g_fEndLocB[3];
float g_fEndLocC[3];
float g_fEndLocD[3];
float g_fEndRotate;

// Weapons
StringMap hWeaponNamesTrie;
StringMap hMeleeWeaponNamesTrie;
StringMap hMeleeWeaponModelsTrie;

char WeaponNames[view_as<int>(WEPID_UPGRADE_ITEM)+1][] =
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

char LongWeaponNames[view_as<int>(WEPID_UPGRADE_ITEM)+1][] = 
{
    "None", "Pistol", "Uzi", // 0
    "Pump", "Autoshotgun", "M-16", // 3
    "Hunting Rifle", "Mac", "Chrome", // 6
    "Desert Rifle", "Military Sniper", "SPAS Shotgun", // 9
    "First Aid Kit", "Molotov", "Pipe Bomb", // 12
    "Pills", "Gascan", "Propane Tank", // 15
    "Oxygen Tank", "Melee", "Chainsaw", // 18
    "Grenade Launcher", "Ammo Pack", "Adrenaline", // 21
    "Defibrillator", "Bile Bomb", "AK-47", // 24
    "Gnome", "Cola Bottles", "Fireworks", // 27
    "Incendiary Ammo Pack", "Explosive Ammo Pack", "Deagle", // 30
    "MP5", "SG552", "AWP", // 33
    "Scout", "M60", "Tank Claw", // 36
    "Hunter Claw", "Charger Claw", "Boomer Claw", // 39
    "Smoker Claw", "Spitter Claw", "Jockey Claw", // 42
    "Turret", "vomit", "splat", // 45
    "pounce", "lounge", "pull", // 48
    "choke", "rock", "physics", // 51
    "ammo", "upgrade_item" // 54
};

char MeleeWeaponNames[view_as<int>(WEPID_PITCHFORK)+1][] =
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

char WeaponModels[view_as<int>(WEPID_UPGRADE_ITEM)+1][] =
{
    "",
    "/w_models/weapons/w_pistol_B.mdl",
    "/w_models/weapons/w_smg_uzi.mdl",
    "/w_models/weapons/w_shotgun.mdl",
    "/w_models/weapons/w_autoshot_m4super.mdl",
    "/w_models/weapons/w_rifle_m16a2.mdl",
    "/w_models/weapons/w_sniper_mini14.mdl",
    "/w_models/weapons/w_smg_a.mdl",
    "/w_models/weapons/w_pumpshotgun_a.mdl",
    "/w_models/weapons/w_desert_rifle.mdl",           // "/w_models/weapons/w_rifle_b.mdl"
    "/w_models/weapons/w_sniper_military.mdl",
    "/w_models/weapons/w_shotgun_spas.mdl",
    "/w_models/weapons/w_eq_medkit.mdl",
    "/w_models/weapons/w_eq_molotov.mdl",
    "/w_models/weapons/w_eq_pipebomb.mdl",
    "/w_models/weapons/w_eq_painpills.mdl",
    "/props_junk/gascan001a.mdl",
    "/props_junk/propanecanister001.mdl",
    "/props_equipment/oxygentank01.mdl",
    "",
    "/weapons/melee/w_chainsaw.mdl",
    "/w_models/weapons/w_grenade_launcher.mdl",
    "",
    "/w_models/weapons/w_eq_adrenaline.mdl",
    "/w_models/weapons/w_eq_defibrillator.mdl",
    "/w_models/weapons/w_eq_bile_flask.mdl",
    "/w_models/weapons/w_rifle_ak47.mdl",
    "/props_junk/gnome.mdl",
    "/w_models/weapons/w_cola.mdl",
    "/props_junk/explosive_box001.mdl",
    "/w_models/weapons/w_eq_incendiary_ammopack.mdl",
    "/w_models/weapons/w_eq_explosive_ammopack.mdl",
    "/w_models/weapons/w_desert_eagle.mdl",
    "/w_models/weapons/w_smg_mp5.mdl",
    "/w_models/weapons/w_rifle_sg552.mdl",
    "/w_models/weapons/w_sniper_awp.mdl",
    "/w_models/weapons/w_sniper_scout.mdl",
    "/w_models/weapons/w_m60.mdl",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    "",
    ""
};

char MeleeWeaponModels[view_as<int>(WEPID_PITCHFORK)+1][] =
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
    "/weapons/melee/v_shovel.mdl",
    "/weapons/melee/v_pitchfork.mdl"
};

char LongMeleeWeaponNames[view_as<int>(WEPID_PITCHFORK)+1][] =
{
    "None",
    "Knife",
    "Baseball Bat",
    "Chainsaw",
    "Cricket Bat",
    "Crowbar",
    "didgeridoo", // derp
    "Guitar",
    "Axe",
    "Frying Pan",
    "Golf Club",
    "Katana",
    "Machete",
    "Riot Shield",
    "Tonfa",
    "Shovel",
    "Pitchfork"
};

int WeaponSlots[view_as<int>(WEPID_UPGRADE_ITEM)+1] =
{
    -1, // WEPID_NONE
    1,  // WEPID_PISTOL
    0,  // WEPID_SMG
    0,  // WEPID_PUMPSHOTGUN
    0,  // WEPID_AUTOSHOTGUN
    0,  // WEPID_RIFLE
    0,  // WEPID_HUNTING_RIFLE
    0,  // WEPID_SMG_SILENCED
    0,  // WEPID_SHOTGUN_CHROME
    0,  // WEPID_RIFLE_DESERT
    0,  // WEPID_SNIPER_MILITARY
    0,  // WEPID_SHOTGUN_SPAS
    3,  // WEPID_FIRST_AID_KIT
    2,  // WEPID_MOLOTOV
    2,  // WEPID_PIPE_BOMB
    4,  // WEPID_PAIN_PILLS
    -1, // WEPID_GASCAN
    -1, // WEPID_PROPANE_TANK
    -1, // WEPID_OXYGEN_TANK
    1,  // WEPID_MELEE
    1,  // WEPID_CHAINSAW
    0,  // WEPID_GRENADE_LAUNCHER
    3,  // WEPID_AMMO_PACK
    4,  // WEPID_ADRENALINE
    3,  // WEPID_DEFIBRILLATOR
    2,  // WEPID_VOMITJAR
    0,  // WEPID_RIFLE_AK47
    -1, // WEPID_GNOME_CHOMPSKI
    -1, // WEPID_COLA_BOTTLES
    -1, // WEPID_FIREWORKS_BOX
    3,  // WEPID_INCENDIARY_AMMO
    3,  // WEPID_FRAG_AMMO
    1,  // WEPID_PISTOL_MAGNUM
    0,  // WEPID_SMG_MP5
    0,  // WEPID_RIFLE_SG552
    0,  // WEPID_SNIPER_AWP
    0,  // WEPID_SNIPER_SCOUT
    0,  // WEPID_RIFLE_M60
    -1, // WEPID_TANK_CLAW
    -1, // WEPID_HUNTER_CLAW
    -1, // WEPID_CHARGER_CLAW
    -1, // WEPID_BOOMER_CLAW
    -1, // WEPID_SMOKER_CLAW
    -1, // WEPID_SPITTER_CLAW
    -1, // WEPID_JOCKEY_CLAW
    -1, // WEPID_MACHINEGUN
    -1, // WEPID_FATAL_VOMIT
    -1, // WEPID_EXPLODING_SPLAT
    -1, // WEPID_LUNGE_POUNCE
    -1, // WEPID_LOUNGE
    -1, // WEPID_FULLPULL
    -1, // WEPID_CHOKE
    -1, // WEPID_THROWING_ROCK
    -1, // WEPID_TURBO_PHYSICS
    -1, // WEPID_AMMO
    -1  // WEPID_UPGRADE_ITEM
};


// colors.inc
enum Colors
{
 	Color_Default = 0,
	Color_Green,
	Color_Lightgreen,
	Color_Red,
	Color_Blue,
	Color_Olive
}

/* Colors' properties */
//				白色  橙色  浅绿色  红色  蓝色 橄榄绿
char CTag[][] = {"{W}", "{O}", "{LG}", "{R}", "{B}", "{G}"};
char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
bool CTagReqSayText2[] = {false, false, true, true, true, false};

/* Game default profile */
bool CProfile_Colors[] = {true, true, false, false, false, false};
int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, NO_INDEX, NO_INDEX, NO_INDEX, NO_INDEX};



// ====================================================================================================
//										PLUGIN INFO / START
// ====================================================================================================
public Plugin myinfo =
{
	name = "l4d2library",
	description = "Useful natives and fowards for L4D2 Plugins",
	author = "Confogl Team, Yukari190",
	version = PLUGIN_VERSION,
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	
	
	// ====================================================================================================
	//									FORWARDS
	// ====================================================================================================
	// FORWARDS
	// List should match the CreateDetour list of forwards.
	hFwdRoundStart = new GlobalForward("L4D2_OnRealRoundStart", ET_Ignore);
	hFwdRoundEnd = new GlobalForward("L4D2_OnRealRoundEnd", ET_Ignore);
	hFwdFirstTankSpawn = new GlobalForward("L4D2_OnTankFirstSpawn", ET_Ignore, Param_Cell);
	hFwdTankPassControl = new GlobalForward("L4D2_OnTankPassControl", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	hFwdTankDeath = new GlobalForward("L4D2_OnTankDeath", ET_Ignore, Param_Cell, Param_Cell);
	hFwd_PlayerHurt = new GlobalForward("L4D2_OnPlayerHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_String, Param_Cell, Param_Cell, Param_Cell);
	hFwdJoinSurvivor = new GlobalForward("L4D2_OnJoinSurvivor", ET_Event, Param_Cell);
	hFwdAwaySurvivor = new GlobalForward("L4D2_OnAwaySurvivor", ET_Event, Param_Cell);
	hFwdJoinInfected = new GlobalForward("L4D2_OnJoinInfected", ET_Event, Param_Cell);
	hFwdAwayInfected = new GlobalForward("L4D2_OnAwayInfected", ET_Event, Param_Cell);
	hFwdTeamChanged = new GlobalForward("L4D2_OnPlayerTeamChanged", ET_Event, Param_Cell, Param_Cell, Param_Cell);
	hFwdInfectedSpawn = new GlobalForward("L4D2_OnInfectedSpawn", ET_Ignore, Param_Cell, Param_Cell);
	hFwdTankRunCmd = new GlobalForward("L4D2_OnTankRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdSmokerRunCmd = new GlobalForward("L4D2_OnSmokerRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdHunterRunCmd = new GlobalForward("L4D2_OnHunterRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdJockeyRunCmd = new GlobalForward("L4D2_OnJockeyRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdBoomerRunCmd = new GlobalForward("L4D2_OnBoomerRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdSpitterRunCmd = new GlobalForward("L4D2_OnSpitterRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdChargerRunCmd = new GlobalForward("L4D2_OnChargerRunCmd", ET_Event, Param_Cell, Param_Cell, Param_Array, Param_Array);
	hFwdEntitySpawned = new GlobalForward("L4D2_OnEntitySpawned", ET_Ignore, Param_Cell, Param_String);
	
	
	
	// ====================================================================================================
	//									NATIVES
	// ====================================================================================================
	CreateNative("L4D2_SetMaxPlayers", _native_SetMaxPlayers);
	CreateNative("L4D2_ChangeClientTeam", _native_ChangeClientTeam);
	CreateNative("L4D2_FillBots", _native_FillBots);
	CreateNative("L4D2_RestoreHealth", _native_RestoreHealth);
	CreateNative("L4D2_ResetInventory", _native_ResetInventory);
	CreateNative("L4D2_IsLanIP", _native_IsLanIP);
	CreateNative("L4D2_SetAnimFling", _native_SetAnimFling);
	CreateNative("L4D2_SetPlayerRespawn", _native_SetPlayerRespawn);
	CreateNative("L4D2_PauseClient", _native_PauseClient);
	CreateNative("L4D2_IsClientCaster", _native_IsClientCaster);
	CreateNative("L4D2_IsIDCaster", _native_IsIDCaster);
	CreateNative("L4D2_GetRandomSurvivor", _native_GetRandomSurvivor);
	CreateNative("L4D2_IdentifySurvivor", _native_IdentifySurvivor);
	CreateNative("L4D2_ClientModelToSC", _native_ClientModelToSC);
	CreateNative("L4D2_GetSurvivorName", _native_GetSurvivorName);
	CreateNative("L4D2_GetInfectedClassName", _native_GetInfectedClassName);
	CreateNative("L4D2_DelayStart", _native_DelayStart);
	CreateNative("L4D2_DelayExpired", _native_DelayExpired);
	CreateNative("L4D2_SetState", _native_SetState);
	CreateNative("L4D2_GetState", _native_GetState);
	CreateNative("L4D2_NearestSurvivorDistance", _native_NearestSurvivorDistance);
	CreateNative("L4D2_NearestActiveSurvivorDistance", _native_NearestActiveSurvivorDistance);
	CreateNative("L4D2_GetMoveSpeed", _native_GetMoveSpeed);
	CreateNative("L4D2_IsCoop", _native_IsCoop);
	CreateNative("L4D2_IsVersus", _native_IsVersus);
	CreateNative("L4D2_IsScavenge", _native_IsScavenge);
	CreateNative("L4D2_IsSurvival", _native_IsSurvival);
	CreateNative("L4D2_GetTankToSpawn", _native_GetTankToSpawn);
	CreateNative("L4D2_SetTankToSpawn", _native_SetTankToSpawn);
	CreateNative("L4D2_GetTankFlowPercent", _native_GetTankFlowPercent);
	CreateNative("L4D2_SetTankFlowPercent", _native_SetTankFlowPercent);
	CreateNative("L4D2_GetFurthestSurvivorFlow2", _native_GetFurthestSurvivorFlow);
	CreateNative("L4D2_GetHighestSurvivorFlow", _native_GetHighestSurvivorFlow);
	//CreateNative("L4D2_GetTankFlow", _native_GetTankFlow);
	CreateNative("L4D2_GetSurvivorTemporaryHealth", _native_GetSurvivorTemporaryHealth);
	CreateNative("L4D2_GetInfectedVictim", _native_GetInfectedVictim);
	CreateNative("L4D2_IsBeingAttacked", _native_IsBeingAttacked);
	CreateNative("L4D2_IsSecondRound", _native_IsSecondRound);
	CreateNative("L4D2_CurrentlyInRound", _native_CurrentlyInRound);
	CreateNative("L4D2_GetSurvivorCount", _native_GetSurvivorCount);
	CreateNative("L4D2_GetSurvivorOfIndex", _native_GetSurvivorOfIndex);
	CreateNative("L4D2_GiveDefaultAmmo", _native_GiveDefaultAmmo);
	CreateNative("L4D2_GetMapValueInt", _native_GetMapValueInt);
	CreateNative("L4D2_GetMapValueFloat", _native_GetMapValueFloat);
	CreateNative("L4D2_GetMapValueVector", _native_GetMapValueVector);
	CreateNative("L4D2_IsEntityInSaferoom", _native_IsEntityInSaferoom);
	//CreateNative("L4D2_IsPlayerInSaferoom", _native_IsPlayerInSaferoom);
	CreateNative("L4D2_GetSlotFromWeaponId", _native_GetSlotFromWeaponId);
	CreateNative("L4D2_HasValidWeaponModel", _native_HasValidWeaponModel);
	CreateNative("L4D2_HasValidMeleeWeaponModel", _native_HasValidMeleeWeaponModel);
	CreateNative("L4D2_WeaponNameToId", _native_WeaponNameToId);
	CreateNative("L4D2_GetWeaponName", _native_GetWeaponName);
	CreateNative("L4D2_GetLongWeaponName", _native_GetLongWeaponName);
	CreateNative("L4D2_GetLongMeleeWeaponName", _native_GetLongMeleeWeaponName);
	CreateNative("L4D2_GetWeaponModel", _native_GetWeaponModel);
	CreateNative("L4D2_IdentifyWeapon", _native_IdentifyWeapon);
	CreateNative("L4D2_GetMeleeWeaponNameFromEntity", _native_GetMeleeWeaponNameFromEntity);
	CreateNative("L4D2_IdentifyMeleeWeapon", _native_IdentifyMeleeWeapon);
	CreateNative("L4D2_ConvertWeaponSpawn", _native_ConvertWeaponSpawn);
	CreateNative("L4D2_CPrintToChat", _native_CPrintToChat);
	CreateNative("L4D2_CPrintToChatAll", _native_CPrintToChatAll);
	
	RegPluginLibrary("l4d2library");
	return APLRes_Success;
}

public void OnPluginStart()
{
	// ====================================================================================================
	//									SETUP
	// ====================================================================================================
	char sNameBuff[PLATFORM_MAX_PATH];
	kvData = new KeyValues("MapInfo");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "../../cfg/lgofnoc/shared/mapinfo.txt");
	if (!FileToKeyValues(kvData, sNameBuff))
	{
		LogError("[MI] 找不到 mapinfo.txt 文件信息");
		delete kvData;
	}
	
	casterTrie = new StringMap();
	allowedCastersTrie = new StringMap();
	
    hSurvivorModelsTrie = new StringMap();
    for (int i = 0; i < 8; i++)
	{
		hSurvivorModelsTrie.SetValue(SurvivorModels[i], i);
	}
	
	hWeaponNamesTrie = new StringMap();
	for (int i = 0; i < view_as<int>(WEPID_UPGRADE_ITEM)+1; i++)
	{
		hWeaponNamesTrie.SetValue(WeaponNames[view_as<WeaponId>(i)], i);
	}
	
	hMeleeWeaponNamesTrie = new StringMap();
	hMeleeWeaponModelsTrie = new StringMap();
    for (int i = 0; i < view_as<int>(MeleeWeaponId); ++i)
    {
        hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[view_as<MeleeWeaponId>(i)], i);
        hMeleeWeaponModelsTrie.SetString(MeleeWeaponModels[view_as<MeleeWeaponId>(i)], MeleeWeaponNames[view_as<MeleeWeaponId>(i)]);
    }
	
	
	LoadGameData();
	
	
	
	// ====================================================================================================
	//									Commands
	// ====================================================================================================
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
	RegConsoleCmd("sm_cast", Cast_Cmd, "将呼叫玩家注册为裁判, 这样该回合将不会启动, 除非他们已经准备好");
	RegAdminCmd("sm_caster", Caster_Cmd, ADMFLAG_BAN, "将玩家注册为裁判, 这样一轮除非准备就绪, 否则该回合将无法进行");
	RegServerCmd("sm_resetcasters", ResetCaster_Cmd, "用于重置比赛之间的裁判. 这应该用在confogl_off.cfg或您的系统等效");
	RegServerCmd("sm_add_caster_id", AddCasterSteamID_Cmd, "用于将裁判添加到白名单中，即允许谁自注册为裁判");
	RegConsoleCmd("sm_notcasting", NotCasting_Cmd, "取消自己作为裁判或允许管理员取消其他玩家");
	
	
	
	// ====================================================================================================
	//									CVARS
	// ====================================================================================================
	CreateConVar("l4d2library_version", PLUGIN_VERSION, "L4D2 Utilities Library plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	
	hGameMode = FindConVar("mp_gamemode");
	g_hVsBossBuffer = FindConVar("versus_boss_buffer");
	hDecayRate = FindConVar("pain_pills_decay_rate");
	hMaxPlayers = FindConVar("sv_maxplayers");
	hVisibleMaxPlayers = FindConVar("sv_visiblemaxplayers");
	hSurvivorLimit = FindConVar("survivor_limit");
	hMaxPlayerZombies = FindConVar("z_max_player_zombies");
	hTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
	
	hGameMode.AddChangeHook(ConVarChange);
	g_hVsBossBuffer.AddChangeHook(ConVarChange);
	hDecayRate.AddChangeHook(ConVarChange);
	hSurvivorLimit.AddChangeHook(ConVarChange);
	hMaxPlayerZombies.AddChangeHook(ConVarChange);
	hTankLotterySelectionTime.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	SetConVarBool(FindConVar("director_no_bosses"), true);
	
	
	// ====================================================================================================
	//									EVENTS
	// ====================================================================================================
	HookEvent("round_end", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("mission_lost", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("map_transition", RoundEnd_Event, EventHookMode_PostNoCopy);
	HookEvent("finale_win", RoundEnd_Event, EventHookMode_PostNoCopy);
	
	HookEvent("scavenge_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("versus_round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	HookEvent("round_start", RoundStart_Event, EventHookMode_PostNoCopy);
	
	HookEvent("server_spawn", CEvent_MapStart, EventHookMode_PostNoCopy);

	HookEvent("tank_spawn", TankSpawn_Event, EventHookMode_Post);
	HookEvent("item_pickup", ItemPickup_Event, EventHookMode_Post);
	HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
	HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
	HookEvent("player_spawn", OnInfectedSpawn, EventHookMode_Post);
	HookEvent("player_disconnect", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_bot_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("bot_player_replace", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("defibrillator_used", SI_BuildIndex_Event, EventHookMode_PostNoCopy);
	HookEvent("player_team", PlayerTeam_Event, EventHookMode_Post);
	HookEvent("server_cvar", Event_ServerConVar, EventHookMode_Pre);
}

public int ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	fVsBossBuffer = g_hVsBossBuffer.FloatValue;
	fDecayRate = hDecayRate.FloatValue;
	iSurvivorLimit = hSurvivorLimit.IntValue;
	iMaxPlayerZombies = hMaxPlayerZombies.IntValue;
	fTankLotterySelectionTime = hTankLotterySelectionTime.FloatValue;
	
	char gmode[20];
	hGameMode.GetString(gmode, sizeof(gmode));
	if(
		StrEqual(gmode, "coop") || StrEqual(gmode, "realism") || StrEqual(gmode, "mutation1") || StrEqual(gmode, "mutation2") || 
		StrEqual(gmode, "mutation3") || StrEqual(gmode, "mutation4") || StrEqual(gmode, "mutation5") || StrEqual(gmode, "mutation7") || 
		StrEqual(gmode, "mutation8") || StrEqual(gmode, "mutation9") || StrEqual(gmode, "mutation10") || StrEqual(gmode, "mutation14") || 
		StrEqual(gmode, "mutation16") || StrEqual(gmode, "mutation17") || StrEqual(gmode, "mutation20") || StrEqual(gmode, "community1") || 
		StrEqual(gmode, "community2") || StrEqual(gmode, "community5")
	) iGameMode = 0;
	else if(
		StrEqual(gmode,"versus") || StrEqual(gmode, "teamversus") || StrEqual(gmode, "mutation11") || StrEqual(gmode, "mutation12") || 
		StrEqual(gmode, "mutation18") || StrEqual(gmode, "mutation19") || StrEqual(gmode, "community3")
	) iGameMode = 1;
	else if(StrEqual(gmode, "scavenge") || StrEqual(gmode, "teamscavenge") || StrEqual(gmode, "mutation13")) iGameMode = 2;
	else if(StrEqual(gmode, "survival") || StrEqual(gmode, "mutation15") || StrEqual(gmode, "community4")) iGameMode = 3;
	else iGameMode = -1;
}

public void OnPluginEnd()
{
	delete kvData;
	ResetConVar(FindConVar("director_no_bosses"));
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return;
	CreateTimer(0.1, EntitySpawnedDelay, entity, TIMER_FLAG_NO_MAPCHANGE);
}

public Action EntitySpawnedDelay(Handle timer, any entity)
{
	if (L4D2_IsServerActive())
	{
		if (!IsValidEntity(entity) || !IsValidEdict(entity)) return;
		char classname[64];
		if (!GetEdictClassname(entity, classname, sizeof(classname))) return;
		
		Call_StartForward(hFwdEntitySpawned);
		Call_PushCell(entity);
		Call_PushString(classname);
		Call_Finish();
		return;
	}
	CreateTimer(1.0, EntitySpawnedDelay, entity, TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapStart()
{
	IsMapInStart = true;
	bTankSpawn = false;
	fTankFlow = 0.0;
	
    g_bHasStart = false;        g_bHasStartExtra = false;
    g_bHasEnd = false;          g_bHasEndExtra = false;
    g_fStartLocA = NULL_VECTOR; g_fStartLocB = NULL_VECTOR; g_fStartLocC = NULL_VECTOR; g_fStartLocD = NULL_VECTOR;
    g_fEndLocA = NULL_VECTOR;   g_fEndLocB = NULL_VECTOR;   g_fEndLocC = NULL_VECTOR;   g_fEndLocD = NULL_VECTOR;
    g_fStartRotate = 0.0;       g_fEndRotate = 0.0;
	
	GetCurrentMap(g_sMapname, 64);
	
    if (KvJumpToKey(kvData, g_sMapname))
    {
        KvGetVector(kvData, "start_loc_a", g_fStartLocA);
        KvGetVector(kvData, "start_loc_b", g_fStartLocB);
        KvGetVector(kvData, "start_loc_c", g_fStartLocC);
        KvGetVector(kvData, "start_loc_d", g_fStartLocD);
        g_fStartRotate = KvGetFloat(kvData, "start_rotate", g_fStartRotate);
        KvGetVector(kvData, "end_loc_a", g_fEndLocA);
        KvGetVector(kvData, "end_loc_b", g_fEndLocB);
        KvGetVector(kvData, "end_loc_c", g_fEndLocC);
        KvGetVector(kvData, "end_loc_d", g_fEndLocD);
        g_fEndRotate = KvGetFloat(kvData, "end_rotate", g_fEndRotate);
        
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
    }
    else
    {
        LogMessage("[SI] SaferoomInfo for %s is missing.", g_sMapname);
    }
}

public void OnMapEnd()
{
	IsMapInStart = false;
	KvRewind(kvData);
	bRoundEnd = false;
	bSecondRound = false;
	bInRound = false;
}

public Action L4D_OnGetMissionVSBossSpawning(float &spawn_pos_min, float &spawn_pos_max, float &tank_chance, float &witch_chance)
{
	return Plugin_Handled;
}

public Action L4D_OnGetScriptValueInt(const char[] key, int &retVal)
{
	if (StrEqual(key, "DisallowThreatType"))
	{
		retVal = 0;
		return Plugin_Handled;
	}
	if (StrEqual(key, "ProhibitBosses"))
	{
		retVal = 0;
		return Plugin_Handled;
	}
	return Plugin_Continue;
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

public Action L4D_OnGetRunTopSpeed(int client, float &retVal)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || GetClientTeam(client) != 3 || !IsPlayerAlive(client)) return Plugin_Continue;
	float pos[3];
	GetClientAbsOrigin(client, pos);
	g_move_grad[client][0] = pos[0] - g_pos[client][0];
	g_move_grad[client][1] = pos[1] - g_pos[client][1];
	g_move_grad[client][2] = pos[2] - g_pos[client][2];
	g_move_speed[client] = SquareRoot(g_move_grad[client][0] * g_move_grad[client][0] + g_move_grad[client][1] * g_move_grad[client][1]);
	if (g_move_speed[client] > MOVESPEED_MAX)
	{
		g_move_speed[client] = 0.0;
		g_move_grad[client][0] = 0.0;
		g_move_grad[client][1] = 0.0;
		g_move_grad[client][2] = 0.0;
	}
	g_pos[client] = pos;
	return Plugin_Continue;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (
		client <= 0 || client > MaxClients ||
		!IsClientInGame(client) || !IsFakeClient(client) ||
		GetClientTeam(client) != 3 || !IsPlayerAlive(client)
	) return Plugin_Continue;
	if (bPause[client]) return Plugin_Handled;
	if (!GetEntProp(client, Prop_Send, "m_isGhost"))
	{
		L4D2_Infected zombie_class = view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
		Action aResult = Plugin_Continue;
		switch (zombie_class)
		{
			case L4D2Infected_Tank:
			{
				Call_StartForward(hFwdTankRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Smoker:
			{
				Call_StartForward(hFwdSmokerRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Hunter:
			{
				Call_StartForward(hFwdHunterRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Jockey:
			{
				Call_StartForward(hFwdJockeyRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Boomer:
			{
				Call_StartForward(hFwdBoomerRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Spitter:
			{
				Call_StartForward(hFwdSpitterRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
			case L4D2Infected_Charger:
			{
				Call_StartForward(hFwdChargerRunCmd);
				Call_PushCell(client);
				Call_PushCell(buttons);
				Call_PushArray(vel, 3);
				Call_PushArray(angles, 3);
				Call_Finish(aResult);
			}
		}
		return aResult;
	}
	return Plugin_Continue;
}



/* Events */
public Action RoundEnd_Event(Event event, char[] name, bool dontBroadcast)
{
	if (bInRound)
	{
		bInRound = false;
		bRoundEnd = true;
		Call_StartForward(hFwdRoundEnd);
		Call_Finish();
	}
}

public Action RoundStart_Event(Event event, char[] name, bool dontBroadcast)
{
	CreateTimer(0.5, RoundStart_Delay, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
}

public Action RoundStart_Delay(Handle timer)
{
	if (IsMapInStart)
	{
		if (!bInRound)
		{
			bInRound = true;
			if (bRoundEnd)
			{
				bSecondRound = true;
			}
			Call_StartForward(hFwdRoundStart);
			Call_Finish();
			
			if (iGameMode == 0)
			{
				CreateTimer(0.5, TankSpawnPercentCheck, 0, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
			}
		}
		InitStatus();
		ResetStatus();
		PrintToServer("%s", g_sMapname);
		KillTimer(timer);
	}
}

public Action TankSpawnPercentCheck(Handle timer)
{
	if (L4D_HasAnySurvivorLeftSafeArea() && bTankSpawn && GetBossProximity() >= fTankFlow)
	{
		float spawnPos[3];
		int client = L4D_GetHighestFlowSurvivor();
		if (client && L4D_GetRandomPZSpawnPosition(client, 8, 100, spawnPos))
		{
			L4D2_SpawnTank(spawnPos, NULL_VECTOR);
		}
		else
		{
			PrintToChatAll("[SM] Failed to find a spawn for tank in maximum allowed attempts");
		}
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

public Action TankSpawn_Event(Event event, char[] name, bool dontBroadcast)
{
	if (!bExpectTankSpawn) return;
	bExpectTankSpawn = false;
	if (bIsTankActive) return;
	bIsTankActive = true;
	
	iTank = GetClientOfUserId(event.GetInt("userid"));
	if (
		iTank <= 0 || iTank > MaxClients || !IsClientInGame(iTank) || 
		GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8
	)
	{
		return;
	}
	
	if (IsFakeClient(iTank))
	{
		PauseClient(iTank, true);
		CreateTimer(fTankLotterySelectionTime, ResumeTankTimer, iTank);
	}
	
	Call_StartForward(hFwdFirstTankSpawn);
	Call_PushCell(iTank);
	Call_Finish();
}

public Action ResumeTankTimer(Handle timer, any client)
{
	PauseClient(client, false);
	
	int survivors[NUM_OF_SURVIVORS];
	int numSurvivors = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = iSurvivorIndex[i];
		if (index == 0 || !IsPlayerAlive(index)) continue;
	    survivors[numSurvivors] = index;
	    numSurvivors++;
	}
	int attacker = survivors[GetRandomInt(0, numSurvivors - 1)];
	SDKHooks_TakeDamage(client, attacker, attacker, 0.1, DMG_BULLET);
}

public Action ItemPickup_Event(Event event, char[] name, bool dontBroadcast)
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
		if (
			iTank <= 0 || iTank > MaxClients || !IsClientInGame(iTank) || 
			GetClientTeam(iTank) != 3 || GetEntProp(iTank, Prop_Send, "m_zombieClass") != 8
		) return;
		if (hTankDeathTimer != INVALID_HANDLE)
		{
			KillTimer(hTankDeathTimer);
			hTankDeathTimer = INVALID_HANDLE;
		}
		Call_StartForward(hFwdTankPassControl);
		Call_PushCell(iPrevTank);
		Call_PushCell(iTank);
		Call_PushCell(iTankPassCount);
		Call_Finish();
		iTankPassCount += 1;
	}
}

public Action PlayerDeath_Event(Event event, char[] name, bool dontBroadcast)
{
	if (!bIsTankActive)
	{
		return;
	}
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}
	if (iTank != client)
	{
		return;
	}
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

public Action PlayerHurt_Event(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker;
	int health = event.GetInt("health");
	char weapon[256];
	event.GetString("weapon", weapon, 256);
	int damage = event.GetInt("dmg_health");
	int dmgtype = event.GetInt("type");
	int hitgroup = event.GetInt("hitgroup");
	if (victim <= 0 || victim > MaxClients || !IsClientInGame(victim) || !IsPlayerAlive(victim)) return;
	
	Call_StartForward(hFwd_PlayerHurt);
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

public Action PlayerTeam_Event(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int oldteam = event.GetInt("oldteam");
	int team = event.GetInt("team");
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return;
	}
	Action aResult = Plugin_Continue;
	if (team == 2)
	{
		Call_StartForward(hFwdJoinSurvivor);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	else if (team == 3)
	{
		Call_StartForward(hFwdJoinInfected);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	
	if (oldteam == 2)
	{
		Call_StartForward(hFwdAwaySurvivor);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	else if (oldteam == 3)
	{
		Call_StartForward(hFwdAwayInfected);
		Call_PushCell(client);
		Call_Finish(aResult);
	}
	
	Call_StartForward(hFwdTeamChanged);
	Call_PushCell(client);
	Call_PushCell(oldteam);
	Call_PushCell(team);
	Call_Finish(aResult);
	if (aResult == Plugin_Handled)
	{
		ChangeClientTeam(client, oldteam);
	}
	if (oldteam == 2 || team == 2)
	{
		CreateTimer(0.3, BuildArray_Timer);
	}
}

public Action BuildArray_Timer(Handle timer)
{
	Survivors_RebuildArray();
}

public Action SI_BuildIndex_Event(Event event, char[] name, bool dontBroadcast)
{
	Survivors_RebuildArray();
}

public Action OnInfectedSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client <= 0 || client > MaxClients || !IsClientInGame(client) || !IsPlayerAlive(client)) return;
	L4D2_Infected iClass = view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
	if (iClass < L4D2Infected_Smoker || iClass > L4D2Infected_Charger) return;
	Call_StartForward(hFwdInfectedSpawn);
	Call_PushCell(client);
	Call_PushCell(iClass);
	Call_Finish();
}

public Action CEvent_MapStart(Event event, char[] name, bool dontBroadcast)
{
	CProfile_Colors[Color_Lightgreen] = true;
	CProfile_Colors[Color_Red] = true;
	CProfile_Colors[Color_Blue] = true;
	CProfile_Colors[Color_Olive] = true;
	CProfile_TeamIndex[Color_Lightgreen] = SERVER_INDEX;
	CProfile_TeamIndex[Color_Red] = 3;
	CProfile_TeamIndex[Color_Blue] = 2;
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

public Action Cast_Cmd(int client, int args)
{	
	char buffer[64];
	GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer));

	if (GetClientTeam(client) != 1) ChangeClientTeam(client, 1);

	casterTrie.SetValue(buffer, 1);
	CPrintToChat(client, "{B}[{W}Cast{B}] {W}您已将自己注册为裁判");
	CPrintToChat(client, "{B}[{W}Cast{B}] {W}重新连接以使您的插件正常工作.");
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
	if (target > 0)
	{
		if (GetClientAuthId(target, AuthId_Steam3, buffer, sizeof(buffer)))
		{
			casterTrie.SetValue(buffer, 1);
			ReplyToCommand(client, "注册 %N 作为裁判", target);
			CPrintToChat(client, "{B}[{G}!{B}] {W}管理员已将您注册为裁判");
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
	casterTrie.Clear();
	return Plugin_Handled;
}

public Action AddCasterSteamID_Cmd(int args)
{
	char buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] != EOS) 
	{
		int index;
		GetTrieValue(allowedCastersTrie, buffer, index);
		if (index == -1)
		{
			SetTrieValue(allowedCastersTrie, buffer, 1);
			PrintToServer("[casters_database] 已添加 '%s'", buffer);
		}
		else PrintToServer("[casters_database] '%s' 已经存在", buffer);
	}
	else PrintToServer("[casters_database] 未指定args / 空字符");
	return Plugin_Handled;
}

public Action NotCasting_Cmd(int client, int args)
{
	char buffer[64];
	if (args < 1)
	{
		GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer));
		casterTrie.Remove(buffer);
		CPrintToChat(client, "{B}[{W}Reconnect{B}] {W}您将重新连接到服务器..");
		CPrintToChat(client, "{B}[{W}Reconnect{B}] {W}有一个黑屏, 而不是一个加载栏!");
		CreateTimer(3.0, Reconnect, client);
		return Plugin_Handled;
	}
	else
	{
		if (!L4D2_IsClientAdmin(client))
		{
			ReplyToCommand(client, "只有管理员可以删除其他裁判. 如果您想删除自己, 请使用不带参数的sm_notcasting.");
			return Plugin_Handled;
		}
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		int target = FindTarget(client, buffer, true, false);
		if (target > 0)
		{
			if (GetClientAuthId(target, AuthId_Steam3, buffer, sizeof(buffer)))
			{
				casterTrie.Remove(buffer);
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

public Action Reconnect(Handle timer, any client)
{
	if (IsClientInGame(client)) ReconnectClient(client);
}



/* Plugin Natives */
public int _native_CurrentlyInRound(Handle plugin, int numParams)
{
	return bInRound;
}

public int _native_IsSecondRound(Handle plugin, int numParams)
{
	return bSecondRound;
}

public int _native_IsCoop(Handle plugin, int numParams)
{
	return iGameMode == 0;
}

public int _native_IsVersus(Handle plugin, int numParams)
{
	return iGameMode == 1;
}

public int _native_IsScavenge(Handle plugin, int numParams)
{
	return iGameMode == 2;
}

public int _native_IsSurvival(Handle plugin, int numParams)
{
	return iGameMode == 3;
}

public int _native_SetMaxPlayers(Handle plugin, int numParams)
{
	int amount = GetNativeCell(1);
	SetConVarInt(hMaxPlayers, amount);
	SetConVarInt(hVisibleMaxPlayers, amount);
	PrintToServer("服务器人数设置为 %i", amount);
	PrintToChatAll("服务器人数设置为 %i", amount);
}

public int _native_ChangeClientTeam(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	L4D2_Team team = GetNativeCell(2);
	bool force = GetNativeCell(3);
	if (view_as<L4D2_Team>(GetClientTeam(client)) == team) return true;
	if (!force)
	{
		int humans = 0;
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && view_as<L4D2_Team>(GetClientTeam(i)) == team) humans++;
		}
		if (humans >= ((team == L4D2Team_Survivor) ? iSurvivorLimit : ((team == L4D2Team_Infected) ? iMaxPlayerZombies : MaxClients)))
		{
			PrintToChat(client, "您选择的团队已经满了.");
			return false;
		}
	}
	if (team != L4D2Team_Survivor)
	{
		ChangeClientTeam(client, view_as<int>(team));
		return true;
	}
	else
	{
		for (int i = 0; i < NUM_OF_SURVIVORS; i++)
		{
			int index = iSurvivorIndex[i];
			if (index == 0 || !IsFakeClient(index)) continue;
			L4D2_CheatCommand(client, "sb_takecontrol");
			if (GetClientTeam(client) != 2) L4D2_CheatCommand(client, "jointeam 2");
			return true;
		}
	}
	return false;
}

public int _native_FillBots(Handle plugin, int numParams)
{
	CreateTimer(0.1, Timer_FillBots, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_FillBots(Handle timer)
{
	if (GetTeamClientCount(view_as<int>(L4D2Team_Survivor)) < iSurvivorLimit) 
	{
		ServerCommand("sb_add");
		return Plugin_Continue;
	}
	else
	{
		return Plugin_Stop;
	}
}

public int _native_RestoreHealth(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client))
	{
		L4D2_CheatCommand(client, "give", "health");
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
		SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
	}
}

public int _native_ResetInventory(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client))
	{
		for (int j = 0; j < 5; j++)
		{
			int item = GetPlayerWeaponSlot(client, j);
			if (item > 0)
			{
				RemovePlayerItem(client, item);
			}
		}	
		L4D2_CheatCommand(client, "give", "pistol");
	}
}

public int _native_IsLanIP(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] src = new char[len];
	GetNativeString(1, src, len);
	char ip4[4][4];
	int ipnum;
	if (ExplodeString(src, ".", ip4, 4, 4) == 4)
	{
		ipnum = StringToInt(ip4[0])*65536 + StringToInt(ip4[1])*256 + StringToInt(ip4[2]);
		if ((ipnum >= 655360 && ipnum < 655360+65535) || (ipnum >= 11276288 && ipnum < 11276288+4095) || (ipnum >= 12625920 && ipnum < 12625920+255))
		{
			return true;
		}
	}
	return false;
}

public int _native_SetAnimFling(Handle plugin, int numParams)
{
	float value[3];
	int client = GetNativeCell(1);
	int attacker = GetNativeCell(2);
	GetNativeArray(3, value, 3);
	SDKCall(sdkCallFling, client, value, 96, attacker, 3.0); //76 is the 'got bounced' animation in L4D2
}

public int _native_SetPlayerRespawn(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	SDKCall(hRoundRespawn, client);
}

public int _native_PauseClient(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	bool b = GetNativeCell(2);
	PauseClient(client, b);
}

public int _native_IsClientCaster(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return view_as<int>(IsClientCaster(client));
}

public int _native_IsIDCaster(Handle plugin, int numParams)
{
	char buffer[64];
	GetNativeString(1, buffer, sizeof(buffer));
	return view_as<int>(IsIDCaster(buffer));
}

public int _native_GetRandomSurvivor(Handle plugin, int numParams)
{
	int survivors[NUM_OF_SURVIVORS];
	int numSurvivors = 0;
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = iSurvivorIndex[i];
		if (index == 0 || !IsPlayerAlive(index)) continue;
	    survivors[numSurvivors] = index;
	    numSurvivors++;
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

public int _native_IdentifySurvivor(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
    if (client <= 0 || client > MaxClients || !IsClientInGame(client)) return view_as<int>(L4D2SurvivorCharacter_None);
    char clientModel[42];
    GetClientModel(client, clientModel, sizeof(clientModel));
    return view_as<int>(ClientModelToSC(clientModel));
}

public int _native_ClientModelToSC(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] model = new char[len];
	GetNativeString(1, model, len);
	ClientModelToSC(model);
}

public int _native_GetSurvivorName(Handle plugin, int numParams)
{
	L4D2_SurvivorCharacter character = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] buffer = new char[len];
    if (character == L4D2SurvivorCharacter_None) return false;
    strcopy(buffer, len, SurvivorNames[view_as<int>(character)]);
	SetNativeString(2, buffer, len);
    return true;
}

public int _native_GetSurvivorCount(Handle plugin, int numParams)
{
	return iSurvivorCount;
}

public int _native_GetSurvivorOfIndex(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	if (index < 0 || index > 3) return 0;
	return iSurvivorIndex[index];
}

public int _native_GiveDefaultAmmo(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (iAmmoPile != -1)
		SDKCall(hSDKGiveDefaultAmmo, iAmmoPile, client);
}


public int _native_DelayStart(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int no = GetNativeCell(2);
	g_delay[client][no] = GetGameTime();
}

public int _native_DelayExpired(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int no = GetNativeCell(2);
	float delay = GetNativeCell(3);
	return GetGameTime() - g_delay[client][no] > delay;
}

public int _native_SetState(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int no = GetNativeCell(2);
	int value = GetNativeCell(3);
	g_state[client][no] = value;
}

public int _native_GetState(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int no = GetNativeCell(2);
	return g_state[client][no];
}

public int _native_NearestSurvivorDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	float self[3];
	float min_dist = 100000.0;
	GetClientAbsOrigin(client, self);
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = iSurvivorIndex[i];
		if (index == 0 || !IsPlayerAlive(index)) continue;
		float target[3];
		GetClientAbsOrigin(index, target);
		float dist = GetVectorDistance(self, target);
		if (dist < min_dist)
		{
			min_dist = dist;
		}
	}
	return view_as<int>(min_dist);
}

public int _native_NearestActiveSurvivorDistance(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	float self[3];
	float min_dist = 100000.0;
	GetClientAbsOrigin(client, self);
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = iSurvivorIndex[i];
		if (index == 0 || !IsPlayerAlive(index)) continue;
		if (!GetEntProp(client, Prop_Send, "m_isIncapacitated"))
		{
			float target[3];
			GetClientAbsOrigin(index, target);
			float dist = GetVectorDistance(self, target);
			if (dist < min_dist)
			{
				min_dist = dist;
			}
		}
	}
	return view_as<int>(min_dist);
}

public int _native_GetMoveSpeed(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return view_as<int>(g_move_speed[client]);
}

public int _native_GetInfectedClassName(Handle plugin, int numParams)
{
	int iClass = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, InfectedNames[iClass]);
	SetNativeString(2, nameBuffer, len);
}

public int _native_GetSurvivorTemporaryHealth(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	float fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float bleedTime = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fTempHp = fHealthBuffer - bleedTime * fDecayRate - 1.0;
	return view_as<int>((fTempHp > 100.0) ? 100.0 : (fTempHp < 0.0) ? 0.0 : fTempHp);
}

public int _native_IsBeingAttacked(Handle plugin, int numParams)
{
	int survivor = GetNativeCell(1);
	int attacker;
    for (int i = 0; i < sizeof(SI_DOMINATION_OFFSETS); i++)
    {
		attacker = GetEntPropEnt(survivor, Prop_Send, SI_DOMINATION_OFFSETS[i]);
		if (attacker > 0 && attacker <= MaxClients && IsClientInGame(attacker))
		{
			return attacker;
		}
    }
	return -1;
}

public int _native_GetInfectedVictim(Handle plugin, int numParams)
{
	int attacker = GetNativeCell(1);
	int zClass = GetEntProp(attacker, Prop_Send, "m_zombieClass");
	if (strlen(InfectedVictimNetprops[zClass]) == 0) return -1;
	int target = GetEntPropEnt(attacker, Prop_Send, InfectedVictimNetprops[zClass]);
	if (target < 1 || target > MaxClients || !IsClientInGame(target))
	{
		return -1;
	}
	return target;
}

public int _native_GetTankToSpawn(Handle plugin, int numParams)
{
	return bTankSpawn;
}

public int _native_SetTankToSpawn(Handle plugin, int numParams)
{
	bTankSpawn = GetNativeCell(1);
	L4D2Direct_SetVSTankToSpawnThisRound(0, bTankSpawn);
	L4D2Direct_SetVSTankToSpawnThisRound(1, bTankSpawn);
}

public int _native_GetTankFlowPercent(Handle plugin, int numParams)
{
	return RoundToNearest(fTankFlow * 100.0);
}

public int _native_SetTankFlowPercent(Handle plugin, int numParams)
{
	fTankFlow = GetNativeCell(1);
	L4D2Direct_SetVSTankFlowPercent(0, fTankFlow);
	L4D2Direct_SetVSTankFlowPercent(1, fTankFlow);
}

public int _native_GetFurthestSurvivorFlow(Handle plugin, int numParams)
{
	int flow = RoundToNearest(100.0 * (L4D2_GetFurthestSurvivorFlow() + fVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	return L4D2_Min(flow, 100);
}

public int _native_GetHighestSurvivorFlow(Handle plugin, int numParams)
{
	int flow = -1;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0) {
		flow = RoundToNearest(100.0 * (L4D2Direct_GetFlowDistance(client) + fVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance());
	}
	return L4D2_Min(flow, 100);
}

/*public int _native_GetTankFlow(Handle plugin, int numParams)
{
	return view_as<int>(fTankFlow - fVsBossBuffer / L4D2Direct_GetMapMaxFlowDistance());
}*/

public int _native_GetMapValueFloat(Handle plugin, int numParams)
{
	int len;
	float defval;
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	defval = GetNativeCell(2);
	return view_as<int>(KvGetFloat(kvData, key, defval));
}

public int _native_GetMapValueInt(Handle plugin, int numParams)
{
	int len;
	int defval;
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	defval = GetNativeCell(2);
	return KvGetNum(kvData, key, defval);
}

public int _native_GetMapValueVector(Handle plugin, int numParams)
{
	int len;
	float defval[3];
	float value[3];
	GetNativeStringLength(1, len);
	len += 1;
	char[] key = new char[len];
	GetNativeString(1, key, len);
	GetNativeArray(3, defval, 3);
	KvGetVector(kvData, key, value, defval);
	SetNativeArray(2, value, 3);
}

public int _native_IsEntityInSaferoom(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	if (!IsValidEntity(entity) || GetEntSendPropOffs(entity, "m_vecOrigin", true) == -1) { return false; }
	float location[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
	return IsPointInStartSaferoom(location) || IsPointInEndSaferoom(location);
}

/*public int _native_IsPlayerInSaferoom(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
	{
		return false;
	}
	float locationA[3];
	float locationB[3];
	GetClientAbsOrigin(client, locationA);
	GetClientEyePosition(client, locationB);
	return IsPointInStartSaferoom(locationA) || IsPointInStartSaferoom(locationB) || IsPointInEndSaferoom(locationA) || IsPointInEndSaferoom(locationB);
}*/

public int _native_IdentifyWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	return view_as<int>(IdentifyWeapon(entity));
}

public int _native_IdentifyMeleeWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
    if (IdentifyWeapon(entity) != WEPID_MELEE)
    {
        return view_as<int>(WEPID_MELEE_NONE);
    }

    char sName[128];
    if (! GetMeleeWeaponNameFromEntity(entity, sName, sizeof(sName)))
    {
        return view_as<int>(WEPID_MELEE_NONE);
    }

    int id;
    if (hMeleeWeaponNamesTrie.GetValue(sName, id))
    {
        return id;
    }
	return view_as<int>(WEPID_MELEE_NONE);
}

public int _native_HasValidWeaponModel(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	return HasValidWeaponModel(wepid);
}

public int _native_HasValidMeleeWeaponModel(Handle plugin, int numParams)
{
	MeleeWeaponId wepid = GetNativeCell(1);
	return L4D2_IsValidMeleeWeaponId(wepid) && MeleeWeaponModels[wepid][0] != '\0';
}

public int _native_WeaponNameToId(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] weaponName= new char[len];
	GetNativeString(1, weaponName, len);
	return view_as<int>(WeaponNameToId(weaponName));
}

public int _native_ConvertWeaponSpawn(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	WeaponId wepid = GetNativeCell(2);
	int count = GetNativeCell(3);
	int len;
	GetNativeStringLength(4, len);
	len += 1;
	char[] model = new char[len];
	GetNativeString(4, model, len);

    if(!IsValidEntity(entity)) return -1;
    if(!L4D2_IsValidWeaponId(wepid)) return -1;
    if(model[0] == '\0' && !HasValidWeaponModel(wepid)) return -1;

    float origins[3], angles[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origins);
    GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
    AcceptEntityInput(entity, "kill");
    
    entity = CreateEntityByName("weapon_spawn");
    if(!IsValidEntity(entity)) return -1;
    SetEntProp(entity, Prop_Send, "m_weaponID", wepid);

    char buf[64];
    if(model[0] == '\0')
    {
        SetEntityModel(entity, model);
    }
    else
    {
        GetWeaponModel(wepid, buf, sizeof(buf));
        SetEntityModel(entity, buf);
    }

    IntToString(count, buf, sizeof(buf));
    DispatchKeyValue(entity, "count", buf);

    TeleportEntity(entity, origins, angles, NULL_VECTOR);
    DispatchSpawn(entity);
    SetEntityMoveType(entity,MOVETYPE_NONE);
	return entity;
}

public int _native_GetLongWeaponName(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (L4D2_IsValidWeaponId(view_as<WeaponId>(wepid)) ? (LongWeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

public int _native_GetLongMeleeWeaponName(Handle plugin, int numParams)
{
	MeleeWeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (L4D2_IsValidMeleeWeaponId(view_as<MeleeWeaponId>(wepid)) ? (LongMeleeWeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

public int _native_GetMeleeWeaponNameFromEntity(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] buffer = new char[len];
	if (GetMeleeWeaponNameFromEntity(entity, buffer, len))
	{
		SetNativeString(2, buffer, len);
		return true;
	}
	return false;
}

public int _native_GetSlotFromWeaponId(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	return L4D2_IsValidWeaponId(wepid) ? WeaponSlots[wepid] : -1;
}

public int _native_GetWeaponModel(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] modelBuffer = new char[len];
	GetWeaponModel(wepid, modelBuffer, len);
	SetNativeString(2, modelBuffer, len);
}

public int _native_GetWeaponName(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (L4D2_IsValidWeaponId(view_as<WeaponId>(wepid)) ? (WeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

public int _native_CPrintToChat(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char szMessage[250];
	FormatNativeString(0, 2, 3, sizeof(szMessage), _, szMessage);
	CPrintToChat(client, "%s", szMessage);
}

public int _native_CPrintToChatAll(Handle plugin, int numParams)
{
	char szMessage[250];
	char szBuffer[250];
	FormatNativeString(0, 1, 2, sizeof(szMessage), _, szMessage);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, 250, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}



/* NATIVE FUNCTIONS */
// New Super Awesome Functions!!!
// ------
void LoadGameData()
{
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x56\x8B\xF1\xE8\x2A\x2A\x2A\x2A\xE8\x2A\x2A\x2A\x2A\x84\xC0\x75", 16))
	{
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN13CTerrorPlayer12RoundRespawnEv", 0))
			LogError("Failed to find signature: CTerrorPlayer_RoundRespawn");
	}
	hRoundRespawn = EndPrepSDKCall();
	if (hRoundRespawn == null)
		LogError("Failed to create SDKCall: CTerrorPlayer_RoundRespawn");
	
	Handle ConfigFile = LoadGameConfigFile("left4dhooks.l4d2");
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	if (sdkCallFling == null) LogError("Cant initialize Fling SDKCall");
	delete ConfigFile;
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "\x55\x8B\xEC\x51\x53\x8B\x5D\x08\x85", 9))
	{
		if (!PrepSDKCall_SetSignature(SDKLibrary_Server, "@_ZN16CWeaponAmmoSpawn3UseEP11CBaseEntityS1_8USE_TYPEf", 0))
			LogError("Failed to find signature: CWeaponAmmoSpawn_Use");
	}
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	hSDKGiveDefaultAmmo = EndPrepSDKCall();
	if(hSDKGiveDefaultAmmo == null)
		LogError("Failed to create SDKCall: CWeaponAmmoSpawn_Use");
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

L4D2_SurvivorCharacter ClientModelToSC(const char[] model)
{
    L4D2_SurvivorCharacter sc;
    if (hSurvivorModelsTrie.GetValue(model, sc)) return sc;
    return L4D2SurvivorCharacter_None;
}

float GetBossProximity()
{
	float flow = -1.0;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0) {
		flow = (L4D2Direct_GetFlowDistance(client) + fVsBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
	}
	return ((flow > 0.0) ? flow : 0.0);
}

void InitStatus()
{
	float time = GetGameTime();
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		bPause[i] = false;
		g_move_speed[i] = 0.0;
		for (int j = 0; j < 8; j++)
		{
			g_delay[i][j] = time;
			g_state[i][j] = 0;
		}
		for (int j = 0; j < 3; j++)
		{
			g_move_grad[i][j] = 0.0;
			g_pos[i][j] = 0.0;
		}
	}
}

void ResetStatus()
{
	bExpectTankSpawn = false;
	bIsTankActive = false;
	iTank = -1;
	iTankPassCount = 0;
	
	if (hTankDeathTimer != INVALID_HANDLE)
	{
		KillTimer(hTankDeathTimer);
		hTankDeathTimer = INVALID_HANDLE;
	}
}

void Survivors_RebuildArray()
{
	if (!IsServerProcessing()) return;
	
	iSurvivorCount = 0;
	int ifoundsurvivors = 0;
	int ichar;
	
	for (int i = 0; i < NUM_OF_SURVIVORS; i++) iSurvivorIndex[i] = 0;
	for (int client = 1; client <= MaxClients; client++)
	{
		if (ifoundsurvivors == NUM_OF_SURVIVORS) break;
		if (!IsClientInGame(client) || GetClientTeam(client) != 2) continue;
		ichar = GetEntProp(client, Prop_Send, "m_survivorCharacter");
		ifoundsurvivors++;
		if (ichar > 3 || ichar < 0) continue;
		iSurvivorIndex[ichar] = client;
		iSurvivorCount++;
	}
}

bool HasValidWeaponModel(WeaponId wepid)
{
    return L4D2_IsValidWeaponId(wepid) && WeaponModels[wepid][0] != '\0';
}

WeaponId WeaponNameToId(const char[] weaponName)
{
    WeaponId id;
    if (hWeaponNamesTrie.GetValue(weaponName, id))
    {
        return id;
    }
    return WEPID_NONE;
}

void GetWeaponModel(WeaponId wepid, char[] modelBuffer, int length)
{
    strcopy(modelBuffer, length, HasValidWeaponModel(view_as<WeaponId>(wepid)) ? (WeaponModels[view_as<int>(wepid)]) : "");
}

WeaponId IdentifyWeapon(int entity)
{
    if (!entity || !IsValidEntity(entity) || !IsValidEdict(entity))
    {
        return WEPID_NONE;
    }
    char class[64];
    if (!GetEdictClassname(entity, class, sizeof(class)))
    {
        return WEPID_NONE;
    }

    if (StrEqual(class, "weapon_spawn") || StrEqual(class, "weapon_item_spawn"))
    {
        return view_as<WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));
    }

    int len = strlen(class);
    if (len-6 > 0 && StrEqual(class[len-6], "_spawn"))
    {
        class[len-6]='\0';
        return WeaponNameToId(class);
    }
    
    return WeaponNameToId(class);
}

bool GetMeleeWeaponNameFromEntity(int entity, char[] buffer, int length)
{
    char classname[64];
    if (! GetEdictClassname(entity, classname, sizeof(classname)))
    {
        return false;
    }
    if (StrEqual(classname, "weapon_melee_spawn"))
    {
        char sModelName[128];
        GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

        if (strncmp(sModelName, "models/", 7, false) == 0)
        {
            strcopy(sModelName, sizeof(sModelName), sModelName[6]);
        }

        if (hMeleeWeaponModelsTrie.GetString(sModelName, buffer, length))
        {
            return true;
        }
        return false;
    }
    else if (StrEqual(classname, "weapon_melee"))
    {
        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
        return true;
    }
    return false;
}

void CPrintToChat(int client, const char[] szMessage, any ...)
{
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(szBuffer, sizeof(szBuffer), "\x01[SM]%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 3);
	
	int index = NO_INDEX;
	ReplaceString(szCMessage, sizeof(szCMessage), "{teamcolor}", "");
	for (int i = 0; i < MAX_COLORS; i++)
	{
		if (StrContains(szCMessage, CTag[i]) == -1) continue;
		else if (!CProfile_Colors[i])
		{
			ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[Color_Green]);
		}
		else if (!CTagReqSayText2[i])
		{
			ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[i]);
		}
		else
		{
			if (index == NO_INDEX)
			{
				if (CProfile_TeamIndex[i] == SERVER_INDEX)
				{
					index = 0;
				}
				else
				{
					for (int j = 1; j <= MaxClients; j++)
					{
						if (IsClientInGame(j) && GetClientTeam(j) == CProfile_TeamIndex[i])
						{
							index = j;
							break;
						}
						index = NO_PLAYER;
					}	
				}
				
				if (index == NO_PLAYER)
				{
					ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[Color_Green]);
				}
				else
				{
					ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[i]);
				}
			}
			else
			{
				ThrowError("Using two team colors in one message is not allowed");
			}
			
		}
	}
	
	if (index == NO_INDEX)
	{
		PrintToChat(client, "%s", szCMessage);
	}
	else
	{
		Handle hBuffer = StartMessageOne("SayText2", client);
		BfWriteByte(hBuffer, index);
		BfWriteByte(hBuffer, true);
		BfWriteString(hBuffer, szCMessage);
		EndMessage();
	}
}

bool IsClientCaster(int client)
{
	char buffer[64];
	return GetClientAuthId(client, AuthId_Steam3, buffer, sizeof(buffer)) && IsIDCaster(buffer);
}

bool IsIDCaster(const char[] AuthID)
{
	int dummy;
	return casterTrie.GetValue(AuthID, dummy);
}

void PauseClient(int client, bool b)
{
	bPause[client] = b;
	if (!IsValidEntity(client)) return;
	if (b)
	{
		SetEntityMoveType(client, MOVETYPE_NONE);
		SetEntProp(client, Prop_Send, "m_isGhost", 1);
	}
	else
	{
		SetEntityMoveType(client, MOVETYPE_CUSTOM);
		SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
}
