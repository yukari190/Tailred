#if defined l4d2util_inc_
	#endinput
#endif
#define l4d2util_inc_

//#pragma semicolon 1

enum L4D2_Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected,
	
	L4D2Team_Size //4 size
};

//The official order of characters in the game
enum L4D2_Infected
{
	L4D2Infected_Common = 0,
	L4D2Infected_Smoker = 1,
	L4D2Infected_Boomer,
	L4D2Infected_Hunter,
	L4D2Infected_Spitter,
	L4D2Infected_Jockey,
	L4D2Infected_Charger,
	L4D2Infected_Witch,
	L4D2Infected_Tank,
	L4D2Infected_Survivor,
	
	L4D2Infected_Size //10 size
};

enum L4D2_Gender
{
	L4D2Gender_Neutral			= 0,
	L4D2Gender_Male				= 1,
	L4D2Gender_Female			= 2,
	L4D2Gender_Nanvet			= 3, //Bill
	L4D2Gender_TeenGirl			= 4, //Zoey
	L4D2Gender_Biker			= 5, //Francis
	L4D2Gender_Manager			= 6, //Louis
	L4D2Gender_Gambler			= 7, //Nick
	L4D2Gender_Producer			= 8, //Rochelle
	L4D2Gender_Coach			= 9, //Coach
	L4D2Gender_Mechanic			= 10, //Ellis
	L4D2Gender_Ceda				= 11,
	L4D2Gender_Crawler			= 12, //Mudman
	L4D2Gender_Undistractable	= 13, //Workman
	L4D2Gender_Fallen			= 14,
	L4D2Gender_Riot_Control		= 15, //RiotCop
	L4D2Gender_Clown			= 16,
	L4D2Gender_Jimmy			= 17, //JimmyGibbs
	L4D2Gender_Hospital_Patient	= 18,
	L4D2Gender_Witch_Bride		= 19,
	L4D2Gender_Police			= 20, //l4d1 RiotCop (was removed from the game)
	L4D2Gender_Male_L4D1		= 21,
	L4D2Gender_Female_L4D1		= 22,
	
	L4D2Gender_MaxSize //23 size
};

// Animation IDs used by CTerrorPlayer::DoAnimationEvent
// Gaps do not mean the animation doesn't exist, just that I don't know what it maps to.
enum Animation
{
	ANIM_RELOAD_PISTOL_UZI_SNIPER = 4,
	ANIM_RELOAD_SHOTGUN = 5,
	ANIM_RELOAD_SHOTGUN_FINAL = 6,
	ANIM_JUMP = 7,
	ANIM_LAND = 8,
	ANIM_TANK_DEATH = 10,
	ANIM_HUNTER_CLEAR = 18,
	ANIM_BACK_TO_IDLE = 20,
	ANIM_TANK_PUNCH = 33,
	ANIM_SHOVE_COMMON = 34,
	ANIM_SHOVE = 35,
	ANIM_START_RELOADING_SHOTGUN = 38, // Secondary value: Number of shells to reload
	ANIM_ATTACKA = 40,
	ANIM_ATTACKB = 41,
	ANIM_HEAL_SELF = 42,
	ANIM_HEAL_OTHER = 43,
	ANIM_PICKUP_START_HELPER = 44,
	ANIM_PICKUP_DEFIB_DEPLOY_STOP = 46,
	ANIM_PICKUP_START_SUBJECT = 47,
	ANIM_PICKUP_STOP_SUBJECT = 48,
	ANIM_PICKUP_SUCCESS_SUBJECT = 49,
	ANIM_DEFIB_START = 50,
	ANIM_DEFIB_END = 51,
	ANIM_DEPLOY_AMMO = 52,
	ANIM_COLA_DELIVER = 55,
	ANIM_SHOVED_BY_TEAMMATE = 57,
	ANIM_TAKE_DAMAGE = 58,
	ANIM_THROW_ITEM_START = 59,
	ANIM_THROW_ITEM_FINISH = 61,
	ANIM_THROW_ITEM_CANCEL = 63,
	ANIM_USE = 64,
	ANIM_CHANGE_SLOT = 65,
	ANIM_STUMBLE = 68, // Secondary value: ??
	ANIM_SPITTER_SPIT = 70,
	ANIM_CHARGER_START_CHARGE = 71,
	ANIM_CHARGER_STUMBLE = 72, // Will also play STUMBLE (68)
	ANIM_CHARGER_GETUP = 78,
	ANIM_HUNTER_GETUP = 86,
	ANIM_SMOKER_TONGUE_FIREA = 87,
	ANIM_SMOKER_TONGUE_FIREB = 88,
	ANIM_SMOKER_CLAW_TARGET = 90,
	ANIM_SMOKER_TONGUE_BROKE = 91,
	ANIM_SURVIVOR_PULLED = 92,
	ANIM_ROCK = 93, // Secondary value: 1
	ANIM_TANK_CLIMB = 94, // Secondary value: Height (1-6)
	ANIM_TANK_PUNCH_GETUP = 96,
	ANIM_IDLE = 98,
	
