#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]readyup>
#include <[LIB]l4d2library>

#define MELEE_TIME              0.25
#define POUNCE_TIMER            0.1

#define HITGROUP_HEAD           1

#define WPTYPE_NONE             0
#define WPTYPE_SHELLS           1
#define WPTYPE_MELEE            2
#define WPTYPE_BULLETS          3

#define WP_MELEE                19

#define WP_PISTOL               1
#define WP_PISTOL_MAGNUM        32

#define WP_SMG                  2
#define WP_SMG_SILENCED         7

#define WP_HUNTING_RIFLE        6
#define WP_SNIPER_MILITARY      10

#define WP_PUMPSHOTGUN          3
#define WP_SHOTGUN_CHROME       8
#define WP_AUTOSHOTGUN          4
#define WP_SHOTGUN_SPAS         11

#define WP_RIFLE                5
#define WP_RIFLE_DESERT         9
#define WP_RIFLE_AK47           26

#define WP_MOLOTOV              13
#define WP_PIPE_BOMB            14
#define WP_VOMITJAR             25

#define WP_SMG_MP5              33
#define WP_RIFLE_SG552          34
#define WP_SNIPER_AWP           35
#define WP_SNIPER_SCOUT         36

#define WP_FIRST_AID_KIT        12
#define WP_PAIN_PILLS           15
#define WP_ADRENALINE           23
#define WP_MACHINEGUN           45

Handle hPounceDmgInt;

int iPounceDmgInt;

char sClientName[MAXPLAYERS + 1][64];

int iGotKills[MAXPLAYERS + 1];                  // SI kills             track for each client
int iGotCommon[MAXPLAYERS + 1];                 // CI kills
int iDidDamage[MAXPLAYERS + 1];                 // SI only              these are a bit redundant, but will keep anyway for now
int iDidDamageAll[MAXPLAYERS + 1];              // SI + tank + witch
int iDidDamageTank[MAXPLAYERS + 1];             // tank only
int iDidDamageWitch[MAXPLAYERS + 1];            // witch only

int iShotsFired[MAXPLAYERS + 1];                // shots total
int iPelletsFired[MAXPLAYERS + 1];              // shotgun pellets total
int iShotsHit[MAXPLAYERS + 1];                  // shots hit
int iPelletsHit[MAXPLAYERS + 1];                // shotgun pellets hit
int iMeleesFired[MAXPLAYERS + 1];               // melees total
int iMeleesHit[MAXPLAYERS + 1];                 // melees hit

int iDeadStops[MAXPLAYERS + 1];                 // all hunter deadstops (lunging hunters only)
int iHuntSkeets[MAXPLAYERS + 1];                // actual skeets (lunging hunter kills, full/normal)
int iHuntSkeetsInj[MAXPLAYERS + 1];             // injured skeets (< 150.0, on injured hunters)
int iHuntHeadShots[MAXPLAYERS + 1];             // all headshots on hunters (non-skeets too)

bool bIsHurt[MAXPLAYERS + 1];              // if a hunter player has been damaged (below 150)
bool bIsPouncing[MAXPLAYERS + 1];
bool bIsRoundLive;

int iDmgDuringPounce[MAXPLAYERS + 1];           // how much total damage in a single pounce (cumulative)

int iClientPlaying;                             // which clientId is the survivor this round?

float fPreviousShot[MAXPLAYERS + 1];       // when was the previous shotgun blast? (to collect all hits for 1 shot)
int iPreviousShotType[MAXPLAYERS + 1];          // weapon id for shotgun/melee that fired previous shot
int bCurrentShotHit[MAXPLAYERS + 1];            // whether we got a hit for the shot
int iCurrentShotDmg[MAXPLAYERS + 1];            // counting shotgun blast damage

public Plugin myinfo =
{
	name = "1v1 EQ",
	author = "Blade + Confogl Team, Tabun, Visor",
	description = "A plugin designed to support 1v1.",
	version = "0.1",
	url = "https://github.com/Attano/Equilibrium"
}

