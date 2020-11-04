#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <colors>

#define PLUGIN_VERSION "0.9.19"

#define MIN_DC_TRIGGER_DMG      300
#define MIN_DC_FALL_DMG         175
#define WEIRD_FLOW_THRESH       900.0
#define MIN_FLOWDROPHEIGHT      350.0
#define MIN_DC_RECHECK_DMG      100

#define CUT_KILL        3
#define CUT_SLASH       4

#define VICFLG_CARRIED          (1 << 0)
#define VICFLG_FALL             (1 << 1)
#define VICFLG_DROWN            (1 << 2)
#define VICFLG_HURTLOTS         (1 << 3)
#define VICFLG_TRIGGER          (1 << 4)
#define VICFLG_AIRDEATH         (1 << 5)
#define VICFLG_KILLEDBYOTHER    (1 << 6)
#define VICFLG_WEIRDFLOW        (1 << 7)
#define VICFLG_WEIRDFLOWDONE    (1 << 8)

enum strWeaponType
{
    WPTYPE_SNIPER,
    WPTYPE_MAGNUM,
    WPTYPE_GL
};

enum strAbility
{
    ABL_HUNTERLUNGE,
    ABL_ROCKTHROW
};

enum strRockData
{
    rckDamage,
    rckTank,
    rckSkeeter
};

enum enAlarmReasons
{
    CALARM_UNKNOWN,
    CALARM_HIT,
    CALARM_TOUCHED,
    CALARM_EXPLOSION,
    CALARM_BOOMER
};

Handle g_hTrieWeapons;
Handle g_hTrieEntityCreated;
Handle g_hTrieAbility;
Handle g_hRockTrie;

float g_fSpawnTime[MAXPLAYERS + 1];
float g_fPinTime[MAXPLAYERS + 1][2];
int g_iSpecialVictim[MAXPLAYERS + 1];

int OEC_TANKROCK;
int g_iHunterShotDmgTeam[MAXPLAYERS + 1];
int g_iHunterShotDmg[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fHunterShotStart[MAXPLAYERS + 1][MAXPLAYERS + 1];
float g_fHunterTracePouncing[MAXPLAYERS + 1];
float g_fHunterLastShot[MAXPLAYERS + 1];
int g_iHunterLastHealth[MAXPLAYERS + 1];
int g_iHunterOverkill[MAXPLAYERS + 1];
bool g_bHunterKilledPouncing[MAXPLAYERS + 1];
int g_iPounceDamage[MAXPLAYERS + 1];
float g_fPouncePosition[MAXPLAYERS + 1][3];

int g_iChargerHealth[MAXPLAYERS + 1];
float g_fChargeTime[MAXPLAYERS + 1];
int g_iChargeVictim[MAXPLAYERS + 1];
float g_fChargeVictimPos[MAXPLAYERS + 1][3];
int g_iVictimCharger[MAXPLAYERS + 1];
int g_iVictimFlags[MAXPLAYERS + 1];
int g_iVictimMapDmg[MAXPLAYERS + 1];

int g_iTankRock[MAXPLAYERS + 1];
int g_iRocksBeingThrown[10];
int g_iRocksBeingThrownCount = 0;
int g_iAlarmCarClient;

bool g_bIsHopping[MAXPLAYERS + 1];
bool g_bHopCheck[MAXPLAYERS + 1];
int g_iHops[MAXPLAYERS + 1];
float g_fLastHop[MAXPLAYERS + 1][3];
float g_fHopTopVelocity[MAXPLAYERS + 1];

Handle g_hCvarPounceInterrupt;
int g_iPounceInterrupt;
Handle g_hCvarChargerHealth;
Handle g_hCvarMaxPounceDistance;
Handle g_hCvarMinPounceDistance;
Handle g_hCvarMaxPounceDamage;

int g_iSurvivorLimit;
int g_iBoomerClient;
int g_iBoomerKiller;
int g_iBoomerShover;
int g_iLastHealth[MAXPLAYERS + 1];
int g_iDamageDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];
int g_iShotsDealt[MAXPLAYERS + 1][MAXPLAYERS + 1];

bool g_bHasRoundEnded;
bool g_bHasBoomLanded;
bool g_bIsPouncing[MAXPLAYERS + 1];
bool g_bShotCounted[MAXPLAYERS + 1][MAXPLAYERS +1];

Handle g_hBoomerShoveTimer;
Handle g_hBoomerKillTimer;
float BoomerKillTime;
char Boomer[32];

public Plugin myinfo = 
{
    name = "Skill Detection (skeets, crowns, levels)",
    author = "Tabun",
    description = "Detects and reports skeets, crowns, levels, highpounces, etc.",
    version = PLUGIN_VERSION,
    url = "https://github.com/Tabbernaut/L4D2-Plugins"
}

