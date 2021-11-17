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
enum
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
forward void L4D2_OnRealRoundStart(int iRoundNumber);

/**
 * Called on a real L4D2 round_end
 *
 * @param roundNumber			The round number for the round that has ended
 * @noreturn
 */
forward void L4D2_OnRealRoundEnd(int iRoundNumber);

/**
 * @Called when a tank is first spawned into the game
 * 
 * @param tankClient		The client index of the tank
 * @noreturn
 */
forward void L4D2_OnTankFirstSpawn(int iTankClient);

/**
 * @Called when a tank passes from one client to another
 * 
 * @param oldTank			The client index of the previous tank
 * @param newTank			The client index of the new tank
 * @param passCount			The number of times this tank has been passed
 * @noreturn
 */
forward void L4D2_OnTankPassControl(int iOldTank, int iNewTank);

/**
 * @Called 0.5s after a tank death
 * 
 * @param tankClient		The client index of the tank that died
 * @noreturn
 */
forward void L4D2_OnTankDeath(int iTankClient);




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
native int L4D2_IsEntityInSaferoom(int iEnt);

/**
 * @brief Get an Int value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0)
 * @return			Integer value for given key, or defvalue if key is not found
 */
native int L4D2_GetMapValueInt(const char[] sKey, const int iDefvalue = 0);

/**
 * @brief Get a Float value from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param defvalue	Default value to return if key is not found (default 0.0)
 * @return			Float value for given key, or defvalue if key is not found
 */
native float L4D2_GetMapValueFloat(const char[] sKey, const float fDefvalue = 0.0);

/**
 * @brief Get a Vector from the MapInfo keyvalues for the current map with a specific key
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param key		Key to read the value from
 * @param vector	Vector to store the result in
 * @param defvalue	Default value to use if key is not found (default NULL_VECTOR)
 * @noreturn
 */
native void L4D2_GetMapValueVector(const char[] sKey, float fVector[3], const float fDefvalue[3] = NULL_VECTOR);

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
native void L4D2_GetMapValueString(const char[] sKey, char[] sValue, int iMaxlength, const char[] sDefvalue = "");

/**
 * @brief Copy a Subsection from the MapInfo keyvalues for the current map
 * @remarks Mapinfo keyvalues is used to store static data about maps
 * 
 * @param kv		KeyValues Handle to copy to
 * @param section	Name of the section to copy
 * @noreturn
 */
native void L4D2_CopyMapSubsection(Handle hKv, const char[] sSection);

/**
 * 地图是否转换中
 *
 * @return bool
 */
native bool L4D2_IsInTransition();


// l4d2_saferoom_detect
/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
native bool SAFEDETECT_IsEntityInStartSaferoom(int iEntity);
native bool SAFEDETECT_IsEntityInEndSaferoom(int iEntity);

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
	MarkNativeAsOptional("L4D2_IsMapDataAvailable");
	MarkNativeAsOptional("L4D2_IsEntityInSaferoom");
	MarkNativeAsOptional("L4D2_GetMapValueInt");
	MarkNativeAsOptional("L4D2_GetMapValueFloat");
	MarkNativeAsOptional("L4D2_GetMapValueVector");
	MarkNativeAsOptional("L4D2_GetMapValueString");
	MarkNativeAsOptional("L4D2_CopyMapSubsection");
	MarkNativeAsOptional("L4D2_IsInTransition");
	
	// l4d2_saferoom_detect
	MarkNativeAsOptional("SAFEDETECT_IsEntityInStartSaferoom");
	MarkNativeAsOptional("SAFEDETECT_IsEntityInEndSaferoom");
}
#endif
