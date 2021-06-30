#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]l4d2_weapon_stocks>

StringMap hWeaponNamesTrie;
StringMap hMeleeWeaponNamesTrie;
StringMap hMeleeWeaponModelsTrie;

char WeaponNames[view_as<int>(WEPID_UPGRADE_ITEM)+1][] =
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

char LongWeaponNames[view_as<int>(WEPID_UPGRADE_ITEM)+1][] = 
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

char MeleeWeaponNames[view_as<int>(WEPID_PITCHFORK)+1][] =
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

char WeaponModels[view_as<int>(WEPID_UPGRADE_ITEM)+1][] =
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
    "",
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

char MeleeWeaponModels[view_as<int>(WEPID_PITCHFORK)+1][] =
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
    "/weapons/melee/v_shovel.mdl",
    "/weapons/melee/v_pitchfork.mdl"
};

char LongMeleeWeaponNames[view_as<int>(WEPID_PITCHFORK)+1][] =
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

int WeaponSlots[view_as<int>(WEPID_UPGRADE_ITEM)+1] =
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

public Plugin myinfo =
{
	name = "L4D2 Weapon Stocks",
	description = "",
	author = "",
	version = "1.0",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("GetSlotFromWeaponId", _native_GetSlotFromWeaponId);
	CreateNative("HasValidWeaponModel", _native_HasValidWeaponModel);
	CreateNative("HasValidMeleeWeaponModel", _native_HasValidMeleeWeaponModel);
	CreateNative("WeaponNameToId", _native_WeaponNameToId);
	CreateNative("GetWeaponName", _native_GetWeaponName);
	CreateNative("GetLongWeaponName", _native_GetLongWeaponName);
	CreateNative("GetLongMeleeWeaponName", _native_GetLongMeleeWeaponName);
	CreateNative("GetWeaponModel", _native_GetWeaponModel);
	CreateNative("IdentifyWeapon", _native_IdentifyWeapon);
	CreateNative("GetMeleeWeaponNameFromEntity", _native_GetMeleeWeaponNameFromEntity);
	CreateNative("IdentifyMeleeWeapon", _native_IdentifyMeleeWeapon);
	CreateNative("ConvertWeaponSpawn", _native_ConvertWeaponSpawn);
	RegPluginLibrary("l4d2_weapons");
	return APLRes_Success;
}

public void OnPluginStart()
{
	hWeaponNamesTrie = new StringMap();
	for (int i = 0; i < view_as<int>(WeaponId); i++)
	{
		hWeaponNamesTrie.SetValue(WeaponNames[view_as<WeaponId>(i)], i);
	}
	
	hMeleeWeaponNamesTrie = new StringMap();
	hMeleeWeaponModelsTrie = new StringMap();
    for (int i = 0; i < view_as<int>(MeleeWeaponId); ++i)
    {
        hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[view_as<MeleeWeaponId>(i)], i);
        hMeleeWeaponModelsTrie.SetString(MeleeWeaponModels[view_as<MeleeWeaponId>(i)], MeleeWeaponNames[view_as<MeleeWeaponId>(i)]);
    }
}

public int _native_IdentifyWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	return view_as<int>(_IdentifyWeapon(entity));
}

public int _native_IdentifyMeleeWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
    if (_IdentifyWeapon(entity) != WEPID_MELEE)
    {
        return view_as<int>(WEPID_MELEE_NONE);
    }

    char sName[128];
    if (! _GetMeleeWeaponNameFromEntity(entity, sName, sizeof(sName)))
    {
        return view_as<int>(WEPID_MELEE_NONE);
    }

    int id;
    if (hMeleeWeaponNamesTrie.GetValue(sName, id))
    {
        return id;
    }
	return view_as<int>(WEPID_MELEE_NONE);
}

public int _native_HasValidWeaponModel(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	return _HasValidWeaponModel(wepid);
}

public int _native_HasValidMeleeWeaponModel(Handle plugin, int numParams)
{
	MeleeWeaponId wepid = GetNativeCell(1);
	return IsValidMeleeWeaponId(wepid) && MeleeWeaponModels[wepid][0] != '\0';
}

public int _native_WeaponNameToId(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] weaponName= new char[len];
	GetNativeString(1, weaponName, len);
	return view_as<int>(_WeaponNameToId(weaponName));
}

