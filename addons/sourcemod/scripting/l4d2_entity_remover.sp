#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2lib>

Handle kERData;

#define ER_KV_ACTION_KILL			1

#define ER_KV_PROPTYPE_INT		1
#define ER_KV_PROPTYPE_FLOAT		2
#define ER_KV_PROPTYPE_BOOL		3
#define ER_KV_PROPTYPE_STRING		4

#define ER_KV_CONDITION_EQUAL		1
#define ER_KV_CONDITION_NEQUAL	2
#define ER_KV_CONDITION_LESS		3
#define ER_KV_CONDITION_GREAT		4
#define ER_KV_CONDITION_CONTAINS	5


public void OnPluginStart()
{
	ER_KV_Load();
	RegAdminCmd("confogl_erdata_reload", ER_KV_CmdReload, ADMFLAG_CONFIG);
}

public void OnPluginEnd()
{
	ER_KV_Close();
}

void ER_KV_Close()
{
	if(kERData == INVALID_HANDLE) return;
	CloseHandle(kERData);
	kERData = INVALID_HANDLE;
}

void ER_KV_Load()
{
	char sNameBuff[PLATFORM_MAX_PATH], sDescBuff[256], sValBuff[32];
	
	kERData = CreateKeyValues("EntityRemover");
	BuildPath(Path_SM, sNameBuff, sizeof(sNameBuff), "configs/entityremove.txt"); //Build our filepath
	if (!FileToKeyValues(kERData, sNameBuff))
	{
		LogError("[ER] Couldn't load EntityRemover data!");
		ER_KV_Close();
		return;	
	}
	
	// Create cvars for all entity removes
	KvGotoFirstSubKey(kERData);
	do
	{
			KvGotoFirstSubKey(kERData);
			do
			{
				KvGetString(kERData, "cvar", sNameBuff, sizeof(sNameBuff));
				KvGetString(kERData, "cvar_desc", sDescBuff, sizeof(sDescBuff));
				KvGetString(kERData, "cvar_val", sValBuff, sizeof(sValBuff));
				CreateConVar(sNameBuff, sValBuff, sDescBuff);
				
			} while(KvGotoNextKey(kERData));
			KvGoBack(kERData);
	} while(KvGotoNextKey(kERData));
	KvRewind(kERData);
}


public Action ER_KV_CmdReload(int client, int args)
{
	ReplyToCommand(client, "[ER] Reloading EntityRemoveData");
	ER_KV_Reload();
	return Plugin_Handled;
}

void ER_KV_Reload()
{
	ER_KV_Close();
	ER_KV_Load();	
}

bool ER_KV_TestCondition(int lhsval, int rhsval, int condition)
{
	switch(condition)
	{
		case ER_KV_CONDITION_EQUAL:
		{
			return lhsval == rhsval;
		}
		case ER_KV_CONDITION_NEQUAL:
		{
			return lhsval != rhsval;
		}
		case ER_KV_CONDITION_LESS:
		{
			return lhsval < rhsval;
		}
		case ER_KV_CONDITION_GREAT:
		{
			return lhsval > rhsval;
		}
	}
	return false;
}

bool ER_KV_TestConditionFloat(float lhsval, float rhsval, int condition)
{
	switch(condition)
	{
		case ER_KV_CONDITION_EQUAL:
		{
			return lhsval == rhsval;
		}
		case ER_KV_CONDITION_NEQUAL:
		{
			return lhsval != rhsval;
		}
		case ER_KV_CONDITION_LESS:
		{
			return lhsval < rhsval;
		}
		case ER_KV_CONDITION_GREAT:
		{
			return lhsval > rhsval;
		}
	}
	return false;
}

bool ER_KV_TestConditionString(char[] lhsval, char[] rhsval, int condition)
{
	switch(condition)
	{
		case ER_KV_CONDITION_EQUAL:
		{
			return StrEqual(lhsval, rhsval);
		}
		case ER_KV_CONDITION_NEQUAL:
		{
			return !StrEqual(lhsval, rhsval);
		}
		case ER_KV_CONDITION_CONTAINS:
		{
			return StrContains(lhsval, rhsval) != -1;
		}
	}
	return false;
}

