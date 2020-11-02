#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

bool inCharge[MAXPLAYERS + 1];

public Plugin myinfo =
{
    name = "StopTrolls",
    author = "raziEiL [disawar1]",
    description = "防止人们阻挡爬上梯子的玩家.",
    version = "1.0",
    url = "http://steamcommunity.com/id/raziEiL"
}

public void OnPluginStart()
{
    HookEvent("charger_charge_start", Charging);
    HookEvent("charger_charge_end", NotCharging);
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	inCharge[client] = false;
	
	if (!IsValidInGame(client)) return;
	
	if (nowteam > 1 && oldteam <= 1)
	{
		SDKHook(client, SDKHook_Touch, SDKHook_cb_Touch);
	}
	else if (nowteam <= 1 && oldteam > 1)
	{
		SDKUnhook(client, SDKHook_Touch, SDKHook_cb_Touch);
	}
}

public Action Charging(Event event, const char[] name, bool dontBroadcast)
{
    inCharge[GetClientOfUserId(event.GetInt("userid"))] = true;
}

public Action NotCharging(Event event, const char[] name, bool dontBroadcast)
{
    inCharge[GetClientOfUserId(event.GetInt("userid"))] = false;
}

public Action SDKHook_cb_Touch(int entity, int other)
{
    if (other > MaxClients || other < 1) return;
    
    if (IsGuyTroll(entity, other)){
        
        int iClass = GetInfectedClass(entity);
        
        if (iClass == 8 || iClass == 9)
		{
            iClass = GetInfectedClass(other);
			
			if (iClass == 8) return;
            
            if (inCharge[other]) return;
            
            if (IsOnLadder(other)){
                
                float vOrg[3];
                GetClientAbsOrigin(other, vOrg);
                vOrg[2] += 2.5;
                TeleportEntity(other, vOrg, NULL_VECTOR, NULL_VECTOR);
            }
            else
            TeleportEntity(other, NULL_VECTOR, NULL_VECTOR, view_as<float>({0.0, 0.0, 251.0}));
        }
    }
}

bool IsGuyTroll(int victim, int troll)
{
    return IsOnLadder(victim) && GetClientTeam(victim) != GetClientTeam(troll) && GetEntPropFloat(victim, Prop_Send, "m_vecOrigin[2]") < GetEntPropFloat(troll, Prop_Send, "m_vecOrigin[2]");
}

bool IsOnLadder(int entity)
{
    return GetEntityMoveType(entity) == MOVETYPE_LADDER;
}