public void OnPluginStart()
{
    HookEvent("player_spawn",               Event_PlayerSpawn,              EventHookMode_Post);
    HookEvent("player_death",               Event_PlayerDeath,              EventHookMode_Pre);
    HookEvent("ability_use",                Event_AbilityUse,               EventHookMode_Post);
    HookEvent("lunge_pounce",               Event_LungePounce,              EventHookMode_Post);
    HookEvent("player_jump",                Event_PlayerJumped,             EventHookMode_Post);
    HookEvent("player_jump_apex",           Event_PlayerJumpApex,           EventHookMode_Post);
    HookEvent("weapon_fire", Event_WeaponFire);
	HookEvent("player_shoved", Event_PlayerShoved);
	HookEvent("player_now_it", Event_PlayerBoomed);
	HookEvent("create_panic_event", Event_Panic);
	
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
    HookEvent("triggered_car_alarm", Event_AlarmCar);
    
    CreateConVar( "sm_skill_detect_version", PLUGIN_VERSION, "Skill detect plugin version.", FCVAR_SS_ADDED|FCVAR_NOTIFY|FCVAR_REPLICATED|FCVAR_DONTRECORD );
    
	g_iSurvivorLimit = GetConVarInt(FindConVar("survivor_limit"));
    g_hCvarPounceInterrupt = FindConVar("z_pounce_damage_interrupt");
    HookConVarChange(g_hCvarPounceInterrupt, CvarChange_PounceInterrupt);
    g_iPounceInterrupt = GetConVarInt(g_hCvarPounceInterrupt);
    
    g_hCvarChargerHealth = FindConVar("z_charger_health");
    
    g_hCvarMaxPounceDistance = FindConVar("z_pounce_damage_range_max");
    g_hCvarMinPounceDistance = FindConVar("z_pounce_damage_range_min");
    g_hCvarMaxPounceDamage = FindConVar("z_hunter_max_pounce_bonus_damage");
    if ( g_hCvarMaxPounceDistance == INVALID_HANDLE ) { g_hCvarMaxPounceDistance = CreateConVar( "z_pounce_damage_range_max",  "1000.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_SS_ADDED, true, 0.0, false ); }
    if ( g_hCvarMinPounceDistance == INVALID_HANDLE ) { g_hCvarMinPounceDistance = CreateConVar( "z_pounce_damage_range_min",  "300.0", "Not available on this server, added by l4d2_skill_detect.", FCVAR_SS_ADDED, true, 0.0, false ); }
    if ( g_hCvarMaxPounceDamage == INVALID_HANDLE ) { g_hCvarMaxPounceDamage = CreateConVar( "z_hunter_max_pounce_bonus_damage",  "49", "Not available on this server, added by l4d2_skill_detect.", FCVAR_SS_ADDED, true, 0.0, false ); }
	
    g_hTrieWeapons = CreateTrie();
    SetTrieValue(g_hTrieWeapons, "hunting_rifle",               WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_military",             WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_awp",                  WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "sniper_scout",                WPTYPE_SNIPER);
    SetTrieValue(g_hTrieWeapons, "pistol_magnum",               WPTYPE_MAGNUM);
    SetTrieValue(g_hTrieWeapons, "grenade_launcher_projectile", WPTYPE_GL);
    
    g_hTrieEntityCreated = CreateTrie();
    SetTrieValue(g_hTrieEntityCreated, "tank_rock",             OEC_TANKROCK);
    
    g_hTrieAbility = CreateTrie();
    SetTrieValue(g_hTrieAbility, "ability_lunge",               ABL_HUNTERLUNGE);
    SetTrieValue(g_hTrieAbility, "ability_throw",               ABL_ROCKTHROW);
    
    g_hRockTrie = CreateTrie();
}

public int CvarChange_PounceInterrupt( Handle convar, const char[] oldValue, const char[] newValue )
{
    g_iPounceInterrupt = GetConVarInt(convar);
}

/*
    Tracking
    --------
*/
public void OnMapStart()
{
	g_bHasRoundEnded = false;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		ClearDamage(i);
	}
	g_iAlarmCarClient = 0;
}

public void L4D2_OnRealRoundStart()
{
    g_iRocksBeingThrownCount = 0;
    
    for ( int i = 1; i <= MAXPLAYERS; i++ )
    {
        g_bIsHopping[i] = false;
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
	if (g_bHasRoundEnded) return;
	g_bHasRoundEnded = true;
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		ClearDamage(i);
	}
}

public void L4D2_OnPlayerHurtPre(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype, int hitgroup)
{
    int zClass;
    
    if ( IsValidInfected(victim) )
    {
        zClass = GetInfectedClass(victim);
        
        if ( damage < 1 ) { return; }
        
        switch ( zClass )
        {
            case ZC_HUNTER:
            {
                if ( !IsValidSurvivor(attacker) )
                {
                    g_iHunterLastHealth[victim] = health;
                    return;
                }
                
                if ( g_iHunterLastHealth[victim] > 0 && damage > g_iHunterLastHealth[victim] )
                {
                    damage = g_iHunterLastHealth[victim];
                    g_iHunterOverkill[victim] = g_iHunterLastHealth[victim] - damage;
                    g_iHunterLastHealth[victim] = 0;
                }
                
                if ( g_iHunterShotDmg[victim][attacker] > 0 && (GetGameTime() - g_fHunterShotStart[victim][attacker]) > 0.1 )
                {
                    g_fHunterShotStart[victim][attacker] = 0.0;
                }
                
                bool isPouncing = (
                        GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce")     ||
                        g_fHunterTracePouncing[victim] != 0.0 && ( GetGameTime() - g_fHunterTracePouncing[victim] ) < 0.001
                    );
                
                if ( isPouncing )
                {
                    if ( dmgtype & DMG_BUCKSHOT )
                    {
                        if ( g_fHunterShotStart[victim][attacker] == 0.0 )
                        {
                            g_fHunterShotStart[victim][attacker] = GetGameTime();
                            g_fHunterLastShot[victim] = g_fHunterShotStart[victim][attacker];
                        }
                        g_iHunterShotDmg[victim][attacker] += damage;
                        g_iHunterShotDmgTeam[victim] += damage;
                        
                        if ( health == 0 ) {
                            g_bHunterKilledPouncing[victim] = true;
                        }
                    }
                    else if ( dmgtype & (DMG_BLAST | DMG_PLASMA) && health == 0 )
                    {
                        strWeaponType  weaponTypeB;
                        
                        if ( GetTrieValue(g_hTrieWeapons, Weapon, weaponTypeB) && weaponTypeB == WPTYPE_GL )
                        {
                            HandleSkeet( attacker, victim, false );
                        }
                    }
                    else if (   dmgtype & DMG_BULLET &&
                                health == 0 &&
                                hitgroup == 1
                    ) {
                        strWeaponType  weaponTypeA;
                        
                        if (    GetTrieValue(g_hTrieWeapons, Weapon, weaponTypeA) &&
                                (   weaponTypeA == WPTYPE_SNIPER ||
                                    weaponTypeA == WPTYPE_MAGNUM )
                        ) {
                            if ( damage >= g_iPounceInterrupt )
                            {
                                g_iHunterShotDmgTeam[victim] = 0;
                                HandleSkeet( attacker, victim, false );
                                ResetHunter(victim);
                            }
                            else
                            {
                                HandleNonSkeet( victim, damage, ( g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt ) );
                                ResetHunter(victim);
                            }
                        }
                    }
                    else if ( dmgtype & DMG_SLASH || dmgtype & DMG_CLUB )
                    {
                        if ( damage >= g_iPounceInterrupt )
                        {
                            g_iHunterShotDmgTeam[victim] = 0;
							HandleSkeet( attacker, victim, true );
                            ResetHunter(victim);
                        }
                        else if ( health == 0 )
                        {
                            HandleNonSkeet( victim, damage, true );
                            ResetHunter(victim);
                        }
                    }
                }
                else if ( health == 0 )
                {
                    g_bHunterKilledPouncing[victim] = false;
                }
                
                g_iHunterLastHealth[victim] = health;
            }
            
            case ZC_CHARGER:
            {
                if ( IsValidSurvivor(attacker) )
                {                
                    if ( health == 0 && ( dmgtype & DMG_CLUB || dmgtype & DMG_SLASH ) )
                    {
                        int iChargeHealth = GetConVarInt(g_hCvarChargerHealth);
                        int abilityEnt = GetEntPropEnt( victim, Prop_Send, "m_customAbility" );
                        if ( IsValidEntity(abilityEnt) && GetEntProp(abilityEnt, Prop_Send, "m_isCharging") )
                        {
                            if ( damage > (iChargeHealth * 0.65) ) {
                                HandleLevel( attacker, victim );
                            }
                            else {
                                HandleLevelHurt( attacker, victim, damage );
                            }
                        }
                    }
                }
                
                if ( health > 0 )
                {
                    g_iChargerHealth[victim] = health;
                }
            }
        }
    }
    else if ( IsValidInfected(attacker) )
    {
        zClass = GetInfectedClass(attacker);
        
        switch ( zClass )
        {
            case ZC_HUNTER:
            {
                if ( dmgtype & DMG_CRUSH ) {
                    g_iPounceDamage[attacker] = damage;
                }
            }
            
            case ZC_TANK:
            {
                if ( StrEqual(Weapon, "tank_rock") )
                {
                    if ( g_iTankRock[attacker] )
                    {
                        char rock_key[10];
                        FormatEx(rock_key, sizeof(rock_key), "%x", g_iTankRock[attacker]);
                        int rock_array[3];
                        rock_array[rckDamage] = -1;
                        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
                    }
                }
                
                return;
            }
        }
    }
    
    if ( IsValidSurvivor(victim) )
    {
        if ( dmgtype & DMG_DROWN || dmgtype & DMG_FALL ) {
            g_iVictimMapDmg[victim] += damage;
        }
        
        if ( dmgtype & DMG_DROWN && damage >= MIN_DC_TRIGGER_DMG )
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_HURTLOTS;
        }
        else if ( dmgtype & DMG_FALL && damage >= MIN_DC_FALL_DMG )
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_HURTLOTS;
        }
    }
}