	//ANIMATION_SIZE //99 size
};

stock const char L4D2_InfectedNames[view_as<int>(L4D2Infected_Size)][] =
{
	"Common",
	"Smoker",
	"Boomer",
	"Hunter",
	"Spitter",
	"Jockey",
	"Charger",
	"Witch",
	"Tank",
	"Survivor"
};

stock const char L4D2_TeamName[view_as<int>(L4D2Team_Size)][] =
{
	"None",
	"Spectator",
	"Survivors",
	"Infected"
};

stock const char L4D2_AttackerNetProps[][] =
{
	"m_tongueOwner",	// Smoker
	"m_pounceAttacker",	// Hunter
	"m_jockeyAttacker",	// Jockey
	"m_carryAttacker", // Charger carry
	"m_pummelAttacker",	// Charger pummel
};

// Internal array of strings for timer ability timer entity classnames
stock const char L4D2_InfectedTimerEntities[view_as<int>(L4D2Infected_Size)][] =
{
	"",
	"ability_tongue", //Smoker
	"ability_vomit", //Boomer
	"ability_lunge", //Hunter
	"ability_spit", //Spitter
	"ability_leap", //Jockey
	"ability_charge", //Charger
	"",
	"",
	""
};

// Internal array of strings for Infected victim netprops
stock const char L4D2_InfectedVictimNetprops[view_as<int>(L4D2Infected_Size)][] =
{
	"",
	"m_tongueVictim", //Smoker
	"",
	"m_pounceVictim", //Hunter
	"",
	"m_jockeyVictim", //Jockey
	"m_pummelVictim", //Charger
	"",
	"",
	""
};

/**
 * Returns true if the survivor was attacked
 *
 * @param client client ID
 * @return bool
 */
stock bool IsSurvivorAttacked(int survivor)
{
	for (int i = 0; i < sizeof(L4D2_AttackerNetProps); i++)
	{
		if (GetEntPropEnt(survivor, Prop_Send, L4D2_AttackerNetProps[i]) != -1)
		{
			return true;
		}
	}

	return false;
}

stock int IsBeingAttacked(int survivor)
{
	int attacker = -1;
    for (int i = 0; i < sizeof(L4D2_AttackerNetProps); i++)
	{
		attacker = GetEntPropEnt(survivor, Prop_Send, L4D2_AttackerNetProps[i]);
		if (attacker != -1)
		{
			return attacker;
		}
    }
	return -1;
}

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsSurvivor(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == view_as<int>(L4D2Team_Survivor));
}

/**
 * Returns true if the player is currently on the survivor team. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsValidSurvivor(int client)
{
	return (L4D2Util_IsValidClient(client) && IsSurvivor(client));
}

/**
 * Returns true if the player is incapacitated. 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsIncapacitated(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isIncapacitated"));
}

/**
 * Returns the amount of permanent health a survivor has. 
 *
 * @param client client ID
 * @return int
 */
stock int GetSurvivorPermanentHealth(int client)
{
	return GetEntProp(client, Prop_Send, "m_iHealth");
}

/**
 * The number of times a survivor has been incapacitated.
 *
 * @param client client ID
 * @return incap count
 */
stock int GetSurvivorIncapCount(int client)
{
	return GetEntProp(client, Prop_Send, "m_currentReviveCount");
}

/**
 * Returns true if the survivor is hanging onto a ledge (or falling from one to their doom).
 *
 * @param client client ID
 * @return bool
 */