public void OnPluginStart()
{
    HookEvent("player_hurt", PlayerHurt_Event, EventHookMode_Post);
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("player_shoved", PlayerShoved_Event, EventHookMode_Post);
    HookEvent("infected_hurt" ,InfectedHurt_Event, EventHookMode_Post);
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
	
    HookEvent("weapon_fire", WeaponFire_Event, EventHookMode_Post);
    HookEvent("ability_use", AbilityUse_Event, EventHookMode_Post);
	
    hPounceDmgInt = FindConVar("z_pounce_damage_interrupt");
    iPounceDmgInt = GetConVarInt(hPounceDmgInt);
    HookConVarChange(hPounceDmgInt, ConVarChange_PounceDmgInt);
	
    RegConsoleCmd("sm_skeets", SkeetStat_Cmd, "Prints the current skeetstats.");
    RegConsoleCmd("say", Say_Cmd);
    RegConsoleCmd("say_team", Say_Cmd);
	
	HookEvent("player_hurt", Event_PlayerHurt, EventHookMode_Post);
}

public int ConVarChange_PounceDmgInt(Handle cvar, const char[] oldValue, const char[] newValue)         { iPounceDmgInt = StringToInt(newValue); }

public void OnClientPutInServer(int client)
{
    char tmpBuffer[64];
    GetClientName(client, tmpBuffer, sizeof(tmpBuffer));
    if (strcmp(tmpBuffer, sClientName[client], true) != 0)
    {
        ClearClientSkeetStats(client);
        strcopy(sClientName[client], 64, tmpBuffer);
    }
}

public void OnRoundIsLive()
{
    bIsRoundLive = true;
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
    iClientPlaying = GetCurrentSurvivor();
}

public void L4D2_OnRealRoundStart()
{
	bIsRoundLive = false;
	
    iClientPlaying = GetCurrentSurvivor();
    
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        ClearClientSkeetStats(i);
    }
}

public void L4D2_OnRealRoundEnd()
{
    ResolveOpenShots();
    CreateTimer(3.0, delayedSkeetStatPrint);
}

public Action Say_Cmd(int client, int args)
{
	if (!client) { return Plugin_Continue; }
	
    char sMessage[MAX_NAME_LENGTH];
    GetCmdArg(1, sMessage, sizeof(sMessage));
        
    if (StrEqual(sMessage, "!skeets")) { return Plugin_Handled; }
        
    return Plugin_Continue;
}

public Action SkeetStat_Cmd(int client, int args)
{
    ResolveOpenShots();                                 // make sure we're up to date (this *might* affect the stats, but it'd have to be insanely badly timed
    PrintSkeetStats(client);
    return Plugin_Handled;
}

public Action delayedSkeetStatPrint(Handle timer)
{
    PrintSkeetStats(0);
}

public Action Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int victim = GetClientOfUserId(event.GetInt("userid"));

	if (!L4D2_IsValidClient(attacker))
		return;

	int damage = event.GetInt("dmg_health");
	L4D2_Infected zombie_class = L4D2_GetInfectedClass(attacker);

	if (GetClientTeam(attacker) == 3 && zombie_class != L4D2Infected_Tank && damage >= 24)
	{
		int remaining_health = GetClientHealth(attacker);
		char sBuffer[16];
		L4D2_GetInfectedClassName(zombie_class, sBuffer, sizeof(sBuffer));
		L4D2_CPrintToChatAll(
			"[{G}EQ 1v1{W}] {R}%N{W}({O}%s{W}) had {G}%d{W} health remaining!", 
			attacker, 
			sBuffer, 
			remaining_health
		);

		ForcePlayerSuicide(attacker);    

		if (remaining_health == 1)
		{
			PrintToChat(victim, "You don't have to be mad...");
		}
	}
}