public void L4D2_OnPlayerHurtPost(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype, int hitgroup)
{
	if (g_bHasRoundEnded) return;

	if (IsValidSurvivor(attacker) && IsValidInfected(victim))
	{
		int zombieclass = GetInfectedClass(victim);
		if (zombieclass == ZC_TANK) return;

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

public Action Event_WeaponFire(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		g_bShotCounted[i][client] = false;
	}
}

public Action Event_PlayerShoved(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHasRoundEnded) return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidInfected(victim)) return;

	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSurvivor(attacker)) return;

	int zombieclass = GetInfectedClass(victim);
	if (zombieclass == ZC_BOOMER)
	{
		if (g_hBoomerShoveTimer != INVALID_HANDLE)
		{
			KillTimer(g_hBoomerShoveTimer);
			if (!g_iBoomerShover || !IsValidInGame(g_iBoomerShover)) g_iBoomerShover = attacker;
		}
		else
		{
			g_iBoomerShover = attacker;
		}
		g_hBoomerShoveTimer = CreateTimer(4.0, Timer_BoomerShove);
	}
}

public Action Timer_BoomerShove(Handle timer)
{
	g_hBoomerShoveTimer = INVALID_HANDLE;
	g_iBoomerShover = 0;
}

public Action Event_PlayerBoomed(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bHasBoomLanded) return;
	g_bHasBoomLanded = true;
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

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidInfected(client)) return;
    
    int zClass = GetInfectedClass(client);
    
    g_fSpawnTime[client] = GetGameTime();
    g_fPinTime[client][0] = 0.0;
    g_fPinTime[client][1] = 0.0;
    
    switch ( zClass )
    {
        case ZC_HUNTER:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Hunter);
    
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case ZC_JOCKEY:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Jockey);
            
            g_fPouncePosition[client][0] = 0.0;
            g_fPouncePosition[client][1] = 0.0;
            g_fPouncePosition[client][2] = 0.0;
        }
        case ZC_CHARGER:
        {
            SDKHook(client, SDKHook_TraceAttack, TraceAttack_Charger);
            
            g_iChargerHealth[client] = GetConVarInt(g_hCvarChargerHealth);
        }
		case ZC_BOOMER:
		{
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
    }
	
	if (zClass == ZC_TANK) return;
	
	g_iLastHealth[client] = GetClientHealth(client);
}

public Action Timer_KillBoomer(Handle timer)
{
	BoomerKillTime += 0.1;
}

// player about to get incapped
public Action Event_IncapStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    int attackent = event.GetInt("attackerentid");
    int dmgtype = event.GetInt("type");
    
    char  classname[24];
    int  classnameOEC;
    if ( IsValidEntity(attackent) ) {
        GetEdictClassname(attackent, classname, sizeof(classname));
        if ( GetTrieValue(g_hTrieEntityCreated, classname, classnameOEC)) {
            g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_TRIGGER;
        }
    }
    
    float  flow = GetSurvivorDistance(client);
    
    if ( dmgtype & DMG_DROWN )
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_DROWN;
    }
    if ( flow < WEIRD_FLOW_THRESH )
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_WEIRDFLOW;
    }
}

