#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>
#include <weapons>
#include <colors>

#define HORDE_SOUND	"/npc/mega_mob/mega_mob_incoming.wav"

public Plugin myinfo = 
{
	name = "L4D2 Merge",
	author = "Confogl Team, Tabun, Jahze, CanadaRox, Stabby, ProdigySim, Estoopi, Jacob, Sir, Visor",
	description = "",
	version = "1.0",
	url = ""
};

enum struct ItemTracking
{
	int IT_entity;
	float IT_origins;
	float IT_origins1;
	float IT_origins2;
	float IT_angles;
	float IT_angles1;
	float IT_angles2;
}

ArrayList g_hItemSpawns;
ConVar g_hCvarLimits, g_hReplaceFinaleKits, hMaxStaggerDuration, hPounceCrouchDelay, hLeapInterval;
bool bReplaceFinaleKits, announcedInChat;
int iGameMode, commonLimit, commonTank, commonTotal, lastCheckpoint, g_iItemLimits, g_GlobalWeaponRules[MAX_SIZE_WeaponId] = {-1, ...};
float staggerTime, fPounceCrouchDelay, fLeapInterval;

public void OnPluginStart()
{
	SetConVarInt(FindConVar("z_max_hunter_pounce_stagger_duration"), 1);
	
	g_hItemSpawns = new ArrayList(sizeof(ItemTracking));
	
	for (int i = 0; i < view_as<int>(MAX_SIZE_WeaponId); i++) g_GlobalWeaponRules[i] = -1;
	
	g_hCvarLimits = CreateConVar("l4d2_pills_limit", "-1", "限制每张地图上止痛药的数量. -1: 没有限制; >=0: 限制为cvar值");
	g_hReplaceFinaleKits = CreateConVar("l4d2_replace_finalekits", "0", "用药丸替代救援关卡的急救包");
	hMaxStaggerDuration = FindConVar("z_max_stagger_duration");
	hPounceCrouchDelay = FindConVar("z_pounce_crouch_delay");
	hLeapInterval = FindConVar("z_leap_interval");
	
	g_hCvarLimits.AddChangeHook(ConVarChange);
	g_hReplaceFinaleKits.AddChangeHook(ConVarChange);
	hMaxStaggerDuration.AddChangeHook(ConVarChange);
	hPounceCrouchDelay.AddChangeHook(ConVarChange);
	hLeapInterval.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
    RegServerCmd("l4d2_addweaponrule", AddWeaponRuleCb);
    RegServerCmd("l4d2_resetweaponrules", ResetWeaponRulesCb);
	
	HookEvent("jockey_ride_end", JockeyRideEnd, EventHookMode_Post);
	HookEvent("player_use", OnPlayerUse, EventHookMode_PostNoCopy);
	HookEvent("player_shoved", OutSkilled, EventHookMode_Post);
	HookEvent("player_incapacitated_start", Incap_Event, EventHookMode_Post);
}

public void OnPluginEnd()
{
	ResetConVar(FindConVar("z_max_hunter_pounce_stagger_duration"));
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	g_iItemLimits = g_hCvarLimits.IntValue;
	bReplaceFinaleKits = g_hReplaceFinaleKits.BoolValue;
	staggerTime = hMaxStaggerDuration.FloatValue;
	fPounceCrouchDelay = hPounceCrouchDelay.FloatValue;
	fLeapInterval = hLeapInterval.FloatValue;
}

public void OnMapStart()
{
	iGameMode = Gamemode();
    char mapname[64];
    GetCurrentMap(mapname, sizeof(mapname));
    if (StrEqual(mapname, "c2m1_highway", false)) DisableClips();
    else if (StrEqual(mapname, "c2m3_coaster", false)) DisableClips();
    else if (StrEqual(mapname, "c3m4_plantation", false)) DisableClips();
    else if ((StrEqual(mapname, "c4m2_sugarmill_a", false) || StrEqual(mapname, "c4m3_sugarmill_b", false))) DisableClips();
    else if (StrEqual(mapname, "c5m1_waterfront", false))
    {
        DisableClips();
        DisableFuncBrush();
    }
	
	commonLimit = L4D2_GetMapValueInt("horde_limit", -1);
	commonTank = L4D2_GetMapValueInt("horde_tank", -1);
	PrecacheSound(HORDE_SOUND);
	
	if (g_iItemLimits != -1)
	{
		if (L4D_IsMissionFinalMap()) g_iItemLimits = 0; 
	}
	
	ClearArray(g_hItemSpawns);
}

