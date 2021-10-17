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
 * Called on a real L4D2 player_team
 *
 * @param client 	
 * @param oldteam 	
 * @param team 	
 * @noreturn
 */
forward void L4D2_OnPlayerTeamChanged(int client, int oldteam, int team);

/**
 * Called on a real L4D2 SDKHook_OnTakeDamage
 *
 * @param victim 	client who was take damage
 * @param attacker 	entity id who attacked, if attacker not a player, and userid therefore invalid
 * @param inflictor 	
 * @param damage 	damage done to health
 * @param damageType 	damage type 
 * @param weapon 	weapon name attacker used, if not the world
 * @param damageForce 	
 * @param damagePosition 	
 * @return Action
 */
forward Action L4D2_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]);




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

/**
 * Identifies the survivor character corresponding to a player model.
 * @remark SurvivorCharacter_Invalid on errors, uses SurvivorModelTrie
 *
 * @param model                 Player model to identify
 * @return SurvivorCharacter    index identifying the model, or SurvivorCharacter_Invalid if not identified.
 */
native SurvivorCharacter ClientModelToSC(const char[] model);

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
 * Identifies a client's survivor character based on their current model.
 * @remark SurvivorCharacter_Invalid on errors
 *
 * @param client                Survivor client to identify
 * @return SurvivorCharacter    index identifying the survivor, or SurvivorCharacter_Invalid if not identified.
 */
