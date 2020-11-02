#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public Plugin myinfo = 
{
    name = "L4D HOTs",
    author = "ProdigySim, CircleSquared",
    description = "Pills and Adrenaline heal over time",
    version = "0.3",
    url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

ConVar g_hPillCvar, hCvarPillInterval, hCvarPillIncrement, hCvarPillTotal;
float iPillInterval;
int iPillIncrement, iPillTotal;

public void OnPluginStart()
{
    g_hPillCvar = FindConVar("pain_pills_health_value");
    hCvarPillInterval = CreateConVar("l4d_pills_hot_interval", "0.1", "Interval for pills hot");
    hCvarPillIncrement = CreateConVar("l4d_pills_hot_increment", "2", "Increment amount for pills hot");
    hCvarPillTotal = CreateConVar("l4d_pills_hot_total", "50", "Total amount for pills hot");
	
    iPillInterval = GetConVarFloat(hCvarPillInterval);
    iPillIncrement = GetConVarInt(hCvarPillIncrement);
    iPillTotal = GetConVarInt(hCvarPillTotal);
	
	hCvarPillInterval.AddChangeHook(ConVarChange);
	hCvarPillIncrement.AddChangeHook(ConVarChange);
	hCvarPillTotal.AddChangeHook(ConVarChange);
	
    SetConVarInt(g_hPillCvar, 0);
    HookEvent("pills_used", PillsUsed_Event);
}

public void OnPluginEnd()
{
    ResetConVar(g_hPillCvar);
}

public void ConVarChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
    iPillInterval = hCvarPillInterval.FloatValue;
    iPillIncrement = hCvarPillIncrement.IntValue;
    iPillTotal = hCvarPillTotal.IntValue;
}

public Action PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    HealEntityOverTime(client, iPillInterval, iPillIncrement, iPillTotal);
}

void HealEntityOverTime(int client, float interval, int increment, int total)
{
    int maxhp=GetEntProp(client, Prop_Send, "m_iMaxHealth");
    
    if(client==0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return;
    }
    if(increment >= total)
    {
        HealTowardsMax(client, total, maxhp);
    }
    else
    {
        HealTowardsMax(client, increment, maxhp);
        Handle myDP;
        CreateDataTimer(interval, __HOT_ACTION, myDP, 
            TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
        WritePackCell(myDP, client);
        WritePackCell(myDP, increment);
        WritePackCell(myDP, total-increment);
        WritePackCell(myDP, maxhp);
    }
}

public Action __HOT_ACTION(Handle timer, Handle pack)
{
    ResetPack(pack);
    int client = ReadPackCell(pack);
    int increment = ReadPackCell(pack);
    DataPackPos pos = GetPackPosition(pack);
    int remaining = ReadPackCell(pack);
    int maxhp = ReadPackCell(pack);
    
//  PrintToChatAll("HOT: %d %d %d %d", client, increment, remaining, maxhp);
    
    if(client==0 || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    
    if(increment >= remaining)
    {
        HealTowardsMax(client, remaining, maxhp);
        return Plugin_Stop;
    }
    HealTowardsMax(client, increment, maxhp);
    SetPackPosition(pack, pos);
    WritePackCell(pack, remaining-increment);
    
    return Plugin_Continue;
}

void HealTowardsMax(int client, int amount, int max)
{
    float hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer"), 
    overflow = (hb+GetClientHealth(client))-max;
    if(overflow > 0)
    {
        hb -= overflow;
    }
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
}