public void OnEntitySpawned(int entity, const char[] classname)
{
	if (!IsValidEntity(entity) || !IsValidEdict(entity)) return;
	if (StrEqual(classname, "infected", false))
	{
		if (isUncommon(entity))
		{
			float location[3];
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", location);
			RemoveEntityLog(entity);
			SpawnCommon(location);
		}
		else if (announcedInChat && IsInfiniteHordeActive())
		{
			if (commonLimit < 0) return;
			
			if (commonTotal >= commonLimit)
			{
				L4D2Direct_SetPendingMobCount(0);
				return;
			}
			
			commonTotal++;
			
			if (commonLimit < 120) return;
			
			if ((commonTotal >= ((lastCheckpoint + 1) * RoundFloat(float(commonLimit / 4)))))
			{
				int remaining = commonLimit - commonTotal;
				if (remaining)
				{
					CPrintToChatAll("<{G}Horde{W}> 事件剩余 {R}%i {W}.. ", remaining);
					EmitSoundToAll(HORDE_SOUND);
				}
				lastCheckpoint++;
			}
		}
	}
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (!IsValidInGame(client)) return Plugin_Continue;
	if (GetClientTeam(client) > TEAM_SPECTATOR && GetEntityFlags(client) & FL_INWATER && IsPlayerAlive(client))
	{
		if (GetClientTeam(client) == 2 && !IsLimping(client)) 
		{
			if (iGameMode == GAMEMODE_COOP) ApplySlowdown(client, 1.235 * 1.235);
			else if (iGameMode == GAMEMODE_VERSUS) ApplySlowdown(client, 1.235);
		} 
		else if (GetClientTeam(client) == 3 && GetInfectedClass(client) == ZC_TANK) ApplySlowdown(client, 1.0);
	}
	return Plugin_Continue;
}

//L4DT
public Action L4D_OnSpawnMob(int &amount)
{
	if (commonTank > 0 && FindTank() != -1 && IsInfiniteHordeActive())
	{
		L4D2Direct_SetPendingMobCount(0);
		amount = 0;
		return Plugin_Handled;
	}
	if (commonLimit < 0) return Plugin_Continue;
	if (IsInfiniteHordeActive())
	{
		if (!announcedInChat)
		{
			CPrintToChatAll("<{G}Horde{W}> {B}有限的{W}暴动事件开始! 总数: {G}%i{W} .", commonLimit);
			announcedInChat = true;
		}
		if (commonTotal >= commonLimit)
		{
			L4D2Direct_SetPendingMobCount(0);
			amount = 0;
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}

//Lib
public void OnRoundIsLive()
{
	int startingItem;
	float clientOrigin[3];
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index != 0)
		{
			if (GetPlayerWeaponSlot(index, 4) <= -1 && GetPlayerWeaponSlot(index, 3) <= -1)
			{
				startingItem = CreateEntityByName("weapon_pain_pills");
				GetClientAbsOrigin(index, clientOrigin);
				TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(startingItem);
				EquipPlayerWeapon(index, startingItem);
			}
		}
	}
}

public void L4D2_OnRealRoundStart()
{
	commonTotal = 0;
	lastCheckpoint = 0;
	announcedInChat = false;
	CreateTimer(1.0, RoundStartDelay, _, TIMER_REPEAT);
}

