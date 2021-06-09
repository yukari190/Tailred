/*
	The base functionality of this code was written by ShadowSyn, using ProdigySim's gamedata
	(https://forums.alliedmods.net/showthread.php?t=320849)
	- The program flow has been restructured to support a spawn function that can be passed position and angular coordinates
	- The spawn commands have been rewritten for debugging purposes
	- version cvar and game engine checking have been removed
	- set g_isSequel = true, as this is written purely for L4D2
*/
#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>

// Infected models
#define MODEL_SMOKER "models/infected/smoker.mdl"
#define MODEL_BOOMER "models/infected/boomer.mdl"
#define MODEL_HUNTER "models/infected/hunter.mdl"
#define MODEL_SPITTER "models/infected/spitter.mdl"
#define MODEL_JOCKEY "models/infected/jockey.mdl"
#define MODEL_CHARGER "models/infected/charger.mdl"
#define MODEL_TANK "models/infected/hulk.mdl"
#define MODEL_WITCH "models/infected/witch.mdl"
#define MODEL_WITCHBRIDE "models/infected/witch_bride.mdl"

#define GAMEDATA "spawn_infected_nolimit"

#define DIRECTOR_CLASS "info_director"
#define BRIDE_WITCH_TARGETNAME "plugin_dzs_bride"

static Handle hCreateSmoker = null;
#define NAME_CreateSmoker "NextBotCreatePlayerBot<Smoker>"
static Handle hCreateBoomer = null;
#define NAME_CreateBoomer "NextBotCreatePlayerBot<Boomer>"
static Handle hCreateHunter = null;
#define NAME_CreateHunter "NextBotCreatePlayerBot<Hunter>"
static Handle hCreateSpitter = null;
#define NAME_CreateSpitter "NextBotCreatePlayerBot<Spitter>"
static Handle hCreateJockey = null;
#define NAME_CreateJockey "NextBotCreatePlayerBot<Jockey>"
static Handle hCreateCharger = null;
#define NAME_CreateCharger "NextBotCreatePlayerBot<Charger>"
static Handle hCreateTank = null;
#define NAME_CreateTank "NextBotCreatePlayerBot<Tank>"

static Handle hInfectedAttackSurvivorTeam = null;
#define NAME_InfectedAttackSurvivorTeam "Infected::AttackSurvivorTeam"

public Plugin myinfo = 
{
	name = "Direct Infected Spawn",
	author = "Tordecybombo, breezy",
	description = "Spawn special infected without the director limits!",
	version = "1.2.1",
	url = ""
};

/***********************************************************************************************************************************************************************************
     																			INITIALISATION                        
***********************************************************************************************************************************************************************************/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("TriggerSpawn", _native_TriggerSpawn);
	
	RegPluginLibrary("DirectInfectedSpawn");
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvent("witch_harasser_set", witch_harasser_set, EventHookMode_Post);
	HookEvent("witch_killed", witch_killed, EventHookMode_Post);
	
	GetGamedata();
}

/*  ========  Natives  ========*/
public int _native_TriggerSpawn(Handle plugin, int numParams)
{
	L4D2_Infected desiredClass = GetNativeCell(1);
	float pos[3];
	float ang[3];
	GetNativeArray(2, pos, 3);
	GetNativeArray(3, ang, 3);
	TriggerSpawn(desiredClass, pos, ang);
}

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}

public void OnMapStart()
{
	CheckandPrecacheModel(MODEL_SMOKER);
	CheckandPrecacheModel(MODEL_BOOMER);
	CheckandPrecacheModel(MODEL_HUNTER);
	CheckandPrecacheModel(MODEL_SPITTER);
	CheckandPrecacheModel(MODEL_JOCKEY);
	CheckandPrecacheModel(MODEL_CHARGER);
	CheckandPrecacheModel(MODEL_WITCHBRIDE);
	CheckandPrecacheModel(MODEL_TANK);
	CheckandPrecacheModel(MODEL_WITCH);
}

/***********************************************************************************************************************************************************************************
MECHANISM: TriggerSpawn() -> ProcessSpawn() -> CreateInfected()
TriggerSpawn()		- Uses SI class numbers for brevity, position and eye angles
ProcessSpawn()		- Translates class numbers to names
CreateInfected()	- Uses SI names(to differentiate witch and witch bride)
					- hooks directly into the inbuilt spawn commands
***********************************************************************************************************************************************************************************/

