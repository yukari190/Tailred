#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <l4d2lib>
#include <l4d2util>
#include <readyup>

public Plugin myinfo =
{
	name = "Starting Ai Weapon",
	author = "Yukari190",
	description = "",
	version = "1.0"
};

public void OnRoundIsLive()
{
	GiveStartingWeapon();
}

void GiveStartingWeapon()
{
	for (int i = 0; i < L4D2_GetSurvivorCount(); i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index) || !IsFakeClient(index)) continue;
		if (GetPlayerWeaponSlot(index, 0) <= -1)
		{
			CheatCommand(index, "give", "smg_silenced");
		}
	}
}

void CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (IsValidAndInGame(client))
		{
		    int originalUserFlags = GetUserFlagBits(client);
		    int originalCommandFlags = GetCommandFlags(commandName);            
		    SetUserFlagBits(client, ADMFLAG_ROOT); 
		    SetCommandFlags(commandName, originalCommandFlags ^ FCVAR_CHEAT);               
		    FakeClientCommand(client, "%s %s %s", commandName, argument1, argument2);
		    SetCommandFlags(commandName, originalCommandFlags);
		    SetUserFlagBits(client, originalUserFlags);
		}
		else
		{
			char pluginName[128];
			GetPluginFilename(null, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}