stock bool IsHangingFromLedge(int client)
{
	return (view_as<bool>(GetEntProp(client, Prop_Send, "m_isHangingFromLedge")) 
		|| view_as<bool>(GetEntProp(client, Prop_Send, "m_isFallingFromLedge")));
}

/**
 *
 * @return: the index to a random survivor
 */
stock int GetRandomSurvivor()
{
	int survivors[MAXPLAYERS+1];
	for (int i = 0; i <= MAXPLAYERS; ++i)
	{
		survivors[i] = -1;	
	}
	int numSurvivors = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
		    survivors[numSurvivors] = i;
		    numSurvivors++;
		}
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

#define UTIL_ARRAY_INDEX_DURATION 0
#define UTIL_ARRAY_INDEX_TIMESTAMP 1

/**
 * Return true if the client is on the infected team.
 *
 * @param client client ID
 * @return bool
 */
stock bool IsInfected(int client)
{
	return (IsClientInGame(client) && GetClientTeam(client) == view_as<int>(L4D2Team_Infected));
}

stock bool IsValidInfected(int client)
{
	return L4D2Util_IsValidClient(client) && IsInfected(client);
}

/**
 * Returns the ID of the client's infected class. Use GetInfectedClassName()
 * to convert it to a string.
 *
 * @param client client ID
 * @return class ID
 */
stock L4D2_Infected GetInfectedClass(int client)
{
	return view_as<L4D2_Infected>(GetEntProp(client, Prop_Send, "m_zombieClass"));
}

/**
 * Return true if the infected is in ghost (spawn) mode.
 *
 * @param client client ID
 * @return bool
 */
stock bool IsInfectedGhost(int client)
{
	return view_as<bool>(GetEntProp(client, Prop_Send, "m_isGhost"));
}

/**
 * Converts an infected type ID to a string.
 *
 * @param iClass infected class ID
 * @param sBuffer buffer to store the class name in
 * @param iBufLen size of sBuffer
 * @noreturn
 */
stock void GetInfectedClassName(L4D2_Infected iClass, char[] sBuffer, const int iBufLen)
{
	strcopy(sBuffer, iBufLen, L4D2_InfectedNames[view_as<int>(iClass)]);
}

/**
 * Internal function for retrieving the game entity associtated with an ability
 *
 * @param owner client ID of the entity's owner
 * @param type classname of entity
 * @return entity ID or -1
 */
stock int GetInfectedAbilityEntity(int owner)
{
	return GetEntPropEnt(owner, Prop_Send, "m_customAbility");
}

/**
 * Get the timestamp and duration of an SI's ability timer
 *
 * @param client whose timer to get
 * @param timestamp output parameter for the timestamp
 * @param duration output parameter for the duration
 * @return true if the timer was found otherwise false
 */
stock bool GetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
	L4D2_Infected zClass = GetInfectedClass(client);
	if (strlen(L4D2_InfectedTimerEntities[view_as<int>(zClass)]) == 0) {
		return false;
	}

	int ability = GetInfectedAbilityEntity(client);
	if (ability == -1 || !IsValidEntity(ability)) {
		return false;
	}
	
	/*
	 * Table: m_nextActivationTimer (offset 1104) (type DT_CountdownTimer)
	 *	Member: m_duration (offset 4) (type float) (bits 0) (NoScale)
	 *	Member: m_timestamp (offset 8) (type float) (bits 0) (NoScale)
	*/
	duration = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", UTIL_ARRAY_INDEX_DURATION);
	timestamp = GetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", UTIL_ARRAY_INDEX_TIMESTAMP);

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
stock bool SetInfectedAbilityTimer(int client, float &timestamp, float &duration)
{
	L4D2_Infected zClass = GetInfectedClass(client);

	if (strlen(L4D2_InfectedTimerEntities[view_as<int>(zClass)]) == 0) {
		return false;
	}

	int ability = GetInfectedAbilityEntity(client);
	if (ability == -1 || !IsValidEntity(ability)) {
		return false;
	}
	
	/*
	 * Table: m_nextActivationTimer (offset 1104) (type DT_CountdownTimer)
	 *	Member: m_duration (offset 4) (type float) (bits 0) (NoScale)
	 *	Member: m_timestamp (offset 8) (type float) (bits 0) (NoScale)
	*/
	SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", duration, UTIL_ARRAY_INDEX_DURATION);
	SetEntPropFloat(ability, Prop_Send, "m_nextActivationTimer", timestamp, UTIL_ARRAY_INDEX_TIMESTAMP);

	return true;
}

