#define SPAWN_PREFIX			"weapon_"
#define SPAWN_SURFIX			"_spawn"

enum
{
	WEAPON_NULL_INDEX,
	WEAPON_CHAINSAW_INDEX,
	WEAPON_FIRST_AID_KIT_INDEX,
	WEAPON_DEFIBRILLATOR_INDEX,
	WEAPON_UPG_EXPLOSIVE_INDEX,
	WEAPON_UPG_INCENDIARY_INDEX,
	
	WEAPON_MAX_SIZE
};

static const int Weapon_Attributes[WEAPON_MAX_SIZE] =
{
	WEPID_NONE,
	WEPID_CHAINSAW,
	WEPID_FIRST_AID_KIT,
	WEPID_DEFIBRILLATOR,
	WEPID_FRAG_AMMO,
	WEPID_INCENDIARY_AMMO
};

static const char Weapon_Spawns[WEAPON_MAX_SIZE][] = 
{
	"",	
	"chainsaw",
	"first_aid_kit",
	"defibrillator",
	"upgradepack_explosive",
	"upgradepack_incendiary"
};

int
	Weapon_iKitCount;


ConVar
	hSurvivorLimit = null,
	Weapon_hConvar[WEAPON_MAX_SIZE] = {null, ...},
	Weapon_hReplaceFinaleKits = null,
	Weapon_hRemoveLaserSight = null;

public void WI_OnModuleStart()
{
	hSurvivorLimit = FindConVar("survivor_limit");
	
	Weapon_hConvar[WEAPON_CHAINSAW_INDEX] 			= CreateConVarEx("remove_chainsaw","1","Remove all chainsaws");
	
	Weapon_hConvar[WEAPON_FIRST_AID_KIT_INDEX]		= CreateConVarEx("remove_statickits","1","Remove all static medkits (medkits such as the gun shop, these are compiled into the map)");
	Weapon_hConvar[WEAPON_DEFIBRILLATOR_INDEX]		= CreateConVarEx("remove_defib","1","Remove all defibrillators");
	Weapon_hConvar[WEAPON_UPG_EXPLOSIVE_INDEX]		= CreateConVarEx("remove_upg_explosive","1","Remove all explosive upgrade packs");
	Weapon_hConvar[WEAPON_UPG_INCENDIARY_INDEX]		= CreateConVarEx("remove_upg_incendiary","1","Remove all incendiary upgrade packs");
	
	Weapon_hReplaceFinaleKits 		= CreateConVarEx("replace_finalekits","1","Replaces finale medkits with pills");
	Weapon_hRemoveLaserSight 		= CreateConVarEx("remove_lasersight","1","Remove all laser sight upgrades");
}

public void WI_RoundStart()
{
	CreateTimer(3.0, WI_RoundStartLoop);
}

public Action WI_RoundStartLoop(Handle timer)
{
	Weapon_iKitCount = 0;
	
	int iWeaponIndex;
	char entclass[128];
	int entcount = GetEntityCount();
	
	for(int iEntity = MaxClients+1;iEntity<=entcount;iEntity++)
	{
		if(!IsValidEdict(iEntity) || !IsValidEntity(iEntity)){continue;}
		GetEdictClassname(iEntity,entclass,128);
		
		iWeaponIndex = WI_GetWeaponIndex(iEntity,entclass);
		if(iWeaponIndex != WEAPON_NULL_INDEX)
		{
			if(iWeaponIndex <= WEAPON_CHAINSAW_INDEX)
			{
				WI_ReplaceWeapon(iEntity,iWeaponIndex);
			}
			else
			{
				WI_ReplaceExtra(iEntity,iWeaponIndex);
			}
			continue;
		}
		
		if(Weapon_hRemoveLaserSight.BoolValue && StrContains(entclass,"upgrade_laser_sight") != -1)
		{
			KillEntity(iEntity);
			continue;
		}
	}
	
	return Plugin_Stop;
}