// Does not perform spawning; handles timing of spawn event 
void TriggerSpawn( L4D2_Infected desiredClass, float pos[3], float ang[3])
{
	int kick = KickDeadInfectedBots();
	if (kick <= 0) // spawn immediately without delay
    {
   		ProcessSpawn(view_as<L4D2_Infected>(desiredClass), pos, ang);
	} 
	else { // spawn on short delay
		DataPack data = CreateDataPack();
		data.WriteCell(view_as<int>(desiredClass));
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		data.WriteFloat(ang[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		CreateTimer(0.01, Timer_CreateInfected, data);
	}	
}

Action Timer_CreateInfected(Handle timer, DataPack data)
{
	int desiredClass;
	float pos[3];
	float ang[3];
	
	// Read data pack
	data.Reset();
	desiredClass = data.ReadCell(); 
	for (int i = 0; i < 3; ++i) // pos[3]
	{
		pos[i] = data.ReadCell();
	}
	for (int i = 0; i < 3; ++i) // ang[3]
	{
		ang[i] = data.ReadCell();
	}
	// Close data pack if necessary
	if (data != null)
	{ 
		CloseHandle(data);
	}
	
	ProcessSpawn(view_as<L4D2_Infected>(desiredClass), pos, ang);
}

void ProcessSpawn (L4D2_Infected desiredClass, float pos[3], float ang[3])
{
	int spawnedClient;
	switch (desiredClass)
	{
		case (L4D2Infected_Smoker):
		{
			spawnedClient = CreateInfected("smoker", pos, ang);
		}
		case (L4D2Infected_Boomer):
		{
			spawnedClient = CreateInfected("boomer", pos, ang);
		}
		case (L4D2Infected_Hunter):
		{
			spawnedClient = CreateInfected("hunter", pos, ang);
		}
		case (L4D2Infected_Spitter):
		{
			spawnedClient = CreateInfected("spitter", pos, ang);
		}
		case (L4D2Infected_Jockey):
		{
			spawnedClient = CreateInfected("jockey", pos, ang);
		}
		case (L4D2Infected_Charger):
		{
			spawnedClient = CreateInfected("charger", pos, ang);
		}
		case (L4D2Infected_Witch):
		{
			spawnedClient = CreateInfected("witch", pos, ang);
		}
		case (L4D2Infected_Tank):
		{
			spawnedClient = CreateInfected("tank", pos, ang);
		}
		default:
		{
			LogError("Spawn function was passed invalid class number %d", view_as<int>(desiredClass));
		}		
	}
	if (!IsValidEntity(spawnedClient))
	{
		LogError("[ SS2_DirectInfectedSpawn ] - Failed to spawn SI class %d at position [%f, %f, %f]", view_as<int>(desiredClass), pos[0], pos[1], pos[2]);
	}	
}

int CreateInfected(const char[] zomb, float[3] pos, float[3] ang)
{
	int bot = -1;	
	if (StrEqual(zomb, "witch", false) || StrEqual(zomb, "witch_bride", false))
	{
		int witch = CreateEntityByName("witch");
		TeleportEntity(witch, pos, ang, NULL_VECTOR);
		DispatchSpawn(witch);
		ActivateEntity(witch);
		if (StrEqual(zomb, "witch_bride", false))
		{
			SetEntityModel(witch, MODEL_WITCHBRIDE);
			//AssignPanicToWitch(witch);
			DispatchKeyValue(witch, "targetname", BRIDE_WITCH_TARGETNAME);
		}
		return witch;
	}
	else if (StrEqual(zomb, "smoker", false))
	{
		bot = SDKCall(hCreateSmoker, "Smoker");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_SMOKER);
	}
	else if (StrEqual(zomb, "boomer", false))
	{
		bot = SDKCall(hCreateBoomer, "Boomer");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_BOOMER);
	}
	else if (StrEqual(zomb, "hunter", false))
	{
		bot = SDKCall(hCreateHunter, "Hunter");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_HUNTER);
	}
	else if (StrEqual(zomb, "spitter", false))
	{
		bot = SDKCall(hCreateSpitter, "Spitter");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_SPITTER);
	}
	else if (StrEqual(zomb, "jockey", false))
	{
		bot = SDKCall(hCreateJockey, "Jockey");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_JOCKEY);
	}
	else if (StrEqual(zomb, "charger", false))
	{
		bot = SDKCall(hCreateCharger, "Charger");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_CHARGER);
	}
	else if (StrEqual(zomb, "tank", false))
	{
		bot = SDKCall(hCreateTank, "Tank");
		if (L4D2_IsValidClient(bot)) SetEntityModel(bot, MODEL_TANK);
	}
	else
	{
		int infected = CreateEntityByName("infected");
		TeleportEntity(infected, pos, ang, NULL_VECTOR);
		DispatchSpawn(infected);
		ActivateEntity(infected);
		if (StrContains(zomb, "chase", false) > -1)
		{ CreateTimer(0.4, Timer_Chase, infected); }
		return infected;
	}
	
	if (L4D2_IsValidClient(bot))
	{
		ChangeClientTeam(bot, 3);
		//SDKCall(hRoundRespawn, bot);
		SetEntProp(bot, Prop_Send, "m_usSolidFlags", 16);
		SetEntProp(bot, Prop_Send, "movetype", 2);
		SetEntProp(bot, Prop_Send, "deadflag", 0);
		SetEntProp(bot, Prop_Send, "m_lifeState", 0);
		//SetEntProp(bot, Prop_Send, "m_fFlags", 129);
		SetEntProp(bot, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(bot, Prop_Send, "m_iPlayerState", 0);
		SetEntProp(bot, Prop_Send, "m_zombieState", 0);
		DispatchSpawn(bot);
		ActivateEntity(bot);
		
		DataPack data = CreateDataPack();
		data.WriteFloat(pos[0]);
		data.WriteFloat(pos[1]);
		data.WriteFloat(pos[2]);
		data.WriteFloat(ang[1]);
		data.WriteCell(bot);
		RequestFrame(RequestFrame_SetPos, data); 
	}
	
	return bot;
}

