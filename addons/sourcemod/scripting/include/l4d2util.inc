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
	L4D2Gender_Neutral,
	L4D2Gender_Male,
	L4D2Gender_Female,
	L4D2Gender_Bill,
	L4D2Gender_Zoey,
	L4D2Gender_Francis,
	L4D2Gender_Louis,
	L4D2Gender_Nick,
	L4D2Gender_Rochelle,
	L4D2Gender_Coach,
	L4D2Gender_Ellis,
	L4D2Gender_CEDA,
	L4D2Gender_Mudman,
	L4D2Gender_Workman,
	L4D2Gender_Fallen,
	L4D2Gender_RiotCop,
	L4D2Gender_Clown,
	L4D2Gender_JimmyGibbs,
	L4D2Gender_HospitalPatient,
	
	L4D2Gender_MaxSize //19 size
};

/* @A1m`:
 * The correct order of characters in the game,
 * this may work correctly with a netprop 'm_survivorCharacter'.
 * We need to find out the type of map l4d1 or l4d2...
*/
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

stock const char SurvivorNames[view_as<int>(SurvivorCharacter_Size)][] =
{
	"Nick",
	"Rochelle",
	"Coach",
	"Ellis",
	"Bill",
	"Zoey",
	"Louis",
	"Francis"
};

// Models for each of the characters
stock const char SurvivorModels[view_as<int>(SurvivorCharacter_Size)][] =
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
 * Initializes internal structure necessary for IdentifySurvivor() function
 * @remark It is recommended that you run this function on plugin start, but not necessary
 *
 * @noreturn
 */
stock void InitSurvivorModelTrie()
{

}

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
 * Get the name of a survivor character. 
 * Will write to string 'None' in case of error.
 * 
 * @param character     SurvivorCharacter to get the name of
 * @param buffer        buffer to store name
 * @param length        length of buffer
 * @return bool         false if SurvivorCharacter_Invalid, otherwise true
 */
