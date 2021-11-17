#define ZOMBIECLASS_TANK 8
#define THROWRANGE 99999999.0
#define FIREIMMUNITY_TIME 5.0
#define INCAPHEALTH 300

ConVar
	hMobSpawnSizeMin,
	hMobSpawnSizeMax,
	hMobSpawnTimeMin,
	hMobSpawnTimeMax,
	hTankLotterySelectionTime,
	hTankThrowAllowRange,
	g_hGT_Enabled,
	g_hGT_RemoveEscapeTank,
	g_hGT_DisableTankHordes;

Handle
	g_hGT_TankDeathTimer = null;

float
	fMobSpawnTimeMin,
	fMobSpawnTimeMax;

int
	iMobSpawnSizeMin,
	iMobSpawnSizeMax,
	g_iGT_TankClient,
	passes;

bool
	g_bGT_TankIsInPlay,
	g_bGT_TankHasFireImmunity,
	g_bGT_FinaleVehicleIncoming,
	g_bGT_HordesDisabled;

public void GT_OnModuleStart()
{
    hMobSpawnSizeMin = FindConVar("z_mob_spawn_min_size");
    hMobSpawnSizeMax = FindConVar("z_mob_spawn_max_size");
    hMobSpawnTimeMin = FindConVar("z_mob_spawn_min_interval_normal");
    hMobSpawnTimeMax = FindConVar("z_mob_spawn_max_interval_normal");
    
    hMobSpawnSizeMin.AddChangeHook(ConVarChange);
    hMobSpawnSizeMax.AddChangeHook(ConVarChange);
    hMobSpawnTimeMin.AddChangeHook(ConVarChange);
    hMobSpawnTimeMax.AddChangeHook(ConVarChange);
    
    ConVarChange(null, "", "");
    
    hTankLotterySelectionTime = FindConVar("director_tank_lottery_selection_time");
    hTankThrowAllowRange = FindConVar("tank_throw_allow_range");
    
    g_hGT_Enabled	= CreateConVarEx("boss_tank", "1", "Tank can't be prelight, frozen and ghost until player takes over, punch fix, and no rock throw for AI tank while waiting for player",CVAR_FLAGS);
    g_hGT_RemoveEscapeTank = CreateConVarEx("remove_escape_tank", "1", "Remove tanks that spawn as the rescue vehicle is incoming on finales.");
    g_hGT_DisableTankHordes = CreateConVarEx("disable_tank_hordes", "0", "Disable natural hordes while tanks are in play");
    HookEvent("finale_vehicle_incoming", GT_FinaleVehicleIncoming);
    HookEvent("item_pickup", GT_ItemPickup);
    HookEvent("player_hurt",GT_TankOnFire);
    HookEvent("player_incapacitated", GT_PlayerIncap);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	iMobSpawnSizeMin = hMobSpawnSizeMin.IntValue;
	iMobSpawnSizeMax = hMobSpawnSizeMax.IntValue;
	fMobSpawnTimeMin = hMobSpawnTimeMin.FloatValue;
	fMobSpawnTimeMax = hMobSpawnTimeMax.FloatValue;
}

Action GT_OnTankSpawn_Forward()
{
    if(g_hGT_RemoveEscapeTank.BoolValue && g_bGT_FinaleVehicleIncoming)
        return Plugin_Handled;
    return Plugin_Continue;
}

Action GT_OnSpawnMob_Forward(int &amount)
{
    if(g_bGT_HordesDisabled)
    {
        if (amount < iMobSpawnSizeMin || amount > iMobSpawnSizeMax)
        {
            return Plugin_Continue;
        }
        if (!L4D2_CTimerIsElapsed(L4D2CT_MobSpawnTimer))
        {
            return Plugin_Continue;
        }
        
        float duration = L4D2_CTimerGetCountdownDuration(L4D2CT_MobSpawnTimer);
        if (duration < fMobSpawnTimeMin || duration > fMobSpawnTimeMax)
        {
            return Plugin_Continue;
        }
        
        return Plugin_Handled;
    }
    return Plugin_Continue;
}

Action GT_OnTryOfferingTankBot(bool &enterStasis)
{
	passes++;
	if(g_hGT_Enabled.BoolValue) enterStasis = false;
	if(g_hGT_RemoveEscapeTank.BoolValue && g_bGT_FinaleVehicleIncoming) return Plugin_Handled;
	return Plugin_Continue;
}

public void GT_FinaleVehicleIncoming(Event event, const char[] name, bool dontBroadcast)
{
    g_bGT_FinaleVehicleIncoming = true;
    if(g_bGT_TankIsInPlay && IsFakeClient(g_iGT_TankClient))
    {
        KickClient(g_iGT_TankClient);
        GT_Reset();
    }
}

