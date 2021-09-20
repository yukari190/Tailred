#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <left4dhooks>

#define MAX_SOUNDFILE_LENGTH    64
#define MAX_JOCKEYSOUND         17

#define JOCKEY_VOICE_TIMEOUT    2.0
#define SOUND_CHECK_INTERVAL    3.0

#define TEAM_INFECTED 		3
#define ZC_JOCKEY               5
#define SNDCHAN_VOICE           2

static const char sJockeySound[MAX_JOCKEYSOUND+1][] =
{
    "player/jockey/voice/idle/jockey_recognize02.wav",
    "player/jockey/voice/idle/jockey_recognize06.wav",
    "player/jockey/voice/idle/jockey_recognize07.wav",
    "player/jockey/voice/idle/jockey_recognize08.wav",
    "player/jockey/voice/idle/jockey_recognize09.wav",
    "player/jockey/voice/idle/jockey_recognize10.wav",
    "player/jockey/voice/idle/jockey_recognize11.wav",
    "player/jockey/voice/idle/jockey_recognize12.wav",
    "player/jockey/voice/idle/jockey_recognize13.wav",
    "player/jockey/voice/idle/jockey_recognize15.wav",
    "player/jockey/voice/idle/jockey_recognize16.wav",
    "player/jockey/voice/idle/jockey_recognize17.wav",
    "player/jockey/voice/idle/jockey_recognize18.wav",
    "player/jockey/voice/idle/jockey_recognize19.wav",
    "player/jockey/voice/idle/jockey_recognize20.wav",
    "player/jockey/voice/idle/jockey_recognize24.wav",
    "player/jockey/voice/idle/jockey_lurk04.wav",
    "player/jockey/voice/idle/jockey_lurk05.wav"
};

static const char sJockeyMusic[] = "music/bacteria/jockeybacterias.wav";

static const int sm_unsilentjockey_always = 1;  //Whether to play jockey spawn sound even if it is not detected as silent.
static const float sm_unsilentjockey_time = 0.1;  //How soon to play sound after spawning (in seconds).

Handle hJockeyLaughingTimer[MAXPLAYERS+1];

float fJockeyLaughingStop[MAXPLAYERS+1];

public Plugin myinfo = 
{
	name = "Unsilent Jockey & Musical",
	author = "Tabun, Jacob",
	description = "Prevents the Jockey from having silent spawns.",
	version = "1.3b",
	url = "Earth"
};

public void OnPluginStart()
{
    AddNormalSoundHook(view_as<NormalSHook>(HookSound_Callback));
    HookEvent("player_spawn", PlayerSpawn_Event);
}

public void OnMapStart()
{
	PrecacheSound(sJockeyMusic);
    for (int i = 0; i <= MAX_JOCKEYSOUND; i++)
    {
        PrefetchSound(sJockeySound[i]);
        PrecacheSound(sJockeySound[i], true);
    }
}

public Action PlayerSpawn_Event(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsClientAndInGame(client)) return;
    if (GetClientTeam(client) != TEAM_INFECTED) return;
    if (GetEntProp(client, Prop_Send, "m_zombieClass") != ZC_JOCKEY) return;
	EmitSoundToAll(sJockeyMusic, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);
    CreateTimer(sm_unsilentjockey_time, delayedJockeySound, client);
}

public Action delayedJockeySound(Handle timer, any client)
{
    if (hJockeyLaughingTimer[client] && !sm_unsilentjockey_always)
	{
        PrintToServer("[uj] Jockey [%d] was not silent.", client);
        return;
    }
    PrintToServer("[uj] Jockey [%d] unsilenced.%s", client, (sm_unsilentjockey_always)?" (forced)":"");
    int rndPick = GetRandomInt(0, MAX_JOCKEYSOUND);
    EmitSoundToAll(sJockeySound[rndPick], client, SNDCHAN_VOICE);
}

public Action HookSound_Callback(int Clients[64], int &NumClients, char StrSample[PLATFORM_MAX_PATH], int &Entity)
{
    if (StrContains(StrSample, "/jockey/voice/", false) == -1)  return Plugin_Continue;
    
    if (!IsClientAndInGame(Entity)) { return Plugin_Continue; }
    fJockeyLaughingStop[Entity] = GetTickedTime() + JOCKEY_VOICE_TIMEOUT;
    if (hJockeyLaughingTimer[Entity] == INVALID_HANDLE)
	{
        hJockeyLaughingTimer[Entity] = CreateTimer(SOUND_CHECK_INTERVAL, Timer_IsJockeyLaughing, Entity, TIMER_REPEAT);
    }
    return Plugin_Continue;
}

public Action Timer_IsJockeyLaughing(Handle hTimer, any Client)
{
    if (fJockeyLaughingStop[Client] >= GetTickedTime())
	{
        if (IsClientAndInGame(Client))
		{
            if (IsPlayerAlive(Client))
			{
                return Plugin_Continue;
            }
        }
    }
    hJockeyLaughingTimer[Client] = INVALID_HANDLE;
    return Plugin_Stop;
}

bool IsClientAndInGame(int index)
{
    return (index > 0 && index <= MaxClients && IsClientInGame(index));
}
