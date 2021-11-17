enum
{
	IL_PainPills,
	IL_Adrenaline,
	// Not sure we need these.
	//IL_FirstAid,
	//IL_Defib,  
	IL_PipeBomb,
	IL_Molotov,
	IL_VomitJar,
	
	IL_MAXSIZE
};

enum
{
	IN_shortname,	
	IN_longname, 	
	IN_officialname, 	
	IN_modelname,
	
	IN_MAXSIZE
};

#if SOURCEMOD_V_MINOR > 9
enum struct ItemTracking
{
	int IT_entity;
	float IT_origins;
	float IT_origins1;
	float IT_origins2;
	float IT_angles;
	float IT_angles1;
	float IT_angles2;
}
#else
enum ItemTracking
{
	IT_entity,
	Float:IT_origins,
	Float:IT_origins1,
	Float:IT_origins2,
	Float:IT_angles,
	Float:IT_angles1,
	Float:IT_angles2
};
#endif

static const char g_sItemNames[IL_MAXSIZE][IN_MAXSIZE][] =
{
	{ "pills", "pain pills", "pain_pills", "painpills" },
	{ "adrenaline", "adrenaline shots", "adrenaline", "pipebomb" },
	// { "kits", "first aid kits", "first_aid_kit", "medkit" },
	// { "defib", "defibrillators", "defibrillator", "defibrillator" },
	{ "pipebomb", "pipe bombs", "pipe_bomb", "pipebomb" },
	{ "molotov", "molotovs", "molotov", "molotov" },
	{ "vomitjar", "bile bombs", "vomitjar", "bile_flask" }
};

ConVar
	g_hCvarEnabled,
	g_hCvarMapSpecificSpawns,
	g_hCvarLimits[IL_MAXSIZE];

StringMap
	g_hItemListTrie;

ArrayList
	g_hItemSpawns[IL_MAXSIZE];


int
	g_iItemLimits[IL_MAXSIZE];

bool
	g_bIsRound1Over;

public void IT_OnModuleStart()
{
	char sNameBuf[64], sCvarDescBuf[256];
	
	g_hCvarEnabled = CreateConVarEx("enable_itemtracking", "1", "Enable the itemtracking module");
	g_hCvarMapSpecificSpawns = CreateConVarEx("itemtracking_mapspecific", "3", "Change how mapinfo.txt overrides work. 0 = ignore mapinfo.txt, 1 = allow limit reduction, 2 = allow limit increases,");
	
	for (int i = 0; i < IL_MAXSIZE; i++)
	{
		Format(sNameBuf, sizeof(sNameBuf), "%s_limit", g_sItemNames[i][IN_shortname]);
		Format(sCvarDescBuf, sizeof(sCvarDescBuf), "Limits the number of %s on each map. -1: no limit; >=0: limit to cvar value", g_sItemNames[i][IN_longname]);
		g_hCvarLimits[i] = CreateConVarEx(sNameBuf, "-1", sCvarDescBuf);
	}
	
	g_hItemListTrie = new StringMap();
	SetTrieValue(g_hItemListTrie, "weapon_pain_pills_spawn", IL_PainPills);
	SetTrieValue(g_hItemListTrie, "weapon_pain_pills", IL_PainPills);
	SetTrieValue(g_hItemListTrie, "weapon_adrenaline_spawn", IL_Adrenaline);
	SetTrieValue(g_hItemListTrie, "weapon_adrenaline", IL_Adrenaline);
	SetTrieValue(g_hItemListTrie, "weapon_pipe_bomb_spawn", IL_PipeBomb);
	SetTrieValue(g_hItemListTrie, "weapon_pipe_bomb", IL_PipeBomb);
	SetTrieValue(g_hItemListTrie, "weapon_molotov_spawn", IL_Molotov);
	SetTrieValue(g_hItemListTrie, "weapon_molotov", IL_Molotov);
	SetTrieValue(g_hItemListTrie, "weapon_vomitjar_spawn", IL_VomitJar);
	SetTrieValue(g_hItemListTrie, "weapon_vomitjar", IL_VomitJar);
	
#if SOURCEMOD_V_MINOR > 9
	for (int i = 0; i < IL_MAXSIZE; i++)
	{
		g_hItemSpawns[i] = new ArrayList(sizeof(ItemTracking));
	}
#else
	for (int i = 0; i < IL_MAXSIZE; i++)
	{
		g_hItemSpawns[i] = new ArrayList(view_as<int>(ItemTracking));
	}
#endif
	
	RegAdminCmd("sm_item_track", Command_ItemTrack, ADMFLAG_ROOT);
}