public Action PlayerHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    int victimId = event.GetInt("userid");
    int victim = GetClientOfUserId(victimId);
    
    int attackerId = event.GetInt("attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    if (attacker != iClientPlaying)                             { return; }     // ignore shots fired by anyone but survivor player
    if (!L4D2_IsInfected(victim))                 { return; }     // safeguard
    
    int damage =        event.GetInt("dmg_health");
    int damagetype =    event.GetInt("type");
    int hitgroup =      event.GetInt("hitgroup");
    
    if (damagetype & DMG_BUCKSHOT) {
        iCurrentShotDmg[iClientPlaying] += damage;
        
        if (bIsPouncing[victim]) {
            iDmgDuringPounce[victim] += damage;
        }
        if (!bCurrentShotHit[iClientPlaying]) {
            if (hitgroup == HITGROUP_HEAD) { iHuntHeadShots[iClientPlaying]++; }              // only count headshot once for shotgun blast (not that it matters, but this might miss some hs's)
        }
        
        bCurrentShotHit[iClientPlaying] = true;
    }
    else if (damagetype & DMG_BULLET) {
        iShotsHit[iClientPlaying]++;
        if (hitgroup == HITGROUP_HEAD) { iHuntHeadShots[iClientPlaying]++; }
        
        if (bIsPouncing[victim]) {
            iDmgDuringPounce[victim] += damage;
        }
    }
    else if (damagetype & DMG_SLASH || damagetype & DMG_CLUB) {
        if (iPreviousShotType[iClientPlaying] == WP_MELEE && (GetEngineTime() - fPreviousShot[iClientPlaying]) < MELEE_TIME) {
            bCurrentShotHit[iClientPlaying] = true;
        }
    }
    
    L4D2_Infected zombieClass = L4D2_GetInfectedClass(victim);
    
    if (zombieClass >= L4D2Infected_Smoker && zombieClass < L4D2Infected_Witch)
    {
        iDidDamage[attacker] += damage;
        iDidDamageAll[attacker] += damage;
    }
}

public Action InfectedHurt_Event(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("attacker");
    int user = GetClientOfUserId(userId);
    if (user != iClientPlaying)                                 { return; }     // ignore shots fired by anyone but survivor player
    
    if (!bIsRoundLive)                                  { return; }     // don't count saferoom shooting for now.
    if (GetEntityMoveType(user) == MOVETYPE_NONE) { return; }     // ignore any shots by RUP-frozen player
    
    int damage = event.GetInt("amount");
    int damageType = event.GetInt("type");
    int victimEntId = event.GetInt("entityid");
    
    if (damageType & DMG_BUCKSHOT) {
        bCurrentShotHit[iClientPlaying] = true;
        if (IsCommonInfected(victimEntId)) {
            switch (iPreviousShotType[iClientPlaying]) {
                    case WP_PUMPSHOTGUN:    { damage = RoundFloat(float(damage) * 2.03); }       // max 123 on common (250)
                    case WP_SHOTGUN_CHROME: { damage = RoundFloat(float(damage) * 1.64); }       // max 151 on common (248)
                    case WP_AUTOSHOTGUN:    { damage = RoundFloat(float(damage) * 2.29); }       // max 113 on common (253)
                    case WP_SHOTGUN_SPAS:   { damage = RoundFloat(float(damage) * 1.84); }       // max 137 on common (252)
                }
        }        
        iCurrentShotDmg[iClientPlaying] += damage;
    }
    else if (damageType & DMG_BULLET) {
        iShotsHit[iClientPlaying]++;
    }
    else if (damageType & DMG_SLASH || damageType & DMG_CLUB) {
        if (iPreviousShotType[iClientPlaying] == WP_MELEE && (GetEngineTime() - fPreviousShot[iClientPlaying]) < MELEE_TIME) {
            bCurrentShotHit[iClientPlaying] = true;
        }
    }
}