// trace attacks on hunters
public Action TraceAttack_Hunter (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_pounceVictim");
    
    if ( !IsValidSurvivor(attacker) || !IsValidEdict(inflictor) ) { return; }
    
    if ( GetEntProp(victim, Prop_Send, "m_isAttemptingToPounce") )
    {
        g_fHunterTracePouncing[victim] = GetGameTime();
    }
    else
    {
        g_fHunterTracePouncing[victim] = 0.0;
    }   
}
public Action TraceAttack_Charger (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    int victimA = GetEntPropEnt(victim, Prop_Send, "m_carryVictim");
    if ( victimA != -1 ) {
        g_iSpecialVictim[victim] = victimA;
    } else {
        g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_pummelVictim");
    }
    
}
public Action TraceAttack_Jockey (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    g_iSpecialVictim[victim] = GetEntPropEnt(victim, Prop_Send, "m_jockeyVictim");
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId( event.GetInt("userid") );
    int attacker = GetClientOfUserId( event.GetInt("attacker") ); 
	
    if ( IsValidInfected(victim) )
    {
        int zClass = GetInfectedClass(victim);
        
        switch ( zClass )
        {
            case ZC_HUNTER:
            {
                if (IsValidSurvivor(attacker))
                {
					if ( g_iHunterShotDmgTeam[victim] > 0 && g_bHunterKilledPouncing[victim] )
					{
						if (    g_iHunterShotDmgTeam[victim] > g_iHunterShotDmg[victim][attacker] &&
								g_iHunterShotDmgTeam[victim] >= g_iPounceInterrupt
						) {
							//HandleSkeet( -2, victim );
						}
						else if ( g_iHunterShotDmg[victim][attacker] >= g_iPounceInterrupt )
						{
							//HandleSkeet( attacker, victim );
						}
						else if ( g_iHunterOverkill[victim] > 0 )
						{
							HandleNonSkeet( victim, g_iHunterShotDmgTeam[victim], ( g_iHunterOverkill[victim] + g_iHunterShotDmgTeam[victim] > g_iPounceInterrupt ) );
						}
						else
						{
							HandleNonSkeet( victim, g_iHunterShotDmg[victim][attacker] );
						}
					}
					else {
						if ( g_iSpecialVictim[victim] > 0 )
						{
							HandleClear( attacker, victim, g_iSpecialVictim[victim],
									ZC_HUNTER,
									( GetGameTime() - g_fPinTime[victim][0]),
									-1.0
								);
						}
					}
					
					ResetHunter(victim);
				}
            }
            
            case ZC_JOCKEY:
            {
                if ( g_iSpecialVictim[victim] > 0 )
                {
                    HandleClear( attacker, victim, g_iSpecialVictim[victim],
                            ZC_JOCKEY,
                            ( GetGameTime() - g_fPinTime[victim][0]),
                            -1.0
                        );
                }
            }
            
            case ZC_CHARGER:
            {
                if ( IsValidInGame(g_iChargeVictim[victim]) ) {
                    g_fChargeTime[ g_iChargeVictim[victim] ] = GetGameTime();
                }
                
                if ( g_iSpecialVictim[victim] > 0 )
                {
                    HandleClear( attacker, victim, g_iSpecialVictim[victim],
                            ZC_CHARGER,
                            (g_fPinTime[victim][1] > 0.0) ? ( GetGameTime() - g_fPinTime[victim][1]) : -1.0,
                            ( GetGameTime() - g_fPinTime[victim][0])
                        );
                }
            }
        }
    }
    else if ( IsValidSurvivor(victim) )
    {
        int dmgtype = event.GetInt("type"); 
        
        
        if ( dmgtype & DMG_FALL)
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_FALL;
        }
        else if ( IsValidInfected(attacker) && attacker != g_iVictimCharger[victim] )
        {
            g_iVictimFlags[victim] = g_iVictimFlags[victim] | VICFLG_KILLEDBYOTHER;
        }
    }
    
	if (g_bHasRoundEnded) return;

	if (!IsValidInGame(attacker))
	{
		if (IsValidInfected(victim)) ClearDamage(victim);
		return;
	}

	if (IsValidSurvivor(attacker) && IsValidInfected(victim))
	{
		int zombieclass = GetInfectedClass(victim);
		if (zombieclass == ZC_TANK) return;

		int lasthealth = g_iLastHealth[victim];
		g_iDamageDealt[victim][attacker] += lasthealth;

		if (zombieclass == ZC_BOOMER)
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
		else if (zombieclass == ZC_HUNTER && g_bIsPouncing[victim])
		{
			int[][] assisters = new int[g_iSurvivorLimit][2];
			int assister_count;
			int damage = g_iDamageDealt[victim][attacker];
			int shots = g_iShotsDealt[victim][attacker];
			char plural[1] = "s";
			if (shots == 1) plural[0] = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (i == attacker) continue;
				if (g_iDamageDealt[victim][i] > 0 && IsConnectedAndInGame(i))
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
				CPrintToChatAll("{O}★{W} {G}%N {W}was {B}近战{W}-{B}skeeted {W}by {G}%N", victim, attacker);
			}
			else if (assister_count)
			{
				SortCustom2D(assisters, assister_count, ClientValue2DSortDesc);
				char assister_string[128];
				char buf[MAX_NAME_LENGTH + 8];
				int assist_shots = g_iShotsDealt[victim][assisters[0][0]];
				
				Format(assister_string, sizeof(assister_string), "%N (%d/%d 发%s)",
				assisters[0][0],
				assisters[0][1],
				g_iShotsDealt[victim][assisters[0][0]],
				assist_shots == 1 ? "":"s");
				for (int i = 1; i < assister_count; i++)
				{
					assist_shots = g_iShotsDealt[victim][assisters[i][0]];
					Format(buf, sizeof(buf), ", %N (%d/%d 发%s)",
					assisters[i][0],
					assisters[i][1],
					assist_shots,
					assist_shots == 1 ? "":"s");
					StrCat(assister_string, sizeof(assister_string), buf);
				}

				CPrintToChatAll("{O}★{W} {G}%N {W}teamskeeted {G}%N {W}for {B}%d 伤害 {W}in {B}%d 发%s{W}. 协力者: {G}%s",
				attacker, victim, damage, shots, plural, assister_string);
			}
			else
			{
				CPrintToChatAll("{O}★{W} {G}%N {W}skeeted {G}%N {W}in {B}%d 发%s", attacker, victim, shots, plural);
			}
		}
	}
	if (IsValidInfected(victim)) ClearDamage(victim);
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

	if (IsValidInGame(g_iBoomerKiller))
	{
		if (IsValidInGame(g_iBoomerClient))
		{
			if (g_iBoomerShover != 0 && IsValidInGame(g_iBoomerShover))
			{	
				if (g_iBoomerShover == g_iBoomerKiller)
				{
					CPrintToChatAll("{O}★{W} {G}%N {W}shoved and popped {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerKiller, Boomer, BoomerKillTime);
				}
				else
				{
					CPrintToChatAll("{O}★{W} {G}%N {W}shoved and {G}%N {W}popped {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerShover, g_iBoomerKiller, Boomer, BoomerKillTime);
				}
			}
			else
			{
				CPrintToChatAll("{O}★{W} {G}%N {W}has shutdown {G}%s{W}'s Boomer in {B}%0.1fs", g_iBoomerKiller, Boomer, BoomerKillTime);
			}
		}
	}

	g_iBoomerClient = 0;
	BoomerKillTime = 0.0;
}

void ClearDamage(int client)
{
	g_iLastHealth[client] = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iDamageDealt[client][i] = 0;
		g_iShotsDealt[client][i] = 0;
	}
}

