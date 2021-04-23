#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>

#define IS_VALID_SURVIVOR(%1)   (L4D2_IsValidClient(%1) && L4D2_IsSurvivor(%1))
#define IS_VALID_INFECTED(%1)   (L4D2_IsValidClient(%1) && L4D2_IsInfected(%1))

#define SHOTGUN_BLAST_TIME      0.1
#define POUNCE_CHECK_TIME       0.1
#define HOP_CHECK_TIME          0.1
#define HOPEND_CHECK_TIME       0.1     // after streak end (potentially) detected, to check for realz?
#define SHOVE_TIME              0.05
#define MAX_CHARGE_TIME         12.0    // maximum time to pass before charge checking ends
#define CHARGE_CHECK_TIME       0.25    // check interval for survivors flying from impacts
#define CHARGE_END_CHECK        2.5     // after client hits ground after getting impact-charged: when to check whether it was a death
#define CHARGE_END_RECHECK      3.0     // safeguard wait to recheck on someone getting incapped out of bounds
#define VOMIT_DURATION_TIME     2.25    // how long the boomer vomit stream lasts -- when to check for boom count
#define ROCK_CHECK_TIME         0.34    // how long to wait after rock entity is destroyed before checking for skeet/eat (high to avoid lag issues)
#define CARALARM_MIN_TIME       0.11    // maximum time after touch/shot => alarm to connect the two events (test this for LAG)

#define WITCH_CHECK_TIME        0.1     // time to wait before checking for witch crown after shoots fired
#define WITCH_DELETE_TIME       0.15    // time to wait before deleting entry from witch trie after entity is destroyed

#define MIN_DC_TRIGGER_DMG      300     // minimum amount a 'trigger' / drown must do before counted as a death action
#define MIN_DC_FALL_DMG         175     // minimum amount of fall damage counts as death-falling for a deathcharge
#define WEIRD_FLOW_THRESH       900.0   // -9999 seems to be break flow.. but meh
#define MIN_FLOWDROPHEIGHT      350.0   // minimum height a survivor has to have dropped before a WEIRD_FLOW value is treated as a DC spot
#define MIN_DC_RECHECK_DMG      100     // minimum damage from map to have taken on first check, to warrant recheck

#define HOP_ACCEL_THRESH        0.01    // bhop speed increase must be higher than this for it to count as part of a hop streak

#define HITGROUP_HEAD   1

#define DMGARRAYEXT     7                       // MAXPLAYERS+# -- extra indices in witch_dmg_array + 1

#define CUT_KILL        3                       // reason for tongue break (release_type)
#define CUT_SLASH       4                       // this is used for others shoving a survivor free too, don't trust .. it involves tongue damage?

#define VICFLG_CARRIED          (1 << 0)        // was the one that the charger carried (not impacted)
#define VICFLG_FALL             (1 << 1)        // flags stored per charge victim, to check for deathchargeroony -- fallen
#define VICFLG_DROWN            (1 << 2)        // drowned
#define VICFLG_HURTLOTS         (1 << 3)        // whether the victim was hurt by 400 dmg+ at once
#define VICFLG_TRIGGER          (1 << 4)        // killed by trigger_hurt
#define VICFLG_AIRDEATH         (1 << 5)        // died before they hit the ground (impact check)
#define VICFLG_KILLEDBYOTHER    (1 << 6)        // if the survivor was killed by an SI other than the charger
#define VICFLG_WEIRDFLOW        (1 << 7)        // when survivors get out of the map and such
#define VICFLG_WEIRDFLOWDONE    (1 << 8)        //      checked, don't recheck for this

#define DRAW_CROWN_THRESH 500
#define SELF_CLEAR_THRESH 200
#define HUNTER_DP_THRESH 400.0
#define JOCKEY_DP_THRESH 300.0
#define DEATH_CHARGER_HEIGHT 400.0
#define INSTA_TIME 0.75
#define BHOP_MIN_STREAK 3
#define BHOP_MIN_INIT_SPEED 150.0
#define BHOP_CONT_SPEED 300.0

#define BOOMER_STAGGER_TIME 4.0 // Amount of time after a boomer has been meleed that we consider the meleer the person who

public Plugin myinfo = 
{
    name = "Skill Detection (skeets, crowns, levels) & Realtime Stats",
    author = "Tabun, Griffin, Philogl, Sir",
    description = "Detects and reports skeets, crowns, levels, highpounces, etc.",
    version = "1.9.19",
    url = ""
};

enum strWeaponType
{
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM,
    WPTYPE_GL
};

enum strOEC
{
    OEC_WITCH,
    OEC_TANKROCK,
    OEC_TRIGGER,
    OEC_CARALARM,
    OEC_CARGLASS
};

enum strAbility
{
    ABL_HUNTERLUNGE,
    ABL_ROCKTHROW
};

enum
{
    rckDamage,
    rckTank,
    rckSkeeter,
    strRockData
};

enum
{
    WTCH_NONE,
    WTCH_HEALTH,
    WTCH_GOTSLASH,
    WTCH_STARTLED,
    WTCH_CROWNER,
    WTCH_CROWNSHOT,
    WTCH_CROWNTYPE,
    strWitchArray
};

enum
{
    CALARM_UNKNOWN,
    CALARM_HIT,
    CALARM_TOUCHED,
    CALARM_EXPLOSION,
    CALARM_BOOMER,
    enAlarmReasons
};

GlobalForward g_hForwardSkeet;
GlobalForward g_hForwardSkeetHurt;
GlobalForward g_hForwardSkeetMelee;
GlobalForward g_hForwardSkeetMeleeHurt;
GlobalForward g_hForwardSkeetSniper;
GlobalForward g_hForwardSkeetSniperHurt;
GlobalForward g_hForwardSkeetGL;
GlobalForward g_hForwardHunterDeadstop;
GlobalForward g_hForwardSIShove;
GlobalForward g_hForwardBoomerPop;
GlobalForward g_hForwardLevel;
GlobalForward g_hForwardLevelHurt;
GlobalForward g_hForwardCrown;
GlobalForward g_hForwardDrawCrown;
GlobalForward g_hForwardTongueCut;
GlobalForward g_hForwardSmokerSelfClear;
GlobalForward g_hForwardRockSkeeted;
GlobalForward g_hForwardRockEaten;
GlobalForward g_hForwardHunterDP;
GlobalForward g_hForwardJockeyDP;
GlobalForward g_hForwardDeathCharge;
GlobalForward g_hForwardClear;
GlobalForward g_hForwardVomitLanded;
GlobalForward g_hForwardBHopStreak;
GlobalForward g_hForwardAlarmTriggered;

StringMap g_hTrieWeapons;   // weapon check
StringMap g_hTrieEntityCreated;   // getting classname of entity created
StringMap g_hTrieAbility;   // ability check
StringMap g_hWitchTrie;   // witch tracking (Crox)
StringMap g_hRockTrie;   // tank rock tracking
StringMap g_hCarTrie;   // car alarm tracking

// all SI / pinners
float g_fSpawnTime[MAXPLAYERS + 1];                               // time the SI spawned up
float g_fPinTime[MAXPLAYERS + 1][2];                            // time the SI pinned a target: 0 = start of pin (tongue pull, charger carry); 1 = carry end / tongue reigned in
int g_iSpecialVictim[MAXPLAYERS + 1];                               // current victim (set in traceattack, so we can check on death)

// hunters: skeets/pounces
int g_iHunterShotDmgTeam[MAXPLAYERS + 1];                               // counting shotgun blast damage for hunter, counting entire survivor team's damage
int g_iHunterShotDmg[MAXPLAYERS + 1][MAXPLAYERS + 1];               // counting shotgun blast damage for hunter / skeeter combo
float g_fHunterShotStart[MAXPLAYERS + 1][MAXPLAYERS + 1];               // when the last shotgun blast on hunter started (if at any time) by an attacker
float g_fHunterTracePouncing[MAXPLAYERS + 1];                               // time when the hunter was still pouncing (in traceattack) -- used to detect pouncing status
float g_fHunterLastShot[MAXPLAYERS + 1];                               // when the last shotgun damage was done (by anyone) on a hunter
int g_iHunterLastHealth[MAXPLAYERS + 1];                               // last time hunter took any damage, how much health did it have left?
int g_iHunterOverkill[MAXPLAYERS + 1];                               // how much more damage a hunter would've taken if it wasn't already dead
bool g_bHunterKilledPouncing[MAXPLAYERS + 1];                               // whether the hunter was killed when actually pouncing
int g_iPounceDamage[MAXPLAYERS + 1];                               // how much damage on last 'highpounce' done
float g_fPouncePosition[MAXPLAYERS + 1][3];                            // position that a hunter (jockey?) pounced from (or charger started his carry)

// deadstops
float g_fVictimLastShove[MAXPLAYERS + 1][MAXPLAYERS + 1];               // when was the player shoved last by attacker? (to prevent doubles)

// levels / charges
int g_iChargerHealth[MAXPLAYERS + 1];                               // how much health the charger had the last time it was seen taking damage
float g_fChargeTime[MAXPLAYERS + 1];                               // time the charger's charge last started, or if victim, when impact started
int g_iChargeVictim[MAXPLAYERS + 1];                               // who got charged
float g_fChargeVictimPos[MAXPLAYERS + 1][3];                            // location of each survivor when it got hit by the charger
int g_iVictimCharger[MAXPLAYERS + 1];                               // for a victim, by whom they got charge(impacted)
int g_iVictimFlags[MAXPLAYERS + 1];                               // flags stored per charge victim: VICFLAGS_ 
int g_iVictimMapDmg[MAXPLAYERS + 1];                               // for a victim, how much the cumulative map damage is so far (trigger hurt / drowning)

// pops
bool g_bBoomerHitSomebody[MAXPLAYERS + 1];                               // false if boomer didn't puke/exploded on anybody
int g_iBoomerGotShoved[MAXPLAYERS + 1];                               // count boomer was shoved at any point
int g_iBoomerVomitHits[MAXPLAYERS + 1];                               // how many booms in one vomit so far

// crowns
float g_fWitchShotStart[MAXPLAYERS + 1];                               // when the last shotgun blast from a survivor started (on any witch)

// smoker clears
bool g_bSmokerClearCheck[MAXPLAYERS + 1];                               // [smoker] smoker dies and this is set, it's a self-clear if g_iSmokerVictim is the killer
int g_iSmokerVictim[MAXPLAYERS + 1];                               // [smoker] the one that's being pulled
int g_iSmokerVictimDamage[MAXPLAYERS + 1];                               // [smoker] amount of damage done to a smoker by the one he pulled
bool g_bSmokerShoved[MAXPLAYERS + 1];                               // [smoker] set if the victim of a pull manages to shove the smoker

// rocks
int g_iTankRock[MAXPLAYERS + 1];                               // rock entity per tank
int g_iRocksBeingThrown[10];                                           // 10 tanks max simultanously throwing rocks should be ok (this stores the tank client)
int g_iRocksBeingThrownCount = 0;                // so we can do a push/pop type check for who is throwing a created rock

// hops
bool g_bIsHopping[MAXPLAYERS + 1];                               // currently in a hop streak
bool g_bHopCheck[MAXPLAYERS + 1];                               // flag to check whether a hopstreak has ended (if on ground for too long.. ends)
int g_iHops[MAXPLAYERS + 1];                               // amount of hops in streak
float g_fLastHop[MAXPLAYERS + 1][3];                            // velocity vector of last jump
float g_fHopTopVelocity[MAXPLAYERS + 1];                               // maximum velocity in hopping streak