public Action PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (attacker != iClientPlaying)                             { return; }     // ignore shots fired by anyone but survivor player
    if (!L4D2_IsValidClient(victim))                             { return; }     // safeguard
    if (!L4D2_IsInfected(victim))                 { return; }     // safeguard
    
    int damagetype = event.GetInt("type");
    
    if (damagetype & DMG_BUCKSHOT || damagetype & DMG_BULLET)
	{
        if (bIsPouncing[victim]) {
            if (bIsHurt[victim]) {              // inj. skeet
                iHuntSkeetsInj[iClientPlaying]++;
            } else {                            // normal/full skeet
                
                iHuntSkeets[iClientPlaying]++;
            }
            bIsPouncing[victim] = false;
            iDmgDuringPounce[victim] = 0;
        }
    }
    
    L4D2_Infected zombieClass = L4D2_GetInfectedClass(victim);
    
    if (zombieClass >= L4D2Infected_Smoker && zombieClass < L4D2Infected_Witch)
    {
        iGotKills[attacker]++;
    }
}

public Action InfectedDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    int attackerId = event.GetInt("attacker");
    int attacker = GetClientOfUserId(attackerId);
    
    if (attackerId && L4D2_IsValidClient(attacker))
    {
        if ((L4D2_IsSurvivor(attacker))) {
            iGotCommon[attacker]++;
        }
    }
}

public Action PlayerShoved_Event(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("attacker");
    int user = GetClientOfUserId(userId);
    if (user != iClientPlaying)                                 { return; }     // ignore actions by anyone else

    int victimId = event.GetInt("userId");
    int victim = GetClientOfUserId(victimId);
    
    if(bIsPouncing[victim])
    {
        iDeadStops[user]++;
        bIsPouncing[victim] = false;
        iDmgDuringPounce[victim] = 0;
    }
}

public Action AbilityUse_Event(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");
    int user = GetClientOfUserId(userId);
    char abilityName[64];
    
    event.GetString("ability",abilityName,sizeof(abilityName));
    
    if(L4D2_IsValidClient(user) && strcmp(abilityName,"ability_lunge",false) == 0 && !bIsPouncing[user])
    {
        bIsPouncing[user] = true;
        iDmgDuringPounce[user] = 0;                                     // use this to track skeet-damage
        bIsHurt[user] = (GetClientHealth(user) < iPounceDmgInt);
        CreateTimer(POUNCE_TIMER,groundTouchTimer,user,TIMER_REPEAT);   // check every TIMER whether the pounce has ended
    }
}

public Action groundTouchTimer(Handle timer, any client)
{
    if(L4D2_IsValidClient(client) && (isGrounded(client) || !IsPlayerAlive(client)))
    {
        bIsPouncing[client] = false;
        KillTimer(timer);
    }
}
public bool isGrounded(int client)
{
    return (GetEntProp(client,Prop_Data,"m_fFlags") & FL_ONGROUND) > 0;
}

public Action WeaponFire_Event(Event event, const char[] name, bool dontBroadcast)
{
    int userId = event.GetInt("userid");
    int user = GetClientOfUserId(userId);
    if (user != iClientPlaying)                                 { return; }     // ignore shots fired by anyone but survivor player
    
    if (!bIsRoundLive)                                  { return; }     // don't count saferoom shooting for now.
    if (GetEntityMoveType(user) == MOVETYPE_NONE) { return; }     // ignore any shots by RUP-frozen player
    
    int weaponId = event.GetInt("weaponid");
    int count = event.GetInt("count");
    
    int weaponType = GetWeaponType(weaponId);
    
    if (weaponType == WPTYPE_SHELLS)
    {
        ResolveOpenShots();
        
        iShotsFired[iClientPlaying]++;
        iPelletsFired[iClientPlaying] += count;
        fPreviousShot[iClientPlaying] = GetEngineTime();        // track shot from this time
        bCurrentShotHit[iClientPlaying] = false;                // so we can check just 1 hit for the shot
        iCurrentShotDmg[iClientPlaying] = 0;                    // reset, count damage for this shot
        iPreviousShotType[iClientPlaying] = weaponId;           // so we know what kind of shotgun blast it was
        return;
    }
    
    if (weaponType == WPTYPE_MELEE)
    {
        ResolveOpenShots();
        
        iMeleesFired[iClientPlaying]++;
        fPreviousShot[iClientPlaying] = GetEngineTime();        // track shot from this time
        bCurrentShotHit[iClientPlaying] = false;                // so we can check just 1 hit for the swing
        iCurrentShotDmg[iClientPlaying] = 0;                    // reset, count damage for this shot
        iPreviousShotType[iClientPlaying] = WP_MELEE;           // so we know a melee is 'out'
        return;
    }
    
    if (weaponType == WPTYPE_BULLETS)
    {
        iShotsFired[iClientPlaying]++;
        return;
    }
}

