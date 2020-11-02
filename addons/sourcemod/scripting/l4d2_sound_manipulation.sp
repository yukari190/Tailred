#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

#define MAX_JOCKEYSOUND         1
#define SOUND_CHECK_INTERVAL    3.0

#define ZC_SMOKER               1
#define ZC_BOOMER               2
#define ZC_HUNTER               3
#define ZC_SPITTER              4
#define ZC_JOCKEY               5
#define ZC_CHARGER              6
#define ZC_WITCH                7
#define ZC_TANK                 8

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
	
	int SI = GetInfectedClass(client);
	
	if (SI == ZC_SMOKER)
	{
		isSmoker[client] = true;
	}
	else if (SI == ZC_BOOMER)
	{
		isBoomer[client] = true;
	}
	else if (SI == ZC_HUNTER)
	{
		isHunter[client] = true;
	}
	else if (SI == ZC_JOCKEY)
	{
		isJockey[client] = true;
	}
	else if (SI == ZC_CHARGER)
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
	if (IsValidInfected(client) && !IsFakeClient(client))
	{
		int SI = GetInfectedClass(client);
		if (SI == ZC_TANK)
		{
			Clear(client);
			return;
		}
		
		if (isSmoker[client])
		{
			PlaySound(ZC_SMOKER);
		}
		else if (isBoomer[client])
		{
			PlaySound(ZC_BOOMER);
		}
		else if (isHunter[client])
		{
			PlaySound(ZC_HUNTER);
		}
		else if (isJockey[client])
		{
			PlaySound(ZC_JOCKEY);
		}
		else if (isCharger[client])
		{
			PlaySound(ZC_CHARGER);
		}
	}
	Clear(client);
	
	if (GetInfectedClass(client) == ZC_JOCKEY) CreateTimer(0.1, delayedJockeySound, client);
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

public int PlaySound(int ZClass)
{
	switch(ZClass)
	{
		case ZC_SMOKER: EmitSoundToAll("music/bacteria/smokerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case ZC_BOOMER: EmitSoundToAll("music/bacteria/boomerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case ZC_HUNTER: EmitSoundToAll("music/bacteria/hunterbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case ZC_JOCKEY: EmitSoundToAll("music/bacteria/jockeybacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
		case ZC_CHARGER: EmitSoundToAll("music/bacteria/chargerbacterias.wav", _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
	}
}
