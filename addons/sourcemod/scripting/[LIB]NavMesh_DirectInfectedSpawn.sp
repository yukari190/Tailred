/*
	The base functionality of this code was written by ShadowSyn, using ProdigySim's gamedata
	(https://forums.alliedmods.net/showthread.php?t=320849)
	- The program flow has been restructured to support a spawn function that can be passed position and angular coordinates
	- The spawn commands have been rewritten for debugging purposes
	- version cvar and game engine checking have been removed
*/


#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[LIB]left4dhooks>
//#include <[LIB]navmesh>
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

#define TEAM_SURVIVORS 2
#define TEAM_INFECTED 3

#define GAMEDATA "spawn_infected_nolimit"

#define BOUNDINGBOX_INFLATION_OFFSET 0.5

#define DIRECTOR_CLASS "info_director"
#define DIRECTOR_ENT "plugin_director_ent_do_not_use"
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
	name = "NavMesh Direct Infected Spawn",
	author = "Shadowysn, ProdigySim (Major Windows Fix), Tordecybombo, breezy",
	description = "Spawn special infected without the director limits!",
	version = "1.2.1",
	url = ""
};

/***********************************************************************************************************************************************************************************
     																			INITIALISATION                        
***********************************************************************************************************************************************************************************/


#define CNAVAREA_ARRAYSIZE 512 // guesstimating this is overkill, unless a much wider accepted spawn range is used
#define CNAVAREA_MEMORYSIZE 1024 // could be much smaller; staying on the safe side out of ignorance
#define MAX_SPAWN_NAVMESH_DIST 700.0 // thinking this should be low to minimise spawning on the other side chain link walls
#define CNAVAREA_MAXID 9999999

Handle hCVarRearSpawnMaxTrailingDistance;

/*
/	CNavArea IDs appear to move into the six digits, whereas the CNavArea area indices move into the four digits
*/

int g_iPathLaserModelIndex = -1;

float g_flTrackNavAreaThinkRate = 0.1;
float g_flTrackNavAreaNextThink = 0.0;

static const int DefaultAreaColor[] = { 255, 0, 0, 255 };
static const int FocusedAreaColor[] = { 255, 255, 0, 255 };


bool g_bPlayerTrackNavArea[MAXPLAYERS + 1] = { false, ... };
Handle g_hPlayerTrackNavAreaInfoHudSync = null;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead and Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	
	CreateNative("NMDIS_TriggerSpawn", _native_TriggerSpawn);
	CreateNative("NMDIS_NavMeshSpawn", _native_NavMeshSpawn);
	
	RegPluginLibrary("NavMesh_DirectInfectedSpawn");
	return APLRes_Success;
}

public void OnPluginStart()
{
	hCVarRearSpawnMaxTrailingDistance = CreateConVar("ss2_rearspawn_max_trailing_distance", "150", "Limit set on ", _, true, 0.0);
	g_hPlayerTrackNavAreaInfoHudSync = CreateHudSynchronizer();	
	
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

public int _native_NavMeshSpawn(Handle plugin, int numParams)
{
	int SpawnQueue[MAXPLAYERS];
	GetNativeArray(1, SpawnQueue, MAXPLAYERS);
	NavMeshSpawn(SpawnQueue);
}

public void OnMapStart()
{
	g_iPathLaserModelIndex = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_flTrackNavAreaNextThink = 0.0;	
	
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
void TriggerSpawn(L4D2_Infected desiredClass, float pos[3], float ang[3])
{
	int kick = KickDeadInfectedBots();
	if (kick <= 0) // spawn immediately without delay
    {
   		ProcessSpawn(desiredClass, pos, ang);
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

void ProcessSpawn(L4D2_Infected desiredClass, float pos[3], float ang[3])
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
		if (!L4D2_IsValidClient(loopclient)) continue;
		if (!L4D2_IsInfected(loopclient) || !IsFakeClient(loopclient) || IsPlayerAlive(loopclient)) continue;
		KickClient(loopclient);
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
	Handle hConf = LoadGameConfigFile(GAMEDATA); // For some reason this doesn't return null even for invalid files, so check they exist first.
	
	if (hConf == null)
	{ SetFailState("Unable to find %s.txt gamedata.", GAMEDATA); return; }
	
	Address replaceWithBot = GameConfGetAddress(hConf, "NextBotCreatePlayerBot.jumptable");
	
	if (replaceWithBot != Address_Null && LoadFromAddress(replaceWithBot, NumberType_Int8) == 0x68)
	{
		// We're on L4D2 and linux
		
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
	}
	else
	{
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSpitter))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSpitter); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSpitter = EndPrepSDKCall();
		if (hCreateSpitter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSpitter); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateJockey))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateJockey); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateJockey = EndPrepSDKCall();
		if (hCreateJockey == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateJockey); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateCharger))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateCharger); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateCharger = EndPrepSDKCall();
		if (hCreateCharger == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateCharger); return; }
		
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateSmoker))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateSmoker); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateSmoker = EndPrepSDKCall();
		if (hCreateSmoker == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateSmoker); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateBoomer))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateBoomer); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateBoomer = EndPrepSDKCall();
		if (hCreateBoomer == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateBoomer); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateHunter))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateHunter); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateHunter = EndPrepSDKCall();
		if (hCreateHunter == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateHunter); return; }
		
		StartPrepSDKCall(SDKCall_Static);
		if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_CreateTank))
		{ SetFailState("Unable to find %s signature in gamedata file.", NAME_CreateTank); return; }
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
		PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
		hCreateTank = EndPrepSDKCall();
		if (hCreateTank == null)
		{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_CreateTank); return; }
	}
	
	StartPrepSDKCall(SDKCall_Entity);
	if (!PrepSDKCall_SetFromConf(hConf, SDKConf_Signature, NAME_InfectedAttackSurvivorTeam))
	{ SetFailState("Unable to find %s signature in gamedata file.", NAME_InfectedAttackSurvivorTeam); return; }
	hInfectedAttackSurvivorTeam = EndPrepSDKCall();
	if (hInfectedAttackSurvivorTeam == null)
	{ SetFailState("Cannot initialize %s SDKCall, signature is broken.", NAME_InfectedAttackSurvivorTeam); return; }
	
	delete hConf;
}