// alarms
float g_fLastCarAlarm = 0.0;              // time when last car alarm went off
int g_iLastCarAlarmReason[MAXPLAYERS + 1];                               // what this survivor did to set the last alarm off
int g_iLastCarAlarmBoomer;                                                  // if a boomer triggered an alarm, remember it

// cvars
ConVar g_hCvarPounceInterrupt;   // z_pounce_damage_interrupt
ConVar g_hCvarChargerHealth;   // z_charger_health
ConVar g_hCvarWitchHealth;   // z_witch_health
ConVar g_hCvarMaxPounceDistance;   // z_pounce_damage_range_max
ConVar g_hCvarMinPounceDistance;   // z_pounce_damage_range_min
ConVar g_hCvarMaxPounceDamage;   // z_hunter_max_pounce_bonus_damage;

int g_iPounceInterrupt = 150;
int g_iChargerHealth2;
int g_iWitchHealth;
float g_fMaxPounceDistance;
float g_fMinPounceDistance;
float g_fMaxPounceDamage;


int g_iSurvivorLimit = 4;
ConVar g_hCvarSurvivorLimit;
bool g_bHasRoundEnded;
int g_iBoomerClient;		// Last player to be boomer (or current boomer)
int g_iBoomerKiller;									// Client who shot the boomer
int g_iBoomerShover;									// Client who shoved the boomer
int g_iLastHealth[MAXPLAYERS + 1];
bool g_bHasBoomLanded;
bool g_bIsPouncing[MAXPLAYERS + 1];
Handle g_hBoomerShoveTimer;
Handle g_hBoomerKillTimer;
float BoomerKillTime = 0.0;
char Boomer[32];               // Name of Boomer

// Player temp stats
int g_iDamageDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker
int g_iShotsDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];			// Victim - Attacker, count # of shots (not pellets)
int g_iAlarmCarClient;

