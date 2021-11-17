#if defined l4d2util_inc_
	#endinput
#endif
#define l4d2util_inc_

#include <l4d2util_stocks>
#include <l4d2util_constants>
#include <l4d2util_infected>
#include <l4d2util_rounds>
#include <l4d2util_survivors>
#include <l4d2util_tanks>
#include <l4d2util_weapons>

/**
 *
 * @return: the index to a random survivor
 */
stock int GetRandomSurvivor()
{
	int survivors[MAXPLAYERS+1];
	for (int i = 0; i <= MAXPLAYERS; ++i)
	{
		survivors[i] = -1;	
	}
	int numSurvivors = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsSurvivor(i) && IsPlayerAlive(i))
		{
		    survivors[numSurvivors] = i;
		    numSurvivors++;
		}
	}
	return survivors[GetRandomInt(0, numSurvivors - 1)];
}

stock int GetSurvivorAttacker(int survivor)
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

stock bool IsValidAndInGame(int client)
{
	return IsValidClientIndex(client) && IsClientInGame(client);
}

stock bool IsSpectator(int client)
{
	return IsClientInGame(client) && GetClientTeam(client) == view_as<int>(L4D2Team_Spectator);
}

stock bool IsValidSpectator(int client)
{
	return IsValidClientIndex(client) && IsSpectator(client);
}

stock int GetSeriousClientCount(bool inGame = false)
{
	int clients = 0;
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (inGame)
		{
			if (IsClientInGame(i) && !IsFakeClient(i)) clients++;
		}
		else
		{
			if (IsClientConnected(i) && !IsFakeClient(i)) clients++;
		}
	}
	
	return clients;
}

stock void GetEdictName(int entity, char[] name, int length)
{
	GetEntPropString(entity, Prop_Data, "m_iName", name, length);
}

stock void GetEdictModelName(int entity, char[] name, int size)
{
	GetEntPropString(entity, Prop_Data, "m_ModelName", name, size);
}

stock void KillEntity(int iEntity)
{
	char pluginName[PLATFORM_MAX_PATH], classname[64];
	GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
	GetEdictClassname(iEntity, classname, 64);
	PrintToServer("[%s] Removed %s", pluginName, classname);
	
#if SOURCEMOD_V_MINOR > 8
	RemoveEntity(iEntity);
#else
	AcceptEntityInput(iEntity, "Kill");
#endif
}
