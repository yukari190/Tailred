#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

#define MAX_JOCKEYSOUND         1
#define SOUND_CHECK_INTERVAL    3.0

#define SNDCHAN_VOICE           2

bool isSmoker[MAXPLAYERS + 1];
bool isBoomer[MAXPLAYERS + 1];
bool isHunter[MAXPLAYERS + 1];
bool isJockey[MAXPLAYERS + 1];
bool isCharger[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name = "Sound Manipulation",
	author = "Sir / Tabun / AtomicStryker, DieTeeTasse, ProdigySim / Jacob / Visor",
	description = "Allows control over certain sounds",
	version = "1.4",
	url = "https://github.com/SirPlease/SirCoding"
};

char sJockeySound[MAX_JOCKEYSOUND+1][] =
{
    "player/jockey/voice/idle/jockey_spotprey_01.wav",
	"player/jockey/voice/idle/jockey_lurk04.wav"
};

public void OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn_Event);
	
	AddNormalSoundHook(view_as<NormalSHook>(OnNormalSound));
	AddAmbientSoundHook(view_as<AmbientSHook>(OnAmbientSound));
}

public void OnMapStart()
{
	PrecacheSound("music/bacteria/smokerbacterias.wav");
	PrecacheSound("music/bacteria/boomerbacterias.wav");
	PrecacheSound("music/bacteria/hunterbacterias.wav");
	PrecacheSound("music/bacteria/jockeybacterias.wav");
	PrecacheSound("music/bacteria/chargerbacterias.wav");
}

public void L4D_OnEnterGhostState(int client)
{
	Clear(client);
	
	L4D2_Infected SI = L4D2_GetInfectedClass(client);
	
	if (SI == L4D2Infected_Smoker)
	{
		isSmoker[client] = true;
	}
	else if (SI == L4D2Infected_Boomer)
	{
		isBoomer[client] = true;
	}
	else if (SI == L4D2Infected_Hunter)
	{
		isHunter[client] = true;
	}
	else if (SI == L4D2Infected_Jockey)
	{
		isJockey[client] = true;
	}
	else if (SI == L4D2Infected_Charger)
	{
		isCharger[client] = true;
	}
}

public Action OnNormalSound(int clients[64], int &numClients, char sample[PLATFORM_MAX_PATH], int &entity)
{
	// Heartbeat
	if (StrEqual(sample, "player/heartbeatloop.wav", false) ||
	// World
	StrContains(sample, "World", true) != -1  ||
	// Look...
	StrContains(sample, "look", false) != -1 ||
	// Ask..
	StrContains(sample, "ask", false) != -1   ||
	// Follow Me..
	StrContains(sample, "followme", false) != -1 ||
	// Follow Me..
	StrContains(sample, "gettingrevived", false) != -1 ||
	// Item..
	StrContains(sample, "alertgiveitem", false) != -1 ||
	// I'm with you..
	StrContains(sample, "imwithyou", false) != -1 ||
	// Laughter..
	StrContains(sample, "laughter", false) != -1 ||
	// Name..
	StrContains(sample, "name", false) != -1 ||
	// Lead on..
	StrContains(sample, "leadon", false) != -1 ||
	// Move On..
	StrContains(sample, "moveon", false) != -1 ||
	// FF..
	StrContains(sample, "friendlyfire", false) != -1 ||
	// Blood Splat..
	StrContains(sample, "splat", false) != -1 ||
	StrContains(sample, "warnhunter", false) != -1 ||
	StrContains(sample, "firewerks", false) != -1) return Plugin_Stop;
	return Plugin_Continue;
}

public Action OnAmbientSound(char sample[256], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay)
{
    return ((StrContains(sample, "firewerks", false) != -1) ? Plugin_Handled : Plugin_Continue);
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (L4D2_IsValidClient(client) && L4D2_IsInfected(client) && !IsFakeClient(client))
	{
		L4D2_Infected SI = L4D2_GetInfectedClass(client);
		if (SI == L4D2Infected_Tank)
		{
			Clear(client);
			return;
		}
		
		if (isSmoker[client])
		{
			PlaySound(L4D2Infected_Smoker);
		}
		else if (isBoomer[client])
		{
			PlaySound(L4D2Infected_Boomer);
		}
		else if (isHunter[client])
		{
			PlaySound(L4D2Infected_Hunter);
		}
		else if (isJockey[client])
		{
			PlaySound(L4D2Infected_Jockey);
		}
		else if (isCharger[client])
		{
			PlaySound(L4D2Infected_Charger);
		}
	}
	Clear(client);
	
	if (L4D2_GetInfectedClass(client) == L4D2Infected_Jockey) CreateTimer(0.1, delayedJockeySound, client);
}

public Action delayedJockeySound(Handle timer, any client)
{
    int rndPick = GetRandomInt(0, MAX_JOCKEYSOUND);
    EmitSoundToAll(sJockeySound[rndPick], client, SNDCHAN_VOICE);
}

public int Clear(int client)
{
	isSmoker[client] = false;
	isBoomer[client] = false;
	isHunter[client] = false;
	isJockey[client] = false;
	isCharger[client] = false;
}

public int PlaySound(L4D2_Infected ZClass)
{
	switch (ZClass)
	{
		case L4D2Infected_Smoker: EmitSoundToAll("music/bacteria/smokerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case L4D2Infected_Boomer: EmitSoundToAll("music/bacteria/boomerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case L4D2Infected_Hunter: EmitSoundToAll("music/bacteria/hunterbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case L4D2Infected_Jockey: EmitSoundToAll("music/bacteria/jockeybacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case L4D2Infected_Charger: EmitSoundToAll("music/bacteria/chargerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
}