bool g_bShotCounted[MAXPLAYERS + 1][MAXPLAYERS +1];		// Victim - Attacker, used by playerhurt and weaponfired

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    g_hForwardSkeet =           new GlobalForward("OnSkeet", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardSkeetHurt =       new GlobalForward("OnSkeetHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardSkeetMelee =      new GlobalForward("OnSkeetMelee", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardSkeetMeleeHurt =  new GlobalForward("OnSkeetMeleeHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardSkeetSniper =     new GlobalForward("OnSkeetSniper", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardSkeetSniperHurt = new GlobalForward("OnSkeetSniperHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardSkeetGL =         new GlobalForward("OnSkeetGL", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardSIShove =         new GlobalForward("OnSpecialShoved", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardHunterDeadstop =  new GlobalForward("OnHunterDeadstop", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardBoomerPop =       new GlobalForward("OnBoomerPop", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float);
    g_hForwardLevel =           new GlobalForward("OnChargerLevel", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardLevelHurt =       new GlobalForward("OnChargerLevelHurt", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardCrown =           new GlobalForward("OnWitchCrown", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardDrawCrown =       new GlobalForward("OnWitchDrawCrown", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardTongueCut =       new GlobalForward("OnTongueCut", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardSmokerSelfClear = new GlobalForward("OnSmokerSelfClear", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
    g_hForwardRockSkeeted =     new GlobalForward("OnTankRockSkeeted", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardRockEaten =       new GlobalForward("OnTankRockEaten", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardHunterDP =        new GlobalForward("OnHunterHighPounce", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell, Param_Cell);
    g_hForwardJockeyDP =        new GlobalForward("OnJockeyHighPounce", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell);
    g_hForwardDeathCharge =     new GlobalForward("OnDeathCharge", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
    g_hForwardClear =           new GlobalForward("OnSpecialClear", ET_Ignore, Param_Cell, Param_Cell, Param_Cell, Param_Cell, Param_Float, Param_Float, Param_Cell);
    g_hForwardVomitLanded =     new GlobalForward("OnBoomerVomitLanded", ET_Ignore, Param_Cell, Param_Cell);
    g_hForwardBHopStreak =      new GlobalForward("OnBunnyHopStreak", ET_Ignore, Param_Cell, Param_Cell, Param_Float);
    g_hForwardAlarmTriggered =  new GlobalForward("OnCarAlarmTriggered", ET_Ignore, Param_Cell, Param_Cell, Param_Cell);
	
    RegPluginLibrary("skill_detect");
    return APLRes_Success;
}

public void OnPluginStart()
{
    // hooks
    HookEvent("player_spawn",               Event_PlayerSpawn,              EventHookMode_Post);
    HookEvent("player_hurt",                Event_PlayerHurt,               EventHookMode_Pre);
    HookEvent("player_death",               Event_PlayerDeathPre,              EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath);
    HookEvent("ability_use",                Event_AbilityUse,               EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,              EventHookMode_Post);
    HookEvent("player_shoved",              Event_PlayerShoved,             EventHookMode_Post);
    HookEvent("player_jump",                Event_PlayerJumped,             EventHookMode_Post);
    HookEvent("player_jump_apex",           Event_PlayerJumpApex,           EventHookMode_Post);
	HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("create_panic_event", Event_Panic);
    
    HookEvent("player_now_it",              Event_PlayerBoomed,             EventHookMode_Post);
    HookEvent("boomer_exploded",            Event_BoomerExploded,           EventHookMode_Post);
    
    HookEvent("witch_spawn",                Event_WitchSpawned,             EventHookMode_Post);
    HookEvent("witch_killed",               Event_WitchKilled,              EventHookMode_Post);
    HookEvent("witch_harasser_set",         Event_WitchHarasserSet,         EventHookMode_Post);
    
    HookEvent("tongue_grab",                Event_TongueGrab,               EventHookMode_Post);
    HookEvent("tongue_pull_stopped",        Event_TonguePullStopped,        EventHookMode_Post);
    HookEvent("choke_start",                Event_ChokeStart,               EventHookMode_Post);
    HookEvent("choke_stopped",              Event_ChokeStop,                EventHookMode_Post);
    HookEvent("jockey_ride",                Event_JockeyRide,               EventHookMode_Post);
    HookEvent("charger_carry_start",        Event_ChargeCarryStart,         EventHookMode_Post);
    HookEvent("charger_carry_end",          Event_ChargeCarryEnd,           EventHookMode_Post);
    HookEvent("charger_impact",             Event_ChargeImpact,             EventHookMode_Post);
    HookEvent("charger_pummel_start",       Event_ChargePummelStart,        EventHookMode_Post);
    
    HookEvent("player_incapacitated_start", Event_IncapStart,               EventHookMode_Post);
    HookEvent("triggered_car_alarm",        Event_CarAlarmGoesOff,          EventHookMode_Post);
    
    // cvars: built in
    g_hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    g_hCvarChargerHealth = FindConVar("z_charger_health");
    g_hCvarWitchHealth = FindConVar("z_witch_health");
    g_hCvarMaxPounceDistance = FindConVar("z_pounce_damage_range_max");
    g_hCvarMinPounceDistance = FindConVar("z_pounce_damage_range_min");
    g_hCvarMaxPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
    if (g_hCvarMaxPounceDistance == INVALID_HANDLE) { g_hCvarMaxPounceDistance = CreateConVar("z_pounce_damage_range_max",  "1000.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_NONE, true, 0.0, false); }
    if (g_hCvarMinPounceDistance == INVALID_HANDLE) { g_hCvarMinPounceDistance = CreateConVar("z_pounce_damage_range_min",  "300.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_NONE, true, 0.0, false); }
    if (g_hCvarMaxPounceDamage == INVALID_HANDLE) { g_hCvarMaxPounceDamage = CreateConVar("z_hunter_max_pounce_bonus_damage",  "49", "Not available on this server, added by l4d2_skill_detect.", FCVAR_NONE, true, 0.0, false); }
    g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	
	g_hCvarPounceInterrupt.AddChangeHook(ConVarChange);
	g_hCvarChargerHealth.AddChangeHook(ConVarChange);
	g_hCvarWitchHealth.AddChangeHook(ConVarChange);
	g_hCvarMaxPounceDistance.AddChangeHook(ConVarChange);
	g_hCvarMinPounceDistance.AddChangeHook(ConVarChange);
	g_hCvarMaxPounceDamage.AddChangeHook(ConVarChange);
	g_hCvarSurvivorLimit.AddChangeHook(ConVarChange);
	
    ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
    // tries
    g_hTrieWeapons = new StringMap();
    g_hTrieWeapons.SetValue("hunting_rifle",               WPTYPE_SNIPER);
    g_hTrieWeapons.SetValue("sniper_military",             WPTYPE_SNIPER);
    g_hTrieWeapons.SetValue("sniper_awp",                  WPTYPE_SNIPER);
    g_hTrieWeapons.SetValue("sniper_scout",                WPTYPE_SNIPER);
    g_hTrieWeapons.SetValue("pistol_magnum",               WPTYPE_MAGNUM);
    g_hTrieWeapons.SetValue("grenade_launcher_projectile", WPTYPE_GL);
    
    g_hTrieEntityCreated = new StringMap();
    g_hTrieEntityCreated.SetValue("tank_rock",             OEC_TANKROCK);
    g_hTrieEntityCreated.SetValue("witch",                 OEC_WITCH);
    g_hTrieEntityCreated.SetValue("trigger_hurt",          OEC_TRIGGER);
    g_hTrieEntityCreated.SetValue("prop_car_alarm",        OEC_CARALARM);
    g_hTrieEntityCreated.SetValue("prop_car_glass",        OEC_CARGLASS);
    
    g_hTrieAbility = new StringMap();
    g_hTrieAbility.SetValue("ability_lunge",               ABL_HUNTERLUNGE);
    g_hTrieAbility.SetValue("ability_throw",               ABL_ROCKTHROW);
    
    g_hWitchTrie = new StringMap();
    g_hRockTrie = new StringMap();
    g_hCarTrie = new StringMap();
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iPounceInterrupt = g_hCvarPounceInterrupt.IntValue;
	g_iChargerHealth2 = g_hCvarChargerHealth.IntValue;
	g_iWitchHealth = g_hCvarWitchHealth.IntValue;
	g_fMaxPounceDistance = g_hCvarMaxPounceDistance.FloatValue;
	g_fMinPounceDistance = g_hCvarMinPounceDistance.FloatValue;
	g_fMaxPounceDamage = g_hCvarMaxPounceDamage.FloatValue;
	g_iSurvivorLimit = g_hCvarSurvivorLimit.IntValue;
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamageByWitch);
}

public Action OnTakeDamageByWitch (int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (L4D2_IsValidClient(victim) && damage > 0.0)
    {
        if (IsWitch(attacker))
        {
            char witch_key[10];
            FormatEx(witch_key, sizeof(witch_key), "%x", attacker);
            int witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
            
            if (!g_hWitchTrie.GetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT))
            {
                for (int i = 0; i <= MAXPLAYERS; i++)
                {
                    witch_dmg_array[i] = 0;
                }
                witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = g_iWitchHealth;
                witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] = 1;  // failed
                g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
            }
            else
            {
                witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] = 1;  // failed
                g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
            }
        }
    }
}


/*
    Tracking
    --------
*/

public void OnMapStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		ClearDamage(i);
	}
	g_iAlarmCarClient = 0;
}


public void L4D2_OnRealRoundStart()
{
    g_iRocksBeingThrownCount = 0;
    
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        g_bIsHopping[i] = false;
        
        for (int j = 1; j <= MAXPLAYERS; j++)
        {
            g_fVictimLastShove[i][j] = 0.0;
        }
    }
	
	g_bHasRoundEnded = false;
	if (g_hBoomerKillTimer != INVALID_HANDLE)
	{
		KillTimer(g_hBoomerKillTimer);
		g_hBoomerKillTimer = INVALID_HANDLE;
		BoomerKillTime = 0.0;
	}
	g_iAlarmCarClient = 0;
}

public void L4D2_OnRealRoundEnd()
{
    g_hCarTrie.Clear();
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		ClearDamage(i);
	}
	if (g_bHasRoundEnded) return;
	g_bHasRoundEnded = true;
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype, int hitgroup)
{
	if (g_bHasRoundEnded) return;
	
	if (!L4D2_IsValidClient(attacker)) return;
	
	if (L4D2_IsSurvivor(attacker) && L4D2_IsInfected(victim))
	{
		if (L4D2_GetInfectedClass(victim) == L4D2Infected_Tank) return; // We don't care about tank damage
		
		if (!g_bShotCounted[victim][attacker])
		{
			g_iShotsDealt[victim][attacker]++;
			g_bShotCounted[victim][attacker] = true;
		}
		
		if (health <= 0) return;
		
		g_iLastHealth[victim] = health;
		
		g_iDamageDealt[victim][attacker] += damage;
	}
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    L4D2_Infected zClass;
    
    int damage = event.GetInt("dmg_health");
    int damagetype = event.GetInt("type");
    
    if (IS_VALID_INFECTED(victim))
    {
        zClass = L4D2_GetInfectedClass(victim);
        int health = event.GetInt("health");
        int hitgroup = event.GetInt("hitgroup");
        
        if (damage < 1) return Plugin_Continue;
        
        switch (zClass)
        {
            case L4D2Infected_Hunter:
            {
                if (!IS_VALID_SURVIVOR(attacker))
                {
                    g_iHunterLastHealth[victim] = health;
                    return Plugin_Continue;
                }
                
                if (g_iHunterLastHealth[victim] > 0 && damage > g_iHunterLastHealth[victim])
                {
                    damage = g_iHunterLastHealth[victim];
                    g_iHunterOverkill[victim] = g_iHunterLastHealth[victim] - damage;
                    g_iHunterLastHealth[victim] = 0;
                }
                
                if (g_iHunterShotDmg[victim][attacker] > 0 && (GetGameTime() - g_fHunterShotStart[victim][attacker]) > SHOTGUN_BLAST_TIME)
                {
                    g_fHunterShotStart[victim][attacker] = 0.0;
                }
                
                if (GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce")
				  || g_fHunterTracePouncing[victim] != 0.0 && (GetGameTime() - g_fHunterTracePouncing[victim]) < 0.001)
                {
                    if (damagetype & DMG_BUCKSHOT)
                    {
                        if (g_fHunterShotStart[victim][attacker] == 0.0)
                        {
                            g_fHunterShotStart[victim][attacker] = GetGameTime();
                            g_fHunterLastShot[victim] = g_fHunterShotStart[victim][attacker];
                        }
                        g_iHunterShotDmg[victim][attacker] += damage;
                        g_iHunterShotDmgTeam[victim] += damage;
                        
                        if (health == 0)
						{
                            g_bHunterKilledPouncing[victim] = true;
                        }
                    }
                    else if (damagetype & (DMG_BLAST | DMG_PLASMA) && health == 0)
                    {
                        char weaponB[32];
                        strWeaponType weaponTypeB;
                        event.GetString("weapon", weaponB, sizeof(weaponB));
                        
                        if (g_hTrieWeapons.GetValue(weaponB, weaponTypeB) && weaponTypeB == WPTYPE_GL)
                        {
                            HandleSkeet(attacker, victim, false, false, true);
                        }
                    }
                    else if (damagetype & DMG_BULLET && health == 0 && hitgroup == HITGROUP_HEAD)
					{
                        char weaponA[32];
                        strWeaponType weaponTypeA;
                        event.GetString("weapon", weaponA, sizeof(weaponA));
                        
                        if (g_hTrieWeapons.GetValue(weaponA, weaponTypeA) && (weaponTypeA == WPTYPE_SNIPER || weaponTypeA == WPTYPE_MAGNUM))
						{
                            if (damage >= g_iPounceInterrupt)
                            {
                                g_iHunterShotDmgTeam[victim] = 0;
                                HandleSkeet(attacker, victim, false, true);
                                ResetHunter(victim);
                            }
                            else
                            {
                                HandleNonSkeet(attacker, victim, damage, (g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt), false, true);
                                ResetHunter(victim);
                            }
                        }
                    }
                    else if (damagetype & DMG_SLASH || damagetype & DMG_CLUB)
                    {
                        if (damage >= g_iPounceInterrupt)
                        {
                            g_iHunterShotDmgTeam[victim] = 0;
                            HandleSkeet(attacker, victim, true);
                            ResetHunter(victim);
                        }
                        else if (health == 0)
                        {
                            HandleNonSkeet(attacker, victim, damage, true, true, false);
                            ResetHunter(victim);
                        }
                    }
                }
                else if (health == 0)
                {
                    g_bHunterKilledPouncing[victim] = false;
                }
                
                g_iHunterLastHealth[victim] = health;
            }
            
            case L4D2Infected_Charger:
            {
                if (IS_VALID_SURVIVOR(attacker))
                {                
                    if (health == 0 && (damagetype & DMG_CLUB || damagetype & DMG_SLASH))
                    {
                        int iChargeHealth = g_iChargerHealth2;
                        int abilityEnt = GetEntPropEnt(victim, Prop_Send, "m_customAbility");
                        if (IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging"))
                        {
                            // charger was killed, was it a full level?
                            if (damage > (iChargeHealth * 0.65))
							{
								if (L4D2_IsValidClient(attacker) && L4D2_IsValidClient(victim) && !IsFakeClient(victim))
								{
									L4D2_CPrintToChatAll("{O}★★★ {G}%N {B}fully {W}leveled {G}%N", attacker, victim);
								}
								else if (L4D2_IsValidClient(attacker))
								{
									L4D2_CPrintToChatAll("{O}★★★ {G}%N {B}fully {W}leveled {G}a charger", attacker);
								}
								
								Call_StartForward(g_hForwardLevel);
								Call_PushCell(attacker);
								Call_PushCell(victim);
								Call_Finish();
                            }
                            else
							{
								if (L4D2_IsValidClient(attacker) && L4D2_IsValidClient(victim) && !IsFakeClient(victim))
								{
									L4D2_CPrintToChatAll("{O}★ {G}%N {B}chip-leveled {G}%N {W}({B}%i dmg{W})", attacker, victim, damage);
								}
								else if (L4D2_IsValidClient(attacker))
								{
									L4D2_CPrintToChatAll("{O}★ {G}%N {B}chip-leveled {W}a charger ({B}%i dmg{W})", attacker, damage);
								}
								
								Call_StartForward(g_hForwardLevelHurt);
								Call_PushCell(attacker);
								Call_PushCell(victim);
								Call_PushCell(damage);
								Call_Finish();
                            }
                        }
                    }
                }
                
                // store health for next damage it takes
                if (health > 0)
                {
                    g_iChargerHealth[victim] = health;
                }
            }
            
            case L4D2Infected_Smoker:
            {
                if (!IS_VALID_SURVIVOR(attacker)) { return Plugin_Continue; }
                
                g_iSmokerVictimDamage[victim] += damage;
            }
            
        }
    }
    else if (IS_VALID_INFECTED(attacker))
    {
        zClass = L4D2_GetInfectedClass(attacker);
        
        switch (zClass)
        {
            case L4D2Infected_Hunter:
            {
                // a hunter pounce landing is DMG_CRUSH
                if (damagetype & DMG_CRUSH) {
                    g_iPounceDamage[attacker] = damage;
                }
            }
            
            case L4D2Infected_Tank:
            {
                char weapon[10];
                event.GetString("weapon", weapon, sizeof(weapon));
                
                if (StrEqual(weapon, "tank_rock"))
                {
                    if (g_iTankRock[attacker])
                    {
                        char rock_key[10];
                        FormatEx(rock_key, sizeof(rock_key), "%x", g_iTankRock[attacker]);
                        int rock_array[3];
                        rock_array[rckDamage] = -1;
                        g_hRockTrie.SetArray(rock_key, rock_array, sizeof(rock_array), true);
                    }
                    
                    if (IS_VALID_SURVIVOR(victim))
                    {
						Call_StartForward(g_hForwardRockEaten);
						Call_PushCell(attacker);
						Call_PushCell(victim);
						Call_Finish();
                    }
                }
                
                return Plugin_Continue;
            }
        }
    }
    
    if (IS_VALID_SURVIVOR(victim))
    {
        // debug
        if (damagetype & DMG_DROWN || damagetype & DMG_FALL)
		{
            g_iVictimMapDmg[victim] += damage;
        }
        
        if (damagetype & DMG_DROWN && damage >= MIN_DC_TRIGGER_DMG)
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_HURTLOTS;
        }
        else if (damagetype & DMG_FALL && damage >= MIN_DC_FALL_DMG)
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_HURTLOTS;
        }
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IS_VALID_INFECTED(client)) return;
	
	L4D2_Infected zClass = L4D2_GetInfectedClass(client);
	
	if (zClass == L4D2Infected_Tank) return;
	
	g_iLastHealth[client] = GetClientHealth(client);
    g_fSpawnTime[client] = GetGameTime();
    g_fPinTime[client][0] = 0.0;
    g_fPinTime[client][1] = 0.0;
    
    switch (zClass)
    {
        case L4D2Infected_Boomer:
        {
            g_bBoomerHitSomebody[client] = false;
            g_iBoomerGotShoved[client] = 0;
			
			if (!IsFakeClient(client) || !g_iBoomerClient)
			{
				g_bHasBoomLanded = false;
				g_iBoomerClient = client;
				g_iBoomerShover = 0;
				g_iBoomerKiller = 0;
			}
			
			if (g_hBoomerShoveTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerShoveTimer);
				g_hBoomerShoveTimer = INVALID_HANDLE;
			}
			BoomerKillTime = 0.0;
			g_hBoomerKillTimer = CreateTimer(0.1, Timer_KillBoomer, _, TIMER_REPEAT);
        }
        case L4D2Infected_Smoker:
        {
            g_bSmokerClearCheck[client] = false;
            g_iSmokerVictim[client] = 0;
            g_iSmokerVictimDamage[client] = 0;
        }
        case L4D2Infected_Hunter:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Hunter);
    
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case L4D2Infected_Jockey:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Jockey);
            
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case L4D2Infected_Charger:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Charger);
            
            g_iChargerHealth[client] = g_iChargerHealth2;
        }
    }
}

public Action Timer_KillBoomer(Handle timer)
{
	BoomerKillTime += 0.1;
}

public Action Event_IncapStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int attackent = event.GetInt("attackerentid");
    int dmgtype = event.GetInt("type");
    
    char classname[24];
    strOEC classnameOEC;
    if (IsValidEntity(attackent))
	{
        GetEdictClassname(attackent, classname, sizeof(classname));
        if (g_hTrieEntityCreated.GetValue(classname, classnameOEC))
		{
            g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_TRIGGER;
        }
    }
    
    float flow = L4D2Direct_GetFlowDistance(client);
    
    if (dmgtype & DMG_DROWN)
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_DROWN;
    }
    if (flow < WEIRD_FLOW_THRESH)
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_WEIRDFLOW;
    }
}

