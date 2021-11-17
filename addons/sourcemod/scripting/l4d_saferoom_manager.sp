#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

public Plugin myinfo = 
{
    name = "Saferoom Door Manager",
    author = "Sir",
    description = "Manages Saferoom Doors",
    version = "1.1b",
    url = "https://github.com/SirPlease/SirCoding"
};

ConVar
	g_hSafeEndClose = null,
	g_hSafeEndTankBlock = null,
	g_hSurvivorLimit = null;

int
	Door,
	TotalDoors,
	checkpointreached[MAXPLAYERS+1],
	checkpointtotal,
	IsIncapped[MAXPLAYERS+1];

bool
	bHasHooked;

public void OnPluginStart()
{
    g_hSafeEndClose = CreateConVar("safe_end_lock", "1", "Close end Saferoom Door on round start?", CVAR_FLAGS, true, 0.0, true, 1.0);
    g_hSafeEndTankBlock = CreateConVar("safe_end_tank", "1", "Stop Survivors from closing saferoom during Tank when 50% or more is Alive", CVAR_FLAGS, true, 0.0, true, 1.0);
    
    g_hSurvivorLimit = FindConVar("survivor_limit");
    
    bHasHooked = false;
    HookEvent("round_start", Round_Start);
}

public Action Round_Start(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        checkpointreached[i] = 0;
        IsIncapped[i] = 0;
    }
    checkpointtotal = 0;
    
    Door = 0;
    TotalDoors = 0;
}

public void OnEntityCreated(int entity, const char[] classname) 
{
    if (classname[0] != 'p') {
        return;
    }
    
    if (StrEqual(classname, "prop_door_rotating_checkpoint")) //Saferoom Door
    {
        CreateTimer(1.0, DelayDoor, entity);
    }
}

public Action DelayDoor(Handle timer, any entity)
{
    char sModel[128], sName[128];
    GetEntPropString(entity, Prop_Data, "m_ModelName", sModel, sizeof(sModel));
    GetEntPropString(entity, Prop_Data, "m_iName", sName, sizeof(sName));
    
    if (StrEqual(sModel, "models/props_doors/checkpoint_door_02.mdl") || StrEqual(sModel, "models/props_doors/checkpoint_door_-02.mdl"))
    {
        TotalDoors++;
        
        if(StrEqual(sName, "checkpoint_entrance") || StrEqual(sName, "door_checkpoint"))
        {
            Door = entity;
            FoundYou();
        }
        else CreateTimer (1.0, NoDoors, entity);
    }
    
    return Plugin_Stop;
}

public Action NoDoors(Handle timer, any entity)
{
    if (TotalDoors == 1 && Door == 0)
    {
        Door = entity;
        FoundYou();
    }
    
    return Plugin_Stop;
}

void FoundYou()
{
    if (L4D_IsMissionFinalMap()) return;
    
    if (g_hSafeEndClose.BoolValue) AcceptEntityInput(Door, "Close");
    
    if (g_hSafeEndTankBlock.BoolValue) Hook();
    else UnHook();
}

public void Player_Entered_Checkpoint(Event event, const char[] name, bool dontBroadcast)
{
    int entered = GetClientOfUserId(event.GetInt("userid"));
    int door = event.GetInt("door");
    
    if (IsValidClient(entered))
    {
        if (door == Door)
        {
            if (GetClientTeam(entered) == 2) 
            {
                checkpointreached[entered] = 1;
                checkpointtotal++;
                
                CanWeClose();
            }	
        }
    }
}

public void Player_Left_Checkpoint(Event event, const char[] name, bool dontBroadcast)
{
    int left = GetClientOfUserId(event.GetInt("userid"));
    
    if (IsValidClient(left) && checkpointreached[left] == 1)
    {
        checkpointreached[left] = 0;
        checkpointtotal--;
        
        if (checkpointtotal > 0) CanWeClose();
    }
}

public void OnRevive(Event event, const char[] name, bool dontBroadcast)
{
    int revive = GetClientOfUserId(event.GetInt("subject"));
    if (!IsValidClient(revive) || GetClientTeam(revive ) != 2) return;
    
    IsIncapped[revive] = 0;
    
    if (checkpointtotal > 0) CanWeClose();
}

public void OnDeath(Event event, const char[] name, bool dontBroadcast)
{
    int death = GetClientOfUserId(event.GetInt("userid"));
    char victim[64];
    event.GetString("victimname", victim, sizeof(victim));
    
    if (!IsValidClient(death)) return;
    
    if (GetClientTeam(death) != 2 && checkpointreached[death] == 1)
    {
        checkpointreached[death] = 0;
        checkpointtotal--;
        
        if (checkpointtotal > 0) CanWeClose();
    }
    else if (StrEqual(victim, "tank", false)) CanWeClose();
}

public void OnIncap(Event event, const char[] name, bool dontBroadcast)
{
    int incap = GetClientOfUserId(event.GetInt("userid"));
    if (!IsValidClient(incap) || GetClientTeam(incap) != 2) return;
    
    IsIncapped[incap] = 1;
    
    if (checkpointtotal > 0) CanWeClose();
}

void CanWeClose()
{
    if(!CheckClose()) DispatchKeyValue(Door, "spawnflags", "32768");
    else DispatchKeyValue(Door, "spawnflags", "8192");
}

bool CheckClose()
{
    if (TankUp())
    {
        if (g_hSurvivorLimit.IntValue <= 2) return false;
        
        if ((((float(checkpointtotal) + float(FindSurvivors())) / float(g_hSurvivorLimit.IntValue)) * 100) > 50)
        {
            return false;
        }
    }
    return true;
}

bool TankUp()
{
    for (int t = 1; t <= MaxClients; t++)
    {
        if (!IsClientInGame(t) 
            || GetClientTeam(t) != 3 
        || !IsPlayerAlive(t) 
        || GetEntProp(t, Prop_Send, "m_zombieClass") != 8)
        continue;
        
        return true; // Found tank, return
    }
    return false;
}

int FindSurvivors()
{
    int Outsiders = 0;
    
    for (int outsider = 1; outsider <= MaxClients; outsider++)
    {
        if (IsValidClient(outsider) 
            && GetClientTeam(outsider) == 2
        && !checkpointreached[outsider]  
        && IsPlayerAlive(outsider) 
        && !IsIncapped[outsider]) 
        
        Outsiders++;
    }
    return Outsiders;
}

void Hook()
{
    if (bHasHooked) return;
    bHasHooked = true;
    
    HookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    HookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    HookEvent("revive_success", OnRevive); 
    HookEvent("player_death", OnDeath);
    HookEvent("player_incapacitated", OnIncap);
}

void UnHook()
{
    if(!bHasHooked) return;
    bHasHooked = false;
    
    UnhookEvent("player_entered_checkpoint", Player_Entered_Checkpoint);
    UnhookEvent("player_left_checkpoint", Player_Left_Checkpoint);
    
    UnhookEvent("revive_success", OnRevive); 
    UnhookEvent("player_death", OnDeath);
    UnhookEvent("player_incapacitated", OnIncap);
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}