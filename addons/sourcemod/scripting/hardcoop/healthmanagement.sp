#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <l4d2lib>
#include <l4d2util>

#define MAX_HEALTH 100
#define	NO_TEMP_HEALTH 0.0

ConVar 
	hCvarLeechThreshold,
	hCvarLeechPercent,
	hCvarCommonLeechAmount;

bool should_leech = true;

public Plugin myinfo = 
{
	name = "Health Management",
	author = "breezy",
	description = "Providing alternative health sources to survivor team",
	version = "",
	url = ""
};

public void OnPluginStart()
{
	hCvarLeechThreshold = CreateConVar("leech_threshold", "20", "Below this health level (inc. temp health), survivors are able to leech");
	hCvarLeechPercent = CreateConVar("leech_percent", "0.05", "造成伤害的百分比被吸收为健康");
	hCvarCommonLeechAmount = CreateConVar("leech_common_ammount", "1", "Health leeched, pending 'leech_chance', from killing a common");
	
	FindConVar("z_survivor_respawn_health").SetInt(100);
	FindConVar("sv_rescue_disabled").SetInt(1);
	
	RegConsoleCmd("sm_leech", Cmd_ToggleLeech, "Toggle health leeching");
	
	HookEvent("infected_death", Event_OnCommonKilled);
	HookEvent("player_transitioned", ResetSurvivors);
}
	
public void OnPluginEnd()
{
	FindConVar("z_survivor_respawn_health").RestoreDefault();
	FindConVar("sv_rescue_disabled").RestoreDefault();
}

public Action ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (IsValidSurvivor(client))
	{
		RestoreHealth(client);
		ResetInventory(client);
	}
}

public Action Event_OnCommonKilled(Event event, const char[] name, bool dontBroadcast)
{ 
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (IsValidSurvivor(attacker) && IsPlayerAlive(attacker))
	{
		int currentHealth = GetSurvivorPermanentHealth(attacker);
		int newHealth = currentHealth + hCvarCommonLeechAmount.IntValue;
		if (currentHealth < hCvarLeechThreshold.IntValue && newHealth < MAX_HEALTH)
		{
			SetEntityHealth(attacker, newHealth);
		} 		
	} 
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype, int hitgroup)
{
    if (should_leech && IsValidInfected(victim) && IsValidSurvivor(attacker))
    {
        int currentHealth = GetSurvivorPermanentHealth(attacker);
        int leechedHealth = RoundToFloor(hCvarLeechPercent.FloatValue * float(damage));
        int newHealth = currentHealth + leechedHealth;
        if (currentHealth < hCvarLeechThreshold.IntValue && newHealth < MAX_HEALTH)
        {
			SetEntityHealth(attacker, newHealth);
        }
    }
}

public Action Cmd_ToggleLeech(int client, int args)
{
	if (IsValidSurvivor(client) && IsPlayerAlive(client))
	{
		should_leech = !should_leech;
		if (should_leech)
		{
			PrintToChatAll("Health leeching enabled.");
		}
		else
		{
			PrintToChatAll("Health leeching disabled.");
		}
	}
}

void RestoreHealth(int client)
{
	CheatCommand(client, "give", "health");
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", NO_TEMP_HEALTH);		
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
}

void ResetInventory(int client)
{
	for (int j = 0; j < 5; j++)
	{
		int item = GetPlayerWeaponSlot(client, j);
		if (item > 0)
		{
			RemovePlayerItem(client, item);
		}
	}	
	CheatCommand(client, "give", "pistol");
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
			GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));        
			LogError("%s could not find or create a client through which to execute cheat command %s", pluginName, commandName);
		}
    }
}
