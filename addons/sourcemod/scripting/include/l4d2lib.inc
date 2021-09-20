/* *
 * =============================================================================
 * L4D2Lib.inc 
 * L4D2Lib (C)2011 Confogl Team
 * =============================================================================
 *
 * This file is part of the Lgofnoc competitive L4D2 plugin suite.
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
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, Lgofnoc Team gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, Lgofnoc Team grants
 * this exception to all derivative works. Lgofnoc defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 */

/**
 * Describes a saferoom location. Can be OR'd together
 */
enum Saferoom
{
	Saferoom_Neither = 0,
	Saferoom_Start = 1,
	Saferoom_End = 2,
	Saferoom_Both = 3
};

/**
 * Called on a real L4D2 round_start
 *
 * @param roundNumber			The round number for the round that is starting
 * @noreturn
 */
forward void L4D2_OnRealRoundStart(int roundNumber);

/**
 * Called on a real L4D2 round_end
 *
 * @param roundNumber			The round number for the round that has ended
 * @noreturn
 */
forward void L4D2_OnRealRoundEnd(int roundNumber);

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
 * @brief Returns the current round number
 * @remarks Updated on round_start events
 * 
 * @return 	0 for pre first round, round number otherwise
 */
native int L4D2_GetCurrentRound();

/**
 * @brief Tells if we're actually in a round or in between rounds
 * @remarks Updated on first round_start/end
 * 
 * @return 	True if within an actual round, false otherwise.
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
 * @brief Tells if map data is available
 * @remarks Map data should be available when any map is loaded, after OnMapStart()
 * 
 * @return 	True if map data is available, false if it is not.
 */
native bool L4D2_IsMapDataAvailable();

/**
 * Determines if an entity is in a start or end saferoom (based on mapinfo.txt or automatically generated info)
 *
 * @param ent			The entity to be checked
 * @return				Saferoom_Neither if entity is not in any saferoom
 *						Saferoom_Start if it is in the starting saferoom
 *						Saferoom_End if it is in the ending saferoom
 *						Saferoom_Start | Saferoom_End if it is in both saferooms (probably won't happen)
 */
native Saferoom L4D2_IsEntityInSaferoom(int ent);

/**
 * @brief Gives the Origins of the starting saferoom area
 * @remarks Should be centered on the medkit spawns in the saferoom
 * 
 * @param origin	Vector to store the origins in.
 * @noreturn
 */
native void L4D2_GetMapStartOrigin(float origin[3]);

/**
 * @brief Gives the Origins of the ending saferoom area
 * @remarks Should be centered on the medkit spawns in the saferoom
 * 
 * @param origin	Vector to store the origins in.
 * @noreturn
 */
native void L4D2_GetMapEndOrigin(float origin[3]);

/**
 * @brief Gives the distance from the map start origin to the edge of the medkit spawns
 * @remarks Should be a small radius just containing medkits
 * 
 * @return	Float distance from map start origin to medkits
 */
native float L4D2_GetMapStartDistance();

/**
 * @brief Gives the distance from the map start origin to the edge of the saferoom
 * @remarks Should be a larger radius, containing the spawns of all saferoom items
 * 
 * @return	Float distance from map start origin to edge of saferoom
 */
native float L4D2_GetMapStartExtraDistance();

/**
 * @brief Gives the distance from the map end origin to the edge of the medkit spawns
 * @remarks Should be a small radius just containing medkits
 * 
 * @return	Float distance from map end origin to medkits
 */
native float L4D2_GetMapEndDistance();

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
native void L4D2_GetMapValueVector(const char[] key, float vector[3], const float defvalue[3] = NULL_VECTOR);

/**
 * @brief Get a String from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param value		String to store the result in
 * @param maxlength Maximum length to write to the value String buffer
 * @param defvalue	Default value to use if key is not found (default "")
 * @noreturn
 */
native void L4D2_GetMapValueString(const char[] key, char[] value, int maxlength, const char[] defvalue = "");

/**
 * @brief Copy a Subsection from the MapInfo keyvalues for the current map
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param kv		KeyValues Handle to copy to
 * @param section	Name of the section to copy
 * @noreturn
 */
native void L4D2_CopyMapSubsection(Handle kv, const char[] section);


/**
 * 目前正在玩这张地图的第二轮?
 *
 * @return bool
 */
native bool L4D2_InSecondHalfOfRound();

/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool SAFEDETECT_IsEntityInStartSaferoom(int entity);
native bool SAFEDETECT_IsEntityInEndSaferoom(int entity);
native bool SAFEDETECT_IsEntityInSaferoom(int entity);

/**
 * 
 *
 * @param 
 * @return 
 */
native void L4D2_PauseClient(int client, bool b);

/**
 * 
 *
 * @param 
 * @return 
 */
native int L4D2_GetRandomSurvivor();

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

public SharedPlugin __pl_l4d2lib = 
{
	name = "l4d2lib",
	file = "l4d2lib.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2lib_SetNTVOptional()
{
	MarkNativeAsOptional("L4D2_GetCurrentRound");
	MarkNativeAsOptional("L4D2_CurrentlyInRound");
	MarkNativeAsOptional("L4D2_GetSurvivorCount");
	MarkNativeAsOptional("L4D2_GetSurvivorOfIndex");
	MarkNativeAsOptional("L4D2_IsMapDataAvailable");
	MarkNativeAsOptional("L4D2_IsEntityInSaferoom");
	MarkNativeAsOptional("L4D2_GetMapStartOrigin");
	MarkNativeAsOptional("L4D2_GetMapEndOrigin");
	MarkNativeAsOptional("L4D2_GetMapStartDistance");
	MarkNativeAsOptional("L4D2_GetMapStartExtraDistance");
	MarkNativeAsOptional("L4D2_GetMapEndDistance");
	MarkNativeAsOptional("L4D2_GetMapValueInt");
	MarkNativeAsOptional("L4D2_GetMapValueFloat");
	MarkNativeAsOptional("L4D2_GetMapValueVector");
	MarkNativeAsOptional("L4D2_GetMapValueString");
	MarkNativeAsOptional("L4D2_CopyMapSubsection");
	
	MarkNativeAsOptional("L4D2_InSecondHalfOfRound");
	MarkNativeAsOptional("SAFEDETECT_IsEntityInStartSaferoom");
	MarkNativeAsOptional("SAFEDETECT_IsEntityInEndSaferoom");
	MarkNativeAsOptional("SAFEDETECT_IsEntityInSaferoom");
	MarkNativeAsOptional("L4D2_PauseClient");
	MarkNativeAsOptional("L4D2_GetRandomSurvivor");
	MarkNativeAsOptional("L4D2_IsCoop");
	MarkNativeAsOptional("L4D2_IsVersus");
	MarkNativeAsOptional("L4D2_IsScavenge");
	MarkNativeAsOptional("L4D2_IsSurvival");
}
#endif