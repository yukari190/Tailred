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
#include <left4dhooks>

public Plugin myinfo = 
{
    name = "L4D2 No SI Friendly Staggers & Tank Rock Stumble Block",
    author = "Visor, Jacob",
    description = "Removes SI staggers caused by other SI(Boomer, Charger, Witch)",
    version = "1.2",
    url = ""
};

static const char L4D2_AttackerNetProps[][] =
{
	"m_tongueOwner",	// Smoker
	"m_pounceAttacker",	// Hunter
	"m_jockeyAttacker",	// Jockey
	"m_carryAttacker", // Charger carry
	"m_pummelAttacker",	// Charger pummel
};

bool blockStumble = false;

public Action L4D2_OnStagger(int target, int source)
{
    // For some reason, Valve chose to set a null source for charger impact staggers.
    // And Left4DHooks converts this null source to -1.
    // Since there aren't really any other possible calls for this function,
    // assume (source == -1) as a charger impact stagger
    // TODO: Patch the binary to pass on the Charger's client ID instead of nothing?
    // Probably not worth it, for now, at least
    
	int team = GetClientTeam(target);
	int classA = GetInfectedClass(target);
	
    if (team == 3 && classA == 8 && blockStumble)
		return Plugin_Handled;
	
    if (!IsValidEdict(source) && source != -1)
        return Plugin_Continue;
    
	int classB = GetInfectedClass(source);
	
    if (classB == 2)  // Is the Boomer eligible?
        return Plugin_Continue;
	
    if (team == 2 && IsBeingAttacked(target))  // Capped Survivors should not get staggered
        return Plugin_Handled;
	
    if (team != 3) // We'll only need SI for the following checks
        return Plugin_Continue;
	
    if (source == -1 && classA != 6)    // Allow Charger selfstaggers through
        return Plugin_Handled;
	
    if (source <= MaxClients && classB == 2) // Cancel any staggers caused by a Boomer explosion
        return Plugin_Handled;
	
    if (source == -1) // Return early if we don't have a valid edict.
        return Plugin_Continue;
	
    return Plugin_Continue;  // Is this even reachable? Probably yes, in case some plugin has used the L4D_StaggerPlayer() native
}

public Action L4D_OnCThrowActivate()
{
    blockStumble = true;
    CreateTimer(2.0, UnblockStumble);
}

public Action UnblockStumble(Handle timer)
{
    blockStumble = false;
}

int GetInfectedClass(int client)
{
    if (client > 0 && client <= MaxClients && IsClientInGame(client))
    {
        return GetEntProp(client, Prop_Send, "m_zombieClass");
    }
    return -1;
}

int IsBeingAttacked(int survivor)
{
    for (int i = 0; i < sizeof(L4D2_AttackerNetProps); i++)
	{
		return GetEntPropEnt(survivor, Prop_Send, L4D2_AttackerNetProps[i]);
    }
	return -1;
}