public Action RoundStartDelay(Handle timer)
{
	int client = GetInGameClient();
	if (client != -1)
	{
		if (g_iItemLimits != -1)
		{
			if (L4D2_IsFirstRound())
			{
				ItemTracking curitem;
				float origins[3], angles[3];
				int iEntCount = GetEntityCount();
				for (int i = MaxClients+1; i <= iEntCount; i++)
				{
					if (IsValidPills(i))
					{
						if (g_iItemLimits == 0)
						{
							RemoveEntityLog(i);
						}
						else if (g_iItemLimits > 0)
						{
							curitem.IT_entity = i;
							GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
							GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
							curitem.IT_origins = origins[0];
							curitem.IT_origins1 = origins[1];
							curitem.IT_origins2 = origins[2];
							curitem.IT_angles = angles[0];
							curitem.IT_angles1 = angles[1];
							curitem.IT_angles2 = angles[2];
							g_hItemSpawns.PushArray(curitem, sizeof(curitem)); 
						}
					}
				}
				
				while (GetArraySize(g_hItemSpawns) > g_iItemLimits)
				{
					int killidx = GetRandomInt(0, GetArraySize(g_hItemSpawns)-1);
					g_hItemSpawns.GetArray(killidx, curitem, sizeof(curitem));
					if (IsValidPills(curitem.IT_entity)) RemoveEntityLog(curitem.IT_entity);
					RemoveFromArray(g_hItemSpawns, killidx);
				}
			}
			else
			{
				int iEntCount = GetEntityCount();
				for (int i = MaxClients+1; i <= iEntCount; i++)
				{
					if (IsValidPills(i)) RemoveEntityLog(i);
				}
				
				ItemTracking curitem;
				float origins[3], angles[3];
				for (int idx = 0; idx < GetArraySize(g_hItemSpawns); idx++)
				{
					g_hItemSpawns.GetArray(idx, curitem, sizeof(curitem));
					origins[0] = curitem.IT_origins;
					origins[1] = curitem.IT_origins1;
					origins[2] = curitem.IT_origins2;
					angles[0] = curitem.IT_angles;
					angles[1] = curitem.IT_angles1;
					angles[2] = curitem.IT_angles2;
					SpawnPills(origins, angles);
				}
			}
		}
		EntitySearchLoop();
		
		char classname[128];
		int iEntCount = GetEntityCount();
		for (int i = MaxClients+1; i <= iEntCount; i++)
		{
			WeaponId source = IdentifyWeapon(i);
			if (IsItem(source) && L4D2_IsEntityInSaferoom(i))
			{
				GetEdictClassname(i, classname, sizeof(classname));
				RemoveEntityLog(i);
				PrintToServer("[SI] Removed %s in Saferoom", classname);
			}
		}
		KillTimer(timer);
	}
}

public void L4D2_OnPlayerHurtPost(int victim, int attacker, int health, char[] Weapon, int damage, int dmgtype)
{
	if (!IsValidInGame(victim)) return;
	if (GetClientTeam(victim) == 3) ApplySlowdown(victim, 1.0);
}

//Event
public Action Incap_Event(Event event, char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    SetEntPropFloat(client, Prop_Send, "m_healthBufferTime", GetGameTime());
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);
}

public Action JockeyRideEnd(Event event, char[] name, bool dontBroadcast)
{
    int jockeyAttacker = GetClientOfUserId(event.GetInt("userid"));
    int jockeyVictim = GetClientOfUserId(event.GetInt("victim"));
    if (IsHangingFromLedge(jockeyVictim)) FixupJockeyTimer(jockeyAttacker);
}

public Action OnPlayerUse(Event event, const char[] name, bool dontBroadcast) 
{
	EntitySearchLoop();
}

public Action OutSkilled(Event event, char[] name, bool dontBroadcast)
{
	int shovee = GetClientOfUserId(event.GetInt("userid"));
	int shover = GetClientOfUserId(event.GetInt("attacker"));
	if (!IsValidSurvivor(shover) || !IsValidInfected(shovee)) return;
	int zClass = GetInfectedClass(shovee);
	if (zClass != 3 && zClass != 5 && zClass != 1) return;
	
	if (zClass == ZC_SMOKER) return;
	CreateTimer(staggerTime - 0.1, ResetAbilityTimer, shovee);
}

public Action ResetAbilityTimer(Handle timer, any shovee)
{
	if (!IsValidInfected(shovee)) return;
	int zClass = GetInfectedClass(shovee);
	float time = GetGameTime();
	float recharge;
	if (zClass == ZC_HUNTER) recharge = fPounceCrouchDelay;
	else recharge = fLeapInterval;
	float timestamp;
	float duration;
	if (!GetInfectedAbilityTimer(shovee, timestamp, duration)) return;
	duration = time + recharge + 0.1;
	if (duration > timestamp) SetInfectedAbilityTimer(shovee, duration, recharge);
}

