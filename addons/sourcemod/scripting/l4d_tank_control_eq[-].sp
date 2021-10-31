#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <colors>

//由于"m_iTankTickets"在Windows下会导致崩溃, 故删除相关代码.
public Plugin myinfo = 
{
    name = "L4D2 Tank Control",
    author = "arti, Yukari190", //Add support sm1.11 - A1m`
    description = "Distributes the role of the tank evenly throughout the team",
    version = "0.0.18",
    url = "https://github.com/alexberriman/l4d2-plugins/tree/master/l4d_tank_control"
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStatis)
{    
    // Reset the tank's frustration if need be
    if (! IsFakeClient(tank_index)) 
    {
        PrintHintText(tank_index, "控制权重新填充");
        for (int i = 1; i <= MaxClients; i++) 
        {
            if (! IsClientInGame(i) || GetClientTeam(i) != 3)
                continue;

            if (tank_index == i) CPrintToChat(i, "{red}<{default}Tank 控制权{red}> {olive}控制权 {red}重新填充");
            else CPrintToChat(i, "{red}<{default}Tank 控制权{red}> {default}({green}%N{default}'s) {olive}控制权 {red}重新填充", tank_index);
        }
        
        SetTankFrustration(tank_index, 100);
        L4D2Direct_SetTankPassedCount(L4D2Direct_GetTankPassedCount() + 1);
        
        return Plugin_Handled;
    }
    
    return Plugin_Continue;
}

void SetTankFrustration(int iTankClient, int iFrustration) {
    if (iFrustration < 0 || iFrustration > 100) {
        return;
    }
    
    SetEntProp(iTankClient, Prop_Send, "m_frustration", 100-iFrustration);
}