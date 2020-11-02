#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

float block_square[4];
Handle hSpitBlockSquares;

public Plugin myinfo =
{
	name = "L4D2 Spit Blocker",
	author = "ProdigySim + Estoopi + Jacob, Visor (:D)",
	description = "Blocks spit damage on various maps",
	version = "2.0",
	url = "https://github.com/Attano/Equilibrium"
};

public void OnPluginStart()
{
	RegServerCmd("spit_block_square", AddSpitBlockSquare);
	hSpitBlockSquares = CreateTrie();
}

public Action AddSpitBlockSquare(int args)
{
	char mapname[64];
	GetCmdArg(1, mapname, sizeof(mapname));

	float square[4];
	char buf[32];
	for (int i = 0; i < 4; i++)
	{
		GetCmdArg(2 + i, buf, sizeof(buf));
		square[i] = StringToFloat(buf);
	}
	SetTrieArray(hSpitBlockSquares, mapname, square, 4);
	OnMapStart();
}

public void OnMapStart()
{
	char mapname[64];
	GetCurrentMap(mapname, sizeof(mapname));
	if (!GetTrieArray(hSpitBlockSquares, mapname, block_square, 4))
	{
		block_square[0] = 0.0;
		block_square[1] = 0.0;
		block_square[2] = 0.0;
		block_square[3] = 0.0;
	}
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client)) return;
	if (nowteam == 2 && oldteam != 2) SDKHook(client, SDKHook_OnTakeDamage, stop_spit_dmg);
	else if (nowteam != 2 && oldteam == 2) SDKUnhook(client, SDKHook_OnTakeDamage, stop_spit_dmg);
}

public Action stop_spit_dmg(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(victim <= 0 || victim > MaxClients) return Plugin_Continue;
	if(!IsValidEdict(inflictor)) return Plugin_Continue;
	char sInflictor[64];
	GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor));
	if(StrEqual(sInflictor, "insect_swarm", false))
	{
		float origin[3];
		GetClientAbsOrigin(victim, origin);
		if(isPointIn2DBox(origin[0], origin[1], block_square[0], block_square[1], block_square[2], block_square[3]))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;	
}

bool isPointIn2DBox(float x0, float y0, float x1, float y1, float x2, float y2)
{
	if(x1 > x2)
	{
		if(y1 > y2) return x0 <= x1 && x0 >= x2 && y0 <= y1 && y0 >= y2;
		else return x0 <= x1 && x0 >= x2 && y0 >= y1 && y0 <= y2;
	}
	else
	{
		if(y1 > y2) return x0 >= x1 && x0 <= x2 && y0 <= y1 && y0 >= y2;
		else return x0 >= x1 && x0 <= x2 && y0 >= y1 && y0 <= y2;
	}
}