public Action TraceAttack_Hunter(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_pounceVictim");
    
    if (!IS_VALID_SURVIVOR(attacker) || !IsValidEdict(inflictor)) { return; }
    
    if (GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
    {
        g_fHunterTracePouncing[victim] = GetGameTime();
    }
    else
    {
        g_fHunterTracePouncing[victim] = 0.0;
    }   
}
public Action TraceAttack_Charger(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    int victimA = GetEntPropEnt(victim, Prop_Send, "m_carryVictim");
    if (victimA != -1)
	{
        g_iSpecialVictim[victim] = victimA;
    }
	else
	{
        g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_pummelVictim");
    }
    
}
public Action TraceAttack_Jockey(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_jockeyVictim");
}

public Action Event_PlayerDeathPre(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker")); 
    
    if (IS_VALID_INFECTED(victim))
    {
        L4D2_Infected zClass = L4D2_GetInfectedClass(victim);
        
        switch (zClass)
        {
            case L4D2Infected_Hunter:
            {
                if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
                
                if (g_iHunterShotDmgTeam[victim] > 0 && g_bHunterKilledPouncing[victim])
                {
                    if (g_iHunterShotDmgTeam[victim] > g_iHunterShotDmg[victim][attacker] && g_iHunterShotDmgTeam[victim] >= g_iPounceInterrupt)
					{
                        HandleSkeet(-2, victim);
                    }
                    else if (g_iHunterShotDmg[victim][attacker] >= g_iPounceInterrupt)
                    {
                        HandleSkeet(attacker, victim);
                    }
                    else if (g_iHunterOverkill[victim] > 0)
                    {
                        HandleNonSkeet(attacker, victim, g_iHunterShotDmgTeam[victim], (g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt));
                    }
                    else
                    {
                        HandleNonSkeet(attacker, victim, g_iHunterShotDmg[victim][attacker]);
                    }
                }
                else
				{
                    if (g_iSpecialVictim[victim] > 0)
                    {
                        HandleClear(attacker, victim, g_iSpecialVictim[victim],
                                L4D2Infected_Hunter,
                                (GetGameTime() - g_fPinTime[victim][0]),
                                -1.0
                           );
                    }
                }
                
                ResetHunter(victim);
            }
            
            case L4D2Infected_Smoker:
            {
                if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
                
                if (g_bSmokerClearCheck[victim] &&
                        g_iSmokerVictim[victim] == attacker &&
                        g_iSmokerVictimDamage[victim] >= SELF_CLEAR_THRESH
               ) {
                        HandleSmokerSelfClear(attacker, victim);
                }
                else
                {
                    g_bSmokerClearCheck[victim] = false;
                    g_iSmokerVictim[victim] = 0;
                }
            }
            
            case L4D2Infected_Jockey:
            {
                if (g_iSpecialVictim[victim] > 0)
                {
                    HandleClear(attacker, victim, g_iSpecialVictim[victim],
                            L4D2Infected_Jockey,
                            (GetGameTime() - g_fPinTime[victim][0]),
                            -1.0
                       );
                }
            }
            
            case L4D2Infected_Charger:
            {
                if (L4D2_IsValidClient(g_iChargeVictim[victim]))
				{
                    g_fChargeTime[ g_iChargeVictim[victim] ] = GetGameTime();
                }
                
                if (g_iSpecialVictim[victim] > 0)
                {
                    HandleClear(attacker, victim, g_iSpecialVictim[victim],
                            L4D2Infected_Charger,
                            (g_fPinTime[victim][1] > 0.0) ? (GetGameTime() - g_fPinTime[victim][1]) : -1.0,
                            (GetGameTime() - g_fPinTime[victim][0])
                       );
                }
            }
        }
    }
    else if (IS_VALID_SURVIVOR(victim))
    {
        int dmgtype = event.GetInt("type"); 
        
        if (dmgtype & DMG_FALL)
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_FALL;
        }
        else if (IS_VALID_INFECTED(attacker) && attacker != g_iVictimCharger[victim])
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_KILLEDBYOTHER;
        }
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
	if (!L4D2_IsValidClient(victim)) return;
	
	if (attacker == 0) return;
	
	if (!L4D2_IsValidClient(attacker))
	{
		if (L4D2_IsInfected(victim)) ClearDamage(victim);
		return;
	}
	
	if (L4D2_IsSurvivor(attacker) && L4D2_IsInfected(victim))
	{
		L4D2_Infected zombieclass = L4D2_GetInfectedClass(victim);
		if (zombieclass == L4D2Infected_Tank) return; // We don't care about tank damage
		
		int lasthealth = g_iLastHealth[victim];
		g_iDamageDealt[victim][attacker] += lasthealth;
		
		if (zombieclass == L4D2Infected_Boomer)
		{
			if (!g_iBoomerClient) g_iBoomerClient = victim;

			if (!IsFakeClient(g_iBoomerClient)) GetClientName(g_iBoomerClient, Boomer, sizeof(Boomer));
			else Boomer = "AI";
			
			CreateTimer(0.2, Timer_BoomerKilledCheck, victim);
			g_iBoomerKiller = attacker;
			
			if (g_hBoomerKillTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerKillTimer);
				g_hBoomerKillTimer = INVALID_HANDLE;
			}
		}
		else if (zombieclass == L4D2Infected_Hunter && g_bIsPouncing[victim])
		{ // Skeet!
			int[][] assisters = new int[g_iSurvivorLimit][2];
			int assister_count, i;
			int damage = g_iDamageDealt[victim][attacker];
			int shots = g_iShotsDealt[victim][attacker];
			char plural[1] = "s";
			if (shots == 1) plural[0] = 0;
			for (i = 1; i <= MaxClients; i++)
			{
				if (i == attacker) continue;
				if (g_iDamageDealt[victim][i] > 0 && IsClientInGame(i))
				{
					assisters[assister_count][0] = i;
					assisters[assister_count][1] = g_iDamageDealt[victim][i];
					assister_count++;
				}
			}
			
			char weapon[64];
			GetClientWeapon(attacker, weapon, sizeof(weapon));
			
			if (StrEqual(weapon, "weapon_melee"))
			{
				L4D2_CPrintToChat(victim, "{B}[{W}Stats{B}] {W}You were {B}melee skeeted {W}by {G}%N", attacker);
				L4D2_CPrintToChat(attacker, "{B}[{W}Stats{B}] {W}You {B}melee{W}-{B}skeeted {G}%N", victim);
				
				for (int b = 1; b <= MaxClients; b++)
				{
					if (IsClientInGame(b) && (victim != b) && (attacker != b))
					{
						L4D2_CPrintToChat(b, "{B}[{W}Stats{B}] {G}%N {W}was {B}melee{W}-{B}skeeted {W}by {G}%N", victim, attacker);
					}
				}
			}
			else if (event.GetBool("headshot") && StrEqual(weapon, "weapon_sniper_scout"))
			{
				L4D2_CPrintToChat(victim, "{B}[{W}Stats{B}] {W}You were {B}Headshotted {W}by {B}Scout-Player{W}: {G}%N", attacker);
				L4D2_CPrintToChat(attacker, "{B}[{W}Stats{B}] {W}You {B}Headshotted {G}%N {W}with the {B}Scout", victim);
				
				for (int b = 1; b <= MaxClients; b++)
				{
					if (IsClientInGame(b) && (victim != b) && (attacker != b))
					{
						L4D2_CPrintToChat(b, "{B}[{W}Stats{B}] {G}%N {W}was {B}Headshotted {W}by {B}Scout-Player{W}: {G}%N", victim, attacker);
					}
				}
			}
			else if (assister_count)
			{
				SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
				char assister_string[128];
				char buf[MAX_NAME_LENGTH + 8];
				int assist_shots = g_iShotsDealt[victim][assisters[0][0]];
				Format(assister_string, sizeof(assister_string), "%N (%d/%d shot%s)",
				assisters[0][0],
				assisters[0][1],
				g_iShotsDealt[victim][assisters[0][0]],
				assist_shots == 1 ? "":"s");
				for (i = 1; i < assister_count; i++)
				{
					assist_shots = g_iShotsDealt[victim][assisters[i][0]];
					Format(buf, sizeof(buf), ", %N (%d/%d shot%s)",
					assisters[i][0],
					assisters[i][1],
					assist_shots,
					assist_shots == 1 ? "":"s");
					StrCat(assister_string, sizeof(assister_string), buf);
				}
				
				for (i = 0; i < assister_count; i++)
				{
					L4D2_CPrintToChat(assisters[i][0], "{B}[{W}Stats{B}] {G}%N {W}teamskeeted {G}%N {W}for {B}%d damage {W}in {B}%d shot%s{W}. Assisted by: {G}%s",
					attacker, victim, damage, shots, plural, assister_string);
				}
				L4D2_CPrintToChat(victim, "{B}[{W}Stats{B}] {W}You were teamskeeted by {G}%N {W}for {B}%d damage {W}in {B}%d shot%s{W}. Assisted by: {G}%s",
				attacker, damage, shots, plural, assister_string);
				
				L4D2_CPrintToChat(attacker, "{B}[{W}Stats{B}] {W}You teamskeeted {G}%N {W}for {B}%d damage {W}in {B}%d shot%s{W}. Assisted by: {G}%s",
				victim, damage, shots, plural, assister_string);
				
				for (int b = 1; b <= MaxClients; b++)
				{
					if (IsClientInGame(b) && (L4D2_IsSpectator(b)))
					{
						L4D2_CPrintToChat(b, "{B}[{W}Stats{B}] {G}%N {W}teamskeeted {G}%N {W}for {B}%d damage {W}in {B}%d shot%s{W}. Assisted by: {G}%s",
						attacker, victim, damage, shots, plural, assister_string);
					}
				}
			}
			else
			{
				L4D2_CPrintToChat(victim, "{B}[{W}Stats{B}] {W}You were skeeted by {G}%N {W}in {B}%d shot%s", attacker, shots, plural);
				
				L4D2_CPrintToChat(attacker, "{B}[{W}Stats{B}] {W}You skeeted {G}%N {W}in {B}%d shot%s", victim, shots, plural);
				
				for (int b = 1; b <= MaxClients; b++)
				{
					if (IsClientInGame(b) && (victim != b) && attacker != b)
					{
						L4D2_CPrintToChat(b, "{B}[{W}Stats{B}] {G}%N {W}skeeted {G}%N {W}in {B}%d shot%s", attacker, victim, shots, plural);
					}
				}
			}
		}
	}
	if (L4D2_IsInfected(victim)) ClearDamage(victim);
}

