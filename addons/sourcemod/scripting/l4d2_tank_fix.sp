#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>

bool blockStumble;
float throwQueuedAt[MAXPLAYERS + 1];

public void L4D2_OnRealRoundStart()
{
	blockStumble = false;
	for (int i = 1; i <= MAXPLAYERS; i++) throwQueuedAt[i] = 0.0;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!IsTank(client) || IsFakeClient(client)) return Plugin_Continue;
	
	//if tank
	if ((buttons & IN_JUMP) && (1.5 > GetGameTime() - throwQueuedAt[client]))
	{
		buttons &= ~IN_JUMP;
	}
	return Plugin_Continue;
}

public Action L4D2_OnStagger(int target)
{
    if (!IsTank(target) || !blockStumble) return Plugin_Continue;
    return Plugin_Handled;
}

public Action L4D_OnCThrowActivate(int ability)
{
	if (!IsValidEntity(ability))
	{
		LogMessage("无效 'ability_throw' 索引: %d. 继续投掷.", ability);
		return Plugin_Continue;
	}
    blockStumble = true;
    CreateTimer(2.0, UnblockStumble);
	int client = GetEntPropEnt(ability, Prop_Data, "m_hOwnerEntity");
	if (GetClientButtons(client) & IN_ATTACK) return Plugin_Handled;
	throwQueuedAt[client] = GetGameTime();
	return Plugin_Continue;
}

public Action UnblockStumble(Handle timer)
{
    blockStumble = false;
}

bool IsTank(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client) && GetClientTeam(client) == 3)
    {
        return GetEntProp(client, Prop_Send, "m_zombieClass") == 8;
    }
    return false;
}