void LoadStringFromAdddress(Address addr, char[] buffer, int maxlength)
{
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

Handle PrepCreateBotCallFromAddress(StringMap hSiFuncTrie, const char[] siName)
{
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

void CheckandPrecacheModel(const char[] model)
{
	if (!IsModelPrecached(model))
	{
		PrecacheModel(model, true);
	}
}




/***********************************************************************************************************************************************************************************

                                                 								AUTOMATIC SPAWNING
                                                                    
***********************************************************************************************************************************************************************************/
 /* 
	 * TODO: 
	 * - spawns are appearing in clustered locationsl, ook into reducing spawn condition check strictness
	 */
stock void NavMeshSpawn ( const int SpawnQueue[MAXPLAYERS] )
{
	int rearSurvivorFlow = GetRearSurvivorFlow(); // The rear survivor's flow distance is required to prevent spawns later spawning too far behind
	ArrayList ProximateSpawns;
	ProximateSpawns = new ArrayList();
	
	/*
	 * Collate all spawn areas near survivors
	 */
	int countFoundSpawnAreas = 0;
	for ( int thisClient = 1; thisClient <= MAXPLAYERS; ++thisClient )
	{
		if ( IsClientInGame(thisClient) && L4D2_IsSurvivor(thisClient) && IsPlayerAlive(thisClient) )
		{
			float posThisSurvivor[3]; // Need this survivor's coordinates to start search
			char nameThisSurvivor[32]; 
			GetClientName(thisClient, nameThisSurvivor, sizeof(nameThisSurvivor)); 
			if ( GetClientAbsOrigin(thisClient, posThisSurvivor) )
			{
				CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); // Identify closest navmesh tile from their coordinates
				if ( areaThisSurvivor != INVALID_NAV_AREA )
				{
					ArrayStack hereProximates = new ArrayStack(); // Get nearby navmesh tiles
					NavMesh_CollectSurroundingAreas(hereProximates, areaThisSurvivor); 
					while ( !hereProximates.Empty )
					{
						CNavArea area = INVALID_NAV_AREA; // for each discovered tile, check we have not seen it before 
						PopStackCell(hereProximates, area); 
						if ( area != INVALID_NAV_AREA && ProximateSpawns.FindValue(area) == -1 )
						{
							float posArea[3];
							int indexArea = view_as<int>(NavMesh_FindAreaByID(view_as<int>(area.ID)));
							if ( NavMeshArea_GetCenter(indexArea, posArea) ) // returns true if successful
							{
								int flowThisArea = GetFlow(posArea);
								if ( flowThisArea >= 0 ) // TODO: checking for flow distance invalidates potential spawn areas with no flow distance attached, not sure of ramifications
								{
									if ( (rearSurvivorFlow - flowThisArea) < GetConVarFloat(hCVarRearSpawnMaxTrailingDistance) )
									{
										++countFoundSpawnAreas;
										if ( CheckSpawnConditions(area) ) // check each tile meets our spawn conditions
										{
											ProximateSpawns.Push(indexArea); // save this tile
										} 
									}
								}
							}
							else
							{
								PrintToServer("NavMeshSpawn(): Failed to find center position for spawn area of ID: %d; unable to calculate flow distance from rear survivor", indexArea);
							}
							
						} 
					}
					delete hereProximates;
				}
				else 
				{
					PrintToServer("NavMeshSpawn(): No CNavArea found near %s required to search for proximate spawn areas", nameThisSurvivor);
				}
			} 
			else 
			{
				PrintToServer("NavMeshSpawn(): Unable to obtain coordinates for survivor %s", nameThisSurvivor);
			}
		}
	}
	PrintToServer("NavMeshSpawn(): Found %d spawns near survivors, of which %d met spawn conditions", countFoundSpawnAreas, ProximateSpawns.Length);
	
	// Spawn all SI in queue
	if ( ProximateSpawns.Length > 0 ) {	
		for( int i = 0; i < MAXPLAYERS; i++ ) 
		{
			if( SpawnQueue[i] < 0 ) // end of spawn queue (does not always fill the whole array)
			{ 
				break;
			}
			else
			{
				int spawnIndex = GetRandomInt(0, ProximateSpawns.Length - 1);	
				int indexRandomSpawn = ProximateSpawns.Get(spawnIndex);
				float posRandomSpawn[3]; 
				if ( NavMeshArea_GetCenter(indexRandomSpawn, posRandomSpawn) ) // returns true if successful
				{
					TriggerSpawn( view_as<L4D2_Infected>(SpawnQueue[i] + 1), posRandomSpawn, NULL_VECTOR);
				}
				else
				{
					PrintToServer("NavMeshSpawn(): Failed to spawn at NavMesh index %d; cannot determine mesh center coordinates", indexRandomSpawn);
				}	
			}
		}
	}
	else 
	{
		LogError("NavMeshSpawn(): Failed to find any proximate spawns");
	} 
	delete ProximateSpawns;
}

bool CheckSpawnConditions(CNavArea spawn)
{
	bool shouldSpawn = false;
	
	if ( !IsSpawnStuck(spawn) )
	{
		int shortestPath = -1; // Find shortest path cost to any member of the survivor team
		for ( int thisClient = 1; thisClient <= MAXPLAYERS; ++thisClient )
		{
			if ( IsClientInGame(thisClient) && L4D2_IsSurvivor(thisClient) && IsPlayerAlive(thisClient) )
			{	
				float posThisSurvivor[3];			
				GetClientAbsOrigin(thisClient, posThisSurvivor);
				CNavArea areaThisSurvivor = NavMesh_GetNearestArea(posThisSurvivor); 
				int indexAreaThisSurvivor = view_as<int>(NavMesh_FindAreaByID(view_as<int>(areaThisSurvivor.ID)));
				bool didBuildPath = NavMesh_BuildPath(spawn, areaThisSurvivor, posThisSurvivor, GauntletPathCost); 
				if ( didBuildPath )
				{
					// TODO: hoping the cost is for the path built in NavMesh_BuildPath
					int pathCost = NavMeshArea_GetTotalCost(indexAreaThisSurvivor); 
					if ( pathCost < shortestPath || shortestPath == -1 )
					{
						shortestPath = pathCost; // update the shortest path found to survivors from this position
					}
				}
			}
		}
		// Return whether this shortest calculated path length is acceptable
		if ( shortestPath > 500 /*GetConVarInt(hCvarSpawnProximityMin)*/ && shortestPath < 650 /*GetConVarInt(hCvarSpawnProximityMax)*/ ) 
		{
			shouldSpawn = true;	
		}
	}
	return shouldSpawn;	
}

stock bool IsSpawnStuck( CNavArea spawnArea ) 
{
	return false;// TODO: Function is returning too many false positives; almost no spawns 
	bool isStuck = false;
	int indexSpawnArea = view_as<int>(NavMesh_FindAreaByID(view_as<int>(spawnArea.ID)));
	float posSpawnArea[3];
	if ( NavMeshArea_GetCenter(indexSpawnArea, posSpawnArea) ) // need coordinates to run collision check
	{
		/*
		 * Testing with DirectedInfectedSpawn SI appears to indicate all standard SI return the same mins and maxs values below
		 * We are inflating a bit here to reduce chance of being stuck
		 */
		float mins[3] = {-16.0, -16.0, 0.0};
		float maxs[3] = {16.0, 16.0, 71.0};		
		for( int i = 0; i < sizeof(mins); i++ ) 
		{
		    mins[i] -= BOUNDINGBOX_INFLATION_OFFSET;
		    maxs[i] += BOUNDINGBOX_INFLATION_OFFSET;
		}	
		TR_TraceHullFilter(posSpawnArea, posSpawnArea, mins, maxs, MASK_SOLID, TraceEntityFilterSolid); // collision check
		if ( TR_DidHit() )
		{
			isStuck = true;
		} 
		else 
		{
			char readoutCoordinates[32];
			Format(readoutCoordinates, sizeof(readoutCoordinates), "[%f, %f, %f]", posSpawnArea[0], posSpawnArea[1], posSpawnArea[2]);
			LogError("[ SS2_NavMesh ] - Spawn position %s deemed to be stuck", readoutCoordinates);
		}
	} 
	else
	{
		LogError("[ SS2_NavMesh ] - Failed to find coordinates of nav mesh while checking for space to spawn: Nav mesh ID %d", indexSpawnArea);
	}
	return isStuck;
}  

public bool TraceEntityFilterSolid(int entity, int contentsMask) 
{
	return entity > MaxClients;
}

int GauntletPathCost(CNavArea area, CNavArea from, CNavLadder ladder, any data)
{
	if (from == INVALID_NAV_AREA)
	{
		return 0;
	}
	else
	{
		int iDist = 0;
		if (ladder != INVALID_NAV_LADDER)
		{
			iDist = RoundFloat(ladder.Length * 10.0); // addding 10x multiplier to discourage spawn spots that require climbing
		}
		else
		{
			float flAreaCenter[3]; float flFromAreaCenter[3];
			area.GetCenter(flAreaCenter);
			from.GetCenter(flFromAreaCenter);
			
			iDist = RoundFloat(GetVectorDistance(flAreaCenter, flFromAreaCenter));
		}
		
		int iCost = iDist + from.CostSoFar;
		int iAreaFlags = area.Attributes;
		if (iAreaFlags & NAV_MESH_CROUCH) iCost += 20; // default += (20)
		if (iAreaFlags & NAV_MESH_JUMP) iCost += (50 * iDist); // default +=(5 * iDist)
		return iCost;
	}
}

/***********************************************************************************************************************************************************************************

                                                 							MANUAL SPAWNING (for testing)
                                                                    
***********************************************************************************************************************************************************************************/

// Spawn spitters to demarcate the navmeshes with the allocated restrictions 
stock void Spawn_NavMesh_Direct(int client)
{
	// determine centre of spawning area
	float clientPos[3];
	GetClientAbsOrigin(client, clientPos);
	CNavArea searchCentre = NavMesh_GetNearestArea(clientPos);
	// collate surrounding areas
	ArrayStack spawnAreas;
	spawnAreas = new ArrayStack(CNAVAREA_MEMORYSIZE);
	NavMesh_CollectSurroundingAreas(spawnAreas, searchCentre, MAX_SPAWN_NAVMESH_DIST, StepHeight, StepHeight); // keep low enough to prevent spawning on the other side of the wall in labyrinth map layouts	
	while (!IsStackEmpty(spawnAreas))
	{
		CNavArea thisArea = spawnAreas.Pop();
		if (thisArea != INVALID_NAV_AREA)
		{
			float posThisArea[3];
			int indexThisArea = view_as<int>(thisArea.ID);
			int travelCost = NavMeshArea_GetTotalCost(indexThisArea);
			if ( travelCost > 300 && travelCost < 650 ) // considering nav meshes within a specific range
			{
				CreateInfected("spitter", posThisArea, NULL_VECTOR);
			}
			DrawNavArea( client, thisArea, FocusedAreaColor, 3.0 );
		}
	}
	delete spawnAreas;
}

stock int GetDistance2D(float alpha[3], float beta[3])
{
	float distance = SquareRoot( Pow(alpha[COORD_X] - beta[COORD_X], 2.0) + Pow(alpha[COORD_Y] - beta[COORD_Y], 2.0) ); // Pythagoras
	return RoundToNearest(distance);
}

/***********************************************************************************************************************************************************************************

                                                 								DISPLAY SPAWN AREAS
                                                                    
***********************************************************************************************************************************************************************************/

public void OnGameFrame()
{
	EngineVersion engineVersion = GetEngineVersion();

	if ( GetGameTime() >= g_flTrackNavAreaNextThink )
	{
		g_flTrackNavAreaNextThink = GetGameTime() + g_flTrackNavAreaThinkRate;

		for (int client = 1; client <= MaxClients; client++)
		{
			if (!IsClientInGame(client))
				continue;
			
			if ( g_bPlayerTrackNavArea[client] )
			{
				float clientPos[3];
				GetClientAbsOrigin(client, clientPos);
				CNavArea spawnCenter = NavMesh_GetNearestArea(clientPos);
				if (spawnCenter == INVALID_NAV_AREA)
					continue;
					
				// Display all nearby areas
				ArrayStack spawnAreas;
				spawnAreas = new ArrayStack(128);
				if (spawnAreas == INVALID_HANDLE) continue;
				NavMesh_CollectSurroundingAreas(spawnAreas, spawnCenter, 400.0, StepHeight, StepHeight);	
				int numAreas = 0;
				while (!spawnAreas.Empty)
				{
					CNavArea area = spawnAreas.Pop();
					if (area != INVALID_NAV_AREA)
					{
						DrawNavArea( client, area, FocusedAreaColor );
						++numAreas;
						
						ArrayList connections = new ArrayList();
						area.GetAdjacentList(NAV_DIR_COUNT, connections);
						ArrayList incomingConnections = new ArrayList();
						area.GetIncomingConnections(NAV_DIR_COUNT, incomingConnections);
						
						for (int i = 0; i < connections.Length; i++)
						{
							DrawNavArea(client, connections.Get(i), DefaultAreaColor);	
						}
		
						for (int i = 0; i < incomingConnections.Length; i++)
						{
						}
						switch (engineVersion)
						{
							case Engine_Left4Dead2:
							{
								PrintHintText(client, "ID: %d, # Connections: %d, # Incoming: %d", area.ID, connections.Length, incomingConnections.Length);
							}
							default:
							{
								SetHudTextParams(-1.0, 0.75, 0.2, 255, 255, 0, 150, 0, 0.0, 0.0, 0.0);
								ShowSyncHudText(client, g_hPlayerTrackNavAreaInfoHudSync, "ID: %d\n# Connections: %d\n# Incoming: %d\n", area.ID, connections.Length, incomingConnections.Length);
							}
						}
						delete connections;
						delete incomingConnections; 
					}
				}
				delete spawnAreas; 		
			}
		}
	}
}

void DrawNavArea( int client, CNavArea area, const int color[4], float duration=0.15 ) 
{
	if ( !IsClientInGame(client) || area == INVALID_NAV_AREA )
		return;

	float from[3], to[3];
	area.GetCorner( NAV_CORNER_NORTH_WEST, from );
	area.GetCorner( NAV_CORNER_NORTH_EAST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_NORTH_EAST, from );
	area.GetCorner( NAV_CORNER_SOUTH_EAST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_SOUTH_EAST, from );
	area.GetCorner( NAV_CORNER_SOUTH_WEST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);

	area.GetCorner( NAV_CORNER_SOUTH_WEST, from );
	area.GetCorner( NAV_CORNER_NORTH_WEST, to );
	from[2] += 2; to[2] += 2;

	TE_SetupBeamPoints(from, to, g_iPathLaserModelIndex, g_iPathLaserModelIndex, 0, 30, duration, 1.0, 1.0, 0, 0.0, color, 1);
	TE_SendToClient(client);
}

public void OnClientDisconnect(int client)
{
	g_bPlayerTrackNavArea[client] = false;
}

/**
 * @return: the farthest flow distance currently held by a survivor
 */
int GetRearSurvivorFlow() 
{
	int lowestMapFlow = -1; // initialise to impossible value
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int thisClient = L4D2_GetSurvivorOfIndex(i);
		if (thisClient == 0 || !IsPlayerAlive(thisClient)) continue;
		
		float thisSurvivorsOrigin[3];
		char survivorName[32];
		GetClientName(thisClient, survivorName, sizeof(survivorName));
		if ( GetClientAbsOrigin(thisClient, thisSurvivorsOrigin) )
		{
			int thisFlow = GetFlow(thisSurvivorsOrigin);
			if ( thisFlow <= 0 )
			{
				PrintToServer("GetRearSurvivorFlow(): Survivor %s returning invalid flow %f", survivorName, thisFlow);
				continue;
			}
			if ( lowestMapFlow == -1 || thisFlow < lowestMapFlow )
			{
				lowestMapFlow = thisFlow;
			}
		}
		else
		{
			PrintToServer("GetRearSurvivorFlow(): Failed to find position for %s", survivorName);
		}
	}
	return lowestMapFlow;
}
