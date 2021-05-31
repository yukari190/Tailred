/**
 * vim  set ts=4
 * =============================================================================
 *
 * l4d2util plugin
 * Copyright (C) 2012-2015 "Confogl Team"
 *
 * l4d2lib plugin
 * Copyright (C) 2015 "Confogl Team"
 *
 * l4d2_saferoom_detect plugin
 * Copyright (C) 2015 "Tabun, devilesk"
 *
 * l4d2_weapon_stocks.inc include
 *
 * colors.inc include
 *
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http //www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http //www.sourcemod.net/license.php>.
 *
 * Version  $Id$
 */

#if defined _l4d2library_included
 #endinput
#endif
#define _l4d2library_included


#define NUM_OF_SURVIVORS 4


// ====================================================================================================
// l4d2lib.inc
// ====================================================================================================
enum L4D2_Team
{
	L4D2Team_None,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

enum L4D2_Infected
{
	L4D2Infected_None,
	L4D2Infected_Smoker,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank
}

enum L4D2_SurvivorCharacter
{
	L4D2SurvivorCharacter_None = -1,
	L4D2SurvivorCharacter_Coach = 0,
	L4D2SurvivorCharacter_Nick,
	L4D2SurvivorCharacter_Rochelle,
	L4D2SurvivorCharacter_Ellis,
	L4D2SurvivorCharacter_Louis,
	L4D2SurvivorCharacter_Zoey,
	L4D2SurvivorCharacter_Bill,
	L4D2SurvivorCharacter_Francis
}

enum L4D2GlowType 
{ 
	L4D2Glow_None = 0, 
	L4D2Glow_OnUse, 
	L4D2Glow_OnLookAt, 
	L4D2Glow_Constant 
}





// ====================================================================================================
// FORWARDS - l4d2lib.inc
// ====================================================================================================
/**
 * Called on a real L4D2 round_start
 *
 * @noreturn
 */
forward void L4D2_OnRealRoundStart();

/**
 * Called on a real L4D2 round_end
 *
 * @noreturn
 */
forward void L4D2_OnRealRoundEnd();

/**
 * @Called when a tank is first spawned into the game
 * 
 * @param tankClient		The client index of the tank
 * @noreturn
 */
forward void L4D2_OnTankFirstSpawn(int tankClient);

/**
 * @Called when a tank passes from one client to another
 * 
 * @param oldTank			The client index of the previous tank
 * @param newTank			The client index of the new tank
 * @param passCount			The number of times this tank has been passed
 * @noreturn
 */
forward void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount);

/**
 * @Called 0.5s after a tank death
 * 
 * @param tankClient		The client index of the tank that died
 * @noreturn
 */
forward void L4D2_OnTankDeath(int tankClient, int attacker);

/**
 * Called on a real L4D2 player_hurt
 *
 * @param victim 	client who was hurt
 * @param attacker 	entity id who attacked, if attacker not a player, and userid therefore invalid
 * @param health 	remaining health points
 * @param weapon 	weapon name attacker used, if not the world
 * @param damage 	damage done to health
 * @param dmgtype 	damage type 
 * @param hitgroup 	hitgroup that was damaged
 * @noreturn
 */