public Action Timer_BoomerKilledCheck(Handle timer)
{
	BoomerKillTime = BoomerKillTime - 0.2;
	
	if (g_bHasBoomLanded || BoomerKillTime > 2.0)
	{
		g_iBoomerClient = 0;
		BoomerKillTime = 0.0;
		return;
	}
	
	if (L4D2_IsValidClient(g_iBoomerKiller) && L4D2_IsValidClient(g_iBoomerClient))
	{
		if (g_iBoomerShover != 0 && L4D2_IsValidClient(g_iBoomerShover))
		{	
			if (g_iBoomerShover == g_iBoomerKiller)
			{
				L4D2_CPrintToChatAll("{B}[{W}Stats{B}] {G}%N {W}shoved and popped {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerKiller, Boomer, BoomerKillTime);
			}
			else
			{
				L4D2_CPrintToChatAll("{B}[{W}Stats{B}] {G}%N {W}shoved and {G}%N {W}popped {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerShover, g_iBoomerKiller, Boomer, BoomerKillTime);
			}
		}
		else
		{
			L4D2_CPrintToChatAll("{B}[{W}Stats{B}] {G}%N {W}has shutdown {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerKiller, Boomer, BoomerKillTime);
		}
	}
	
	g_iBoomerClient = 0;
	BoomerKillTime = 0.0;
}

public Action Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	
    if (!IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(victim)) return;
	
	L4D2_Infected zClass = L4D2_GetInfectedClass(victim);
	
	switch (zClass)
	{
		case L4D2Infected_Boomer:
		{
			g_iBoomerGotShoved[victim]++;
			if (g_bHasRoundEnded) return;
			if (g_hBoomerShoveTimer != INVALID_HANDLE)
			{
				KillTimer(g_hBoomerShoveTimer);
				if (!g_iBoomerShover || !L4D2_IsValidClient(g_iBoomerShover)) g_iBoomerShover = attacker;
			}
			else
			{
				g_iBoomerShover = attacker;
			}
			g_hBoomerShoveTimer = CreateTimer(BOOMER_STAGGER_TIME, Timer_BoomerShove);
		}
		case L4D2Infected_Hunter:
		{
			if (GetEntPropEnt(victim, Prop_Send, "m_pounceVictim") > 0)
			{
				HandleClear(attacker, victim, GetEntPropEnt(victim, Prop_Send, "m_pounceVictim"),
						L4D2Infected_Hunter,
						(GetGameTime() - g_fPinTime[victim][0]),
						-1.0,
						true
				   );
			}
		}
		case L4D2Infected_Jockey:
		{
			if (GetEntPropEnt(victim, Prop_Send, "m_jockeyVictim") > 0)
			{
				HandleClear(attacker, victim, GetEntPropEnt(victim, Prop_Send, "m_jockeyVictim"),
						L4D2Infected_Jockey,
						(GetGameTime() - g_fPinTime[victim][0]),
						-1.0,
						true
				   );
			}
		}
	}
    
    if (g_fVictimLastShove[victim][attacker] == 0.0 || (GetGameTime() - g_fVictimLastShove[victim][attacker]) >= SHOVE_TIME)
    {
        if (GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce"))
        {
			Call_StartForward(g_hForwardHunterDeadstop);
			Call_PushCell(attacker);
			Call_PushCell(victim);
			Call_Finish();
        }
        
		Call_StartForward(g_hForwardSIShove);
		Call_PushCell(attacker);
		Call_PushCell(victim);
		Call_PushCell(zClass);
		Call_Finish();
        
        g_fVictimLastShove[victim][attacker] = GetGameTime();
    }
    
    if (g_iSmokerVictim[victim] == attacker)
    {
        g_bSmokerShoved[victim] = true;
    }
}

public Action Timer_BoomerShove(Handle timer)
{
	g_hBoomerShoveTimer = INVALID_HANDLE;
	g_iBoomerShover = 0;
}

public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("userid"));
	int victim = GetClientOfUserId(event.GetInt("victim"));
	
	if (L4D2_GetInfectedClass(attacker) == L4D2Infected_Hunter) g_bIsPouncing[attacker] = false;
	
    g_fPinTime[attacker][0] = GetGameTime();
    
    ResetHunter(attacker);
    
    if (g_fPouncePosition[attacker][0] == 0.0
        &&  g_fPouncePosition[attacker][1] == 0.0
        &&  g_fPouncePosition[attacker][2] == 0.0
   ) {
        return Plugin_Continue;
    }
        
    float endPos[3];
    GetClientAbsOrigin(attacker, endPos);
    float fHeight = g_fPouncePosition[attacker][2] - endPos[2];
    
    float fMin = g_fMinPounceDistance;
    float fMax = g_fMaxPounceDistance;
    float fMaxDmg = g_fMaxPounceDamage;
    
    int distance = RoundToNearest(GetVectorDistance(g_fPouncePosition[attacker], endPos));
    
    float fDamage = (((float(distance) - fMin) / (fMax - fMin)) * fMaxDmg) + 1.0;

    if (fDamage < 0.0)
	{
        fDamage = 0.0;
    }
	else if (fDamage > fMaxDmg + 1.0)
	{
        fDamage = fMaxDmg + 1.0;
    }
    
    Handle pack = CreateDataPack();
    WritePackCell(pack, attacker);
    WritePackCell(pack, victim);
    WritePackFloat(pack, fDamage);
    WritePackFloat(pack, fHeight);
    CreateTimer(0.05, Timer_HunterDP, pack);
    
    return Plugin_Continue;
}

public Action Timer_HunterDP(Handle timer, Handle pack)
{
    ResetPack(pack);
    int client = ReadPackCell(pack);
    int victim = ReadPackCell(pack);
    float fDamage = ReadPackFloat(pack);
    float fHeight = ReadPackFloat(pack);
    CloseHandle(pack);
    
    if (fHeight >= HUNTER_DP_THRESH)
	{
        if (L4D2_IsValidClient(client) && L4D2_IsValidClient(victim) && !IsFakeClient(client))
        {
            L4D2_CPrintToChatAll("{O}★★ {G}%N {R}high-pounced {G}%N {W}({R}%i {W}dmg, height: {R}%i{W})", client,  victim, RoundFloat(fDamage), RoundFloat(fHeight));
        }
        else if (L4D2_IsValidClient(victim))
        {
            L4D2_CPrintToChatAll("{O}★★ {G}A hunter {R}high-pounced {G}%N {W}({R}%i {W}dmg, height: {R}%i{W})", victim, RoundFloat(fDamage), RoundFloat(fHeight));
        }
    }
    
    Call_StartForward(g_hForwardHunterDP);
    Call_PushCell(client);
    Call_PushCell(victim);
    Call_PushCell(g_iPounceDamage[client]);
    Call_PushFloat(fDamage);
    Call_PushFloat(fHeight);
    Call_PushCell((fHeight >= HUNTER_DP_THRESH) ? 1 : 0);
    Call_PushCell(0);
    Call_Finish();
}

public Action Event_PlayerJumped(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (IS_VALID_INFECTED(client))
    {
        L4D2_Infected zClass = L4D2_GetInfectedClass(client);
        if (zClass != L4D2Infected_Jockey) return Plugin_Continue;
    
        GetClientAbsOrigin(client, g_fPouncePosition[client]);
    }
    else if (IS_VALID_SURVIVOR(client))
    {
        float  fPos[3], fVel[3];
        GetClientAbsOrigin(client, fPos);
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel); 
        fVel[2] = 0.0; // safeguard
        
        float fLengthNew, fLengthOld;
        fLengthNew = GetVectorLength(fVel);
        
        
        g_bHopCheck[client] = false;
        
        if (!g_bIsHopping[client])
        {
            if (fLengthNew >= BHOP_MIN_INIT_SPEED)
            {
                g_fHopTopVelocity[client] = fLengthNew;
                g_bIsHopping[client] = true;
                g_iHops[client] = 0;
            }
        }
        else
        {
            fLengthOld = GetVectorLength(g_fLastHop[client]);
            
            if (fLengthNew - fLengthOld > HOP_ACCEL_THRESH || fLengthNew >= BHOP_CONT_SPEED)
            {
                g_iHops[client]++;
                
                if (fLengthNew > g_fHopTopVelocity[client])
                {
                    g_fHopTopVelocity[client] = fLengthNew;
                }
            }
            else
            {
                g_bIsHopping[client] = false;
                
                if (g_iHops[client])
                {
                    HandleBHopStreak(client, g_iHops[client], g_fHopTopVelocity[client]);
                    g_iHops[client] = 0;
                }
            }
        }
        
        g_fLastHop[client][0] = fVel[0];
        g_fLastHop[client][1] = fVel[1];
        g_fLastHop[client][2] = fVel[2];
        
        if (g_iHops[client] != 0)
        {
            CreateTimer(HOP_CHECK_TIME, Timer_CheckHop, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckHop (Handle timer, any client)
{
    if (!L4D2_IsValidClient(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    else if (GetEntityFlags(client) & FL_ONGROUND)
    {
        float fVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel); 
        fVel[2] = 0.0; // safeguard
        
        g_bHopCheck[client] = true;
        
        CreateTimer(HOPEND_CHECK_TIME, Timer_CheckHopStreak, client, TIMER_FLAG_NO_MAPCHANGE);
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckHopStreak (Handle timer, any client)
{
    if (!L4D2_IsValidClient(client) || !IsPlayerAlive(client)) return Plugin_Continue;
    
    if (g_bHopCheck[client] && g_iHops[client])
    {
        HandleBHopStreak(client, g_iHops[client], g_fHopTopVelocity[client]);
        g_bIsHopping[client] = false;
        g_iHops[client] = 0;
        g_fHopTopVelocity[client] = 0.0;
    }
    
    g_bHopCheck[client] = false;
    
    return Plugin_Continue;
}


public Action Event_PlayerJumpApex(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (g_bIsHopping[client])
    {
        float fVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel); 
        fVel[2] = 0.0;
        float fLength = GetVectorLength(fVel);
        
        if (fLength > g_fHopTopVelocity[client])
        {
            g_fHopTopVelocity[client] = fLength;
        }
    }
}

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bShotCounted[i][client] = false;
	}
}

public Action Event_Panic(Event event, const char[] name, bool dontBroadcast)
{
	g_iAlarmCarClient = GetClientOfUserId(event.GetInt("userid"));
	CreateTimer(0.5, Clear, g_iAlarmCarClient);
}

public Action Clear(Handle timer)
{
	g_iAlarmCarClient = 0;
}

public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (!IS_VALID_INFECTED(client) || !IS_VALID_SURVIVOR(victim)) return;
    
    g_fPinTime[client][0] = GetGameTime();
    
    if (g_fPouncePosition[client][0] == 0.0 && g_fPouncePosition[client][1] == 0.0 && g_fPouncePosition[client][2] == 0.0) return;
    
    float endPos[3];
    GetClientAbsOrigin(client, endPos);
    float fHeight = g_fPouncePosition[client][2] - endPos[2];
    
    if (fHeight >= JOCKEY_DP_THRESH)
	{
        if (L4D2_IsValidClient(client) && L4D2_IsValidClient(victim) && !IsFakeClient(client))
        {
            L4D2_CPrintToChatAll("{O}★★★ {G}%N {R}high-pounced {G}%N {W}({R}height{W}: {R}%i{W})", client,  victim, RoundFloat(fHeight));
        }
        else if (L4D2_IsValidClient(victim))
        {
            L4D2_CPrintToChatAll("{O}★★★ {G}A jockey {R}high-pounced {G}%N {W}({R}height{W}: {R}%i{W})", victim, RoundFloat(fHeight));
        }
    }
    
    Call_StartForward(g_hForwardJockeyDP);
    Call_PushCell(client);
    Call_PushCell(victim);
    Call_PushFloat(fHeight);
    Call_PushCell((fHeight >= JOCKEY_DP_THRESH) ? 1 : 0);
    Call_Finish();
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client)) return;
	
    char abilityName[64];
    event.GetString("ability", abilityName, sizeof(abilityName));
	
    strAbility ability;
    if (!g_hTrieAbility.GetValue(abilityName, ability)) return;
    
    switch (ability)
    {
        case ABL_HUNTERLUNGE:
        {
            ResetHunter(client);
            GetClientAbsOrigin(client, g_fPouncePosition[client]);
        }
    
        case ABL_ROCKTHROW:
        {
            g_iRocksBeingThrown[g_iRocksBeingThrownCount] = client;
            
            if (g_iRocksBeingThrownCount < 9) { g_iRocksBeingThrownCount++; }
        }
    }
	
	if (g_bHasRoundEnded) return;
	
	if (L4D2_GetInfectedClass(client) == L4D2Infected_Hunter)
	{
		g_bIsPouncing[client] = true;
		CreateTimer(0.5, Timer_GroundedCheck, client, TIMER_REPEAT);
	}
}

public Action Timer_GroundedCheck(Handle timer, any client)
{
	if (!L4D2_IsValidClient(client) || (GetEntProp(client, Prop_Data, "m_fFlags") & FL_ONGROUND) > 0)
	{
		g_bIsPouncing[client] = false;
		KillTimer(timer);
	}
}

public Action Event_ChargeCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    if (!IS_VALID_INFECTED(client)) return;

    PrintDebug("Charge carry start: %i - %i -- time: %.2f", client, victim, GetGameTime());
    
    g_fChargeTime[client] = GetGameTime();
    g_fPinTime[client][0] = g_fChargeTime[client];
    g_fPinTime[client][1] = 0.0;
    
    if (!IS_VALID_SURVIVOR(victim)) { return; }
    
    g_iChargeVictim[client] = victim;           // store who we're carrying (as long as this is set, it's not considered an impact charge flight)
    g_iVictimCharger[victim] = client;          // store who's charging whom
    g_iVictimFlags[victim] = VICFLG_CARRIED;    // reset flags for checking later - we know only this now
    g_fChargeTime[victim] = g_fChargeTime[client];
    g_iVictimMapDmg[victim] = 0;
    
    GetClientAbsOrigin(victim, g_fChargeVictimPos[victim]);
    
    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_ChargeImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    if (!IS_VALID_INFECTED(client) || !IS_VALID_SURVIVOR(victim)) { return; }
    
    GetClientAbsOrigin(victim, g_fChargeVictimPos[victim]);
    
    g_iVictimCharger[victim] = client;      // store who we've bumped up
    g_iVictimFlags[victim] = 0;             // reset flags for checking later
    g_fChargeTime[victim] = GetGameTime();  // store time per victim, for impacts
    g_iVictimMapDmg[victim] = 0;
    
    CreateTimer(CHARGE_CHECK_TIME, Timer_ChargeCheck, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Event_ChargePummelStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if (!IS_VALID_INFECTED(client)) { return; }
    
    g_fPinTime[client][1] = GetGameTime();
}


public Action Event_ChargeCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (client < 1 || client > MaxClients) { return; }
    
    g_fPinTime[client][1] = GetGameTime();
    
    CreateTimer(0.1, Timer_ChargeCarryEnd, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ChargeCarryEnd(Handle timer, any client)
{
    g_iChargeVictim[client] = 0;        // unset this so the repeated timer knows to stop for an ongroundcheck
}

public Action Timer_ChargeCheck(Handle timer, any client)
{
    if (!IS_VALID_SURVIVOR(client) || !g_iVictimCharger[client] || g_fChargeTime[client] == 0.0 || (GetGameTime() - g_fChargeTime[client]) > MAX_CHARGE_TIME)
    {
        return Plugin_Stop;
    }
    
    if (!IsPlayerAlive(client))
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_AIRDEATH;
        
        CreateTimer(0.0, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE);
        
        return Plugin_Stop;
    }
    else if (GetEntityFlags(client) & FL_ONGROUND && g_iChargeVictim[ g_iVictimCharger[client] ] != client)
    {
        CreateTimer(CHARGE_END_CHECK, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE);
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_DeathChargeCheck(Handle timer, any client)
{
    if (!L4D2_IsValidClient(client)) { return; }
    
    PrintDebug("Checking charge victim: %i - %i - flags: %i (alive? %i)", g_iVictimCharger[client], client, g_iVictimFlags[client], IsPlayerAlive(client));
    
    int flags = g_iVictimFlags[client];
    
    if (!IsPlayerAlive(client))
    {
        float pos[3];
        GetClientAbsOrigin(client, pos);
        float fHeight = g_fChargeVictimPos[client][2] - pos[2];
        
        if (((flags & VICFLG_DROWN || flags & VICFLG_FALL) &&
                    (flags & VICFLG_HURTLOTS || flags & VICFLG_AIRDEATH) ||
                    (flags & VICFLG_WEIRDFLOW && fHeight >= MIN_FLOWDROPHEIGHT) ||
                    g_iVictimMapDmg[client] >= MIN_DC_TRIGGER_DMG
               ) &&
                !(flags & VICFLG_KILLEDBYOTHER)
       ) {
			if (fHeight >= DEATH_CHARGER_HEIGHT)
			{
				if (L4D2_IsValidClient(g_iVictimCharger[client]) && L4D2_IsValidClient(client) && !IsFakeClient(g_iVictimCharger[client]))
				{
					L4D2_CPrintToChatAll("{O}★★★★ {G}%N {R}death-charged {G}%N{W} %s({R}height{W}: {R}%i{W})",
							g_iVictimCharger[client],
							client,
							(view_as<bool>(flags & VICFLG_CARRIED)) ? "" : "by bowling ",
							RoundFloat(fHeight)
					   );
				}
				else if (L4D2_IsValidClient(client))
				{
					L4D2_CPrintToChatAll("{O}★★★★ {G}A charger {R}death-charged {G}%N{W} %s({R}height{W}: {R}%i{W})",
							client,
							(view_as<bool>(flags & VICFLG_CARRIED)) ? "" : "by bowling ",
							RoundFloat(fHeight) 
					   );
				}
			}
			
			Call_StartForward(g_hForwardDeathCharge);
			Call_PushCell(g_iVictimCharger[client]);
			Call_PushCell(client);
			Call_PushFloat(fHeight);
			Call_PushFloat(GetVectorDistance(g_fChargeVictimPos[client], pos, false));
			Call_PushCell((view_as<bool>(flags & VICFLG_CARRIED)) ? 1 : 0);
			Call_Finish();
        }
    }
    else if ((flags & VICFLG_WEIRDFLOW || g_iVictimMapDmg[client] >= MIN_DC_RECHECK_DMG) &&
                !(flags & VICFLG_WEIRDFLOWDONE)
   ) {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_WEIRDFLOWDONE;
        
        CreateTimer(CHARGE_END_RECHECK, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE);
    }
}

void ResetHunter(int client)
{
    g_iHunterShotDmgTeam[client] = 0;
    
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        g_iHunterShotDmg[client][i] = 0;
        g_fHunterShotStart[client][i] = 0.0;
    }
    g_iHunterOverkill[client] = 0;
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if (entity < 1 || !IsValidEntity(entity) || !IsValidEdict(entity)) return;
    
    strOEC classnameOEC;
    if (!g_hTrieEntityCreated.GetValue(classname, classnameOEC)) return;
    
    switch (classnameOEC)
    {
        case OEC_TANKROCK:
        {
            char rock_key[10];
            FormatEx(rock_key, sizeof(rock_key), "%x", entity);
            int rock_array[3];
            
            int tank = ShiftTankThrower();
            
            if (L4D2_IsValidClient(tank))
            {
                g_iTankRock[tank] = entity;
                rock_array[rckTank] = tank;
            }
            g_hRockTrie.SetArray(rock_key, rock_array, sizeof(rock_array), true);
            
            SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
            SDKHook(entity, SDKHook_Touch, OnTouch_Rock);
        }
        
        
        case OEC_CARALARM:
        {
            char car_key[10];
            FormatEx(car_key, sizeof(car_key), "%x", entity);
            
            SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage_Car);
            SDKHook(entity, SDKHook_Touch, OnTouch_Car);
            
            SDKHook(entity, SDKHook_Spawn, OnEntitySpawned_CarAlarm); 
        }
        
        case OEC_CARGLASS:
        {
            SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage_CarGlass);
            SDKHook(entity, SDKHook_Touch, OnTouch_CarGlass);
            
            SDKHook(entity, SDKHook_Spawn, OnEntitySpawned_CarAlarmGlass); 
        }
    }
}