Action Timer_Chase(Handle timer, int infected)
{
	if (!IsValidEntity(infected)) return;
	char class[64];
	GetEntityClassname(infected, class, sizeof(class));
	if (!StrEqual(class, "infected", false)) return;
	SDKCall(hInfectedAttackSurvivorTeam, infected);
}

void RequestFrame_SetPos(DataPack data)
{
	data.Reset();
	float pos0 = data.ReadFloat();
	float pos1 = data.ReadFloat();
	float pos2 = data.ReadFloat();
	float ang1 = data.ReadFloat();
	int bot = data.ReadCell();
	if (data != null)
	{ CloseHandle(data); }
	
	float pos[3];pos[0]=pos0;pos[1]=pos1;pos[2]=pos2;
	float ang[3];ang[0]=0.0;ang[1]=ang1;ang[2]=0.0;
	
	TeleportEntity(bot, pos, ang, NULL_VECTOR);
}

int KickDeadInfectedBots(int client=-1)
{
	int kicked_Bots = 0;
	for (int loopclient = 1; loopclient <= MaxClients; loopclient++)
	{
		if (!IsClientInGame(loopclient)) continue;
		if (!L4D2_IsInfected(loopclient) || !IsFakeClient(loopclient) || IsPlayerAlive(loopclient)) continue;
		KickClient(loopclient, "");
		kicked_Bots += 1;
	}
	if (kicked_Bots > 0 && L4D2_IsValidClient(client))
	{ 
		PrintToChat(client, "Kicked %i bots.", kicked_Bots);
	}
	return kicked_Bots;
}

