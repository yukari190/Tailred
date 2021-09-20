#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <l4d2lib>

public Plugin myinfo = 
{
    name = "L4D HOTs",
    author = "ProdigySim, CircleSquared, Yukari190",
    description = "Pills and Adrenaline heal over time",
    version = "0.4.1",
    url = "https://bitbucket.org/ProdigySim/misc-sourcemod-plugins"
}

static const float l4d_pills_hot_interval = 0.1;
static const int l4d_pills_hot_increment = 2;
int l4d_pills_hot_total[MAXPLAYERS+1];

public void OnPluginStart()
{
	SetConVarInt(FindConVar("pain_pills_health_value"), 0);
	HookEvent("pills_used", PillsUsed_Event);
}

public void OnPluginEnd()
{
    ResetConVar(FindConVar("pain_pills_health_value"));
}

public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		l4d_pills_hot_total[i] = 50;
	}
}

public Action PillsUsed_Event(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    float iPillInterval = l4d_pills_hot_interval;
    int iPillIncrement = l4d_pills_hot_increment;
    int iPillTotal = l4d_pills_hot_total[client];
    HealEntityOverTime(client, iPillInterval, iPillIncrement, iPillTotal);
	if (iPillTotal != 30) PrintHintText(client, "药片下次的恢复效果将降低!");
	l4d_pills_hot_total[client] = 30;
}

void HealEntityOverTime(int client, float interval, int increment, int total)
{
    int maxhp = GetEntProp(client, Prop_Send, "m_iMaxHealth", 2);
    
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return;
    }
    if (increment >= total)
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
    
    if (!client || !IsClientInGame(client) || !IsPlayerAlive(client))
    {
        return Plugin_Stop;
    }
    
    if (increment >= remaining)
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
    float hb = float(amount) + GetEntPropFloat(client, Prop_Send, "m_healthBuffer");
    float overflow = (hb+GetClientHealth(client))-max;
    if (overflow > 0)
    {
        hb -= overflow;
    }
    SetEntPropFloat(client, Prop_Send, "m_healthBuffer", hb);
}
