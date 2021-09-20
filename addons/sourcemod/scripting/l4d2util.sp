#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2lib>

#define __IN_L4D2UTIL__
#include <l4d2util>

public Plugin myinfo = 
{
    name = "L4D2 Utilities (compatible)",
    author = "Confogl Team",
    description = "Useful functions and forwards for Left 4 Dead 2 SourceMod plugins",
    version = "1.0",
    url = "https://github.com/ConfoglTeam/l4d2util"
};

static const char sLibraryName[] = "l4d2util";

GlobalForward 
	hFwdOnRoundStart,
	hFwdOnRoundEnd,
	hFwdOnTankPunchHittable,
	hFwdOnTankSpawn,
	hFwdOnTankPass,
	hFwdOnTankDeath;

StringMap 
	hSurvivorModelsTrie,
	hWeaponNamesTrie,
	hMeleeWeaponNamesTrie,
	hMeleeWeaponModelsTrie;

float fDecayRate;

public APLRes AskPluginLoad2(Handle hPlugin, bool bLateLoad, char[] sError, int iErrMax)
{
	CreateNative("GetSurvivorTemporaryHealth", _native_GetSurvivorTemporaryHealth);
	CreateNative("IdentifySurvivor", _native_IdentifySurvivor);
	CreateNative("GetClientSurvivorName", _native_GetClientSurvivorName);
	CreateNative("WeaponNameToId", _native_WeaponNameToId);
	CreateNative("IdentifyWeapon", _native_IdentifyWeapon);
	CreateNative("GetMeleeWeaponNameFromEntity", _native_GetMeleeWeaponNameFromEntity);
	CreateNative("IdentifyMeleeWeapon", _native_IdentifyMeleeWeapon);
	
    hFwdOnRoundStart = new GlobalForward("OnRoundStart", ET_Ignore);
    hFwdOnRoundEnd = new GlobalForward("OnRoundEnd", ET_Ignore);
    hFwdOnTankPunchHittable = new GlobalForward("OnTankPunchHittable", ET_Ignore, Param_Cell, Param_Cell);
    hFwdOnTankSpawn = new GlobalForward("OnTankSpawn", ET_Ignore, Param_Cell);
    hFwdOnTankPass = new GlobalForward("OnTankPass", ET_Ignore, Param_Cell, Param_Cell);
    hFwdOnTankDeath = new GlobalForward("OnTankDeath", ET_Ignore, Param_Cell);

    RegPluginLibrary(sLibraryName);
    return APLRes_Success;
}

public void OnPluginStart()
{
	hSurvivorModelsTrie = new StringMap();
	for (int i = 0; i < view_as<int>(SurvivorCharacter_Size); i++)
	{
		hSurvivorModelsTrie.SetValue(SurvivorModels[i], i);
	}
	
	hWeaponNamesTrie = new StringMap();
	for (int i = 0; i < view_as<int>(WEPID_SIZE); i++)
	{
		hWeaponNamesTrie.SetValue(WeaponNames[i], i);
	}
	
	hMeleeWeaponNamesTrie = new StringMap();
	hMeleeWeaponModelsTrie = new StringMap();
    for (int i = 0; i < view_as<int>(WEPID_MELEES_SIZE); ++i)
    {
        hMeleeWeaponNamesTrie.SetValue(MeleeWeaponNames[i], i);
        hMeleeWeaponModelsTrie.SetString(MeleeWeaponModels[i], MeleeWeaponNames[i]);
    }
	
	ConVar hDecayRate = FindConVar("pain_pills_decay_rate");
	fDecayRate = hDecayRate.FloatValue;
	hDecayRate.AddChangeHook(ConVarChange);
}

public int ConVarChange(ConVar convar, char[] oldValue, char[] newValue)
{
	fDecayRate = convar.FloatValue;
}

public any _native_GetSurvivorTemporaryHealth(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	float fHealthBuffer = GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
	float fHealthBufferTimeStamp = GetEntPropFloat(client, Prop_Send, "m_healthBufferTime");
	float fHealthBufferDuration = GetGameTime() - fHealthBufferTimeStamp;
	int iTempHp = RoundToCeil(fHealthBuffer - (fHealthBufferDuration * fDecayRate)) - 1;
	return (iTempHp > 100) ? 100 : (iTempHp < 0) ? 0 : iTempHp;
}

public any _native_IdentifySurvivor(Handle plugin, int numParams)
{
	return IdentifySurvivor(GetNativeCell(1));
}