public int ClientValue2DSortDesc(int[] x, int[] y, const int[][] array, Handle data)
{
	if (x[1] > y[1]) return -1;
	else if (x[1] < y[1]) return 1;
	else return 0;
}

bool IsGrounded(int client)
{
	return view_as<bool>(GetEntityFlags(client) & FL_ONGROUND);
}

public Action Event_LungePounce(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId( event.GetInt("victim") );
	int attacker = GetClientOfUserId(event.GetInt("userid"));
    
    g_fPinTime[attacker][0] = GetGameTime();
    
    ResetHunter(attacker);

    if (    g_fPouncePosition[attacker][0] == 0.0
        &&  g_fPouncePosition[attacker][1] == 0.0
        &&  g_fPouncePosition[attacker][2] == 0.0
    ) {
        return;
    }
        
    float  endPos[3];
    GetClientAbsOrigin( attacker, endPos );
    float  fHeight = g_fPouncePosition[attacker][2] - endPos[2];
    
    float  fMin = GetConVarFloat(g_hCvarMinPounceDistance);
    float  fMax = GetConVarFloat(g_hCvarMaxPounceDistance);
    float  fMaxDmg = GetConVarFloat(g_hCvarMaxPounceDamage);
    
    int distance = RoundToNearest( GetVectorDistance(g_fPouncePosition[attacker], endPos) );
    
    float  fDamage = ( ( (float(distance) - fMin) / (fMax - fMin) ) * fMaxDmg ) + 1.0;

    // apply bounds
    if (fDamage < 0.0) {
        fDamage = 0.0;
    } else if (fDamage > fMaxDmg + 1.0) {
        fDamage = fMaxDmg + 1.0;
    }
    
    Handle  pack = CreateDataPack();
    WritePackCell( pack, attacker );
    WritePackCell( pack, victim );
    WritePackFloat( pack, fDamage );
    WritePackFloat( pack, fHeight );
    CreateTimer( 0.05, Timer_HunterDP, pack );
    
	
	int zombieclass = GetInfectedClass(attacker);

	if (zombieclass == ZC_HUNTER) g_bIsPouncing[attacker] = false;
}

public Action Timer_HunterDP( Handle timer, Handle pack )
{
    ResetPack( pack );
    int client = ReadPackCell( pack );
    int victim = ReadPackCell( pack );
    float  fDamage = ReadPackFloat( pack );
    float  fHeight = ReadPackFloat( pack );
    CloseHandle( pack );
    
    HandleHunterDP( client, victim, fDamage, fHeight );
}