public void OnEntitySpawned_CarAlarm(int entity)
{
    if (!IsValidEntity(entity)) { return; }
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", entity);
    
    char target[48];
    GetEntPropString(entity, Prop_Data, "m_iName", target, sizeof(target));
    
    g_hCarTrie.SetValue(target, entity);
    g_hCarTrie.SetValue(car_key, 0);         // who shot the car?
    
    HookSingleEntityOutput(entity, "OnCarAlarmStart", Hook_CarAlarmStart);
}

public void OnEntitySpawned_CarAlarmGlass(int entity)
{
    if (!IsValidEntity(entity)) { return; }
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", entity);
    
    char parent[48];
    GetEntPropString(entity, Prop_Data, "m_iParent", parent, sizeof(parent));
    int parentEntity;
    
    if (g_hCarTrie.GetValue(parent, parentEntity))
    {
        if (IsValidEntity(parentEntity))
        {
            g_hCarTrie.SetValue(car_key, parentEntity);
            
            char car_key_p[10];
            FormatEx(car_key_p, sizeof(car_key_p), "%x_A", parentEntity);
            int testEntity;
            
            if (g_hCarTrie.GetValue(car_key_p, testEntity))
            {
                FormatEx(car_key_p, sizeof(car_key_p), "%x_B", parentEntity);
            }
            
            g_hCarTrie.SetValue(car_key_p, entity);
        }
    }
}

public void OnEntityDestroyed(int entity)
{
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", entity);
    
    int rock_array[3];
    if (g_hRockTrie.GetArray(witch_key, rock_array, sizeof(rock_array)))
    {
        // tank rock
        CreateTimer(ROCK_CHECK_TIME, Timer_CheckRockSkeet, entity);
        SDKUnhook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
        return;
    }

    int witch_array[MAXPLAYERS+DMGARRAYEXT];
    if (g_hWitchTrie.GetArray(witch_key, witch_array, sizeof(witch_array)))
    {
        // witch
        //  delayed deletion, to avoid potential problems with crowns not detecting
        CreateTimer(WITCH_DELETE_TIME, Timer_WitchKeyDelete, entity);
        SDKUnhook(entity, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
        return;
    }
}

public Action Timer_WitchKeyDelete(Handle timer, any witch)
{
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    g_hWitchTrie.Remove(witch_key);
}


public Action Timer_CheckRockSkeet(Handle timer, any rock)
{
    int rock_array[3];
    char rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", rock);
    if (!g_hRockTrie.GetArray(rock_key, rock_array, sizeof(rock_array))) { return Plugin_Continue; }
    
    g_hRockTrie.Remove(rock_key);
    
    if (rock_array[rckDamage] > 0)
    {
		L4D2_CPrintToChatAll("{O}★ {G}%N {B}skeeted {W}a tank rock", rock_array[rckSkeeter]);
		
		Call_StartForward(g_hForwardRockSkeeted);
		Call_PushCell(rock_array[rckSkeeter]);
		Call_PushCell(rock_array[rckTank]);
		Call_Finish();
    }
    
    return Plugin_Continue;
}

public Action Event_PlayerBoomed(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    bool byBoom = event.GetBool("by_boomer");
    
    if (byBoom && IS_VALID_INFECTED(attacker))
    {
        g_bBoomerHitSomebody[attacker] = true;
        
        bool byExplosion = event.GetBool("exploded");
        if (!byExplosion)
        {
            if (!g_iBoomerVomitHits[attacker])
			{
                CreateTimer(VOMIT_DURATION_TIME, Timer_BoomVomitCheck, attacker, TIMER_FLAG_NO_MAPCHANGE);
            }
            g_iBoomerVomitHits[attacker]++;
        }
    }
	if (g_bHasBoomLanded) return;
	g_bHasBoomLanded = true;
}

public Action Timer_BoomVomitCheck(Handle timer, any client)
{
	Call_StartForward(g_hForwardVomitLanded);
	Call_PushCell(client);
	Call_PushCell(g_iBoomerVomitHits[client]);
	Call_Finish();
    g_iBoomerVomitHits[client] = 0;
}

public Action Event_BoomerExploded(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    bool biled = event.GetBool("splashedbile");
    if (!biled && !g_bBoomerHitSomebody[client])
    {
        int attacker = GetClientOfUserId(event.GetInt("attacker"));
        if (IS_VALID_SURVIVOR(attacker))
        {
			Call_StartForward(g_hForwardBoomerPop);
			Call_PushCell(attacker);
			Call_PushCell(client);
			Call_PushCell(g_iBoomerGotShoved[client]);
			Call_PushFloat((GetGameTime() - g_fSpawnTime[client]));
			Call_Finish();
        }
    }
}

// crown tracking
public Action Event_WitchSpawned(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    
    SDKHook(witch, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
    
    int witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = g_iWitchHealth;
    g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
}

public Action Event_WitchKilled(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    SDKUnhook(witch, SDKHook_OnTakeDamagePost, OnTakeDamagePost_Witch);
    
    if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
    
    bool bOneShot = event.GetBool("oneshot");
    
    Handle  pack = CreateDataPack();
    WritePackCell(pack, attacker);
    WritePackCell(pack, witch);
    WritePackCell(pack, (bOneShot) ? 1 : 0);
    CreateTimer(WITCH_CHECK_TIME, Timer_CheckWitchCrown, pack);
    
    return Plugin_Continue;
}
public Action Event_WitchHarasserSet(Event event, const char[] name, bool dontBroadcast)
{
    int witch = event.GetInt("witchid");
    
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    int witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    
    if (!g_hWitchTrie.GetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT))
    {
        for (int i = 0; i <= MAXPLAYERS; i++)
        {
            witch_dmg_array[i] = 0;
        }
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = g_iWitchHealth;
        witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] = 1;  // harasser set
        g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
    }
    else
    {
        witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] = 1;  // harasser set
        g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
}

