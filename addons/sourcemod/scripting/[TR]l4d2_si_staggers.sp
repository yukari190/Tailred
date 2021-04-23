/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.

	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.

	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <[SilverShot]left4dhooks>
#include <[TR]l4d2library>

int FLAGS[3] = {
    1 << 0, // boomer
    1 << 1, // charger
    1 << 2, // witch
};

ConVar hCvarInfectedFlags;

int iActiveFlags;

public Plugin myinfo = 
{
    name = "L4D2 No SI Friendly Staggers",
    author = "Visor",
    description = "Removes SI staggers caused by other SI(Boomer, Charger, Witch)",
    version = "1.1",
    url = ""
};

public void OnPluginStart()
{
    hCvarInfectedFlags = CreateConVar("l4d2_disable_si_friendly_staggers", "2", "Remove SI staggers caused by other SI(bitmask: 1-Boomer/2-Charger/4-Witch)");
    iActiveFlags = hCvarInfectedFlags.IntValue;
    hCvarInfectedFlags.AddChangeHook(PluginActivityChanged);
}

public int PluginActivityChanged(Handle cvar, const char[] oldValue, const char[] newValue)
{
    iActiveFlags = hCvarInfectedFlags.IntValue;
}

public Action L4D2_OnStagger(int target, int source)
{
    // For some reason, Valve chose to set a null source for charger impact staggers.
    // And Left4DHooks converts this null source to -1.
    // Since there aren't really any other possible calls for this function,
    // assume (source == -1) as a charger impact stagger
    // TODO: Patch the binary to pass on the Charger's client ID instead of nothing?
    // Probably not worth it, for now, at least
    
    if (!IsValidEdict(source) && source != -1)
        return Plugin_Continue;
        
    if (!iActiveFlags)  // Is the plugin active at all?
        return Plugin_Continue;

    if (GetInfectedClass(source) == 2 && !(iActiveFlags & FLAGS[0]))  // Is the Boomer eligible?
        return Plugin_Continue;

    if (source == -1 && !(iActiveFlags & FLAGS[1]))  // Is the Charger eligible?
        return Plugin_Continue;

    if (GetClientTeam(target) == 2 && L4D2_IsBeingAttacked(target))  // Capped Survivors should not get staggered
        return Plugin_Handled;

    if (GetClientTeam(target) != 3) // We'll only need SI for the following checks
        return Plugin_Continue;

    if (source == -1 && GetInfectedClass(target) != 6)    // Allow Charger selfstaggers through
        return Plugin_Handled;

    if (source <= MaxClients && GetInfectedClass(source) == 2) // Cancel any staggers caused by a Boomer explosion
        return Plugin_Handled;
    
    if (source == -1) // Return early if we don't have a valid edict.
        return Plugin_Continue;

    char classname[64];
    GetEdictClassname(source, classname, sizeof(classname));
    if ((iActiveFlags & FLAGS[2]) && StrEqual(classname, "witch"))  // Cancel any staggers caused by a running Witch(if eligible)
        return Plugin_Handled;
    
    return Plugin_Continue;  // Is this even reachable? Probably yes, in case some plugin has used the L4D_StaggerPlayer() native
}

int GetInfectedClass(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        return GetEntProp(client, Prop_Send, "m_zombieClass");
    }
    return -1;
}