public Action Command_ItemTrack(int client, int args)
{
	EntitySearch();
}

public void IT_OnMapStart()
{
	for (int i; i < IL_MAXSIZE; i++) g_iItemLimits[i] = g_hCvarLimits[i].IntValue;
	if (g_hCvarMapSpecificSpawns.IntValue)
	{
		int itemlimit;
		KeyValues kOverrideLimits = new KeyValues("ItemLimits");
		L4D2_CopyMapSubsection(kOverrideLimits, "ItemLimits");
		for (int i = 0; i < IL_MAXSIZE; i++)
		{
			itemlimit = g_hCvarLimits[i].IntValue;
			int temp = KvGetNum(kOverrideLimits, g_sItemNames[i][IN_officialname], itemlimit);
			if (((g_iItemLimits[i] > temp) && (g_hCvarMapSpecificSpawns.IntValue & 1)) || ((g_iItemLimits[i] < temp) && (g_hCvarMapSpecificSpawns.IntValue & 2)))
			{
				g_iItemLimits[i] = temp;
			}
			g_hItemSpawns[i].Clear();
		}
		CloseHandle(kOverrideLimits);
	}
	g_bIsRound1Over = false;
}

public void IT_RoundEnd()
{
	g_bIsRound1Over = true;
}

public void IT_RoundStart()
{
	// Mapstart happens after round_start most of the time, so we need to wait for g_bIsRound1Over.
	// Plus, we don't want to have conflicts with EntityRemover.
	CreateTimer(1.0, IT_RoundStartTimer);
}

public Action IT_RoundStartTimer(Handle timer)
{
	EntitySearch();
	
	if (!g_bIsRound1Over)
	{
		// Round1
		if (g_hCvarEnabled.BoolValue)
		{
			EnumAndElimSpawns();
		}
	}
	else
	{
		// Round2
		if (g_hCvarEnabled.BoolValue)
		{
			GenerateStoredSpawns();
		}
	}
	return Plugin_Stop;
}

void EntitySearch()
{
	int iEntCount = GetEntityCount();
	for (int i = MaxClients+1; i <= iEntCount; i++)
	{
		if (IsValidEntity(i))
		{
			int itemindex = GetItemIndexFromEntity(i);
			if (itemindex >= 0 && !L4D2_IsEntityInSaferoom(i))
			{
				if (g_iItemLimits[itemindex] == 0)
				{
					KillEntity(i);
				}
			}
		}
	}
}

void EnumAndElimSpawns()
{
	EnumerateSpawns();
	RemoveToLimits();
}

void GenerateStoredSpawns()
{
	KillRegisteredItems();
	SpawnItems();
}

void KillRegisteredItems()
{
	int itemindex;
	int psychonic = GetEntityCount();
	for (int i = MaxClients+1; i <= psychonic; i++)
	{
		if (IsValidEntity(i))
		{
			itemindex = GetItemIndexFromEntity(i);
			if(itemindex >= 0 && !L4D2_IsEntityInSaferoom(i) /* && !IsEntityInSaferoom(i) */ )
			{
				if (g_iItemLimits[itemindex] > 0)
				{
					KillEntity(i);
				}
			}
		}
	}
}