public void GT_ItemPickup(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_bGT_TankIsInPlay) return;
    
    char item[64];
    event.GetString("item", item, sizeof(item));
    
    if (StrEqual(item, "tank_claw")) 
    {
        g_iGT_TankClient = GetClientOfUserId(event.GetInt("userid"));
        if(g_hGT_TankDeathTimer != null)
        {
            KillTimer(g_hGT_TankDeathTimer);
            g_hGT_TankDeathTimer = null;
        }
    }
}

public void GT_RoundStart()
{
    g_bGT_FinaleVehicleIncoming = false;
    GT_Reset();
}

public void GT_TankKilled(Event event)
{
    if(!g_bGT_TankIsInPlay) return;
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(client != g_iGT_TankClient) return;
    g_hGT_TankDeathTimer = CreateTimer(1.0, GT_TankKilled_Timer);
}

public void GT_TankSpawn(Event event)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    g_iGT_TankClient = client;
    
    if(g_bGT_TankIsInPlay) return;
    
    g_bGT_TankIsInPlay = true;
    
    if(g_hGT_DisableTankHordes.BoolValue)
    {
        g_bGT_HordesDisabled = true;
    }
    
    if(!g_hGT_Enabled.BoolValue) return;
    
    float fFireImmunityTime = FIREIMMUNITY_TIME;
    float fSelectionTime = hTankLotterySelectionTime.FloatValue;
    
    if(IsFakeClient(client))
    {
        GT_PauseTank();
        CreateTimer(fSelectionTime,GT_ResumeTankTimer);
        fFireImmunityTime += fSelectionTime;
    }
    
    CreateTimer(fFireImmunityTime, GT_FireImmunityTimer);
}

public void GT_TankOnFire(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_bGT_TankIsInPlay || !g_bGT_TankHasFireImmunity || !g_hGT_Enabled.BoolValue) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(g_iGT_TankClient != client || !IsValidClient(client)) return;
    
    int dmgtype = GetEventInt(event,"type");
    
    if(dmgtype != 8) return;
    
    ExtinguishEntity(client);
    int CurHealth = GetClientHealth(client);
    int DmgDone	  = event.GetInt("dmg_health");
    SetEntityHealth(client,(CurHealth + DmgDone));
}

public void GT_PlayerIncap(Event event, const char[] name, bool dontBroadcast)
{
    if(!g_bGT_TankIsInPlay || !g_hGT_Enabled.BoolValue) return;
    
    char weapon[16];
    GetEventString(event, "weapon", weapon, 16);
    
    if(!StrEqual(weapon, "tank_claw")) return;
    
    int client = GetClientOfUserId(event.GetInt("userid"));
    if(!IsValidClient(client)) return;
    
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 0);
    SetEntityHealth(client, 1);
    CreateTimer(0.4, GT_IncapTimer, client);
}

public Action GT_IncapTimer(Handle timer, any client)
{
    SetEntProp(client, Prop_Send, "m_isIncapacitated", 1);
    SetEntityHealth(client, INCAPHEALTH);
    
    return Plugin_Stop;
}

public Action GT_ResumeTankTimer(Handle timer)
{
    GT_ResumeTank();
    
    return Plugin_Stop;
}

public Action GT_FireImmunityTimer(Handle timer)
{
    g_bGT_TankHasFireImmunity = false;
    
    return Plugin_Stop;
}

void GT_PauseTank()
{
    hTankThrowAllowRange.SetFloat(THROWRANGE);
    if(!IsValidEntity(g_iGT_TankClient)) return;
    SetEntityMoveType(g_iGT_TankClient, MOVETYPE_NONE);
    SetEntProp(g_iGT_TankClient, Prop_Send, "m_isGhost", 1);
}

void GT_ResumeTank()
{
    hTankThrowAllowRange.RestoreDefault();
    if(!IsValidEntity(g_iGT_TankClient)) return;
    SetEntityMoveType(g_iGT_TankClient, MOVETYPE_CUSTOM);
    SetEntProp(g_iGT_TankClient, Prop_Send, "m_isGhost", 0);
}

void GT_Reset()
{
    passes = 0;
    g_hGT_TankDeathTimer = null;
    if(g_bGT_HordesDisabled)
    {
        g_bGT_HordesDisabled = false;
    }
    g_bGT_TankIsInPlay = false;
    g_bGT_TankHasFireImmunity = true;
}

public Action GT_TankKilled_Timer(Handle timer)
{
    GT_Reset();
    
    return Plugin_Stop;
}