public int _native_ConvertWeaponSpawn(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	WeaponId wepid = GetNativeCell(2);
	int count = GetNativeCell(3);
	int len;
	GetNativeStringLength(4, len);
	len += 1;
	char[] model = new char[len];
	GetNativeString(4, model, len);

    if(!IsValidEntity(entity)) return -1;
    if(!IsValidWeaponId(wepid)) return -1;
    if(model[0] == '\0' && !_HasValidWeaponModel(wepid)) return -1;

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
        _GetWeaponModel(wepid, buf, sizeof(buf));
        SetEntityModel(entity, buf);
    }

    IntToString(count, buf, sizeof(buf));
    DispatchKeyValue(entity, "count", buf);

    TeleportEntity(entity, origins, angles, NULL_VECTOR);
    DispatchSpawn(entity);
    SetEntityMoveType(entity,MOVETYPE_NONE);
	return entity;
}

public int _native_GetLongWeaponName(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (IsValidWeaponId(view_as<WeaponId>(wepid)) ? (LongWeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

public int _native_GetLongMeleeWeaponName(Handle plugin, int numParams)
{
	MeleeWeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (IsValidMeleeWeaponId(view_as<MeleeWeaponId>(wepid)) ? (LongMeleeWeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

public int _native_GetMeleeWeaponNameFromEntity(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] buffer = new char[len];
	if (_GetMeleeWeaponNameFromEntity(entity, buffer, len))
	{
		SetNativeString(2, buffer, len);
		return true;
	}
	return false;
}

public int _native_GetSlotFromWeaponId(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	return IsValidWeaponId(wepid) ? WeaponSlots[wepid] : -1;
}

public int _native_GetWeaponModel(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] modelBuffer = new char[len];
	_GetWeaponModel(wepid, modelBuffer, len);
	SetNativeString(2, modelBuffer, len);
}

public int _native_GetWeaponName(Handle plugin, int numParams)
{
	WeaponId wepid = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] nameBuffer = new char[len];
	strcopy(nameBuffer, len, (IsValidWeaponId(view_as<WeaponId>(wepid)) ? (WeaponNames[view_as<int>(wepid)]) : ""));
	SetNativeString(2, nameBuffer, len);
}

bool _HasValidWeaponModel(WeaponId wepid)
{
    return IsValidWeaponId(wepid) && WeaponModels[wepid][0] != '\0';
}

WeaponId _WeaponNameToId(const char[] weaponName)
{
    WeaponId id;
    if (hWeaponNamesTrie.GetValue(weaponName, id))
    {
        return id;
    }
    return WEPID_NONE;
}

void _GetWeaponModel(WeaponId wepid, char[] modelBuffer, int length)
{
    strcopy(modelBuffer, length, _HasValidWeaponModel(view_as<WeaponId>(wepid)) ? (WeaponModels[view_as<int>(wepid)]) : "");
}

WeaponId _IdentifyWeapon(int entity)
{
    if (!entity || !IsValidEntity(entity) || !IsValidEdict(entity))
    {
        return WEPID_NONE;
    }
    char class[64];
    if (!GetEdictClassname(entity, class, sizeof(class)))
    {
        return WEPID_NONE;
    }

    if (StrEqual(class, "weapon_spawn") || StrEqual(class, "weapon_item_spawn"))
    {
        return view_as<WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));
    }

    int len = strlen(class);
    if (len-6 > 0 && StrEqual(class[len-6], "_spawn"))
    {
        class[len-6]='\0';
        return _WeaponNameToId(class);
    }
    
    return _WeaponNameToId(class);
}

bool _GetMeleeWeaponNameFromEntity(int entity, char[] buffer, int length)
{
    char classname[64];
    if (! GetEdictClassname(entity, classname, sizeof(classname)))
    {
        return false;
    }
    if (StrEqual(classname, "weapon_melee_spawn"))
    {
        char sModelName[128];
        GetEntPropString(entity, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

        if (strncmp(sModelName, "models/", 7, false) == 0)
        {
            strcopy(sModelName, sizeof(sModelName), sModelName[6]);
        }

        if (hMeleeWeaponModelsTrie.GetString(sModelName, buffer, length))
        {
            return true;
        }
        return false;
    }
    else if (StrEqual(classname, "weapon_melee"))
    {
        GetEntPropString(entity, Prop_Data, "m_strMapSetScriptName", buffer, length);
        return true;
    }
    return false;
}
