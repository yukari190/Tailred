/*
	Checkpoint Rage Control (C) 2014 Michael Busby
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

#define CALL_OPCODE 0xE8

// xor eax,eax; NOP_3;
int PATCH_REPLACEMENT[5] = {0x31, 0xC0, 0x0f,0x1f,0x00};
int ORIGINAL_BYTES[5];
Address g_pPatchTarget;
bool g_bIsPatched;

public Plugin myinfo =
{
	name = "Checkpoint Rage Control",
	author = "ProdigySim, Visor",
	description = "Enable tank to lose rage while survivors are in saferoom",
	version = "0.3",
	url = "https://github.com/Attano/L4D2-Competitive-Framework"
}

public void OnPluginStart()
{
	Handle hGamedata = LoadGameConfigFile("checkpoint-rage-control");
	if (!hGamedata)
		SetFailState("Gamedata 'checkpoint-rage-control.txt' missing or corrupt");

	g_pPatchTarget = GameConfGetAddress(hGamedata, "SaferoomCheck_Sig");
	if (!g_pPatchTarget)
		SetFailState("Couldn't find the 'SaferoomCheck_Sig' address");
	
	int iOffset = GameConfGetOffset(hGamedata, "UpdateZombieFrustration_SaferoomCheck");
	
	g_pPatchTarget = g_pPatchTarget + (view_as<Address>(iOffset));
	
	if(LoadFromAddress(g_pPatchTarget, NumberType_Int8) != CALL_OPCODE)
		SetFailState("Saferoom Check Offset or signature seems incorrect");
	
	ORIGINAL_BYTES[0] = CALL_OPCODE;
	
	for (int i = 1; i < sizeof(ORIGINAL_BYTES); i++)
	{
		ORIGINAL_BYTES[i] = LoadFromAddress(g_pPatchTarget + view_as<Address>(i), NumberType_Int8);
	}
	
	delete hGamedata;
}

public void OnPluginEnd()
{
	if(g_bIsPatched)
	{
		for (int i = 0; i < sizeof(ORIGINAL_BYTES); i++)
		{
			StoreToAddress(g_pPatchTarget + view_as<Address>(i), ORIGINAL_BYTES[i], NumberType_Int8);
		}
		g_bIsPatched = false;
	}
}

public void OnMapStart()
{
	if(!g_bIsPatched)
	{
		for (int i = 0; i < sizeof(PATCH_REPLACEMENT); i++)
		{
			StoreToAddress(g_pPatchTarget + view_as<Address>(i), PATCH_REPLACEMENT[i], NumberType_Int8);
		}
		g_bIsPatched = true;
	}
}

public void OnRoundIsLive()
{
	if (g_bIsPatched)
	{
		PrintToChatAll("[SM] 幸存者在此地图上的安全室中时, \x04Tank\x01 仍会失去控制权.");
	}
}