char PrintSkeetStats(int toClient)
{
    char printBuffer[512];
    char tmpBuffer[256];

    printBuffer = "";
    
    if (iClientPlaying <= 0) { return; }
	Format(tmpBuffer, sizeof(tmpBuffer), "1v1Stat - Kills: (\x05%4d \x01damage,\x05 %3d \x01kills)  (\x05%3d \x01common)\n", iDidDamageAll[iClientPlaying], iGotKills[iClientPlaying], iGotCommon[iClientPlaying]);
	StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
	
	if (!toClient) {
		PrintToServer("\x01%s", printBuffer);
		PrintToChatAll("\x01%s", printBuffer);
	} else if (L4D2_IsValidClient(toClient)) {
		PrintToChat(toClient, "\x01%s", printBuffer);
	}
	printBuffer = "";
   
    Format(tmpBuffer, sizeof(tmpBuffer), "1v1Stat - Skeet: (\x05%4d \x01normal,\x05 %3d \x01hurt)   (\x05%3d \x01deadstops)\n", iHuntSkeets[iClientPlaying], iHuntSkeetsInj[iClientPlaying], iDeadStops[iClientPlaying]);
	StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
	
	if (!toClient) {
		PrintToServer("\x01%s", printBuffer);
		PrintToChatAll("\x01%s", printBuffer);
	} else if (L4D2_IsValidClient(toClient)) {
		PrintToChat(toClient, "\x01%s", printBuffer);
	}
	printBuffer = "";
    
	if (iShotsFired[iClientPlaying]) {
		if (iShotsFired[iClientPlaying]) {
			Format(tmpBuffer, sizeof(tmpBuffer), "1v1Stat - Acc. : (all shots [\x04%3.0f%%\x01]", float(iShotsHit[iClientPlaying]) / float(iShotsFired[iClientPlaying]) * 100);
		} else {
			Format(tmpBuffer, sizeof(tmpBuffer), "1v1Stat - Acc. : (all shots [\x04%3.0f%%\x01]", 0.0);
		}
		if (iPelletsFired[iClientPlaying]) {
			StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
			Format(tmpBuffer, sizeof(tmpBuffer), ", buckshot [\x04%3.0f%%\x01]", float(iPelletsHit[iClientPlaying]) / float(iPelletsFired[iClientPlaying]) * 100);
		}
		StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
		Format(tmpBuffer, sizeof(tmpBuffer), ")\n");
	} else {
		Format(tmpBuffer, sizeof(tmpBuffer), "1v1Stat - Acc. : (no shots fired)\n");
	}
	StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
	
	if (!toClient) {
		PrintToServer("\x01%s", printBuffer);
		PrintToChatAll("\x01%s", printBuffer);
	} else if (L4D2_IsValidClient(toClient)) {
		PrintToChat(toClient, "\x01%s", printBuffer);
	}
	printBuffer = "";
}