stock bool GetSurvivorName(int character, char[] buffer, int length)
{
	if (character == SurvivorCharacter_Invalid) {
		strcopy(buffer, length, "None");
		return false;
	}
	strcopy(buffer, length, SurvivorNames[view_as<int>(character)]);
    return true;
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

/**
 * Is the second round of this map currently being played?
 *
 * @return bool
 */
stock bool InSecondHalfOfRound()
{
	return L4D2_InSecondHalfOfRound();
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




enum L4D2WeaponSlot
{
	L4D2WeaponSlot_Primary,
	L4D2WeaponSlot_Secondary,
	L4D2WeaponSlot_Throwable,
	L4D2WeaponSlot_HeavyHealthItem,
	L4D2WeaponSlot_LightHealthItem,
	
	L4D2WeaponSlot_Size //5 size
};

// Weapon ID enumerations.
// These values are *NOT* arbitrary! 
// They are used in game as the weaponid for weapon_spawn entities
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

// These values are arbitrary
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

// Weapon names for each of the weapons, used in identification.
stock const char WeaponNames[view_as<int>(WEPID_SIZE)][] =
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

// Long weapon names
stock const char LongWeaponNames[view_as<int>(WEPID_SIZE)][] = 
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

// Internal names for melee weapons
stock const char MeleeWeaponNames[view_as<int>(WEPID_MELEES_SIZE)][] =
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

stock const char LongMeleeWeaponNames[view_as<int>(WEPID_MELEES_SIZE)][] =
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

// World weapon models for each of the weapons. Useful for making new weapon spawns.
// Some models are left blank because no single model can be given, the model is known or none exist.
stock const char WeaponModels[view_as<int>(WEPID_SIZE)][] =
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
	"",                                               // "/weapons/w_knife_t.mdl",
	                                                  // "/weapons/melee/w_bat.mdl",
	                                                  // "/weapons/melee/w_chainsaw.mdl
	                                                  // "/weapons/melee/w_cricket_bat.mdl",
	                                                  // "/weapons/melee/w_crowbar.mdl",
	                                                  // "/weapons/melee/w_didgeridoo.mdl",
	                                                  // "/weapons/melee/w_electric_guitar.mdl",
	                                                  // "/weapons/melee/w_fireaxe.mdl",
	                                                  // "/weapons/melee/w_frying_pan.mdl",
	                                                  // "/weapons/melee/w_golfclub.mdl",
	                                                  // "/weapons/melee/w_katana.mdl",
	                                                  // "/weapons/melee/w_machete.mdl",
	                                                  // "/weapons/melee/w_riotshield.mdl",
	                                                  // "/weapons/melee/w_tonfa.mdl"
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

stock const char MeleeWeaponModels[view_as<int>(WEPID_MELEES_SIZE)][] =
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

stock const int WeaponSlots[view_as<int>(WEPID_SIZE)] =
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

stock void InitWeaponNamesTrie()
{

}

/**
 * Initializes internal structure necessary for weapons.inc functions
 * @remark It is recommended that you run this function on plugin start, but not necessary
 *
 * @noreturn
 */
stock void L4D2Weapons_Init()
{

}

/**
 * Performs bounds checking to determine if a WeaponId is valid
 * @remark Simple check to see if wepid has a garbage value
 *
 * @param wepid        WeaponId to check for validity
 * @return True if wepid is valid, false otherwise.
 */
stock bool IsValidWeaponId(WeaponId wepid)
{
    return wepid >= WEPID_NONE && wepid <= WEPID_UPGRADE_ITEM;
}

/**
 * Get the player weapon slot used by the given WeaponId.
 * 
 * @param wepid     WeaponId to get the slot for.
 * @return Slot number (0-4) or -1 for invalid WeaponId or no slot
 */
stock int GetSlotFromWeaponId(WeaponId wepid)
{
	return IsValidWeaponId(wepid) ? WeaponSlots[wepid] : -1;
}

/**
 * Checks to see if a given weaponid has a known WeaponModel in this file's model array
 * @remark Some weapons (like weapon_melee) have multiple valid models, and this will report false for them.
 *
 * @param wepid        WeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
stock bool HasValidWeaponModel(WeaponId wepid)
{
	return IsValidWeaponId(wepid) && WeaponModels[wepid][0] != '\0';
}

/**
 * Checks to see if a given meleeweaponid has a known WeaponModel in this file's model array
 *
 * @param wepid        MeleeWeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
stock bool HasValidMeleeWeaponModel(MeleeWeaponId wepid)
{
	return IsValidMeleeWeaponId(wepid) && MeleeWeaponModels[wepid][0] != '\0';
}

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
stock void GetWeaponName(WeaponId wepid, char[] nameBuffer, int length)
{
	strcopy(nameBuffer, length, (IsValidWeaponId(view_as<WeaponId>(wepid)) ? (WeaponNames[view_as<int>(wepid)]) : ""));
}

/**
 * Tries to look up L4D2's internal weapon name for a given MeleeWeaponId.
 *
 * @param wepid            MeleeWeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
stock void GetMeleeWeaponName(MeleeWeaponId wepid, char[] nameBuffer, const int length)
{
	strcopy(nameBuffer, length, (IsValidMeleeWeaponId(view_as<MeleeWeaponId>(wepid)) ? (MeleeWeaponNames[view_as<int>(wepid)]) : ""));
}

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
stock void GetLongWeaponName(WeaponId wepid, char[] nameBuffer, int length)
{
	strcopy(nameBuffer, length, (IsValidWeaponId(view_as<WeaponId>(wepid)) ? (LongWeaponNames[view_as<int>(wepid)]) : ""));
}

/**
 * Tries to look up L4D2's internal weapon name for a given MeleeWeaponId.
 *
 * @param wepid            MeleeWeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
stock void GetLongMeleeWeaponName(MeleeWeaponId wepid, char[] nameBuffer, int length)
{
	strcopy(nameBuffer, length, (IsValidMeleeWeaponId(view_as<MeleeWeaponId>(wepid)) ? (LongMeleeWeaponNames[view_as<int>(wepid)]) : ""));
}

/**
 * Tries to look up the weapon model for a given MeleeWeaponId.
 * @remarks You should use HasValidWeaponModel to make sure the MeleeWeaponId you're looking up has a valid model associated with it.
 *
 * @param wepid            MeleeWeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponid or no weapon model available.
 */
stock void GetMeleeWeaponModel(MeleeWeaponId wepid, char[] modelBuffer, const int length)
{
	strcopy(modelBuffer, length, (HasValidMeleeWeaponModel(view_as<MeleeWeaponId>(wepid)) ? (MeleeWeaponModels[view_as<int>(wepid)]) : ""));
}

/**
 * Performs bounds checking to determine if a MeleeWeaponId is valid
 * @remark Simple check to see if wepid has a garbage value
 *
 * @param wepid        MeleeWeaponId to check for validity
 * @return True if wepid is valid, false otherwise.
 */
stock bool IsValidMeleeWeaponId(MeleeWeaponId wepid)
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
stock void GetWeaponModel(WeaponId wepid, char[] modelBuffer, int length)
{
	strcopy(modelBuffer, length, HasValidWeaponModel(view_as<WeaponId>(wepid)) ? (WeaponModels[view_as<int>(wepid)]) : "");
}

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
stock int ConvertWeaponSpawn(int entity, WeaponId wepid, int count=5, const char[] model = "")
{
    if(!IsValidEntity(entity)) return -1;
    if(!IsValidWeaponId(wepid)) return -1;
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




//#if !defined L4D2UTIL_STOCKS_ONLY
#if !defined __IN_L4D2UTIL__

/**
 * Returns the amount of temporary health a survivor has. 
 *
 * @param client client ID
 * @return int
 */
native int GetSurvivorTemporaryHealth(int client);

/**
 * Identifies a client's survivor character based on their current model.
 * @remark SurvivorCharacter_Invalid on errors
 *
 * @param client                Survivor client to identify
 * @return SurvivorCharacter    index identifying the survivor, or SurvivorCharacter_Invalid if not identified.
 */
native SurvivorCharacter IdentifySurvivor(int client);

/**
 * Get the name of a survivor character through client index.
 * Will write to string 'None' in case of error.
 *
 * @param client        client index
 * @param buffer        buffer to store name
 * @param length        length of buffer
 * @return bool         false if SurvivorCharacter_Invalid, otherwise true
 */
native bool GetClientSurvivorName(int client, char[] buffer, const int length);


/**
 * Tries to look up a WeaponId for a given Weapon Name.
 *
 * @param weaponName    Weapon name string to look up Id from
 * @return                The corresponding WeaponId if found, else WEPID_NONE
 */
native WeaponId WeaponNameToId(const char[] weaponName);

/**
 * Identifies a weapon spawn or weapon entity as a WeaponID
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return WeaponID for the entity if it is a weapon, WEPID_NONE otherwise
 */
native WeaponId IdentifyWeapon(int entity);

// Helper function used for getting an entity's internal melee name
native bool GetMeleeWeaponNameFromEntity(int entity, char[] buffer, int length);

/**
 * Identifies a melee weapon spawn or weapon entity as a MeleeWeaponId
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return MeleeWeaponId for the entity if it is a weapon, WEPID_MELEE_NONE otherwise
 */
native MeleeWeaponId IdentifyMeleeWeapon(int entity);




/**
 * Called when a new round begins.
 *
 * @noreturn
 */
#pragma deprecated Use L4D2_OnRealRoundStart() instead
forward void OnRoundStart();

/**
 * Called when a round ends.
 *
 * @noreturn
 */
#pragma deprecated Use L4D2_OnRealRoundEnd() instead
forward void OnRoundEnd();

/**
 * Called when a tank punches a hittable, like a car or dumpster.
 *
 * @param iTank Client ID of the tank
 * @param iEntity Entity ID of the hittable
 * @noreturn
 */
forward void OnTankPunchHittable(int iTank, int iEntity);

/**
 * Called when a tank first spawns.
 *
 * @param iTank Client ID of the tank
 * @noreturn
 */
#pragma deprecated Use L4D2_OnTankFirstSpawn(int tankClient) instead
forward void OnTankSpawn(int iTank);

/**
 * Called when a tank passes control from one player to another.
 *
 * @param iTank Client ID of the tank
 * @param iOldTank Client ID of the previous tank
 * @noreturn
 */
#pragma deprecated Use L4D2_OnTankPassControl(int oldTank, int newTank, int passCount) instead
forward void OnTankPass(int iTank, int iOldTank);

/**
 * Called when the tank dies.
 *
 * @param iOldTank Client ID of the dead tank
 * @noreturn
 */
#pragma deprecated Use L4D2_OnTankDeath(int tankClient, int attacker) instead
forward void OnTankDeath(int iOldTank);



public SharedPlugin __pl_l4d2util =
{
	name = "l4d2util",
	file = "l4d2util.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2util_SetNTVOptional()
{
	// Stub
	MarkNativeAsOptional("GetSurvivorTemporaryHealth");
	MarkNativeAsOptional("IdentifySurvivor");
	MarkNativeAsOptional("GetClientSurvivorName");
	MarkNativeAsOptional("WeaponNameToId");
	MarkNativeAsOptional("IdentifyWeapon");
	MarkNativeAsOptional("GetMeleeWeaponNameFromEntity");
	MarkNativeAsOptional("IdentifyMeleeWeapon");
}
#endif

#endif // __IN_L4D2UTIL__
//#endif // L4D2UTIL_STOCKS_ONLY