// Returns true if the entity is still alive (not killed)
bool ER_KV_ParseEntity(Handle kEntry, int iEntity)
{
	char sBuffer[64], mapname[64];

	// Check CVAR for this entry
	KvGetString(kEntry, "cvar", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer) && !GetConVarBool(FindConVar(sBuffer))) return true;

	// Check MapName for this entry
	GetCurrentMap(mapname, sizeof(mapname));
	KvGetString(kEntry, "map", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer) && StrContains(sBuffer, mapname) == -1)
			return true;

	KvGetString(kEntry, "excludemap", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer) && StrContains(sBuffer, mapname) != -1)
			return true;
	
	// Do property check for this entry
	KvGetString(kEntry, "property", sBuffer, sizeof(sBuffer));
	if(strlen(sBuffer))
	{
		int proptype = KvGetNum(kEntry, "proptype");
		
		switch(proptype)
		{
			case ER_KV_PROPTYPE_INT, ER_KV_PROPTYPE_BOOL:
			{
				int rhsval = KvGetNum(kEntry, "propval");
				int lhsval = GetEntProp(iEntity, view_as<PropType>(KvGetNum(kEntry, "propdata")), sBuffer);
				if(!ER_KV_TestCondition(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
			case ER_KV_PROPTYPE_FLOAT:
			{
				float rhsval = KvGetFloat(kEntry, "propval"), lhsval = GetEntPropFloat(iEntity, view_as<PropType>(KvGetNum(kEntry, "propdata")), sBuffer);
				if(!ER_KV_TestConditionFloat(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
			case ER_KV_PROPTYPE_STRING:
			{
				char rhsval[64], lhsval[64];
				KvGetString(kEntry, "propval", rhsval, sizeof(rhsval));
				GetEntPropString(iEntity, view_as<PropType>(KvGetNum(kEntry, "propdata")), sBuffer, lhsval, sizeof(lhsval));
				if(!ER_KV_TestConditionString(lhsval, rhsval, KvGetNum(kEntry, "condition"))) return true;
			}
		}
	}
	return ER_KV_TakeAction(KvGetNum(kEntry, "action"), iEntity);

}

// Returns true if the entity is still alive (not killed)
bool ER_KV_TakeAction(int action, int iEntity)
{
	switch(action)
	{
		case ER_KV_ACTION_KILL:
		{
			AcceptEntityInput(iEntity, "Kill");
			return false;
		}
		default:
		{
			LogError("[ER] ParseEntity Encountered bad action!");
		}
	}
	return true;
}

bool ER_KillParachutist(int ent)
{
	char buf[32];
	GetCurrentMap(buf, sizeof(buf));
	if (StrEqual(buf, "c3m2_swamp"))
	{
		GetEntPropString(ent, Prop_Data, "m_iName", buf, sizeof(buf));
		if(!strncmp(buf, "parachute_", 10))
		{
			AcceptEntityInput(ent, "Kill");
			return true;
		}
	}
	return false;
}

bool ER_ReplaceTriggerHurtGhost(int ent)
{
	char buf[32];
	GetEdictClassname(ent, buf, sizeof(buf));
	if (StrEqual(buf, "trigger_hurt_ghost"))
	{
		// Replace trigger_hurt_ghost with trigger_hurt
		int replace = CreateEntityByName("trigger_hurt");
		if (replace == -1) 
		{
			LogError("[ER] Could not create trigger_hurt entity!");
			return false;
		}
		
		// Get modelname
		char model[16];
		GetEntPropString(ent, Prop_Data, "m_ModelName", model, sizeof(model));
		
		// Get position and rotation
		float pos[3], ang[3];
		GetEntPropVector(ent, Prop_Send, "m_vecOrigin", pos);
		GetEntPropVector(ent, Prop_Send, "m_angRotation", ang);

		// Kill the old one
		AcceptEntityInput(ent, "Kill");		
		
		// Set the values for the new one
		DispatchKeyValue(replace, "StartDisabled", "0");
		DispatchKeyValue(replace, "spawnflags", "67");
		DispatchKeyValue(replace, "damagetype", "32");
		DispatchKeyValue(replace, "damagemodel", "0");
		DispatchKeyValue(replace, "damagecap", "10000");
		DispatchKeyValue(replace, "damage", "10000");
		DispatchKeyValue(replace, "model", model);
		
		DispatchKeyValue(replace, "filtername", "filter_infected");
		
		// Spawn the new one
		TeleportEntity(replace, pos, ang, NULL_VECTOR);
		DispatchSpawn(replace);
		ActivateEntity(replace);

		return true;
	}

	return false;
}

public void L4D2_OnRealRoundStart()
{
	CreateTimer(0.3,  ER_RoundStart_Timer);
}

public Action ER_RoundStart_Timer(Handle timer)
{
	char sBuffer[64];
	
	if(kERData != INVALID_HANDLE) KvRewind(kERData);
	
	int iEntCount = GetEntityCount();
	for (int ent = MaxClients+1; ent <= iEntCount; ent++)
	{
		if (IsValidEntity(ent))
		{
			GetEdictClassname(ent, sBuffer, sizeof(sBuffer));
			if (ER_KillParachutist(ent))
			{
			}
			else if (ER_ReplaceTriggerHurtGhost(ent))
			{
			}
			else if (kERData != INVALID_HANDLE && KvJumpToKey(kERData, sBuffer))
			{
				KvGotoFirstSubKey(kERData);
				do
				{
					// Parse each entry for this entity's classname
					// Stop if we run out of entries or we have killed the entity
					if(!ER_KV_ParseEntity(kERData, ent)) break;	
				} while (KvGotoNextKey(kERData));
				KvRewind(kERData);
			}
		}
	}
}