public any _native_GetClientSurvivorName(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int len = GetNativeCell(3);
	char[] buffer = new char[len];

	SurvivorCharacter character = IdentifySurvivor(client);
	if (character == SurvivorCharacter_Invalid) {
		strcopy(buffer, len, "None");
		return false;
	}

	strcopy(buffer, len, SurvivorNames[view_as<int>(character)]);
	SetNativeString(2, buffer, len);
	return true;
}

public any _native_IdentifyWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
	return _IdentifyWeapon(entity);
}

public any _native_IdentifyMeleeWeapon(Handle plugin, int numParams)
{
	int entity = GetNativeCell(1);
    if (_IdentifyWeapon(entity) != WEPID_MELEE)
    {
        return WEPID_MELEE_NONE;
    }

    char sName[128];
    if (! _GetMeleeWeaponNameFromEntity(entity, sName, sizeof(sName)))
    {
        return WEPID_MELEE_NONE;
    }

    int id;
    if (hMeleeWeaponNamesTrie.GetValue(sName, id))
    {
        return id;
    }
	return WEPID_MELEE_NONE;
}

public any _native_WeaponNameToId(Handle plugin, int numParams)
{
	int len;
	GetNativeStringLength(1, len);
	len += 1;
	char[] weaponName= new char[len];
	GetNativeString(1, weaponName, len);
	return _WeaponNameToId(weaponName);
}

public any _native_GetMeleeWeaponNameFromEntity(Handle plugin, int numParams)
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


public void L4D2_OnRealRoundStart()
{
    Call_StartForward(hFwdOnRoundStart);
    Call_Finish();

    CreateTimer(0.1, L4D2Util_Tanks_HookProps);
}

public Action L4D2Util_Tanks_HookProps(Handle hTimer)
{
    int iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1)
	{
        if (IsTankHittable(iEntity))
		{
            HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched);
        }
    }
    
    iEntity = -1;
    while ((iEntity = FindEntityByClassname(iEntity, "prop_alarm_car")) != -1)
	{
        HookSingleEntityOutput(iEntity, "OnHitByTank", TankHittablePunched);
    }
}

public void TankHittablePunched(const char[] output, int caller, int activator, float delay)
{
    Call_StartForward(hFwdOnTankPunchHittable);
    Call_PushCell(activator);
    Call_PushCell(caller);
    Call_Finish();
}

public void L4D2_OnRealRoundEnd()
{
    Call_StartForward(hFwdOnRoundEnd);
    Call_Finish();
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
    Call_StartForward(hFwdOnTankSpawn);
    Call_PushCell(tankClient);
    Call_Finish();
}

public void L4D2_OnTankPassControl(int oldTank, int newTank, int passCount)
{
    Call_StartForward(hFwdOnTankPass);
    Call_PushCell(newTank);
    Call_PushCell(oldTank);
    Call_Finish();
}

public void L4D2_OnTankDeath(int tankClient, int attacker)
{
    Call_StartForward(hFwdOnTankDeath);
    Call_PushCell(tankClient);
    Call_Finish();
}

stock SurvivorCharacter IdentifySurvivor(int client)
{
	if (!client || !IsSurvivor(client)) {
		return SurvivorCharacter_Invalid;
	}

	char clientModel[42];
	GetClientModel(client, clientModel, sizeof(clientModel));

	return ClientModelToSC(clientModel);
}

/**
 * Identifies the survivor character corresponding to a player model.
 * @remark SurvivorCharacter_Invalid on errors, uses SurvivorModelTrie
 *
 * @param model                 Player model to identify
 * @return SurvivorCharacter    index identifying the model, or SurvivorCharacter_Invalid if not identified.
 */
stock SurvivorCharacter ClientModelToSC(const char[] model)
{
	SurvivorCharacter sc;
	if (hSurvivorModelsTrie.GetValue(model, sc)) {
		return sc;
	}

	return SurvivorCharacter_Invalid;
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

    if (strcmp(class, "weapon_spawn") == 0 || strcmp(class, "weapon_item_spawn") == 0)
    {
        return view_as<WeaponId>(GetEntProp(entity,Prop_Send,"m_weaponID"));
    }

	int len = strlen(class);
	int len2 = len - 6;
	if (len2 > 0 && strcmp(class[len2], "_spawn") == 0)
	{
		class[len2] = '\0';
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