/**
 * Gets an infected's victim. A victim is a survivor who is currently being dominated, i.e. smoked, charged, hunted or jockeyed.
 *
 * @param client whose victim to get
 * @return client ID or -1 on error
 */
stock int GetInfectedVictim(int client)
{
	L4D2_Infected zClass = GetInfectedClass(client);

	if (strlen(L4D2_InfectedVictimNetprops[view_as<int>(zClass)]) == 0) {
		return -1;
	}

	return GetEntPropEnt(client, Prop_Send, L4D2_InfectedVictimNetprops[view_as<int>(zClass)]);
}

/**
 * Gets an entity's gender
 *
 * @param entity
 * @return L4D_Gender
 */
stock L4D2_Gender GetGender(int entity)
{
	return view_as<L4D2_Gender>(GetEntProp(entity, Prop_Send, "m_Gender"));
}

/**
 * Is the player the tank? 
 *
 * @param client client ID
 * @return bool
 */
stock bool IsTank(int client)
{
	return (IsClientInGame(client)
		&& view_as<L4D2_Team>(GetClientTeam(client)) == L4D2Team_Infected
		&& GetInfectedClass(client) == L4D2Infected_Tank);
}

/**
 * Is the tank able to punch the entity with the tank for instant incaps? 
 *
 * @param iEntity entity ID
 * @return bool
 */
stock bool IsTankHittable(int iEntity)
{
	if (!IsValidEntity(iEntity)) {
		return false;
	}

	char className[64];
	GetEdictClassname(iEntity, className, sizeof(className));
	
	if (strcmp(className, "prop_physics") == 0) {
		if (GetEntProp(iEntity, Prop_Send, "m_hasTankGlow", 1)) {
			return true;
		}
	} else if (strcmp(className, "prop_car_alarm") == 0) {
		return true;
	}

	return false;
}

/**
 * Tanks frustation level in the range 0-100, where 100 is when the rage meter
 * is full.
 *
 * @param iTankClient tank's client ID
 * @return frustration level
 */
stock int GetTankFrustration(int iTankClient)
{
	int iFrustration = 100 - GetEntProp(iTankClient, Prop_Send, "m_frustration");

	return iFrustration;
}

/**
 * Sets the tank's frustration level.
 *
 * @param iTankClient tank's client ID
 * @param iFrustration frustration level (0-100)
 * @noreturn
 */
stock void SetTankFrustration(int iTankClient, int iFrustration)
{
	if (iFrustration < 0 || iFrustration > 100) {
		ThrowError("Native SetTankFrustration. Invalid parameter passed: %d", iFrustration);
	}
	
	int iSetFrustration = 100 - iFrustration;
	SetEntProp(iTankClient, Prop_Send, "m_frustration", iSetFrustration);
}

/**
 * Returns true if the entity or player is on fire.
 *
 * @param entity entity index
 * @return bool
 */
stock bool IsEntityOnFire(int entity)
{
	return view_as<bool>(GetEntityFlags(entity) & FL_ONFIRE);
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindTankClient(int iTankClient)
{
	int i = (iTankClient < 0) ? 1 : iTankClient + 1;
	
	for (; i <= MaxClients; i++) {
		if (IsTank(i)) {
			return i;
		}
	}

	return -1;
}

/**
 * Searches for a live player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindAliveTankClient()
{
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i) && IsPlayerAlive(i)) {
			return i;
		}
	}

	return -1;
}

/**
 * Is there a tank currently in play?
 *
 * @return bool
 */
stock bool IsTankInPlay()
{
	return (FindTankClient(-1) != -1);
}

/**
 * Counts the number of tanks currently in play.
 *
 * @return number of tanks in play
 */
stock int NumTanksInPlay()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsTank(i)) {
			count++;
		}
	}
	
	return count;
}


//Author - A1m`

stock bool L4D2Util_IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

stock int L4D2Util_GetMin(int a, int b)
{
	return (a < b) ? a : b;
}

stock int L4D2Util_GetMax(int a, int b)
{
	return (a > b) ? a : b;
}