public Action Event_PlayerJumped(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    
    if ( IsValidInfected(client) )
    {
        int zClass = GetInfectedClass(client);
        if ( zClass != ZC_JOCKEY ) { return Plugin_Continue; }
    
        GetClientAbsOrigin( client, g_fPouncePosition[client] );
    }
    else if ( IsValidSurvivor(client) )
    {
        float  fPos[3],  fVel[3];
        GetClientAbsOrigin( client, fPos );
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel ); 
        fVel[2] = 0.0;
        
        float  fLengthNew,  fLengthOld;
        fLengthNew = GetVectorLength(fVel);
        
        
        g_bHopCheck[client] = false;
        
        if ( !g_bIsHopping[client] )
        {
            if ( fLengthNew >= 150.0 )
            {
                g_fHopTopVelocity[client] = fLengthNew;
                g_bIsHopping[client] = true;
                g_iHops[client] = 0;
            }
        }
        else
        {
            fLengthOld = GetVectorLength(g_fLastHop[client]);
            
            if ( fLengthNew - fLengthOld > 0.01 || fLengthNew >= 300.0 )
            {
                g_iHops[client]++;
                
                if ( fLengthNew > g_fHopTopVelocity[client] )
                {
                    g_fHopTopVelocity[client] = fLengthNew;
                }
            }
            else
            {
                g_bIsHopping[client] = false;
                
                if ( g_iHops[client] )
                {
                    HandleBHopStreak( client, g_iHops[client], g_fHopTopVelocity[client] );
                    g_iHops[client] = 0;
                }
            }
        }
        
        g_fLastHop[client][0] = fVel[0];
        g_fLastHop[client][1] = fVel[1];
        g_fLastHop[client][2] = fVel[2];
        
        if ( g_iHops[client] != 0 )
        {
            CreateTimer( 0.1, Timer_CheckHop, client, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
        }
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckHop (Handle timer, any client)
{
    if ( !IsValidInGame(client) || !IsPlayerAlive(client) )
    {
        return Plugin_Stop;
    }
    else if ( GetEntityFlags(client) & FL_ONGROUND )
    {
        float  fVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel ); 
        fVel[2] = 0.0;
        
        g_bHopCheck[client] = true;
        
        CreateTimer( 0.1, Timer_CheckHopStreak, client, TIMER_FLAG_NO_MAPCHANGE );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_CheckHopStreak (Handle timer, any client)
{
    if ( !IsValidInGame(client) || !IsPlayerAlive(client) ) { return Plugin_Continue; }
    
    if ( g_bHopCheck[client] && g_iHops[client] )
    {
        HandleBHopStreak( client, g_iHops[client], g_fHopTopVelocity[client] );
        g_bIsHopping[client] = false;
        g_iHops[client] = 0;
        g_fHopTopVelocity[client] = 0.0;
    }
    
    g_bHopCheck[client] = false;
    
    return Plugin_Continue;
}


public Action Event_PlayerJumpApex(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    
    if ( g_bIsHopping[client] )
    {
        float  fVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", fVel ); 
        fVel[2] = 0.0;
        float  fLength = GetVectorLength(fVel);
        
        if ( fLength > g_fHopTopVelocity[client] )
        {
            g_fHopTopVelocity[client] = fLength;
        }
    }
}
    
public Action Event_JockeyRide(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    
    if ( !IsValidInfected(client) || !IsValidSurvivor(victim) ) { return Plugin_Continue; }
    
    g_fPinTime[client][0] = GetGameTime();

    if ( g_fPouncePosition[client][0] == 0.0 && g_fPouncePosition[client][1] == 0.0 && g_fPouncePosition[client][2] == 0.0 ) { return Plugin_Continue; }
    
    float  endPos[3];
    GetClientAbsOrigin( client, endPos );
    float  fHeight = g_fPouncePosition[client][2] - endPos[2];
    
    HandleJockeyDP( client, victim, fHeight );
    
    return Plugin_Continue;
}

public Action Event_AbilityUse(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    char  abilityName[64];
    event.GetString( "ability", abilityName, sizeof(abilityName) );
    
	if(!IsValidInfected(client)) return;
    
    strAbility  ability;
    if ( GetTrieValue(g_hTrieAbility, abilityName, ability) )
    {
		switch ( ability )
		{
			case ABL_HUNTERLUNGE:
			{
				ResetHunter(client);
				GetClientAbsOrigin( client, g_fPouncePosition[client] );
			}
		
			case ABL_ROCKTHROW:
			{
				g_iRocksBeingThrown[g_iRocksBeingThrownCount] = client;
				
				if ( g_iRocksBeingThrownCount < 9 ) { g_iRocksBeingThrownCount++; }
			}
		}
	}
	if (g_bHasRoundEnded) return;

	
	int zombieclass = GetInfectedClass(client);

	if (zombieclass == ZC_HUNTER)
	{
		g_bIsPouncing[client] = true;
		CreateTimer(0.5, Timer_GroundedCheck, client, TIMER_REPEAT);
	}
}

public Action Timer_GroundedCheck(Handle timer, any client)
{
	if (!IsValidInGame(client) || IsGrounded(client))
	{
		g_bIsPouncing[client] = false;
		KillTimer(timer);
	}
}

// charger carrying
public Action Event_ChargeCarryStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    if ( !IsValidInfected(client) ) { return; }

    g_fChargeTime[client] = GetGameTime();
    g_fPinTime[client][0] = g_fChargeTime[client];
    g_fPinTime[client][1] = 0.0;
    
    if ( !IsValidSurvivor(victim) ) { return; }
    
    g_iChargeVictim[client] = victim;
    g_iVictimCharger[victim] = client;
    g_iVictimFlags[victim] = VICFLG_CARRIED;
    g_fChargeTime[victim] = g_fChargeTime[client];
    g_iVictimMapDmg[victim] = 0;
    
    GetClientAbsOrigin( victim, g_fChargeVictimPos[victim] );
    
    CreateTimer( 0.25, Timer_ChargeCheck, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
}

public Action Event_ChargeImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    if ( !IsValidInfected(client) || !IsValidSurvivor(victim) ) { return; }
    
    GetClientAbsOrigin( victim, g_fChargeVictimPos[victim] );
    
    g_iVictimCharger[victim] = client;
    g_iVictimFlags[victim] = 0;
    g_fChargeTime[victim] = GetGameTime();
    g_iVictimMapDmg[victim] = 0;
    
    CreateTimer( 0.25, Timer_ChargeCheck, victim, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE );
}

public Action Event_ChargePummelStart(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    
    if ( !IsValidInfected(client) ) { return; }
    
    g_fPinTime[client][1] = GetGameTime();
}


public Action Event_ChargeCarryEnd(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId( event.GetInt("userid") );
    if ( client < 1 || client > MaxClients ) { return; }
    
    g_fPinTime[client][1] = GetGameTime();
    
    CreateTimer( 0.1, Timer_ChargeCarryEnd, client, TIMER_FLAG_NO_MAPCHANGE );
}

public Action Timer_ChargeCarryEnd( Handle timer, any client )
{
    g_iChargeVictim[client] = 0;
}

public Action Timer_ChargeCheck( Handle timer, any client )
{
    if ( !IsValidSurvivor(client) || !g_iVictimCharger[client] || g_fChargeTime[client] == 0.0 || ( GetGameTime() - g_fChargeTime[client]) > 12.0 )
    {
        return Plugin_Stop;
    }
    
    if ( !IsPlayerAlive(client) )
    {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_AIRDEATH;
        
        CreateTimer( 0.0, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE );
        
        return Plugin_Stop;
    }
    else if ( GetEntityFlags(client) & FL_ONGROUND && g_iChargeVictim[ g_iVictimCharger[client] ] != client )
    {
        CreateTimer( 2.5, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE );
        
        return Plugin_Stop;
    }
    
    return Plugin_Continue;
}

public Action Timer_DeathChargeCheck( Handle timer, any client )
{
    if ( !IsValidInGame(client) ) { return; }
    
    int flags = g_iVictimFlags[client];
    
    if ( !IsPlayerAlive(client) )
    {
        float  pos[3];
        GetClientAbsOrigin( client, pos );
        float  fHeight = g_fChargeVictimPos[client][2] - pos[2];
        
        if (    (   ( flags & VICFLG_DROWN || flags & VICFLG_FALL ) &&
                    ( flags & VICFLG_HURTLOTS || flags & VICFLG_AIRDEATH ) ||
                    ( flags & VICFLG_WEIRDFLOW && fHeight >= MIN_FLOWDROPHEIGHT ) ||
                    g_iVictimMapDmg[client] >= MIN_DC_TRIGGER_DMG
                ) &&
                !( flags & VICFLG_KILLEDBYOTHER )
        ) {
            HandleDeathCharge( g_iVictimCharger[client], client, fHeight, view_as<bool>(flags & VICFLG_CARRIED) );
        }
    }
    else if (   ( flags & VICFLG_WEIRDFLOW || g_iVictimMapDmg[client] >= MIN_DC_RECHECK_DMG ) &&
                !(flags & VICFLG_WEIRDFLOWDONE)
    ) {
        g_iVictimFlags[client] = g_iVictimFlags[client] | VICFLG_WEIRDFLOWDONE;
        
        CreateTimer( 3.0, Timer_DeathChargeCheck, client, TIMER_FLAG_NO_MAPCHANGE );
    }
}

void ResetHunter(int client)
{
    g_iHunterShotDmgTeam[client] = 0;
    
    for ( int i=1; i <= MAXPLAYERS; i++ )
    {
        g_iHunterShotDmg[client][i] = 0;
        g_fHunterShotStart[client][i] = 0.0;
    }
    g_iHunterOverkill[client] = 0;
}

// entity creation
public void OnEntityCreated ( int entity, const char[] classname )
{
    if ( entity < 1 || !IsValidEntity(entity) || !IsValidEdict(entity) ) { return; }
    
    if (!GetTrieValue(g_hTrieEntityCreated, classname, OEC_TANKROCK)) { return; }
    
	char rock_key[10];
	FormatEx(rock_key, sizeof(rock_key), "%x", entity);
	int rock_array[3];
	
	int tank = ShiftTankThrower();
	
	if ( IsValidInGame(tank) )
	{
		g_iTankRock[tank] = entity;
		rock_array[rckTank] = tank;
	}
	SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
	
	SDKHook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
	SDKHook(entity, SDKHook_Touch, OnTouch_Rock);
}

// entity destruction
public void OnEntityDestroyed ( int entity )
{
    char witch_key[10];
    FormatEx(witch_key, sizeof(witch_key), "%x", entity);
    
    int rock_array[3];
    if ( GetTrieArray(g_hRockTrie, witch_key, rock_array, sizeof(rock_array)) )
    {
        CreateTimer( 0.34, Timer_CheckRockSkeet, entity );
        SDKUnhook(entity, SDKHook_TraceAttack, TraceAttack_Rock);
        return;
    }
}

public Action Timer_CheckRockSkeet (Handle timer, any rock)
{
    int rock_array[3];
    char  rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", rock);
    if (!GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array)) ) { return Plugin_Continue; }
    
    RemoveFromTrie(g_hRockTrie, rock_key);
    
    if ( rock_array[rckDamage] > 0 )
    {
        HandleRockSkeeted( rock_array[rckSkeeter] );
    }
    
    return Plugin_Continue;
}