stock SurvivorCharacter IdentifySurvivor(int client)
{
	if (!client || !IsSurvivor(client))
	{
		return SurvivorCharacter_Invalid;
	}

	char clientModel[42];
	GetClientModel(client, clientModel, sizeof(clientModel));

	return ClientModelToSC(clientModel);
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

/**
 * Get the name of a survivor character through client index.
 * Will write to string 'None' in case of error.
 *
 * @param client        client index
 * @param buffer        buffer to store name
 * @param length        length of buffer
 * @return bool         false if SurvivorCharacter_Invalid, otherwise true
 */
stock bool GetClientSurvivorName(int client, char[] buffer, const int length)
{
	SurvivorCharacter character = IdentifySurvivor(client);
	if (character == SurvivorCharacter_Invalid)
	{
		strcopy(buffer, length, "None");
		return false;
	}

	strcopy(buffer, length, SurvivorNames[view_as<int>(character)]);
	return true;
}


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

enum L4D2WeaponSlot
{
	L4D2WeaponSlot_Primary,
	L4D2WeaponSlot_Secondary,
	L4D2WeaponSlot_Throwable,
	L4D2WeaponSlot_HeavyHealthItem,
	L4D2WeaponSlot_LightHealthItem,
	
	L4D2WeaponSlot_Size //5 size
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

/**
 * Tries to look up a WeaponId for a given Weapon Name.
 *
 * @param weaponName    Weapon name string to look up Id from
 * @return                The corresponding WeaponId if found, else WEPID_NONE
 */
native WeaponId WeaponNameToId(const char[] weaponName);

native MeleeWeaponId GetMeleeWeaponIdFromName(char[] MeleeWeaponName);

native bool GetMeleeWeaponNameFromModel(char[] sModelName, char[] buffer, int length);

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
	return (wepid >= WEPID_NONE && wepid < WEPID_SIZE);
}

/**
 * Get the player weapon slot used by the given WeaponId.
 * 
 * @param wepid     WeaponId to get the slot for.
 * @return Slot number (0-4) or -1 for invalid WeaponId or no slot
 */
stock int GetSlotFromWeaponId(WeaponId wepid)
{
	return (IsValidWeaponId(wepid)) ? WeaponSlots[wepid] : -1;
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
	return (IsValidWeaponId(wepid) && WeaponModels[wepid][0] != '\0');
}

/**
 * Checks to see if a given meleeweaponid has a known WeaponModel in this file's model array
 *
 * @param wepid        MeleeWeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
stock bool HasValidMeleeWeaponModel(MeleeWeaponId wepid)
{
	return (IsValidMeleeWeaponId(wepid) && MeleeWeaponModels[wepid][0] != '\0');
}

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
stock void GetWeaponName(WeaponId wepid, char[] nameBuffer, const int length)
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
stock void GetLongWeaponName(WeaponId wepid, char[] nameBuffer, const int length)
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
stock void GetLongMeleeWeaponName(MeleeWeaponId wepid, char[] nameBuffer, const int length)
{
	strcopy(nameBuffer, length, (IsValidMeleeWeaponId(view_as<MeleeWeaponId>(wepid)) ? (LongMeleeWeaponNames[view_as<int>(wepid)]) : ""));
}

// Helper function used for getting an entity's internal melee name
stock bool GetMeleeWeaponNameFromEntity(int entity, char[] buffer, const int length)
{
	char classname[64];
	if (!GetEdictClassname(entity, classname, sizeof(classname))) {
		return false;
	}

	if (StrEqual(classname, "weapon_melee_spawn")) {
		char sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		// Strip models directory
		if (strncmp(sModelName, "models/", 7, false) == 0) {
			strcopy(sModelName, sizeof(sModelName), sModelName[6]);
		}

		if (GetMeleeWeaponNameFromModel(sModelName, buffer, length)) {
			return true;
		}
		
		return false;
	} else if (StrEqual(classname, "weapon_melee")) {
		GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
		return true;
	}

	return false;
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
	return (wepid >= WEPID_MELEE_NONE && wepid < WEPID_MELEES_SIZE);
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
stock void GetWeaponModel(WeaponId wepid, char[] modelBuffer, const int length)
{
	strcopy(modelBuffer, length, HasValidWeaponModel(view_as<WeaponId>(wepid)) ? (WeaponModels[view_as<int>(wepid)]) : "");
}

/**
 * Identifies a weapon spawn or weapon entity as a WeaponID
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return WeaponID for the entity if it is a weapon, WEPID_NONE otherwise
 */
stock WeaponId IdentifyWeapon(int entity, bool nospawn = false)
{
	if (!entity || !IsValidEntity(entity) || !IsValidEdict(entity)) {
		return WEPID_NONE;
	}

	char class[64];
	if (!GetEdictClassname(entity, class, sizeof(class))) {
		return WEPID_NONE;
	}

	if (strcmp(class, "weapon_spawn") == 0/* || strcmp(class, "weapon_item_spawn") == 0*/) {
		return view_as<WeaponId>(GetEntProp(entity, Prop_Send, "m_weaponID"));
	}

	int len = strlen(class);
	int len2 = len - 6;
	if (len2 > 0 && strcmp(class[len2], "_spawn") == 0) {
		class[len2] = '\0';
		return WeaponNameToId(class);
	}

	if (!nospawn) {
		return WeaponNameToId(class);
	}
	
	return WEPID_NONE;
}

/**
 * Identifies a melee weapon spawn or weapon entity as a MeleeWeaponId
 * @remark Should work on most weapon ents--even spawns, singles, held, etc.
 *
 * @param entity        Index of entity to identify
 * @return MeleeWeaponId for the entity if it is a weapon, WEPID_MELEE_NONE otherwise
 */
stock MeleeWeaponId IdentifyMeleeWeapon(int entity)
{
	if (IdentifyWeapon(entity) != WEPID_MELEE) {
		return WEPID_MELEE_NONE;
	}

	char sName[128];
	if (!GetMeleeWeaponNameFromEntity(entity, sName, sizeof(sName))) {
		return WEPID_MELEE_NONE;
	}

	return GetMeleeWeaponIdFromName(sName);
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
stock int ConvertWeaponSpawn(int entity, WeaponId wepid, int count = 5, const char[] model = "")
{
	if (!IsValidEntity(entity)) {
		return -1;
	}
	
	if (!IsValidWeaponId(wepid)) {
		return -1;
	}
	
	if (model[0] == '\0' && !HasValidWeaponModel(wepid)) {
		return -1;
	}

	float origins[3], angles[3];
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origins);
	GetEntPropVector(entity, Prop_Send, "m_angRotation", angles);

	AcceptEntityInput(entity, "kill");

	entity = CreateEntityByName("weapon_spawn");
	if (!IsValidEntity(entity)) {
		return -1;
	}
	
	SetEntProp(entity, Prop_Send, "m_weaponID", wepid);

	static char buf[PLATFORM_MAX_PATH - 16], modelName[PLATFORM_MAX_PATH];
	if (model[0] != '\0') {
		SetEntityModel(entity, model);
	} else {
		GetWeaponModel(wepid, buf, sizeof(buf));
		Format(modelName, sizeof(modelName), "models%s", buf);
		SetEntityModel(entity, modelName);
	}
	
	IntToString(count, buf, sizeof(buf));
	DispatchKeyValue(entity, "count", buf);

	TeleportEntity(entity, origins, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	return entity;
}

/**
 * 创建一个给定的武器生成
 * @remark 说实话, 这适用于任何具有原点/旋转的实体。
 * 此外，要求武器具有有效的武器模型或已提供 
 *
 * @param wepid            WeaponId of the weapon to have the spawner hold
 * @param origins
 * @param angles
 * @param count            Weapon count for the spawner (default 5)
 * @param model            World model to use for the weapon spawn
 * @return entity of the new weapon spawn, or -1 on errors.
 */
stock int CreateWeaponSpawn(WeaponId wepid, float origins[3], float angles[3], int count = 5, const char[] model = "")
{
	if (!IsValidWeaponId(wepid)) {
		return -1;
	}
	
	if (model[0] == '\0' && !HasValidWeaponModel(wepid)) {
		return -1;
	}
	
	int entity = CreateEntityByName("weapon_spawn");
	if (!IsValidEntity(entity)) {
		return -1;
	}
	
	SetEntProp(entity, Prop_Send, "m_weaponID", wepid);

	static char buf[PLATFORM_MAX_PATH - 16], modelName[PLATFORM_MAX_PATH];
	if (model[0] != '\0') {
		SetEntityModel(entity, model);
	} else {
		GetWeaponModel(wepid, buf, sizeof(buf));
		Format(modelName, sizeof(modelName), "models%s", buf);
		SetEntityModel(entity, modelName);
	}
	
	IntToString(count, buf, sizeof(buf));
	DispatchKeyValue(entity, "count", buf);

	TeleportEntity(entity, origins, angles, NULL_VECTOR);
	DispatchSpawn(entity);
	SetEntityMoveType(entity, MOVETYPE_NONE);

	return entity;
}




/**
 * 目前正在玩这张地图的第二轮?
 *
 * @return bool
 */
native bool InSecondHalfOfRound();

/**
 * 地图是否转换中
 *
 * @return bool
 */
native bool IsInTransition();

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
	MarkNativeAsOptional("L4D2_GetMapValueInt");
	MarkNativeAsOptional("L4D2_GetMapValueFloat");
	MarkNativeAsOptional("L4D2_GetMapValueVector");
	MarkNativeAsOptional("L4D2_GetMapValueString");
	MarkNativeAsOptional("L4D2_CopyMapSubsection");
	
	MarkNativeAsOptional("ClientModelToSC");
	MarkNativeAsOptional("WeaponNameToId");
	MarkNativeAsOptional("GetMeleeWeaponIdFromName");
	MarkNativeAsOptional("GetMeleeWeaponNameFromModel");
	
	MarkNativeAsOptional("InSecondHalfOfRound");
	MarkNativeAsOptional("IsInTransition");
}
#endif