stock float L4D2Util_GetMinFloat(float a, float b)
{
	return (a < b) ? a : b;
}

stock float L4D2Util_GetMaxFloat(float a, float b)
{
	return (a > b) ? a : b;
}

stock float L4D2Util_ClampFloat(float inc, float low, float high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}

stock int L4D2Util_Clamp(int inc, int low, int high)
{
	return (inc > high) ? high : ((inc < low) ? low : inc);
}

/* Unsafe functions
stock any L4D2Utill_GetMin(any a, any b)
{
	return (a < b) ? a : b;
}

stock any L4D2Utill_GetMax(any a, any b)
{
	return (a > b) ? a : b;
}
*/

stock int L4D2Util_IntToPercentInt(int iVar, int iVarMax)
{
	if (iVar > iVarMax) {
		return 100;
	} else if (iVar < 1) {
		return 0;
	}
	
	return RoundToNearest((float(iVar) / float(iVarMax)) * 100.0);
}

stock float L4D2Util_IntToPercentFloat(int iVar, int iVarMax)
{
	if (iVar > iVarMax) {
		return 100.0;
	} else if (iVar < 1) {
		return 0.0;
	}
	
	return ((float(iVar) / float(iVarMax)) * 100.0);
}

stock float L4D2Util_FloatToPercentFloat(float iVar, float iVarMax)
{
	if (iVar > iVarMax) {
		return 100.0;
	} else if (iVar < 1) {
		return 0.0;
	}
	
	return ((iVar / iVarMax) * 100.0);
}

stock int L4D2Util_FloatToPercentInt(float iVar, float iVarMax)
{
	if (iVar > iVarMax) {
		return 100;
	} else if (iVar < 1) {
		return 0;
	}
	
	return RoundToNearest((iVar / iVarMax) * 100.0);
}

stock void String_ToLower(char[] str, const int MaxSize)
{
	int iSize = strlen(str); //Сounts string length to zero terminator

	for (int i = 0; i < iSize && i < MaxSize; i++) { //more security, so that the cycle is not endless
		if (IsCharUpper(str[i])) {
			str[i] = CharToLower(str[i]);
		}
	}

	str[iSize] = '\0';
}

/**
 * 比较两个数的大小
 *
 * @param 任意1 任意2
 * @return 最小的值
 */
stock any GetMin(any value1, any value2)
{
	return ((value1 < value2) ? value1 : value2);
}

/**
 * 比较两个数的大小
 *
 * @param 任意1 任意2
 * @return 最大的值
 */
stock any GetMax(any value1, any value2)
{
	return ((value1 > value2) ? value1 : value2);
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock any GetClamp(any value, any min, any max)
{
	return ((value > max) ? max : ((value < min) ? min : value));
}

/**
 * 判断有效的客户端
 *
 * @param client client ID
 * @return bool
 */
stock bool IsValidClient(int client)
{
	return (client > 0 && client <= MaxClients);
}

stock bool IsValidAndInGame(int client)
{
	return IsValidClient(client) && IsClientInGame(client);
}

/**
 * 判断客户端为旁观者
 *
 * @param client client ID
 * @return bool
 */
stock bool IsSpectator(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == view_as<int>(L4D2Team_Spectator);
}

stock bool IsValidSpectator(int client)
{
	return L4D2Util_IsValidClient(client) && IsSpectator(client);
}

/**
 * Searches for a player who is in control of a tank.
 *
 * @param iTankClient client index to begin searching from
 * @return client ID or -1 if not found
 */
stock int FindAnyTank()
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
stock bool AnyTankInPlay()
{
	return L4D2Direct_GetTankCount() > 0;
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock void GetEdictName(int entity, char[] name, int length)
{
	GetEntPropString(entity, Prop_Data, "m_iName", name, length);
}

/**
 * 
 *
 * @param 
 * @return 
 */
stock void GetEdictModelName(int entity, char[] name, int size)
{
	GetEntPropString(entity, Prop_Data, "m_ModelName", name, size);
}


stock int GetSeriousClientCount(bool inGame = false)
{
	int clients = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (inGame)
		{
			if (IsClientInGame(i) && !IsFakeClient(i)) clients++;
		}
		else
		{
			if (IsClientConnected(i) && !IsFakeClient(i)) clients++;
		}
	}
	
	return clients;
}