void SpawnItems()
{
#if SOURCEMOD_V_MINOR > 9
	ItemTracking curitem;
	float origins[3], angles[3];
	int arrsize;
	int itement;
	char sModelname[PLATFORM_MAX_PATH];
	int wepid;
	for (int itemidx = 0; itemidx < IL_MAXSIZE; itemidx++)
	{
		Format(sModelname, sizeof(sModelname), "models/w_models/weapons/w_eq_%s.mdl", g_sItemNames[itemidx][IN_modelname]);
		arrsize = g_hItemSpawns[itemidx].Length;
		for (int idx = 0; idx < arrsize; idx++)
		{
			g_hItemSpawns[itemidx].GetArray(idx, curitem);
			GetSpawnOrigins(origins, curitem);
			GetSpawnAngles(angles, curitem);
			wepid = GetWeaponIDFromItemList(itemidx);
			itement = CreateEntityByName("weapon_spawn");
			SetEntProp(itement, Prop_Send, "m_weaponID", wepid);
			SetEntityModel(itement, sModelname);
			DispatchKeyValue(itement, "count", "1");
			TeleportEntity(itement, origins, angles, NULL_VECTOR);
			DispatchSpawn(itement);
			SetEntityMoveType(itement, MOVETYPE_NONE);
		}
	}
#else
	int curitem[ItemTracking];
	float origins[3], angles[3];
	int arrsize;
	int itement;
	char sModelname[PLATFORM_MAX_PATH];
	int wepid;
	for (int itemidx = 0; itemidx < IL_MAXSIZE; itemidx++)
	{
		Format(sModelname, sizeof(sModelname), "models/w_models/weapons/w_eq_%s.mdl", g_sItemNames[itemidx][IN_modelname]);
		arrsize = g_hItemSpawns[itemidx].Length;
		for (int idx = 0; idx < arrsize; idx++)
		{
			g_hItemSpawns[itemidx].GetArray(idx, curitem[0]);
			GetSpawnOrigins(origins, curitem);
			GetSpawnAngles(angles, curitem);
			wepid = GetWeaponIDFromItemList(itemidx);
			itement = CreateEntityByName("weapon_spawn");
			SetEntProp(itement, Prop_Send, "m_weaponID", wepid);
			SetEntityModel(itement, sModelname);
			DispatchKeyValue(itement, "count", "1");
			TeleportEntity(itement, origins, angles, NULL_VECTOR);
			DispatchSpawn(itement);
			SetEntityMoveType(itement, MOVETYPE_NONE);
		}
	}
#endif
}

void EnumerateSpawns()
{
#if SOURCEMOD_V_MINOR > 9
	int itemindex;
	ItemTracking curitem;
	float origins[3], angles[3];
	int psychonic = GetEntityCount();
	for (int i = MaxClients+1; i <= psychonic; i++)
	{
		if (IsValidEntity(i))
		{
			itemindex = GetItemIndexFromEntity(i);
			if (itemindex >= 0 /* && !IsEntityInSaferoom(i) */ )
			{
				if (!L4D2_IsEntityInSaferoom(i))
				{
					if (g_iItemLimits[itemindex] > 0)
					{
						curitem.IT_entity = i;
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
						GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
						SetSpawnOrigins(origins, curitem);
						SetSpawnAngles(angles, curitem);
						g_hItemSpawns[itemindex].PushArray(curitem);
					}
				}
			}
		}
	}
#else
	int itemindex;
	int curitem[ItemTracking];
	float origins[3], angles[3];
	int psychonic = GetEntityCount();
	for (int i = MaxClients+1; i <= psychonic; i++)
	{
		if (IsValidEntity(i))
		{
			itemindex = GetItemIndexFromEntity(i);
			if (itemindex >= 0 /* && !IsEntityInSaferoom(i) */ )
			{
				if (!L4D2_IsEntityInSaferoom(i))
				{
					if (g_iItemLimits[itemindex] > 0)
					{
						curitem[IT_entity] = i;
						GetEntPropVector(i, Prop_Send, "m_vecOrigin", origins);
						GetEntPropVector(i, Prop_Send, "m_angRotation", angles);
						SetSpawnOrigins(origins, curitem);
						SetSpawnAngles(angles, curitem);
						g_hItemSpawns[itemindex].PushArray(curitem[0]);
					}
				}
			}
		}
	}
#endif
}