void GetGamedata()
{
	Handle hConf = null;
	hConf = LoadGameConfigFile(GAMEDATA); // For some reason this doesn't return null even for invalid files, so check they exist first.
	if (hConf == null)
	{ SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }
	
	Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
	if (replaceWithBot == Address_Null || LoadFromAddress(replaceWithBot, NumberType_Int8) != 0x68)
	{ SetFailState("Cannot initialize NextBotCreatePlayerBot.jumptable SDKCall, address lookup failed."); return; }
	
	StringMap hInfectedFuncs = new StringMap();
	// We have the address of the jump table, starting at the first PUSH instruction of the
	// PUSH mem32 (5 bytes)
	// CALL rel32 (5 bytes)
	// JUMP rel8 (2 bytes)
	// repeated pattern.
	
	// Each push is pushing the address of a string onto the stack. Let's grab these strings to identify each case.
	// "Hunter" / "Smoker" / etc.
	for(int i = 0; i < 7; i++) {
		// 12 bytes in PUSH32, CALL32, JMP8.
		Address caseBase = replaceWithBot + view_as<Address>(i * 12);
		Address siStringAddr = view_as<Address>(LoadFromAddress(caseBase + view_as<Address>(1), NumberType_Int32));
		static char siName[32];
		LoadStringFromAdddress(siStringAddr, siName, sizeof(siName));

		Address funcRefAddr = caseBase + view_as<Address>(6); // 2nd byte of call, 5+1 byte offset.
		int funcRelOffset = LoadFromAddress(funcRefAddr, NumberType_Int32);
		Address callOffsetBase = caseBase + view_as<Address>(10); // first byte of next instruction after the CALL instruction
		Address nextBotCreatePlayerBotTAddr = callOffsetBase + view_as<Address>(funcRelOffset);
		PrintToServer("Found NextBotCreatePlayerBot<%s>() @ %08x", siName, nextBotCreatePlayerBotTAddr);
		hInfectedFuncs.SetValue(siName, nextBotCreatePlayerBotTAddr);
	}

	hCreateSmoker = PrepCreateBotCallFromAddress(hInfectedFuncs, "Smoker");
	if (hCreateSmoker == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSmoker); return; }

	hCreateBoomer = PrepCreateBotCallFromAddress(hInfectedFuncs, "Boomer");
	if (hCreateBoomer == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateBoomer); return; }

	hCreateHunter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Hunter");
	if (hCreateHunter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateHunter); return; }

	hCreateTank = PrepCreateBotCallFromAddress(hInfectedFuncs, "Tank");
	if (hCreateTank == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateTank); return; }
	
	hCreateSpitter = PrepCreateBotCallFromAddress(hInfectedFuncs, "Spitter");
	if (hCreateSpitter == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateSpitter); return; }
	
	hCreateJockey = PrepCreateBotCallFromAddress(hInfectedFuncs, "Jockey");
	if (hCreateJockey == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateJockey); return; }

	hCreateCharger = PrepCreateBotCallFromAddress(hInfectedFuncs, "Charger");
	if (hCreateCharger == null)
	{ SetFailState("Cannot initialize %s SDKCall, address lookup failed.", NAME_CreateCharger); return; }
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_InfectedAttackSurvivorTeam); return; }
	hInfectedAttackSurvivorTeam = EndPrepSDKCall();
	if (hInfectedAttackSurvivorTeam == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_InfectedAttackSurvivorTeam); return; }
	
	delete hConf;
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength) {
	int i = 0;
	while(i < maxlength) {
		char val = LoadFromAddress(addr + view_as<Address>(i), NumberType_Int8);
		if(val == 0) {
			buffer[i] = 0;
			break;
		}
		buffer[i] = val;
		i++;
	}
	buffer[maxlength - 1] = 0;
}

Handle PrepCreateBotCallFromAddress(StringMap hSiFuncTrie, const char[] siName) {
	Address addr;
	StartPrepSDKCall(SDKCall_Static);
	if (!hSiFuncTrie.GetValue(siName, addr) || !PrepSDKCall_SetAddress(addr))
	{
		SetFailState("Unable to find NextBotCreatePlayer<%s> address in memory.", siName);
		return null;
	}
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	return EndPrepSDKCall();	
}

/***********************************************************************************************************************************************************************************
     																			UTIL                     
***********************************************************************************************************************************************************************************/

void witch_harasser_set(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	PrintToServer("Bride startled");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

void witch_killed(Event event, const char[] name, bool dontBroadcast)
{
	int witch = event.GetInt("witchid");
	if (!IsValidEntity(witch) || witch <= 0) return;
	
	char witchName[64];
	GetEntPropString(witch, Prop_Data, "m_iName", witchName, sizeof(witchName));
	if (!StrEqual(witchName, BRIDE_WITCH_TARGETNAME, false)) return;
	
	int dir_ent = CheckForDirectorEnt();
	if (!IsValidEntity(dir_ent) || dir_ent <= 0) return;
	
	//if (!event.GetBool("oneshot")) return;
	
	PrintToServer("Bride killed");
	
	DispatchKeyValue(witch, "targetname", "");
	AcceptEntityInput(dir_ent, "ForcePanicEvent");
}

int CheckForDirectorEnt()
{
	int result = FindEntityByClassname(-1, DIRECTOR_CLASS);
	if (!IsValidEntity(result) || result <= 0)
	{
		result = CreateEntityByName(DIRECTOR_CLASS);
		DispatchSpawn(result);
		ActivateEntity(result);
	}
	return result;
}