//Command
public Action AddWeaponRuleCb(int args)
{
    if (args < 2)
    {
        LogMessage("Usage: l4d2_addweaponrule <match> <replace>");
        return Plugin_Handled;
    }
    char weaponbuf[64];
    GetCmdArg(1, weaponbuf, sizeof(weaponbuf));
    WeaponId match = WeaponNameToId2(weaponbuf);
    GetCmdArg(2, weaponbuf, sizeof(weaponbuf));
    WeaponId to = WeaponNameToId2(weaponbuf);
	if (IsValidWeaponId(match) && (to == view_as<WeaponId>(-1) || IsValidWeaponId(to))) g_GlobalWeaponRules[match] = view_as<int>(to);
    return Plugin_Handled;
}

public Action ResetWeaponRulesCb(int args)
{
    for (int i = 0; i < view_as<int>(MAX_SIZE_WeaponId); i++) g_GlobalWeaponRules[i] = -1;
    return Plugin_Handled;
}

//Stock
void DisableClips()
{
    ModifyEntity("env_player_blocker", "Disable");
}

void DisableFuncBrush()
{
    ModifyEntity("func_brush", "Kill");
}

void ModifyEntity(char[] className, char[] inputName)
{ 
    int iEntity;
    while ((iEntity = FindEntityByClassname(iEntity, className)) != -1)
    {
        if (!IsValidEdict(iEntity) || !IsValidEntity(iEntity)) continue;
        AcceptEntityInput(iEntity, inputName);
    }
}

void ApplySlowdown(int client, float value)
{
	if (value == -1.0) return;
	SetEntPropFloat(client, Prop_Send, "m_flVelocityModifier", value);
}

bool IsLimping(int client)
{
	int PermHealth = GetClientHealth(client);
	float buffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float bleedTime = GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float decay = GetConVarFloat(FindConVar("pain_pills_decay_rate"));
	float TempHealth = CLAMP(buffer - (bleedTime * decay), 0.0, 100.0); // buffer may be negative, also if pills bleed out then bleedTime may be too large.
	return RoundToFloor(PermHealth + TempHealth) < GetConVarInt(FindConVar("survivor_limp_health"));
}

void FixupJockeyTimer(int client)
{
    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "ability_leap")) != -1)
	{
        if (GetEntPropEnt(iEntity, Prop_Send, "m_owner") == client) break;
    }
    if (iEntity == -1) return;
    SetEntPropFloat(iEntity, Prop_Send, "m_timestamp", GetGameTime() + 12.0);
    SetEntPropFloat(iEntity, Prop_Send, "m_duration", 12.0);
}

void EntitySearchLoop()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (RemoveItemList(i)) RemoveEntityLog(i);
		
		WeaponId source = IdentifyWeapon(i);
		if (source > WEPID_NONE)
		{
			if (source == WEPID_FIRST_AID_KIT && !L4D2_IsEntityInSaferoom(i))
			{
				if (bReplaceFinaleKits && L4D_IsMissionFinalMap()) ReplaceSpawnPills(i);
				else RemoveEntityLog(i);
			}
			else if (g_GlobalWeaponRules[source] != -1)
			{
				if(g_GlobalWeaponRules[source] == view_as<int>(WEPID_NONE)) RemoveEntityLog(i);
				else ConvertWeaponSpawn(i, view_as<WeaponId>(g_GlobalWeaponRules[source]));
			}
		}
	}
}

void SpawnCommon(float location[3])
{
    int zombie = CreateEntityByName("infected");
    int ticktime = RoundToNearest( GetGameTime() / GetTickInterval() ) + 5;
    SetEntProp(zombie, Prop_Data, "m_nNextThinkTick", ticktime);
    DispatchSpawn(zombie);
    ActivateEntity(zombie);
    TeleportEntity(zombie, location, NULL_VECTOR, NULL_VECTOR);
}

