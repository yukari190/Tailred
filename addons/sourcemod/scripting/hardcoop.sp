#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

public Plugin myinfo =
{
	name = "HardCoop",
	description = "Advanced Special Infected AI",
	author = "",
	version = "1.0",
	url = ""
};

ConVar vs_tank_damage;



bool SurvivorNearTank[MAXPLAYERS + 1];



float tankDamage;
float throwForce[MAXPLAYERS + 1][3];

/***********************************************************************************************************************************************************************************
     					All credit for the spawn timer, quantities and queue modules goes to the developers of the 'l4d2_autoIS' plugin                            
***********************************************************************************************************************************************************************************/
public void OnPluginStart()
{
	vs_tank_damage = FindConVar("vs_tank_damage");
	
	vs_tank_damage.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
	AddCommandListener(TeamCmd, "jointeam");
	HookEvent("player_transitioned", ResetSurvivors);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	tankDamage = vs_tank_damage.FloatValue;
}

public Action TeamCmd(int client, const char[] command, int argc)
{
	return Plugin_Handled;
}

public Action ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && L4D2_IsSurvivor(client))
	{
		L4D2_RestoreHealth(client);
		L4D2_ResetInventory(client);
	}
}

public void L4D_OnRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SurvivorNearTank[i] = false;
		throwForce[i][0] = 0.0;
		throwForce[i][1] = 0.0;
		throwForce[i][2] = 0.0;
	}
}

public void L4D_OnRoundEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !L4D2_IsSurvivor(i) && IsFakeClient(i))
			CreateTimer(0.1, Timer_KickBot, i);
	}
}


public Action Timer_KickBot(Handle timer, any client)
{
	if (IsClientConnected(client) && !IsClientInKickQueue(client) && IsFakeClient(client))
	{
		KickClient(client);
	}
}

public Action L4D2_OnJoinSurvivor(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action L4D2_OnAwaySurvivor(int client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (
		!L4D2_IsValidClient(victim) || !L4D2_IsSurvivor(victim) || !IsPlayerAlive(victim) || 
		!L4D2_IsValidClient(attacker) || !IsPlayerAlive(attacker) || L4D2_GetInfectedClass(attacker) != L4D2Infected_Tank
	) return Plugin_Continue;
	char classname[64];
	if (attacker == inflictor) GetClientWeapon(inflictor, classname, sizeof(classname));
	else GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrContains(classname, "tank_claw", false) != -1)
	{
		for (int i = 0; i < NUM_OF_SURVIVORS; i++)
		{
			int index = L4D_GetSurvivorOfIndex(i);
			if (index == 0 || !IsPlayerAlive(index) || index == victim || !SurvivorNearTank[index]) continue;
			
			if (!L4D2_IsPlayerIncap(index)) L4D2_SetAnimFling(index, attacker, throwForce[index]);
			SDKHooks_TakeDamage(index, attacker, attacker, tankDamage, DMG_GENERIC);
		}
	}
	return Plugin_Continue;
}

public void L4D_OnTankSpawn(int tankClient)
{
	CreateTimer(0.1, Tank_Distance, tankClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Tank_Distance(Handle timer, any client)
{
	if (!L4D2_IsValidClient(client) || !L4D2_IsInfected(client) || L4D2_GetInfectedClass(client) != L4D2Infected_Tank || !IsPlayerAlive(client)) return Plugin_Stop;
	float survivorPos[3], tankPos[3];
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D_GetSurvivorOfIndex(i);
		if (index == 0 || !IsPlayerAlive(index)) continue;
		GetClientAbsOrigin(client, tankPos);
		GetClientAbsOrigin(index, survivorPos);
		if (GetVectorDistance(survivorPos, tankPos) < 120)
		{
			NormalizeVector(survivorPos, survivorPos);
			NormalizeVector(tankPos, tankPos);
			throwForce[index][0] = L4D2_Clamp((360000.0 * (survivorPos[0] - tankPos[0])), -400.0, 400.0);
			throwForce[index][1] = L4D2_Clamp((90000.0 * (survivorPos[1] - tankPos[1])), -400.0, 400.0);
			throwForce[index][2] = 300.0;
			SurvivorNearTank[index] = true;
		}
		else
		{
			SurvivorNearTank[index] = false;
			throwForce[index][0] = 0.0;
			throwForce[index][1] = 0.0;
			throwForce[index][2] = 0.0;
		}
	}
	return Plugin_Continue;
}



/***********************************************************************************************************************************************************************************

                                                                    	UTILITY
                                                                    
***********************************************************************************************************************************************************************************/

void L4D2_RestoreHealth(int client)
{
	L4D2_CheatCommand(client, "give", "health");
	SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
	SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
	SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
}

void L4D2_ResetInventory(int client)
{
	for (int j = 0; j < 5; j++)
	{
		int item = GetPlayerWeaponSlot(client, j);
		if (item > 0)
		{
			RemovePlayerItem(client, item);
		}
	}	
	L4D2_CheatCommand(client, "give", "pistol");
}

void L4D2_CheatCommand(int client, char[] commandName, char[] argument1 = "", char[] argument2 = "")
{
    if (GetCommandFlags(commandName) != INVALID_FCVAR_FLAGS)
	{
		if (!L4D2_IsValidClient(client))
		{
			int[] player = new int[MaxClients];
			int numplayer = 0;
			for (int i = 1; i <= MaxClients; i++)
			{
				if (IsClientInGame(i))
				{
					player[numplayer] = i;
					numplayer++;
				}
			}
			client = player[GetRandomInt(0, numplayer - 1)];
		}
		if (L4D2_IsValidClient(client))
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