public void ResolveOpenShots()
{
    if (iClientPlaying <= 0) { return; }
    
    if (iPreviousShotType[iClientPlaying])
    {
        if (bCurrentShotHit[iClientPlaying])
		{
            if (iPreviousShotType[iClientPlaying] == WP_MELEE)
			{
                iMeleesHit[iClientPlaying]++;
            
            }
			else
			{
                iShotsHit[iClientPlaying]++;
                
                if (iCurrentShotDmg[iClientPlaying]) {
                    int iTotalPellets, iPelletDamage;
                    switch (iPreviousShotType[iClientPlaying]) {
                        case WP_PUMPSHOTGUN:    { iTotalPellets = 10; iPelletDamage = 25; }
                        case WP_SHOTGUN_CHROME: { iTotalPellets = 8;  iPelletDamage = 31; }
                        case WP_AUTOSHOTGUN:    { iTotalPellets = 11; iPelletDamage = 23; }
                        case WP_SHOTGUN_SPAS:   { iTotalPellets = 9;  iPelletDamage = 28; }
                    }
                    if (iTotalPellets) {
                        int addPellets = RoundFloat(float(iCurrentShotDmg[iClientPlaying] / iPelletDamage ));
                        iPelletsHit[iClientPlaying] += (addPellets <= iTotalPellets) ? addPellets : iTotalPellets;
                    }
                }
            }
        }
        iPreviousShotType[iClientPlaying] = 0;
    }
}

int GetWeaponType(int weaponId)
{
    if (        weaponId == WP_PUMPSHOTGUN      ||
                weaponId == WP_SHOTGUN_CHROME   ||
                weaponId == WP_AUTOSHOTGUN      ||
                weaponId == WP_SHOTGUN_SPAS
    ) {
                return WPTYPE_SHELLS;
    }
    
    if (weaponId == WP_MELEE)
    {
                return WPTYPE_MELEE;
    }

    if (        weaponId == WP_PISTOL           ||
                weaponId == WP_PISTOL_MAGNUM    ||        
                weaponId == WP_SMG              ||
                weaponId == WP_SMG_SILENCED     ||
                weaponId == WP_SMG_MP5          ||
                weaponId == WP_HUNTING_RIFLE    ||
                weaponId == WP_SNIPER_MILITARY  ||
                weaponId == WP_RIFLE            ||
                weaponId == WP_RIFLE_DESERT     ||
                weaponId == WP_RIFLE_AK47       ||
                weaponId == WP_RIFLE_SG552      ||
                weaponId == WP_SNIPER_AWP       ||
                weaponId == WP_SNIPER_SCOUT     ||
                weaponId == WP_MACHINEGUN
    ) {
                return WPTYPE_BULLETS;
    }
    return WPTYPE_NONE;
}

int GetCurrentSurvivor()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && L4D2_IsSurvivor(i)) { return i; }
    }
    return -1;
}

void ClearClientSkeetStats(int client)
{
    iGotKills[client] = 0;
    iGotCommon[client] = 0;
    iDidDamage[client] = 0;
    iDidDamageAll[client] = 0;
    iDidDamageWitch[client] = 0;
    iDidDamageTank[client] = 0;

    iShotsFired[client] = 0;
    iPelletsFired[client] = 0;
    iShotsHit[client] = 0;
    iPelletsHit[client] = 0;
    iMeleesFired[client] = 0;
    iMeleesHit[client] = 0;
    iDeadStops[client] = 0;
    iHuntSkeets[client] = 0;
    iHuntSkeetsInj[client] = 0;
    iHuntHeadShots[client] = 0;
    
    fPreviousShot[client] = 0.0;
    iPreviousShotType[client] = 0;
    bCurrentShotHit[client] = 0;
    iCurrentShotDmg[client] = 0;
    
    bIsPouncing[client] = false;
    bIsHurt[client] = false;
    iDmgDuringPounce[client] = 0;
}

bool IsCommonInfected(int iEntity)
{
    if(iEntity > 0 && IsValidEntity(iEntity) && IsValidEdict(iEntity))
    {
        char strClassName[64];
        GetEdictClassname(iEntity, strClassName, sizeof(strClassName));
        return StrEqual(strClassName, "infected");
    }
    return false;
}