void ReplaceSpawnPills(int entity)
{
	float origin[3], angles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);
	RemoveEntityLog(entity);
	SpawnPills(origin, angles);
}

void SpawnPills(float origin[3], float angles[3])
{
	int entity = CreateEntityByName("weapon_spawn");
	SetEntProp(entity, Prop_Send, "m_weaponID", WEPID_PAIN_PILLS);
	DispatchKeyValue(entity, "count", "1");
	TeleportEntity(entity, origin, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);
}

bool IsItem(WeaponId source)
{
	if (source >= WEPID_FIRST_AID_KIT && source <= WEPID_OXYGEN_TANK) return true;
	if (source == WEPID_MELEE) return true;
	if (source == WEPID_CHAINSAW) return true;
	if (source >= WEPID_ADRENALINE && source <= WEPID_VOMITJAR) return true;
	if (source >= WEPID_COLA_BOTTLES && source <= WEPID_FRAG_AMMO) return true;
	return false;
}

bool IsInfiniteHordeActive()
{
	int countdown = CTimer_HasStarted(L4D2Direct_GetMobSpawnTimer()) ? RoundFloat(CTimer_GetRemainingTime(L4D2Direct_GetMobSpawnTimer())) : -1;
	return (countdown > -1 && countdown <= 10);
}

bool RemoveItemList(int entity)
{
	if (entity <= 0 || entity > 2048 || !IsValidEntity(entity) || !IsValidEdict(entity)) return false;
    char class[128], model[128];
	GetEdictClassname(entity, class, sizeof(class));
    if (StrEqual(class,"prop_physics", false) && GetEntProp(entity, Prop_Send, "m_isCarryable"))
    {
		GetEntityModelName(entity, model, sizeof(model));
        if (StrEqual(model, "models/props_junk/gascan001a.mdl", false)) return true;
        if (StrEqual(model, "models/props_junk/propanecanister001a.mdl", false)) return true;
        if (StrEqual(model, "models/props_equipment/oxygentank01.mdl", false)) return true;
        if (StrEqual(model, "models/props_junk/explosive_box001.mdl", false)) return true;
    }
	if (StrEqual(class,"upgrade_laser_sight", false)) return true;
	if (StrEqual(class,"prop_minigun_l4d1", false)) return true;
	if (StrEqual(class,"prop_minigun", false)) return true;
	if (StrEqual(class,"prop_fuel_barrel", false)) return true;
	if (StrEqual(class, "weapon_ammo_spawn", false)) return true;
	
    return false;
}

bool isUncommon(int entity)
{
	char model[128];
	GetEntityModelName(entity, model, sizeof(model));
	if (StrContains(model, "_ceda", false) != -1) return true;
	if (StrContains(model, "_clown", false) != -1) return true;
	if (StrContains(model, "_mud", false) != -1) return true;
	if (StrContains(model, "_riot", false) != -1) return true;
	if (StrContains(model, "_roadcrew", false) != -1) return true;
    return false;
}

WeaponId WeaponNameToId2(const char[] name)
{
    static char namebuf[64]="weapon_";
    WeaponId wepid = WeaponNameToId(name);
    if (wepid == WEPID_NONE)
    {
        strcopy(namebuf[7], sizeof(namebuf)-7, name);
        wepid = WeaponNameToId(namebuf);
    }
    return wepid;
}

int GetInGameClient()
{
	for (int x = 1; x <= GetClientCount(true); x++)
	{
		if (IsClientInGame(x) && GetClientTeam(x) == 2) return x;
	}
	return -1;
}

bool IsValidPills(int entity)
{
	if (!IsValidEntity(entity) || !IsValidEdict(entity) || L4D2_IsEntityInSaferoom(entity)) return false;
	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	if (StrEqual(classname, "weapon_pain_pills_spawn", false) || StrEqual(classname, "weapon_pain_pills", false)) return true;
	if (StrEqual(classname, "weapon_spawn") || StrEqual(classname, "weapon_item_spawn"))
	{
		if (view_as<WeaponId>(GetEntProp(entity, Prop_Send, "m_weaponID")) == WEPID_PAIN_PILLS) return true;
	}
	return false;
}