// tank rock
public Action TraceAttack_Rock (int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &ammotype, int hitbox, int hitgroup)
{
    if ( IsValidSurvivor(attacker) )
    {
        char rock_key[10];
        int rock_array[3];
        FormatEx(rock_key, sizeof(rock_key), "%x", victim);
        GetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array));
        rock_array[rckDamage] += RoundToFloor(damage);
        rock_array[rckSkeeter] = attacker;
        SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    }
}

void OnTouch_Rock ( int entity )
{
    char rock_key[10];
    FormatEx(rock_key, sizeof(rock_key), "%x", entity);
    int rock_array[3];
    rock_array[rckDamage] = -1;
    SetTrieArray(g_hRockTrie, rock_key, rock_array, sizeof(rock_array), true);
    
    SDKUnhook(entity, SDKHook_Touch, OnTouch_Rock);
}

// smoker tongue cutting & self clears
public Action Event_TonguePullStopped (Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    int smoker = GetClientOfUserId( event.GetInt("smoker") );
    int reason = event.GetInt("release_type");
    
    if ( !IsValidSurvivor(attacker) || !IsValidInfected(smoker) ) { return Plugin_Continue; }
    
    HandleClear( attacker, smoker, victim,
            ZC_SMOKER,
            (g_fPinTime[smoker][1] > 0.0) ? ( GetGameTime() - g_fPinTime[smoker][1]) : -1.0,
            ( GetGameTime() - g_fPinTime[smoker][0])
        );
    
    if ( attacker != victim ) { return Plugin_Continue; }
    
    if ( reason == CUT_SLASH )
    {
        char weapon[32];
        GetClientWeapon( attacker, weapon, 32 );
        
        if ( StrEqual(weapon, "weapon_melee", false) )
        {
            HandleTongueCut( attacker, smoker );
        }
    }
    
    return Plugin_Continue;
}

public Action Event_TongueGrab (Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    
    if ( IsValidInfected(attacker) && IsValidSurvivor(victim) )
    {
        g_fPinTime[attacker][0] = GetGameTime();
        g_fPinTime[attacker][1] = 0.0;
    }
    
    return Plugin_Continue;
}

public Action Event_ChokeStart (Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId( event.GetInt("userid") );
    
    if ( g_fPinTime[attacker][0] == 0.0 ) { g_fPinTime[attacker][0] = GetGameTime(); }
    g_fPinTime[attacker][1] = GetGameTime();
}

public Action Event_ChokeStop (Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId( event.GetInt("userid") );
    int victim = GetClientOfUserId( event.GetInt("victim") );
    int smoker = GetClientOfUserId( event.GetInt("smoker") );
    
    if ( !IsValidSurvivor(attacker) || !IsValidInfected(smoker) ) { return; }
    
    HandleClear( attacker, smoker, victim,
            ZC_SMOKER,
            (g_fPinTime[smoker][1] > 0.0) ? ( GetGameTime() - g_fPinTime[smoker][1]) : -1.0,
            ( GetGameTime() - g_fPinTime[smoker][0])
        );
}

// car alarm handling
public Action Event_AlarmCar(Event event, const char[] name, bool dontBroadcast)
{
	if (g_iAlarmCarClient && IsValidInGame(g_iAlarmCarClient) && GetClientTeam(g_iAlarmCarClient) == 2)
	{
		CPrintToChatAll("{O}★{W} {G}%N {W}触发了 {G}警报车", g_iAlarmCarClient);
		g_iAlarmCarClient = 0;
	}
}

/*
    Reporting and forwards
    ----------------------
*/

// charger level
void HandleLevel( int attacker, int victim )
{
	if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(victim) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} leveled {G}%N{W}.", attacker, victim );
	}
	else if ( IsValidInGame(attacker) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} leveled a charger.", attacker );
	}
	else
	{
		CPrintToChatAll( "{O}★{W} A charger was leveled." );
	}

}
// charger level hurt
void HandleLevelHurt( int attacker, int victim, int damage )
{
	if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(victim) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} chip-leveled {G}%N{W} ({B}%i{W} damage).", attacker, victim, damage );
	}
	else if ( IsValidInGame(attacker) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} chip-leveled a charger. ({B}%i{W} damage)", attacker, damage );
	}
	else
	{
		CPrintToChatAll( "{O}★{W} A charger was chip-leveled ({B}%i{W} damage).", damage );
	}
}

// real skeet
void HandleSkeet( int attacker, int victim, bool bMelee = false )
{
	if ( attacker == -2 )
	{
		if ( IsValidInGame(victim) && !IsFakeClient(victim) ) {
			CPrintToChatAll( "{O}★{W} {G}%N{W} 死于团队集火.", victim );
		} else {
			CPrintToChatAll( "{O}★{W} {W}Hunter 死于团队集火." );
		}
	}
	else if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(victim) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} %sskeeted {G}%N{W}.",
				attacker,
				(bMelee) ? "近战-": "",
				victim 
			);
	}
	else if ( IsValidInGame(attacker) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} %sskeeted a hunter.",
				attacker,
				(bMelee) ? "近战-": ""
			);
	}
}