int WI_GetWeaponIndex(int iEntity, const char sEntityClassName[128])
{
	if (sEntityClassName[0] != 'w')
	{
		return WEAPON_NULL_INDEX;
	}
	
	if (strcmp(sEntityClassName, "weapon_spawn") == 0)
	{
		int WepID = GetEntProp(iEntity, Prop_Send, "m_weaponID");
		
		for (int WeaponIndex = 1; WeaponIndex < WEAPON_MAX_SIZE; WeaponIndex++)
		{
			if(Weapon_Attributes[WeaponIndex] != WepID){continue;}
			return WeaponIndex;
		}
	}
	else
	{
		char sBuffer[128];
		for (int WeaponIndex = 1; WeaponIndex < WEAPON_MAX_SIZE; WeaponIndex++)
		{
			if(strlen(Weapon_Spawns[WeaponIndex]) < 1){continue;}
			Format(sBuffer,sizeof(sBuffer),"%s%s%s",SPAWN_PREFIX,Weapon_Spawns[WeaponIndex],SPAWN_SURFIX);
			if(StrEqual(sEntityClassName,sBuffer)){return WeaponIndex;}
			
			Format(sBuffer,sizeof(sBuffer),"%s%s",SPAWN_PREFIX,Weapon_Spawns[WeaponIndex]);
			if(StrEqual(sEntityClassName,sBuffer)){return WeaponIndex;}
		}
	}
	
	return WEAPON_NULL_INDEX;
}

void WI_ReplaceWeapon(int iEntity, int iWeaponIndex)
{
	if(Weapon_hConvar[iWeaponIndex].BoolValue)
	{
		KillEntity(iEntity);
	}
}

void WI_ReplaceExtra(int iEntity, int iWeaponIndex)
{
	if(Weapon_hConvar[iWeaponIndex].BoolValue && iWeaponIndex != WEAPON_FIRST_AID_KIT_INDEX)
	{
		KillEntity(iEntity);
		return;
	}
	
	if(iWeaponIndex != WEAPON_FIRST_AID_KIT_INDEX)
	{
		return;
	}
	
	float fOrigin[3];
	GetEntPropVector(iEntity, Prop_Send, "m_vecOrigin", fOrigin);
	
	bool bIsInStartSaferoom, bIsInEndSaferoom, bIsInFinaleArea;
	
	if(L4D2_IsEntityInSaferoom(iEntity) == Saferoom_Start)
	{
		bIsInStartSaferoom = true;
	}
	else if(L4D2_IsEntityInSaferoom(iEntity) == Saferoom_End)
	{
		if(IsMapFinale())
			bIsInFinaleArea = true;
		else
			bIsInEndSaferoom = true;
	}
	
	if(bIsInStartSaferoom || bIsInEndSaferoom)
	{
		return;
	}
	
	if(Weapon_iKitCount >= hSurvivorLimit.IntValue)
	{
		KillEntity(iEntity);
		return;
	}
	
	if(Weapon_hConvar[iWeaponIndex].BoolValue && (!bIsInFinaleArea || !Weapon_hReplaceFinaleKits.BoolValue))
	{
		KillEntity(iEntity);
		return;
	}
	
	if(bIsInFinaleArea && Weapon_hReplaceFinaleKits.BoolValue)
	{
		float fRotation[3];
		char sSpawnBuffer[128];
		GetEntPropVector(iEntity, Prop_Send, "m_angRotation", fRotation);
		KillEntity(iEntity);
		Format(sSpawnBuffer,sizeof(sSpawnBuffer),"weapon_pain_pills_spawn");
		iEntity = CreateEntityByName(sSpawnBuffer);
		TeleportEntity(iEntity, fOrigin, fRotation, NULL_VECTOR);
		DispatchSpawn(iEntity);
		SetEntityMoveType(iEntity,MOVETYPE_NONE);
		Weapon_iKitCount++;
	}
}
