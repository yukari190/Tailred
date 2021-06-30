#if defined l4d2_weapons_inc_
    #endinput
#endif
#define l4d2_weapons_inc_

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
native int GetSlotFromWeaponId(WeaponId wepid);

/**
 * Checks to see if a given weaponid has a known WeaponModel in this file's model array
 * @remark Some weapons (like weapon_melee) have multiple valid models, and this will report false for them.
 *
 * @param wepid        WeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
native bool HasValidWeaponModel(WeaponId wepid);

/**
 * Checks to see if a given meleeweaponid has a known WeaponModel in this file's model array
 *
 * @param wepid        MeleeWeaponId to check for a known weapon model for.
 * @return True if a valid weapon model exists for wepid, false otherwise.
 */
native bool HasValidMeleeWeaponModel(MeleeWeaponId wepid);

/**
 * Tries to look up a WeaponId for a given Weapon Name.
 *
 * @param weaponName    Weapon name string to look up Id from
 * @return                The corresponding WeaponId if found, else WEPID_NONE
 */
native WeaponId WeaponNameToId(const char[] weaponName);

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void GetWeaponName(WeaponId wepid, char[] nameBuffer, int length);

/**
 * Tries to look up L4D2's internal weapon name for a given WeaponId.
 *
 * @param wepid            WeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void GetLongWeaponName(WeaponId wepid, char[] nameBuffer, int length);

/**
 * Tries to look up L4D2's internal weapon name for a given MeleeWeaponId.
 *
 * @param wepid            MeleeWeaponId To get name of.
 * @param nameBuffer    String buffer to write the weapon name to.
 * @param length        Max length which can be written to the buffer.
 * @return                Number of bytes written to buffer, or 0 for invalid weaponId.
 */
native void GetLongMeleeWeaponName(MeleeWeaponId wepid, char[] nameBuffer, int length);

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
native void GetWeaponModel(WeaponId wepid, char[] modelBuffer, int length);

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
native int ConvertWeaponSpawn(int entity, WeaponId wepid, int count=5, const char[] model = "");

public SharedPlugin __pl_l4d2_weapons = 
{
	name = "l4d2_weapons",
	file = "l4d2_weapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_l4d2_weapons_SetNTVOptional()
{
	MarkNativeAsOptional("GetSlotFromWeaponId");
	MarkNativeAsOptional("HasValidWeaponModel");
	MarkNativeAsOptional("HasValidMeleeWeaponModel");
	MarkNativeAsOptional("WeaponNameToId");
	MarkNativeAsOptional("GetWeaponName");
	MarkNativeAsOptional("GetLongWeaponName");
	MarkNativeAsOptional("GetLongMeleeWeaponName");
	MarkNativeAsOptional("GetWeaponModel");
	MarkNativeAsOptional("IdentifyWeapon");
	MarkNativeAsOptional("GetMeleeWeaponNameFromEntity");
	MarkNativeAsOptional("IdentifyMeleeWeapon");
	MarkNativeAsOptional("ConvertWeaponSpawn");
}
#endif