public void OnTakeDamagePost_Witch(int victim, int attacker, int inflictor, float damage, int damagetype)
{
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", victim);
    int witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    
    if (!g_hWitchTrie.GetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT))
    {
        for (int i = 0; i <= MAXPLAYERS; i++)
        {
            witch_dmg_array[i] = 0;
        }
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] = g_iWitchHealth;
        g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, false);
    }
    
    if (IS_VALID_SURVIVOR(attacker))
    {
        witch_dmg_array[attacker] += RoundToFloor(damage);
        witch_dmg_array[MAXPLAYERS+WTCH_HEALTH] -= RoundToFloor(damage);
        
        if (g_fWitchShotStart[attacker] == 0.0 || (GetGameTime() - g_fWitchShotStart[attacker]) > SHOTGUN_BLAST_TIME)
        {
            g_fWitchShotStart[attacker] = GetGameTime();
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNER] = attacker;
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] = 0;
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE] = (damagetype & DMG_BUCKSHOT) ? 1 : 0; // only allow shotguns
        }
        
        witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] += RoundToFloor(damage);
        
        g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
    else
    {
        witch_dmg_array[0] += RoundToFloor(damage);
        g_hWitchTrie.SetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT, true);
    }
}

public Action Timer_CheckWitchCrown(Handle timer, Handle pack)
{
    ResetPack(pack);
    int attacker = ReadPackCell(pack);
    int witch = ReadPackCell(pack);
    bool bOneShot = view_as<bool>(ReadPackCell(pack));
    CloseHandle(pack);

    CheckWitchCrown(witch, attacker, bOneShot);
}

void CheckWitchCrown(int witch, int attacker, bool bOneShot = false)
{
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", witch);
    int witch_dmg_array[MAXPLAYERS+DMGARRAYEXT];
    if (!g_hWitchTrie.GetArray(witch_key, witch_dmg_array, MAXPLAYERS+DMGARRAYEXT))
	{
        PrintDebug("Witch Crown Check: Error: Trie entry missing (entity: %i, oneshot: %i)", witch, bOneShot);
        return;
    }
    
    int chipDamage = 0;
    int iWitchHealth = g_iWitchHealth;
    
    if (bOneShot)
    {
        witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE] = 1;
    }
    
    if (witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH] || !witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE])
    {
        PrintDebug("Witch Crown Check: Failed: bungled: %i / crowntype: %i (entity: %i)",
                witch_dmg_array[MAXPLAYERS+WTCH_GOTSLASH],
                witch_dmg_array[MAXPLAYERS+WTCH_CROWNTYPE],
                witch
           );
        PrintDebug("Witch Crown Check: Further details: attacker: %N, attacker dmg: %i, teamless dmg: %i",
                attacker,
                witch_dmg_array[attacker],
                witch_dmg_array[0]
           );
        return;
    }
    
    PrintDebug("Witch Crown Check: crown shot: %i, harrassed: %i (full health: %i / drawthresh: %i / oneshot %i)", 
            witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT],
            witch_dmg_array[MAXPLAYERS+WTCH_STARTLED],
            iWitchHealth,
            DRAW_CROWN_THRESH,
            bOneShot
       );
    
    if (!witch_dmg_array[MAXPLAYERS+WTCH_STARTLED] && (bOneShot || witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] >= iWitchHealth))
    {
		Call_StartForward(g_hForwardCrown);
		Call_PushCell(attacker);
		Call_PushCell(witch_dmg_array[attacker]);
		Call_Finish();
    }
    else if (witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT] >= DRAW_CROWN_THRESH)
    {
        for (int i = 0; i <= MAXPLAYERS; i++)
        {
            if (i == attacker)
			{
                chipDamage += witch_dmg_array[i] - witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT];
            }
			else
			{
                chipDamage += witch_dmg_array[i];
            }
        }
        
		Call_StartForward(g_hForwardDrawCrown);
		Call_PushCell(attacker);
		Call_PushCell(witch_dmg_array[MAXPLAYERS+WTCH_CROWNSHOT]);
		Call_PushCell(chipDamage);
		Call_Finish();
    }
}

public Action TraceAttack_Rock(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if (IS_VALID_SURVIVOR(attacker))
    {
        char rock_key[10];
        int rock_array[3];
        FormatEx(rock_key, sizeof(rock_key), "%x", victim);
        g_hRockTrie.GetArray(rock_key, rock_array, sizeof(rock_array));
        rock_array[rckDamage] += RoundToFloor(damage);
        rock_array[rckSkeeter] = attacker;
        g_hRockTrie.SetArray(rock_key, rock_array, sizeof(rock_array), true);
    }
}

public void OnTouch_Rock(int entity)
{
    char rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", entity);
    int rock_array[3];
    rock_array[rckDamage] = -1;
    g_hRockTrie.SetArray(rock_key, rock_array, sizeof(rock_array), true);
    
    SDKUnhook(entity, SDKHook_Touch, OnTouch_Rock);
}

public Action Event_TonguePullStopped(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int smoker = GetClientOfUserId(event.GetInt("smoker"));
    int reason = event.GetInt("release_type");
    
    if (!IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(smoker)) { return Plugin_Continue; }
    
    HandleClear(attacker, smoker, victim,
            L4D2Infected_Smoker,
            (g_fPinTime[smoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[smoker][1]) : -1.0,
            (GetGameTime() - g_fPinTime[smoker][0]),
            view_as<bool>(reason != CUT_SLASH && reason != CUT_KILL)
       );
    
    if (attacker != victim) return Plugin_Continue;
    
    if (reason == CUT_KILL)
    {
        g_bSmokerClearCheck[smoker] = true;
    }
    else if (g_bSmokerShoved[smoker])
    {
        HandleSmokerSelfClear(attacker, smoker, true);
    }
    else if (reason == CUT_SLASH) // note: can't trust this to actually BE a slash..
    {
        char weapon[32];
        GetClientWeapon(attacker, weapon, 32);
        
        if (StrEqual(weapon, "weapon_melee", false))
        {
			if (L4D2_IsValidClient(attacker) && L4D2_IsValidClient(smoker) && !IsFakeClient(smoker))
			{
				L4D2_CPrintToChatAll("{O}★★★ {G}%N {B}cut {G}%N{W}'s tongue", attacker, smoker);
			}
			else if (L4D2_IsValidClient(attacker))
			{
				L4D2_CPrintToChatAll("{O}★★ {G}%N {B}cut {W}smoker tongue", attacker);
			}
			
			Call_StartForward(g_hForwardTongueCut);
			Call_PushCell(attacker);
			Call_PushCell(smoker);
			Call_Finish();
        }
    }
    
    return Plugin_Continue;
}

public Action Event_TongueGrab(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    
    if (IS_VALID_INFECTED(attacker) && IS_VALID_SURVIVOR(victim))
    {
        g_bSmokerClearCheck[attacker] = false;
        g_bSmokerShoved[attacker] = false;
        g_iSmokerVictim[attacker] = victim;
        g_iSmokerVictimDamage[attacker] = 0;
        g_fPinTime[attacker][0] = GetGameTime();
        g_fPinTime[attacker][1] = 0.0;
    }
    
    return Plugin_Continue;
}

public Action Event_ChokeStart(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    
    if (g_fPinTime[attacker][0] == 0.0) { g_fPinTime[attacker][0] = GetGameTime(); }
    g_fPinTime[attacker][1] = GetGameTime();
}

public Action Event_ChokeStop(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("userid"));
    int victim = GetClientOfUserId(event.GetInt("victim"));
    int smoker = GetClientOfUserId(event.GetInt("smoker"));
    int reason = event.GetInt("release_type");
    
    if (!IS_VALID_SURVIVOR(attacker) || !IS_VALID_INFECTED(smoker)) { return; }
    
    HandleClear(attacker, smoker, victim,
            L4D2Infected_Smoker,
            (g_fPinTime[smoker][1] > 0.0) ? (GetGameTime() - g_fPinTime[smoker][1]) : -1.0,
            (GetGameTime() - g_fPinTime[smoker][0]),
            view_as<bool>(reason != CUT_SLASH && reason != CUT_KILL)
       );
}

public void Hook_CarAlarmStart(const char[] output, int caller, int activator, float delay)
{
    PrintDebug("calarm trigger: caller %i / activator %i / delay: %.2f", caller, activator, delay);
}
public Action Event_CarAlarmGoesOff(Event event, const char[] name, bool dontBroadcast)
{
    g_fLastCarAlarm = GetGameTime();
	if (g_iAlarmCarClient && L4D2_IsValidClient(g_iAlarmCarClient) && GetClientTeam(g_iAlarmCarClient) == 2)
	{
		L4D2_CPrintToChatAll("{B}[{W}Stats{B}] {G}%N {W}triggered an {G}Alarmed Car", g_iAlarmCarClient);
		g_iAlarmCarClient = 0;
	}
}

public Action OnTakeDamage_Car(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
    
    CreateTimer(0.01, Timer_CheckAlarm, victim, TIMER_FLAG_NO_MAPCHANGE);
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", victim);
    g_hCarTrie.SetValue(car_key, attacker);

    if (damagetype & DMG_BLAST)
    {
        if (IS_VALID_INFECTED(inflictor) && L4D2_GetInfectedClass(inflictor) == L4D2Infected_Boomer)
		{
            g_iLastCarAlarmReason[attacker] = CALARM_BOOMER;
            g_iLastCarAlarmBoomer = inflictor;
        }
		else
		{
            g_iLastCarAlarmReason[attacker] = CALARM_EXPLOSION;
        }
    }
    else if (damage == 0.0 && (damagetype & DMG_CLUB || damagetype & DMG_SLASH) && !(damagetype & DMG_SLOWBURN))
    {
        g_iLastCarAlarmReason[attacker] = CALARM_TOUCHED;
    }
    else
    {
        g_iLastCarAlarmReason[attacker] = CALARM_HIT;
    }
    
    return Plugin_Continue;
}