void RemoveToLimits()
{
#if SOURCEMOD_V_MINOR > 9
	int curlimit;
	ItemTracking curitem;
	for (int itemidx = 0; itemidx < IL_MAXSIZE; itemidx++)
	{
		curlimit = g_iItemLimits[itemidx];
		if (curlimit > 0)
		{
			while (g_hItemSpawns[itemidx].Length > curlimit)
			{
				int killidx = GetURandomIntRange(0, g_hItemSpawns[itemidx].Length - 1);
				g_hItemSpawns[itemidx].GetArray(killidx, curitem);
				if (IsValidEntity(curitem.IT_entity))
				{
					KillEntity(curitem.IT_entity);
				}
				g_hItemSpawns[itemidx].Erase(killidx);
			}
		}
	}
#else
	int curlimit;
	int curitem[ItemTracking];
	for (int itemidx = 0; itemidx < IL_MAXSIZE; itemidx++)
	{
		curlimit = g_iItemLimits[itemidx];
		if (curlimit > 0)
		{
			while (g_hItemSpawns[itemidx].Length > curlimit)
			{
				int killidx = GetURandomIntRange(0, g_hItemSpawns[itemidx].Length - 1);
				g_hItemSpawns[itemidx].GetArray(killidx, curitem[0]);
				if (IsValidEntity(curitem[IT_entity]))
				{
					KillEntity(curitem[IT_entity]);
				}
				g_hItemSpawns[itemidx].Erase(killidx);
			}
		}
	}
#endif
}

#if SOURCEMOD_V_MINOR > 9
void SetSpawnOrigins(const float buf[3], ItemTracking spawn)
{
	spawn.IT_origins = buf[0];
	spawn.IT_origins1 = buf[1];
	spawn.IT_origins2 = buf[2];
}

void SetSpawnAngles(const float buf[3], ItemTracking spawn)
{
	spawn.IT_angles = buf[0];
	spawn.IT_angles1 = buf[1];
	spawn.IT_angles2 = buf[2];
}

void GetSpawnOrigins(float buf[3], const ItemTracking spawn)
{
	buf[0] = spawn.IT_origins;
	buf[1] = spawn.IT_origins1;
	buf[2] = spawn.IT_origins2;
}

void GetSpawnAngles(float buf[3], const ItemTracking spawn)
{
	buf[0] = spawn.IT_angles;
	buf[1] = spawn.IT_angles1;
	buf[2] = spawn.IT_angles2;
}
#else
void SetSpawnOrigins(const float buf[3], spawn[ItemTracking])
{
	spawn[IT_origins] = buf[0];
	spawn[IT_origins1] = buf[1];
	spawn[IT_origins2] = buf[2];
}

void SetSpawnAngles(const float buf[3], spawn[ItemTracking])
{
	spawn[IT_angles] = buf[0];
	spawn[IT_angles1] = buf[1];
	spawn[IT_angles2] = buf[2];
}

void GetSpawnOrigins(float buf[3], const spawn[ItemTracking])
{
	buf[0] = spawn[IT_origins];
	buf[1] = spawn[IT_origins1];
	buf[2] = spawn[IT_origins2];
}

void GetSpawnAngles(float buf[3], const spawn[ItemTracking])
{
	buf[0] = spawn[IT_angles];
	buf[1] = spawn[IT_angles1];
	buf[2] = spawn[IT_angles2];
}
#endif

int GetWeaponIDFromItemList(int id)
{
	switch (id)
	{
		case IL_PainPills:
		{
			return WEPID_PAIN_PILLS;
		}
		case IL_Adrenaline:
		{
			return  WEPID_ADRENALINE;
		}		
		case IL_PipeBomb:
		{
			return WEPID_PIPE_BOMB;
		}
		case IL_Molotov:
		{
			return WEPID_MOLOTOV;
		}
		case IL_VomitJar:
		{
			return WEPID_VOMITJAR;
		}
		default:
		{
		
		}
	}
	return -1;
}

int GetItemIndexFromEntity(int entity)
{
	char classname[128];
	int index;
	GetEdictClassname(entity, classname, sizeof(classname));
	if (GetTrieValue(g_hItemListTrie, classname, index))
	{
		return index;
	}
	
	if (strcmp(classname, "weapon_spawn") == 0)
	{
		int id = GetEntProp(entity, Prop_Send, "m_weaponID");
		switch (id)
		{
			case WEPID_VOMITJAR:
			{
				return IL_VomitJar;
			}
			case WEPID_PIPE_BOMB:
			{
				return IL_PipeBomb;
			}
			case WEPID_MOLOTOV:
			{
				return IL_Molotov;
			}
			case WEPID_PAIN_PILLS:
			{
				return IL_PainPills;
			}
			case WEPID_ADRENALINE:
			{
				return IL_Adrenaline;
			}
			default:
			{
			
			}
		}
	}
	
	return -1;
}