forward void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype, int hitgroup);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnJoinSurvivor(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnAwaySurvivor(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnJoinInfected(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnAwayInfected(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnPlayerTeamChanged(int client, int oldteam, int team);

/**
 * 
 *
 * @param 
 * @return 
 */
forward void L4D2_OnInfectedSpawn(int client, L4D2_Infected class);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnTankRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnSmokerRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnHunterRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnJockeyRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnBoomerRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnSpitterRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward Action L4D2_OnChargerRunCmd(int client, int &buttons, float vel[3], float angles[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
forward void L4D2_OnEntitySpawned(int entity, char[] classname);





// ====================================================================================================
// NATIVES - l4d2lib.inc
// ====================================================================================================



/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_SetMaxPlayers(int amount);

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_ChangeClientTeam(int client, L4D2_Team team, bool force = false);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_FillBots();

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_RestoreHealth(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_ResetInventory(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_IsLanIP(char[] src);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_SetAnimFling(int client, int attacker, float vector[3]);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_SetPlayerRespawn(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_PauseClient(int client, bool b);

/**
 * If this in-game and fully connected client is a caster or not
 *
 * @return          True if this is a registered caster
 */
native bool L4D2_IsClientCaster(int client);

/**
 * If this Steam ID is a registered caster or not
 *
 * @param           String containing the user's auth id
 * @return          True if this is a registered caster
 */
native bool L4D2_IsIDCaster(const char[] AuthID);

/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_GetRandomSurvivor();

/**
 * Identifies a client's survivor character based on their current model.
 * @remark L4D2SurvivorCharacter_None on errors
 *
 * @param client                Survivor client to identify
 * @return L4D2_SurvivorCharacter    index identifying the survivor, or L4D2SurvivorCharacter_None if not identified.
 */
native L4D2_SurvivorCharacter L4D2_IdentifySurvivor(int client);

/**
 * Identifies the survivor character corresponding to a player model.
 * @remark L4D2SurvivorCharacter_None on errors, uses SurvivorModelTrie
 *
 * @param model                 Player model to identify
 * @return L4D2_SurvivorCharacter    index identifying the model, or L4D2SurvivorCharacter_None if not identified.
 */
native L4D2_SurvivorCharacter L4D2_ClientModelToSC(const char[] model);

/**
 * Get the name of a survivor character.
 *
 * @param character     L4D2_SurvivorCharacter to get the name of
 * @param buffer        buffer to store name
 * @param length        length of buffer
 * @return bool         false if L4D2SurvivorCharacter_None, otherwise true
 */
native bool L4D2_GetSurvivorName(int character, char[] buffer, int length);

/**
 * Converts an infected type ID to a string.
 *
 * @param iClass infected class ID
 * @param sBuffer buffer to store the class name in
 * @param iBufLen size of sBuffer
 * @noreturn
 */
native void L4D2_GetInfectedClassName(L4D2_Infected iClass, char[] sBuffer, int iBufLen);

/**
 * 在键输入过程中用于繁忙循环和状态维持的变量
 *
 * 死的时候不过关的话会留下之前的信息
 * 做得不太在意
 */
native void L4D2_DelayStart(int client, int no);
native bool L4D2_DelayExpired(int client, int no, float delay);
native float L4D2_SetState(int client, int no, int value);
native int L4D2_GetState(int client, int no);

/**
 * 获取离client最近的生存者的距离
 *
 * 因为我们现在没有追踪,所以我们在一楼和二楼,隔壁的房间
 * 即使有遮挡,也会变得很近
 */
native float L4D2_NearestSurvivorDistance(int client);
native float L4D2_NearestActiveSurvivorDistance(int client);

/**
 * 计算每个客户端的当前移动速度
 *
 * g_move_speedは生存者が直線に走ったときが220くらい
 * 可以判断是跑还是停
 */
native float L4D2_GetMoveSpeed(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_IsCoop();

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_IsVersus();

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_IsScavenge();

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_IsSurvival();

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_GetTankToSpawn();

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_SetTankToSpawn(bool spawn);

/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_GetTankFlowPercent();

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_SetTankFlowPercent(float flow);

/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_GetFurthestSurvivorFlow2();
	
/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_GetHighestSurvivorFlow();


//native float L4D2_GetTankFlow();

/**
 * Returns the amount of permanent health a survivor has. 
 *
 * @param client client ID
 * @return int
 */
stock int L4D2_GetSurvivorPermanentHealth(int client)
{
	int iHealth = GetEntProp(client, Prop_Send, "m_iHealth");
	return GetEntProp(client, Prop_Send, "m_currentReviveCount") > 0 ? 0 : (iHealth > 0 ? iHealth : 0);
}

/**
 * Returns the amount of temporary health a survivor has. 
 *
 * @param client client ID
 * @return float
 */
native float L4D2_GetSurvivorTemporaryHealth(int client);

/**
 * 获取受感染的受害者. 受害者是一名幸存者, 目前正在被控制, 即吸烟, 被控, 狩猎或骑师.
 *
 * @param client whose victim to get
 * @return client ID or -1 on error
 */
native int L4D2_GetInfectedVictim(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_IsBeingAttacked(int survivor);

/**
 * Get the timestamp and duration of an SI's ability timer
 *
 * @param client whose timer to get
 * @param timestamp output parameter for the timestamp
 * @param duration output parameter for the duration
 * @return true if the timer was found otherwise false
 */
stock bool L4D2_GetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
	int ability = GetInfectedCustomAbility(client);
	if (ability == -1) return false;
	timestamp = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
	duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
	return true;
}

/**
 * Set the timestamp and duration of an SI's ability timer
 *
 * @param client whose timer to set
 * @param timestamp
 * @param duration
 * @return true if the timer was found otherwise false
 */
stock bool L4D2_SetInfectedAbilityTimer(int client, float timestamp, float duration)
{
	int ability = GetInfectedCustomAbility(client);
	if (ability == -1) return false;
    SetEntPropFloat(ability, Prop_Send, "m_timestamp", timestamp);
    SetEntPropFloat(ability, Prop_Send, "m_duration", duration);
	return true;
}

stock float L4D2_GetAbilityCooldownDuration(int client)
{
	int ability = GetInfectedCustomAbility(client);
	if (ability != -1 && GetEntProp(ability, Prop_Send, "m_hasBeenUsed"))
	{
		return GetEntPropFloat(ability, Prop_Send, "m_duration");
	}
	return 0.0;
}

stock float L4D2_GetAbilityCooldown(int client)
{
	int ability = GetInfectedCustomAbility(client);
	if (ability != -1 && GetEntProp(ability, Prop_Send, "m_hasBeenUsed"))
	{
		if (GetEntPropFloat(ability, Prop_Send, "m_duration") != 3600.0)
			return GetEntPropFloat(ability, Prop_Send, "m_timestamp") - GetGameTime();
	}
	return 0.0;
}

stock int GetInfectedCustomAbility(int client)
{
	if (HasEntProp(client, Prop_Send, "m_customAbility"))
	{
		return GetEntPropEnt(client, Prop_Send, "m_customAbility");
	}
	return -1;
}

/**
 * 目前正在玩这张地图的第二轮?
 *
 * @return bool
 */
native bool L4D2_IsSecondRound();

/**
 * 
 *
 * @param 
 * @return 
 */
stock int L4D2_GetScavengeRoundNumber()
{
	return GameRules_GetProp("m_nRoundNumber");
}

/**
 * 
 *
 * @param 
 * @return 
 */
native bool L4D2_CurrentlyInRound();

/**
 * @brief Returns the number of alive survivors
 * @remarks Includes all living human and bot survivors
 * 
 * @return The number of alive survivors
 */
native int L4D2_GetSurvivorCount();

/**
 * @brief Returns the survivor of a specific index
 * @remarks returns 0 if a survivor doesn't exist at the specified index
 * @params	index	the index to retrieve the client number from
 * 
 * @return Client number of a survivor stored at the given index.
 */
native int L4D2_GetSurvivorOfIndex(int index);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_GiveDefaultAmmo(int client);

/**
 * @brief Get an Int value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0)
 * @return			Integer value for given key, or defvalue if key is not found
 */
native int L4D2_GetMapValueInt(const char[] key, const int defvalue = 0);

/**
 * @brief Get a Float value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0.0)
 * @return			Float value for given key, or defvalue if key is not found
 */
native float L4D2_GetMapValueFloat(const char[] key, const float defvalue = 0.0);

/**
 * @brief Get a Vector from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param vector	Vector to store the result in
 * @param defvalue	Default value to use if key is not found (default NULL_VECTOR)
 * @noreturn
 */
native void L4D2_GetMapValueVector(const char[] key, float vector[3], const float defvalue[3]=NULL_VECTOR);

/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool L4D2_IsEntityInSaferoom(int entity);

/*
  Check if player (client) is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
//native bool L4D2_IsPlayerInSaferoom(int client);

/**
 * 
 *
 * @param 
 * @return 
 */
stock void L4D2_GetEntityModelName(int entity, char[] name, int size)
{
	GetEntPropString(entity, Prop_Data, "m_ModelName", name, size);
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsServerActive()
{
	if (!IsServerProcessing()) return false;
	for (int x = 1; x <= MaxClients; x++)
	{
		if (IsClientInGame(x) && !IsFakeClient(x)) return true;
	}
	return false;
}

/**
 * 比较两个数的大小
 *
 * @param 浮点数1 浮点数2
 * @return 最小的值
 */
stock any L4D2_Min(any value1, any value2)
{
	return ((value1 < value2) ? value1 : value2);
}

/**
 * 比较两个数的大小
 *
 * @param 浮点数1 浮点数2
 * @return 最大的值
 */
stock any L4D2_Max(any value1, any value2)
{
	return ((value1 > value2) ? value1 : value2);
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock any L4D2_Clamp(any value, any min, any max)
{
	return ((value > max) ? max : ((value < min) ? min : value));
}

/**
 * 判断有效的客户端
 *
 * @param client client ID
 * @return bool
 */
stock bool L4D2_IsValidClient(int client)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client);
}

/**
 * 判断客户端为旁观者
 *
 * @param client client ID
 * @return bool
 */
stock bool L4D2_IsSpectator(int client)
{
	return GetClientTeam(client) == 1;
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsSurvivor(int client)
{
	return GetClientTeam(client) == 2;
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsInfected(int client)
{
	return GetClientTeam(client) == 3;
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsClientAdmin(int client)
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

/**
 * 如果幸存者被挂到窗台(或从一个下降到灭亡), 则返回true.
 *
 * @param client client ID
 * @return bool
 */
stock bool L4D2_IsHangingFromLedge(int client)
{
	return !!(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsBeingDragged(int client)
{
	return !!(GetEntProp(client, Prop_Send, "m_tongueOwner") && !(GetEntProp(client, Prop_Send, "m_isHangingFromTongue")));
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_IsBeingChoked(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isHangingFromTongue");
}

/**
 * Returns the ID of the client's infected class. Use GetInfectedClassName()
 * to convert it to a string.
 *
 * @param client client ID
 * @return class ID
 */
stock L4D2_Infected L4D2_GetInfectedClass(int client)
{
	return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

/**
 * Return true if the infected is in ghost (spawn) mode.
 *
 * @param client client ID
 * @return bool
 */
stock bool L4D2_IsInfectedGhost(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isGhost");
}

/**
 * 如果玩家无行为能力, 则返回true. 
 *
 * @param client client ID
 * @return bool
 */
stock bool L4D2_IsPlayerIncap(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_isIncapacitated");
}

/**
 * The number of times a survivor has been incapacitated.
 *
 * @param client client ID
 * @return incap count
 */
stock int L4D2_GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock bool L4D2_HasVisibleThreats(int client)
{
	return !!GetEntProp(client, Prop_Send, "m_hasVisibleThreats");
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int L4D2_FindAnyTank()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (
			IsClientInGame(i) && 
			GetClientTeam(i) == 3 && 
			IsPlayerAlive(i) && 
			GetEntProp(i, Prop_Send, "m_zombieClass") == view_as<int>(L4D2Infected_Tank)
		) return i;
	}
	return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool L4D2_AnyTankInPlay()
{
	return L4D2Direct_GetTankCount() > 0;
}

/**
 * Tanks frustation level in the range 0-100, where 100 is when the rage meter
 * is full.
 *
 * @param iTankClient tank's client ID
 * @return frustration level
 */
stock int L4D2_GetTankFrustration(int iTankClient)
{
	return 100 - GetEntProp(iTankClient, Prop_Send, "m_frustration");
}

/**
 * Sets the tank's frustration level.
 *
 * @param iTankClient tank's client ID
 * @param iFrustration frustration level (0-100)
 * @noreturn
 */
stock void L4D2_SetTankFrustration(int iTankClient, int iFrustration)
{
	if (iFrustration < 0 || iFrustration > 100) return;
	SetEntProp(iTankClient, Prop_Send, "m_frustration", 100 - iFrustration);
}

/**
 * Is the tank able to punch the entity with the tank for instant incaps? 
 *
 * @param iEntity entity ID
 * @return bool
 */
stock bool L4D2_IsTankHittable(int iEntity)
{
	if (!IsValidEntity(iEntity)) return false;
	char className[64];
	GetEdictClassname(iEntity, className, sizeof(className));
	if (StrEqual(className, "prop_physics"))
	{
		if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) return true;
	}
	else if (StrEqual(className, "prop_car_alarm")) return true;
	return false;
}

/**
 * Set entity glow. This is consider safer and more robust over setting each glow
 * property on their own because glow offset will be check first.
 *
 * @param entity        Entity index.
 * @parma type            Glow type.
 * @param range            Glow max range, 0 for unlimited.
 * @param minRange        Glow min range.
 * @param colorOverride Glow color, RGB.
 * @param flashing        Whether the glow will be flashing.
 * @return                True if glow was set, false if entity does not support
 *                        glow.
 */
stock bool L4D2_SetEntGlow(int entity, L4D2GlowType type, int range, int minRange, int colorOverride[3], bool flashing)
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, sizeof(netclass));
	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1) return false;
	SetEntProp(entity, Prop_Send, "m_iGlowType", view_as<int>(type));
	SetEntProp(entity, Prop_Send, "m_nGlowRange", range);
	SetEntProp(entity, Prop_Send, "m_nGlowRangeMin", minRange);
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
	SetEntProp(entity, Prop_Send, "m_bFlashing", view_as<int>(flashing));
	return true;
}
stock bool L4D2_SetEntGlowOverride(int entity, int colorOverride[3])
{
	char netclass[128];
	GetEntityNetClass(entity, netclass, sizeof(netclass));
	int offset = FindSendPropInfo(netclass, "m_iGlowType");
	if (offset < 1) return false;
	SetEntProp(entity, Prop_Send, "m_glowColorOverride", colorOverride[0] + (colorOverride[1] * 256) + (colorOverride[2] * 65536));
	return true;
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock void L4D2_CheatCommand(int commandDummy, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (!L4D2_IsValidClient(commandDummy))
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i) && IsFakeClient(i))
				{
					char clientName[32];
					GetClientName(i, clientName, sizeof(clientName));
					if (StrContains(clientName, "[CommandBot]") != -1) commandDummy = i;
				}  		
			}
			if (!L4D2_IsValidClient(commandDummy) || IsClientInKickQueue(commandDummy))
			{
				commandDummy = CreateFakeClient("[CommandBot]");
				if (L4D2_IsValidClient(commandDummy))
				  ChangeClientTeam(commandDummy, 1);
			}
		}
		if (L4D2_IsValidClient(commandDummy))
		{
		    int originalUserFlags = GetUserFlagBits(commandDummy);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(commandDummy, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(commandDummy, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(commandDummy, originalUserFlags);            
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
		CreateTimer(0.1, Timer_KickBot, commandDummy);
    }
}
public Action Timer_KickBot(Handle timer, any client)
{
	if (L4D2_IsValidClient(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client, "");
	}
}

/**
 * Returns the flow distance of a given point
 */
stock int GetFlow(const float o[3])
{
	float origin[3]; //non constant var
	origin[0] = o[0];
	origin[1] = o[1];
	origin[2] = o[2];
	Address pNavArea;
	pNavArea = L4D2Direct_GetTerrorNavArea(origin);
	if (pNavArea != Address_Null)
	{
		return RoundToNearest(L4D2Direct_GetTerrorNavAreaFlow(pNavArea));
	}
	else
	{
		return -1;
	}
}





// ====================================================================================================
// NATIVES - l4d2_weapon_stocks.inc
// ====================================================================================================
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
    WEPID_UPGRADE_ITEM      // 55
}

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
    WEPID_PITCHFORK
}

enum L4D2WeaponSlot
{
    L4D2WeaponSlot_Primary,
    L4D2WeaponSlot_Secondary,
    L4D2WeaponSlot_Throwable,
    L4D2WeaponSlot_HeavyHealthItem,
    L4D2WeaponSlot_LightHealthItem
};



/**
 * Performs bounds checking to determine if a WeaponId is valid
 * @remark Simple check to see if wepid has a garbage value
 *
 * @param wepid        WeaponId to check for validity
 * @return True if wepid is valid, false otherwise.
 */
stock bool L4D2_IsValidWeaponId(WeaponId wepid)
{
    return wepid >= WEPID_NONE && wepid <= WEPID_UPGRADE_ITEM;
}

/**
 * Get the player weapon slot used by the given WeaponId.
 * 
 * @param wepid     WeaponId to get the slot for.
 * @return Slot number (0-4) or -1 for invalid WeaponId or no slot
 */
native int L4D2_GetSlotFromWeaponId(WeaponId wepid);

/**
 * Checks to see if a given weaponid has a known WeaponModel in this file's model array
 * @remark Some weapons (like weapon_melee) have multiple valid models, and this will report false for them.
 *
 * @param wepid        WeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
native bool L4D2_HasValidWeaponModel(WeaponId wepid);

/**
 * Checks to see if a given meleeweaponid has a known WeaponModel in this file's model array
 *
 * @param wepid        MeleeWeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
native bool L4D2_HasValidMeleeWeaponModel(MeleeWeaponId wepid);

/**
 * Tries to look up a WeaponId for a given Weapon Name.
 *
 * @param weaponName    Weapon name string to look up Id from
 * @return                The corresponding WeaponId if found, else WEPID_NONE
 */
native WeaponId L4D2_WeaponNameToId(const char[] weaponName);

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void L4D2_GetWeaponName(WeaponId wepid, char[] nameBuffer, int length);

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void L4D2_GetLongWeaponName(WeaponId wepid, char[] nameBuffer, int length);

/**
 * Tries to look up L4D2's internal weapon name for a given MeleeWeaponId.
 *
 * @param wepid            MeleeWeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void L4D2_GetLongMeleeWeaponName(MeleeWeaponId wepid, char[] nameBuffer, int length);

/**
 * Performs bounds checking to determine if a MeleeWeaponId is valid
 * @remark Simple check to see if wepid has a garbage value
 *
 * @param wepid        MeleeWeaponId to check for validity
 * @return True if wepid is valid, false otherwise.
 */
stock bool L4D2_IsValidMeleeWeaponId(MeleeWeaponId wepid)
{
    return wepid >= WEPID_MELEE_NONE && wepid <= WEPID_PITCHFORK;
}

/**
 * Tries to look up the weapon model for a given WeaponId.
 * @remarks You should use HasValidWeaponModel to make sure the WeaponId you're looking up has a valid model associated with it.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponid or no weapon model available.
 */
native void L4D2_GetWeaponModel(WeaponId wepid, char[] modelBuffer, int length);

/**
 * Identifies a weapon spawn or weapon entity as a WeaponID
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return WeaponID for the entity if it is a weapon, WEPID_NONE otherwise
 */
native WeaponId L4D2_IdentifyWeapon(int entity);

// Helper function used for getting an entity's internal melee name
native bool L4D2_GetMeleeWeaponNameFromEntity(int entity, char[] buffer, int length);

/**
 * Identifies a melee weapon spawn or weapon entity as a MeleeWeaponId
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return MeleeWeaponId for the entity if it is a weapon, WEPID_MELEE_NONE otherwise
 */
native MeleeWeaponId L4D2_IdentifyMeleeWeapon(int entity);

/**
 * Attempts to convert a weapon spawn entity to a given weapon spawn
 * @remark Truthfully, this will work on any entity with origin/rotation.
 *        Also, requires the weapon to either have a Valid weapon model or have one provided
 *
 * @param entity        Index of entity to convert to weapon spawn
 * @param wepid            WeaponId of the weapon to have the spawner hold
 * @param count            Weapon count for the spawner (default 5)
 * @param model            World model to use for the weapon spawn
 * @return entity of the new weapon spawn, or -1 on errors.
 */
native int L4D2_ConvertWeaponSpawn(int entity, WeaponId wepid, int count=5, const char[] model = "");





// ====================================================================================================
// NATIVES - colors.inc
// ====================================================================================================
/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
native void L4D2_CPrintToChat(int client, const char[] szMessage, any ...);

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules)
 * @return			  No return
 */
native void L4D2_CPrintToChatAll(const char[] szMessage, any ...);



public SharedPlugin __pl_l4d2library = 
{
	name = "l4d2library",
	file = "l4d2library.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2library_SetNTVOptional()
{
	// =========================
	// l4d2util & l4d2lib & l4d2_saferoom_detect
	// =========================
	MarkNativeAsOptional("L4D2_SetMaxPlayers");
	MarkNativeAsOptional("L4D2_ChangeClientTeam");
	MarkNativeAsOptional("L4D2_FillBots");
	MarkNativeAsOptional("L4D2_RestoreHealth");
	MarkNativeAsOptional("L4D2_ResetInventory");
	MarkNativeAsOptional("L4D2_IsLanIP");
	MarkNativeAsOptional("L4D2_SetAnimFling");
	MarkNativeAsOptional("L4D2_SetPlayerRespawn");
	MarkNativeAsOptional("L4D2_PauseClient");
	MarkNativeAsOptional("L4D2_IsClientCaster");
	MarkNativeAsOptional("L4D2_IsIDCaster");
	MarkNativeAsOptional("L4D2_GetRandomSurvivor");
	MarkNativeAsOptional("L4D2_IdentifySurvivor");
	MarkNativeAsOptional("L4D2_ClientModelToSC");
	MarkNativeAsOptional("L4D2_GetSurvivorName");
	MarkNativeAsOptional("L4D2_GetInfectedClassName");
	MarkNativeAsOptional("L4D2_DelayStart");
	MarkNativeAsOptional("L4D2_DelayExpired");
	MarkNativeAsOptional("L4D2_SetState");
	MarkNativeAsOptional("L4D2_GetState");
	MarkNativeAsOptional("L4D2_NearestSurvivorDistance");
	MarkNativeAsOptional("L4D2_NearestActiveSurvivorDistance");
	MarkNativeAsOptional("L4D2_GetMoveSpeed");
	MarkNativeAsOptional("L4D2_IsCoop");
	MarkNativeAsOptional("L4D2_IsVersus");
	MarkNativeAsOptional("L4D2_IsScavenge");
	MarkNativeAsOptional("L4D2_IsSurvival");
	MarkNativeAsOptional("L4D2_GetTankToSpawn");
	MarkNativeAsOptional("L4D2_SetTankToSpawn");
	MarkNativeAsOptional("L4D2_GetTankFlowPercent");
	MarkNativeAsOptional("L4D2_SetTankFlowPercent");
	MarkNativeAsOptional("L4D2_GetFurthestSurvivorFlow2");
	MarkNativeAsOptional("L4D2_GetHighestSurvivorFlow");
	//MarkNativeAsOptional("L4D2_GetTankFlow");
	MarkNativeAsOptional("L4D2_GetSurvivorTemporaryHealth");
	MarkNativeAsOptional("L4D2_GetInfectedVictim");
	MarkNativeAsOptional("L4D2_IsBeingAttacked");
	MarkNativeAsOptional("L4D2_IsSecondRound");
	MarkNativeAsOptional("L4D2_CurrentlyInRound");
	MarkNativeAsOptional("L4D2_GetSurvivorCount");
	MarkNativeAsOptional("L4D2_GetSurvivorOfIndex");
	MarkNativeAsOptional("L4D2_GiveDefaultAmmo");
	MarkNativeAsOptional("L4D2_GetMapValueInt");
	MarkNativeAsOptional("L4D2_GetMapValueFloat");
	MarkNativeAsOptional("L4D2_GetMapValueVector");
	MarkNativeAsOptional("L4D2_IsEntityInSaferoom");
	//MarkNativeAsOptional("L4D2_IsPlayerInSaferoom");
	
	// =========================
	// l4d2_weapon_stocks.inc
	// =========================
	MarkNativeAsOptional("L4D2_GetSlotFromWeaponId");
	MarkNativeAsOptional("L4D2_HasValidWeaponModel");
	MarkNativeAsOptional("L4D2_HasValidMeleeWeaponModel");
	MarkNativeAsOptional("L4D2_WeaponNameToId");
	MarkNativeAsOptional("L4D2_GetWeaponName");
	MarkNativeAsOptional("L4D2_GetLongWeaponName");
	MarkNativeAsOptional("L4D2_GetLongMeleeWeaponName");
	MarkNativeAsOptional("L4D2_GetWeaponModel");
	MarkNativeAsOptional("L4D2_IdentifyWeapon");
	MarkNativeAsOptional("L4D2_GetMeleeWeaponNameFromEntity");
	MarkNativeAsOptional("L4D2_IdentifyMeleeWeapon");
	MarkNativeAsOptional("L4D2_ConvertWeaponSpawn");
	
	// =========================
	// colors.inc
	// =========================
	MarkNativeAsOptional("L4D2_CPrintToChat");
	MarkNativeAsOptional("L4D2_CPrintToChatAll");
}
#endif