public void OnTouch_Car(int entity, int client)
{
    if (!IS_VALID_SURVIVOR(client)) return;
    
    CreateTimer(0.01, Timer_CheckAlarm, entity, TIMER_FLAG_NO_MAPCHANGE);
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", entity);
    g_hCarTrie.SetValue(car_key, client);
    
    g_iLastCarAlarmReason[client] = CALARM_TOUCHED;
}

public Action OnTakeDamage_CarGlass(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
    if (!IS_VALID_SURVIVOR(attacker)) return Plugin_Continue;
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", victim);
    int parentEntity;
    
    if (g_hCarTrie.GetValue(car_key, parentEntity))
    {
        CreateTimer(0.01, Timer_CheckAlarm, parentEntity, TIMER_FLAG_NO_MAPCHANGE);
        
        FormatEx(car_key, sizeof(car_key), "%x", parentEntity);
        g_hCarTrie.SetValue(car_key, attacker);
        
        if (damagetype & DMG_BLAST)
        {
            if (IS_VALID_INFECTED(inflictor) && L4D2_GetInfectedClass(inflictor) == L4D2Infected_Boomer)
			{
                g_iLastCarAlarmReason[attacker] = CALARM_BOOMER;
                g_iLastCarAlarmBoomer = inflictor;
            }
			else
			{
                g_iLastCarAlarmReason[attacker] = CALARM_EXPLOSION;
            }
        }
        else if (damage == 0.0 && (damagetype & DMG_CLUB || damagetype & DMG_SLASH) && !(damagetype & DMG_SLOWBURN))
        {
            g_iLastCarAlarmReason[attacker] = CALARM_TOUCHED;
        }
        else
        {
            g_iLastCarAlarmReason[attacker] = CALARM_HIT;
        }
    }
    
    return Plugin_Continue;
}

public void OnTouch_CarGlass(int entity, int client)
{
    if (!IS_VALID_SURVIVOR(client)) return;
    
    char car_key[10];
    FormatEx(car_key, sizeof(car_key), "%x", entity);
    int parentEntity;
    
    if (g_hCarTrie.GetValue(car_key, parentEntity))
    {
        CreateTimer(0.01, Timer_CheckAlarm, parentEntity, TIMER_FLAG_NO_MAPCHANGE);
        
        FormatEx(car_key, sizeof(car_key), "%x", parentEntity);
        g_hCarTrie.SetValue(car_key, client);
        
        g_iLastCarAlarmReason[client] = CALARM_TOUCHED;
    }
}

public Action Timer_CheckAlarm(Handle timer, any entity)
{
    if ((GetGameTime() - g_fLastCarAlarm) < CARALARM_MIN_TIME)
    {
        char car_key[10];
        int testEntity;
        int survivor = -1;
        
        FormatEx(car_key, sizeof(car_key), "%x_A", entity);
        if (g_hCarTrie.GetValue(car_key, testEntity))
        {
            g_hCarTrie.Remove(car_key);
            SDKUnhook(testEntity, SDKHook_OnTakeDamage, OnTakeDamage_CarGlass);
            SDKUnhook(testEntity, SDKHook_Touch, OnTouch_CarGlass);
        }
        FormatEx(car_key, sizeof(car_key), "%x_B", entity);
        if (g_hCarTrie.GetValue(car_key, testEntity))
        {
            g_hCarTrie.Remove(car_key);
            SDKUnhook(testEntity, SDKHook_OnTakeDamage, OnTakeDamage_CarGlass);
            SDKUnhook(testEntity, SDKHook_Touch, OnTouch_CarGlass);
        }
        
        FormatEx(car_key, sizeof(car_key), "%x", entity);
        if (g_hCarTrie.GetValue(car_key, survivor))
        {
            g_hCarTrie.Remove(car_key);
            SDKUnhook(entity, SDKHook_OnTakeDamage, OnTakeDamage_Car);
            SDKUnhook(entity, SDKHook_Touch, OnTouch_Car);
        }
        
        int infected = 0;
        if (IS_VALID_SURVIVOR(survivor))
        {
            if (g_iLastCarAlarmReason[survivor] == CALARM_BOOMER)
            {
                infected = g_iLastCarAlarmBoomer;
            }
            else if (IS_VALID_INFECTED(GetEntPropEnt(survivor, Prop_Send, "m_carryAttacker")))
            {
                infected = GetEntPropEnt(survivor, Prop_Send, "m_carryAttacker");
            }
            else if (IS_VALID_INFECTED(GetEntPropEnt(survivor, Prop_Send, "m_jockeyAttacker")))
            {
                infected = GetEntPropEnt(survivor, Prop_Send, "m_jockeyAttacker");
            }
            else if (IS_VALID_INFECTED(GetEntPropEnt(survivor, Prop_Send, "m_tongueOwner")))
            {
                infected = GetEntPropEnt(survivor, Prop_Send, "m_tongueOwner");
            }
        }

		Call_StartForward(g_hForwardAlarmTriggered);
		Call_PushCell(survivor);
		Call_PushCell(infected);
		Call_PushCell(L4D2_IsValidClient(survivor) ? g_iLastCarAlarmReason[survivor] : CALARM_UNKNOWN);
		Call_Finish();
    }
}

public int ClientValue2DSortDesc(int[] x, int[] y, const int[][] array, Handle data)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

/*
    Reporting and forwards
    ----------------------
*/


void HandleSkeet(int attacker, int victim, bool bMelee = false, bool bSniper = false, bool bGL = false)
{
    if (bSniper)
    {
        Call_StartForward(g_hForwardSkeetSniper);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    else if (bGL)
    {
        Call_StartForward(g_hForwardSkeetGL);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    else if (bMelee)
    {
        Call_StartForward(g_hForwardSkeetMelee);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
    else
    {
        Call_StartForward(g_hForwardSkeet);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_Finish();
    }
}

void HandleNonSkeet(int attacker, int victim, int damage, bool bOverKill = false, bool bMelee = false, bool bSniper = false)
{
    if (bSniper)
    {
        Call_StartForward(g_hForwardSkeetSniperHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
    else if (bMelee)
    {
        Call_StartForward(g_hForwardSkeetMeleeHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
    else
    {
        Call_StartForward(g_hForwardSkeetHurt);
        Call_PushCell(attacker);
        Call_PushCell(victim);
        Call_PushCell(damage);
        Call_PushCell(bOverKill);
        Call_Finish();
    }
}

void HandleSmokerSelfClear(int attacker, int victim, bool withShove = false)
{
    if (L4D2_IsValidClient(attacker) && L4D2_IsValidClient(victim) && !IsFakeClient(victim))
    {
        L4D2_CPrintToChatAll("{O}★★ {G}%N {B}self-cleared {W}from {G}%N{W}'s tongue{B}%s", attacker, victim, (withShove) ? " by shoving" : "");
    }
    else if (L4D2_IsValidClient(attacker))
    {
        L4D2_CPrintToChatAll("{O}★★ {G}%N {B}self-cleared {W}from a smoker tongue{B}%s", attacker, (withShove) ? " by shoving" : "");
    }
    
    Call_StartForward(g_hForwardSmokerSelfClear);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushCell(withShove);
    Call_Finish();
}

void HandleClear(int attacker, int victim, int pinVictim, L4D2_Infected zombieClass, float clearTimeA, float clearTimeB, bool bWithShove = false)
{
    if (clearTimeA < 0 && clearTimeA != -1.0) { clearTimeA = 0.0; }
    if (clearTimeB < 0 && clearTimeB != -1.0) { clearTimeB = 0.0; }
    
	char sBuffer[16];
	L4D2_GetInfectedClassName(zombieClass, sBuffer, 16);
    PrintDebug("Clear: %i freed %i from %i: time: %.2f / %.2f -- class: %s (with shove? %i)", attacker, pinVictim, victim, clearTimeA, clearTimeB, sBuffer, bWithShove);
    
    if (attacker != pinVictim)
    {
        float fMinTime = INSTA_TIME;
        float fClearTime = clearTimeA;
        if (zombieClass == L4D2Infected_Charger || zombieClass == L4D2Infected_Smoker) { fClearTime = clearTimeB; }
        
        if (fClearTime != -1.0 && fClearTime <= fMinTime)
        {
            if (L4D2_IsValidClient(attacker) && L4D2_IsValidClient(victim) && !IsFakeClient(victim))
            {
                if (L4D2_IsValidClient(pinVictim))
                {
                    L4D2_CPrintToChatAll("{O}★ {G}%N {B}insta-cleared {G}%N {W}from {G}%N{W}'s %s ({B}%.2f {W}seconds)",
                            attacker, pinVictim, victim,
                            sBuffer,
                            fClearTime
                       );
                }
				else
				{
                    L4D2_CPrintToChatAll("{O}★ {G}%N {B}insta-cleared {G}a teammate {W}from {G}%N{W}'s %s ({B}%.2f {W}seconds)",
                            attacker, victim,
                            sBuffer,
                            fClearTime
                       );
                }
            }
            else if (L4D2_IsValidClient(attacker))
            {
                if (L4D2_IsValidClient(pinVictim))
                {
                    L4D2_CPrintToChatAll("{O}★ {G}%N {B}insta-cleared {G}%N {W}from a %s ({B}%.2f {W}seconds)",
                            attacker, pinVictim,
                            sBuffer,
                            fClearTime
                       );
                }
				else
				{
                    L4D2_CPrintToChatAll("{O}★ {G}%N {B}insta-cleared {G}a teammate {W}from a %s ({B}%.2f {W}seconds)",
                            attacker,
                            sBuffer,
                            fClearTime
                       );
                }
            }
        }
    }
    
    Call_StartForward(g_hForwardClear);
    Call_PushCell(attacker);
    Call_PushCell(victim);
    Call_PushCell(pinVictim);
    Call_PushCell(zombieClass);
    Call_PushFloat(clearTimeA);
    Call_PushFloat(clearTimeB);
    Call_PushCell((bWithShove) ? 1 : 0);
    Call_Finish();
}

void HandleBHopStreak(int survivor, int streak, float maxVelocity)
{
    if (L4D2_IsValidClient(survivor) && !IsFakeClient(survivor) && streak >= BHOP_MIN_STREAK)
	{
        L4D2_CPrintToChat(survivor, "{O}★ {G}You {W}got {B}%i bunnyhop%s {W}in a row ({B}top speed: {G}%.1f{W})",
                streak,
                (streak > 1) ? "s" : "",
                maxVelocity
           );
    }
    
    Call_StartForward(g_hForwardBHopStreak);
    Call_PushCell(survivor);
    Call_PushCell(streak);
    Call_PushFloat(maxVelocity);
    Call_Finish();
}


// support
// -------

int ShiftTankThrower()
{
    int tank = -1;
    
    if (!g_iRocksBeingThrownCount) return -1;
    
    tank = g_iRocksBeingThrown[0];
    
    if (g_iRocksBeingThrownCount > 1)
    {
        for (int x = 1; x <= g_iRocksBeingThrownCount; x++)
        {
            g_iRocksBeingThrown[x-1] = g_iRocksBeingThrown[x];
        }
    }
    
    g_iRocksBeingThrownCount--;
    
    return tank;
}

void PrintDebug(const char[] Message, any ...)
{
    char DebugBuff[256];
    VFormat(DebugBuff, sizeof(DebugBuff), Message, 3);
    LogMessage(DebugBuff);
}

bool IsWitch(int entity)
{
    if (!IsValidEntity(entity)) return false;
    
    char classname[24];
    strOEC classnameOEC;
    GetEdictClassname(entity, classname, sizeof(classname));
    if (!g_hTrieEntityCreated.GetValue(classname, classnameOEC) || classnameOEC != OEC_WITCH) return false;
    
    return true;
}

void ClearDamage(int client)
{
	g_iLastHealth[client] = 0;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}