// hurt skeet / non-skeet
//  NOTE: bSniper not set yet, do this
void HandleNonSkeet( int victim, int damage, bool bOverKill = false )
{
	if ( IsValidInGame(victim) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} was {G}not{W} skeeted ({B}%i{W} damage).%s", victim, damage, (bOverKill) ? "(Would've skeeted if hunter were unchipped!)" : "" );
	}
	else
	{
		CPrintToChatAll( "{O}★{W} Hunter was {G}not{W} skeeted ({B}%i{W} damage).%s", damage, (bOverKill) ? "(Would've skeeted if hunter were unchipped!)" : "" );
	}
}

// smoker clears
void HandleTongueCut( int attacker, int victim )
{
	if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(victim) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} 切断 {G}%N{W} 的舌头.", attacker, victim );
	}
	else if ( IsValidInGame(attacker) )
	{
		CPrintToChatAll( "{O}★{W} {G}%N{W} 切断 Smoker 的舌头.", attacker );
	}
}

// rocks
void HandleRockSkeeted( int attacker )
{
	CPrintToChatAll( "{O}★{W} {G}%N{W} 击碎了 Tank 岩石.", attacker );
}

// highpounces
void HandleHunterDP( int attacker, int victim, float calculatedDamage, float height, bool playerIncapped = false )
{
    if (height >= 400.0 && !playerIncapped)
	{
        if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(attacker) )
        {
            CPrintToChatAll( "{O}★★{W} {G}%N{W} 对 {G}%N{W} 发动了 苍 穹 龙 炎 ({B}%i{W} 伤害, 高度: {G}%i{W}).", attacker,  victim, RoundFloat(calculatedDamage), RoundFloat(height) );
        }
        else if ( IsValidInGame(victim) )
        {
            CPrintToChatAll( "{O}★★{W} Hunter 对 {G}%N{W} 发动了 苍 穹 龙 炎 ({B}%i{W} 伤害, 高度: {G}%i{W}).", victim, RoundFloat(calculatedDamage), RoundFloat(height) );
        }
    }
}
void HandleJockeyDP( int attacker, int victim, float height )
{
    if (height >= 300.0)
	{
        if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(attacker) )
        {
            CPrintToChatAll( "{O}★{W} {G}%N{W}(Jockey) 对 {G}%N{W} 发动了龙炎冲 (高度: {G}%i{W}).", attacker,  victim, RoundFloat(height) );
        }
        else if ( IsValidInGame(victim) )
        {
            CPrintToChatAll( "{O}★{W} Jockey 对 {G}%N{W} 发动了龙炎冲 (高度: {G}%i{W}).", victim, RoundFloat(height) );
        }
    }
}

// deathcharges
void HandleDeathCharge( int attacker, int victim, float height, bool bCarried = true )
{
    if (height >= 400.0)
	{
        if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(attacker) )
        {
            CPrintToChatAll( "{O}★★★{W} {G}%N{W} 对 {G}%N{W} 发动了死刑 %s(高度: {G}%i{W}).",
                    attacker,
                    victim,
                    (bCarried) ? "" : "(通过AOE) ",
                    RoundFloat(height)
                );
        }
        else if ( IsValidInGame(victim) )
        {
            CPrintToChatAll( "{O}★★★{W} Charger 对 {G}%N{W} 发动了死刑 %s(高度: {G}%i{W}).",
                    victim,
                    (bCarried) ? "" : "(通过AOE) ",
                    RoundFloat(height) 
                );
        }
    }
}

// SI clears    (cleartimeA = pummel/pounce/ride/choke, cleartimeB = tongue drag, charger carry)
void HandleClear( int attacker, int victim, int pinVictim, int zombieClass, float clearTimeA, float clearTimeB )
{
    if ( clearTimeA < 0 && clearTimeA != -1.0 ) { clearTimeA = 0.0; }
    if ( clearTimeB < 0 && clearTimeB != -1.0 ) { clearTimeB = 0.0; }
    
    if ( attacker != pinVictim )
    {
        float  fClearTime = clearTimeA;
        if ( zombieClass == ZC_CHARGER || zombieClass == ZC_SMOKER ) { fClearTime = clearTimeB; }
        
        
        if ( fClearTime != -1.0 && fClearTime <= 0.75 )
        {
            if ( IsValidInGame(attacker) && IsValidInGame(victim) && !IsFakeClient(victim) )
            {
                if ( IsValidInGame(pinVictim) )
                {
                    CPrintToChatAll( "{O}★{W} {G}%N{W} insta-cleared {G}%N{W} from {G}%N{W} (%s) (%.2f 秒).",
                            attacker, pinVictim, victim,
                            L4D2_InfectedNames[zombieClass],
                            fClearTime
                        );
                } else {
                    CPrintToChatAll( "{O}★{W} {G}%N{W} insta-cleared a teammate from {G}%N{W} (%s) (%.2f 秒).",
                            attacker, victim,
                            L4D2_InfectedNames[zombieClass],
                            fClearTime
                        );
                }
            }
            else if ( IsValidInGame(attacker) )
            {
                if ( IsValidInGame(pinVictim) )
                {
                    CPrintToChatAll( "{O}★{W} {G}%N{W} insta-cleared {G}%N{W} from a %s (%.2f 秒).",
                            attacker, pinVictim,
                            L4D2_InfectedNames[zombieClass],
                            fClearTime
                        );
                } else {
                    CPrintToChatAll( "{O}★{W} {G}%N{W} insta-cleared a teammate from a %s (%.2f 秒).",
                            attacker,
                            L4D2_InfectedNames[zombieClass],
                            fClearTime
                        );
                }
            }
        }
    }
}

// bhaps
void HandleBHopStreak( int survivor, int streak, float maxVelocity )
{
    if (IsValidInGame(survivor) && !IsFakeClient(survivor) && streak >= 3)
	{
        CPrintToChatAll( "{O}★{W} {G}%N{W} 连续取得了 {G}%i{W} 个加速跳跃 (最高速度: {G}%.1f{W}).",
                survivor,
                streak,
                ( streak > 1 ) ? "s" : "",
                maxVelocity
            );
    }
}

// support
// -------
float GetSurvivorDistance(int client)
{
    return L4D2Direct_GetFlowDistance(client);
}

int ShiftTankThrower()
{
    int tank = -1;
    
    if ( !g_iRocksBeingThrownCount ) { return -1; }
    
    tank = g_iRocksBeingThrown[0];
    
    if ( g_iRocksBeingThrownCount > 1 )
    {
        for ( int x = 1; x <= g_iRocksBeingThrownCount; x++ )
        {
            g_iRocksBeingThrown[x-1] = g_iRocksBeingThrown[x];
        }
    }
    
    g_iRocksBeingThrownCount--;
    
    return tank;
}
