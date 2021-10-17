#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <readyup>
#include <l4d2util>

#define Pai 3.14159265358979323846 

#define State_None 0
#define State_Climb 1
#define State_OnAir 2

#define JumpSpeed 300.0 
#define gbodywidth 20.0 
#define bodylength 70.0

ConVar
	l4d_climb_glow,
	l4d_climb_speed;
float
	BodyNormal[MAXPLAYERS+1][3],
	Angle[MAXPLAYERS+1],
	BodyPos[MAXPLAYERS+1][3],
	LastPos[MAXPLAYERS+1][3],
	SafePos[MAXPLAYERS+1][3],
	BodyWidth[MAXPLAYERS+1],
	JumpTime[MAXPLAYERS+1],
	LastTime[MAXPLAYERS+1],
	Intervual[MAXPLAYERS+1],
	GlowTime[MAXPLAYERS+1],
	ClimbSpeed[MAXPLAYERS+1],
	PlayBackRate[MAXPLAYERS+1],
	StuckIndicator[MAXPLAYERS+1];
int
	Colon[MAXPLAYERS+1],
	State[MAXPLAYERS+1],
	g_Sprite,
	g_HaloSprite;
bool
	FirstRun[MAXPLAYERS+1],
	GlowIndicator[MAXPLAYERS+1];

public void OnPluginStart()
{
	l4d_climb_glow = CreateConVar("l4d_climb_glow", "1", "0 disable 1:enable ", FCVAR_NONE);
	l4d_climb_speed = CreateConVar("l4d_climb_speed", "40", "210 is the walk speed", FCVAR_NONE);
	
	HookEvent("player_bot_replace", player_bot_replace);	 
	HookEvent("player_jump", player_jump);
	HookEvent("player_team", player_team);
	HookEvent("jockey_ride", infected_ablility);
	HookEvent("charger_carry_start", infected_ablility);
	HookEvent("tongue_grab",  infected_ablility);
	HookEvent("player_ledge_grab",  player_ledge_grab);
	HookEvent("lunge_pounce", infected_ablility);
	HookEvent("player_incapacitated_start", player_incapacitated_start); 	
	HookEvent("player_death", player_death);
	HookEvent("player_spawn", player_spawn);
	
	HookEvent("bullet_impact", Event_BulletImpact);
}

public void OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sun/overlay.vmt");
}

public Action OnPlayerRunCmd(int client, int &buttons)
{
	if (IsInReady() && IsValidAndInGame(client) && IsPlayerAlive(client))
	{
		if (buttons & IN_JUMP)
		{
			if (GetEntPropEnt(client, Prop_Send, "m_hGroundEntity") == -1)
			{
				if (GetEntityMoveType(client) != MOVETYPE_LADDER)
				{
					buttons &= ~IN_JUMP;
				}
			}
		}
	}
	return Plugin_Continue;
}

public void L4D2_OnRealRoundStart()
{
	ResetAllState();
}

public void OnReadyupCountdown()
{
	ResetAllState();
}

public void infected_ablility(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return;
	int victim = GetClientOfUserId(event.GetInt("victim"));
	if (!IsValidAndInGame(victim)) return;
	Stop(victim);
}

public void player_ledge_grab(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(victim)) return;
	Stop(victim);
}

public void player_incapacitated_start(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return; 
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(victim)) return;
	Stop(victim);
}

public void player_bot_replace(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return; 
	int client = GetClientOfUserId(event.GetInt("player"));
	int bot = GetClientOfUserId(event.GetInt("bot"));
	if (!IsValidAndInGame(client) || !IsValidAndInGame(bot)) return;
	Stop(client);
	Stop(bot); 
}

public void player_team(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return; 
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(client)) return;
	Stop(client);
}

public void player_death(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(victim)) return;
	Stop(victim); 
}

public void player_spawn(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return;
	int victim = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidAndInGame(victim)) return;
	Stop(victim); 
}

public void player_jump(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady())return;
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsSurvivorAlive(client)) return;
	
	SDKUnhook(client, SDKHook_PostThinkPost,  PreThink); 
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
	State[client] = State_OnAir;
	SDKHook(client, SDKHook_PostThinkPost,  PreThink);   // watch it.
	float pos[3];
	GetClientAbsOrigin(client, pos);
	CopyVector(pos, SafePos[client]);                // save it's postion , if it stucked then teleport it to this postion.
	LastTime[client] = GetEngineTime();
	JumpTime[client] = LastTime[client];
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady()) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if (!IsValidSurvivor(client) || IsFakeClient(client)) return;
	
	// Check if the weapon is an enabled weapon type to tag
	if (GetWeaponType(client))
	{
		int Color[4];
		Color[3] = 100;
		Color[0] = GetRandomInt(0, 255);
		Color[1] = GetRandomInt(0, 255);
		Color[2] = GetRandomInt(0, 255);
		float Origin[3], Direction[3];
	
		Origin[0] = GetEventFloat(event, "x");
		Origin[1] = GetEventFloat(event, "y");
		Origin[2] = GetEventFloat(event, "z");
		
		float startPos[3];
		startPos[0] = Origin[0] ;
		startPos[1] = Origin[1];
		startPos[2] = Origin[2];
		
		float bulletPos[3];
		bulletPos = startPos;
		
		float LaserLife = 0.80, LaserWidth = 1.0, LaserOffset = 36.0;
	
		// Current player's EYE position
		float playerPos[3];
		GetClientEyePosition(client, playerPos);
		
		float lineVector[3];
		SubtractVectors(playerPos, startPos, lineVector);
		NormalizeVector(lineVector, lineVector);
		
		// Offset
		ScaleVector(lineVector, LaserOffset);
		// Find starting point to draw line from
		SubtractVectors(playerPos, lineVector, startPos);
		
		// Draw the line
		TE_SetupBeamPoints(startPos, bulletPos, g_Sprite, 0, 0, 0, LaserLife, LaserWidth, LaserWidth, 1, 0.0, Color, 0);
		
		TE_SendToAll();
		
		Direction[0] = GetRandomFloat(-1.0, 1.0);
		Direction[1] = GetRandomFloat(-1.0, 1.0);
		Direction[2] = GetRandomFloat(-1.0, 1.0);
		TE_SetupBloodSprite(Origin, Direction, Color, 5000, g_Sprite, g_HaloSprite);
		
		TE_SendToAll(0.0);
	}
}


bool GetWeaponType(int client)
{
	// Get current weapon
	char weapon[32];
	GetClientWeapon(client, weapon, 32);
	
	if(StrEqual(weapon, "weapon_hunting_rifle") || StrContains(weapon, "sniper") >= 0) return true;
	if(StrContains(weapon, "weapon_rifle") >= 0) return true;
	if(StrContains(weapon, "pistol") >= 0) return true;
	if(StrContains(weapon, "smg") >= 0) return true;
	if(StrContains(weapon, "shotgun") >=0) return true;
	
	return false;
}

void ResetAllState()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i)) Stop(i);
	}
}

void Stop(int client)
{
	if (State[client] == State_None) return;
	if (State[client] == State_Climb) Jump(client, false, 50.0);
	State[client] = State_None;
	if (Colon[client] > 0 && IsValidEdict(Colon[client]) && IsValidEntity(Colon[client]))  // remove dummy body
	{
		AcceptEntityInput(Colon[client], "kill");
		Colon[client] = 0;
		
		GotoFirstPerson(client); 
		VisiblePlayer(client, true);
		SetEntityMoveType(client, MOVETYPE_WALK); 
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	}
	
	SDKUnhook(client, SDKHook_PostThinkPost,  PreThink); //stop watching it
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);  //other people can see it's real body.
}

void Start(int client)
{
	float vAngles[3], vOrigin[3], hit[3], normal[3], up[3];
	GetClientEyePosition(client,vOrigin);
	GetClientEyeAngles(client, vAngles);	 
	
	GetRay(client, vOrigin, vAngles, hit, normal, 0.0 - gbodywidth); 
	if (GetVectorDistance(hit, vOrigin) < gbodywidth * 2.0)   //calc distince between body and surfece, if it is close enough, then get into climb mode.
	{
		SetVector(up, 0.0, 0.0, 1.0);
		float f = GetAngle(normal, up) * 180 / Pai;
		if (f < 10.0 || f > 170.0) //the surfece is horizontal, can not climb
		{
			return;
		}
		//code below get into climb mode
		
		CopyVector(normal, BodyNormal[client]); 
		CopyVector(hit, BodyPos[client]);
	 
		Angle[client] = 0.0;
		CopyVector(normal, BodyNormal[3]);
	 
		int c = CreateClone(client);  //create dummy body
		if (c > 0)
		{
			Colon[client] = c;
			SetEntityMoveType(client, MOVETYPE_NONE); 
			GotoThirdPerson(client); 
			VisiblePlayer(client, false);
			SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
			SDKHook(client, SDKHook_SetTransmit, OnSetTransmitClient); //other player can not see it's real body
			SDKUnhook(client, SDKHook_PostThinkPost, PreThink); 
			SDKHook(client, SDKHook_PostThinkPost, PreThink);  // watch it.
			SaveWeapon(client);
			State[client] = State_Climb;
			FirstRun[client] = true;
			
			GlowIndicator[client] = false;
			GlowTime[client] = 0.0;
		}
		else PrintToChat(client, "Your model is not allow for climb");
	}
}

void Jump(int client, bool check = true, float speed = JumpSpeed)
{
	float time = GetEngineTime(); 
	if (check)
	{
		if (time - JumpTime[client] < 2.0)
		{
			PrintCenterText(client, "you are jump too quick");
			return;
		}
	}
 	if (Colon[client] > 0) //remove dummy body
	{
		AcceptEntityInput(Colon[client], "kill");
		Colon[client]=0;
		RestoreWeapon(client); 
	}
	SDKUnhook(client, SDKHook_SetTransmit, OnSetTransmitClient);
	
	GotoFirstPerson(client);
	VisiblePlayer(client, true);
	SetEntityMoveType(client, MOVETYPE_WALK);  
	float vAngles[3], vOrigin[3], vec[3], pos[3];
	GetClientEyePosition(client,vOrigin);
	CopyVector(BodyNormal[client], vec);
	NormalizeVector(vec, vec);
	ScaleVector(vec, BodyWidth[client]);
	AddVectors(vOrigin, vec, pos);
	
	GetClientEyeAngles(client, vAngles);
	GetAngleVectors(vAngles, vec, NULL_VECTOR,NULL_VECTOR);
	NormalizeVector(vec, vec);
	ScaleVector(vec, speed);
	TeleportEntity(client, pos, NULL_VECTOR, vec); // jump into her's look direction
	CopyVector(pos, LastPos[client]);
	JumpTime[client] = time;
	StuckIndicator[client] = 0.0;
	State[client] = State_OnAir;                   //state switch to onair
}

public Action OnSetTransmitClient(int climber, int client)
{
	if (climber != client)
	{
		int teamClimber = GetClientTeam(climber);
		if (teamClimber == 2) return Plugin_Handled; 
		int teamClient = GetClientTeam(client);
		if (teamClimber == 3 && teamClient == 2)return Plugin_Handled; 
		if (GlowIndicator[climber]) return Plugin_Continue;
		return Plugin_Handled; 
	}
	else return Plugin_Continue;
}

public void PreThink(int client)
{
	if (IsSurvivorAlive(client))
	{
		float time = GetEngineTime();
		float intervual = time - LastTime[client]; 
		Intervual[client] = intervual;
		if (State[client] == State_OnAir) OnAir(client); // player is on air 
		else if (State[client] == State_Climb) Climb(client, intervual); // player is climbing
		LastTime[client] = time;
		if (l4d_climb_glow.IntValue == 1)
		{
			GlowTime[client] += intervual;
			
			if (GlowTime[client] > 4.0)
			{
				GlowIndicator[client] = false;
				GlowTime[client] = 0.0;
			}
			else if (GlowTime[client] > 3.5)
			{			 
				GlowIndicator[client] = true;	 
			}
		}
	}
}

void OnAir(int client)
{
	int flag = GetEntityFlags(client);  //FL_ONGROUND
	if (flag & FL_ONGROUND) // on ground , so stop
	{
		Stop(client);
		return;
	}
	int button = GetClientButtons(client);
	if((button & IN_USE))   // press use key, then start climb
	{ 
		Start(client); 
	}	
	//code below determine if a player is stucked after jump.
	float time = GetEngineTime();
	if (time > JumpTime[client] + 1.0) return;
	float pos[3];
	GetClientAbsOrigin(client, pos);
	StuckIndicator[client] += GetVectorDistance(pos, LastPos[client]);
	CopyVector(pos, LastPos[client]);
	if (time > JumpTime[client] + 0.5 && StuckIndicator[client] < 10.0)
	{
		TeleportEntity(client, SafePos[client], NULL_VECTOR,NULL_VECTOR); 
		PrintHintText(client, "You are stucked");
		Stop(client);
	} 
}

void Climb(int client, float intervual)
{
	int clone = Colon[client];
	if (clone > 0)
	{ 
		SetEntProp(client, Prop_Send, "m_iAddonBits", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
		float colonPos[3], clientPos[3], bodyPos[3], headOffset[3], footOffset[3], bodyTouchPos[3], headTouchPos[3], footTouchPos[3], 
			moveDir[3], cloneAnge[3], bodyNormal[3], eyeNormal[3], footNormal[3], normal[3], temp[3], up[3];
		SetVector(up, 0.0, 0.0, 1.0); 
		int button = GetClientButtons(client);
		SetEntityMoveType(client, MOVETYPE_NONE); 
		
		float playrate = 0.0;	
		bool needprocess;
		bool moveforward;
		bool moveback;
		if (button & IN_FORWARD)
		{
			needprocess = true; 
			moveforward = true;
		}
		else if (button & IN_BACK)
		{
			needprocess = true; 
			moveback = true;
		}
		if (button & IN_MOVELEFT)
		{
			Angle[client]+=intervual*90.0;
			playrate=PlayBackRate[client]*0.5;
			needprocess = true;
		}
		else if (button & IN_MOVERIGHT)
		{
			Angle[client]-=intervual*90.0;
			playrate=PlayBackRate[client]*0.5;
			needprocess = true;
		}
		if (button & IN_JUMP || button & IN_ATTACK || button & IN_ATTACK2)
		{
			Jump(client);
			return;
		}
 
		while (needprocess || FirstRun[client])
		{
			FirstRun[client] = false;
			CopyVector(BodyPos[client], bodyPos);  
			CopyVector(BodyNormal[client], normal);
			CopyVector(normal, cloneAnge);
			ScaleVector(cloneAnge, -1.0);
			GetVectorAngles(cloneAnge, cloneAnge); 
			cloneAnge[2] = 0.0 - Angle[client]; 
			
			float f = GetAngle(BodyNormal[client], up) * 180 / Pai;
			if (f < 10.0 || f > 170.0)
			{
				Jump(client, false, 0.0);
				return;
			}
			
			SetVector(headOffset, 0.0, 0.0, 1.0); 
			GetProjection(normal, up, headOffset);  
			RotateVector(normal, headOffset, AngleCovert(Angle[client]), headOffset); 
			CopyVector(headOffset, footOffset);
			NormalizeVector(headOffset, headOffset);
			NormalizeVector(footOffset, footOffset);
			ScaleVector(footOffset, 0.0 - bodylength * 0.5);
			ScaleVector(headOffset, bodylength * 0.5);
			
			AddVectors(bodyPos, headOffset, headTouchPos);
			AddVectors(bodyPos, footOffset, footTouchPos);	
			
			if (GetRaySimple(client, headTouchPos, footTouchPos, temp))
			{ 
				break;
			}
			
			CopyVector(footTouchPos, colonPos);
			
			float disBody = GetRay(client, bodyPos, cloneAnge , bodyTouchPos, bodyNormal, 0.0 - BodyWidth[client]);  
			float disHead = GetRay(client, headTouchPos, cloneAnge , headTouchPos, eyeNormal, 0.0 - BodyWidth[client]);  
			float disFoot = GetRay(client, footTouchPos, cloneAnge , footTouchPos, footNormal, 0.0 - BodyWidth[client]);  
			
			if (disBody > BodyWidth[client] * 2.0)
			{
				Jump(client, false, 50.0);				 
				return;
			}
			bool needrotatenormal = false;
			if (disHead > BodyWidth[client])
			{
				disHead = BodyWidth[client];
				needrotatenormal=true;
			}
			if (disFoot > BodyWidth[client])
			{
				disFoot = BodyWidth[client];
				needrotatenormal = true;
			}
			float ft = disHead - disFoot;
			
			if (needrotatenormal)
			{
				ft = ArcSine(ft / SquareRoot(ft * ft + bodylength * 0.5 * bodylength * 0.5));
				GetVectorCrossProduct(bodyNormal, headOffset, temp);
				RotateVector(temp, normal, ft * 0.5, normal);
				CopyVector(normal, normal);
			}
			else
			{
				CopyVector(bodyNormal, normal);
			}
			
			CopyVector(headOffset, moveDir);
			NormalizeVector(moveDir, moveDir); 
			ScaleVector(moveDir, ClimbSpeed[client] * intervual);
			
			CopyVector(bodyTouchPos, bodyPos); 
			
			if (moveforward)
			{
				playrate = PlayBackRate[client]; 
				AddVectors(colonPos, moveDir, colonPos);
				AddVectors(bodyPos, moveDir, bodyPos);
			}
			else if (moveback)
			{
			 
				playrate = 0.0 - PlayBackRate[client];
				SubtractVectors(colonPos, moveDir, colonPos);
				SubtractVectors(bodyPos, moveDir, bodyPos);
			 
			}
			
			CopyVector(bodyPos, clientPos);
			clientPos[2] -= bodylength * 0.5;
			TeleportEntity(client, clientPos, NULL_VECTOR, NULL_VECTOR); 
			TeleportEntity(clone, colonPos, cloneAnge, NULL_VECTOR); 
			CopyVector(bodyPos, BodyPos[client]);
			CopyVector(normal, BodyNormal[client]);
			break;
		}
		SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", playrate);			
	}
	else
	{
		Stop(client);
	}
	return;
}

int CreateClone(int client)
{
	float vAngles[3], vOrigin[3];
	GetClientAbsOrigin(client, vOrigin);
	GetClientEyeAngles(client, vAngles);	 
	char playerModel[42]; 
	GetEntPropString(client, Prop_Data, "m_ModelName", playerModel, sizeof(playerModel)); 
	int iAnim = GetModelInfo(playerModel, ClimbSpeed[client] ,PlayBackRate[client], BodyWidth[client]); 
	int clone = 0;
	if (iAnim > 0)
	{
		clone = CreateEntityByName("prop_dynamic_override"); //prop_dynamic
		SetEntityModel(clone, playerModel);  
	 
		float vPos[3], vAng[3];
		vPos[0] = -0.0; 
		vPos[1] = -0.0;
		vPos[2] = -30.0;
		
		vAng[2] = -90.0;
		vAng[0] = -90.0;
		vAng[1] = 0.0;
	 
		TeleportEntity(clone,  vOrigin, vAngles, NULL_VECTOR); 
		
		SetEntProp(clone, Prop_Send, "m_nSequence", iAnim);
		SetEntPropFloat(clone, Prop_Send, "m_flPlaybackRate", 1.0); 
		
		SetEntPropFloat(clone, Prop_Send, "m_fadeMinDist", 10000.0); 
		SetEntPropFloat(clone, Prop_Send, "m_fadeMaxDist", 20000.0); 
		
		SetEntProp(clone, Prop_Send, "m_iGlowType", 3);
		SetEntProp(clone, Prop_Send, "m_nGlowRange", 0);
		SetEntProp(clone, Prop_Send, "m_nGlowRangeMin", 600);
		int red = 0;
		int gree = 151;
		int blue = 0;
		SetEntProp(clone, Prop_Send, "m_glowColorOverride", red + (gree * 256) + (blue* 65536)); 
	}
	return clone;
}

 
void SaveWeapon(int client)
{ 
	client = client + 1;
}

void RestoreWeapon(int client)
{ 
	client = client + 1;
}

bool IsSurvivorAlive(int client)
{
	return IsValidSurvivor(client) && IsPlayerAlive(client) && !IsFakeClient(client);
}

int GetModelInfo(char[] model, float &speedvalue, float &playbackrate, float &bodywidth)
{
	int anim = 0;
	float S = 0.0;
	bodywidth = gbodywidth;
	if (StrContains(model, "survivor_teenangst") != -1)
	{ 
		anim = 633;
		S = 30.0;
	}
	else if (StrContains(model, "survivor_manager") != -1)
	{
		anim = 514;
		S = 30.0;
	}
	else if (StrContains(model, "survivor_namvet") != -1)
	{
		anim = 514;
		S = 30.0;
	}
	else if (StrContains(model, "survivor_biker") != -1)
	{
		anim = 517;
		S = 30.0;
	}
	else if (StrContains(model, "gambler") != -1)
	{
		anim = 605;
		S = 30.0;
	}
 	else if (StrContains(model, "producer") != -1)
	{
		anim = 614;
		S = 30.0;
	}
	else if(StrContains(model, "coach") != -1)
	{
		anim = 606;
		S = 30.0;
	}
 	else if(StrContains(model, "mechanic") != -1)
	{
		anim = 610;
		S = 30.0;
	}
	
	speedvalue = l4d_climb_speed.FloatValue;
	playbackrate = 1.0 + (speedvalue - S) / S;
	
	return anim;
}
 
void VisiblePlayer(int client, bool visible = true)
{
	if (visible)
	{
		SetEntityRenderMode(client, RENDER_NORMAL);
		SetEntityRenderColor(client, 255, 255, 255, 255);		 
	}
    else
	{
		SetEntityRenderMode(client, RENDER_TRANSCOLOR);
		SetEntityRenderColor(client, 0, 0, 0, 0);
	} 
}

bool GetRaySimple(int client, float pos1[3] , float pos2[3], float hitpos[3])
{
	Handle trace;
	bool hit;  
	trace = TR_TraceRayFilterEx(pos1, pos2, MASK_SOLID, RayType_EndPoint, DontHitColoeAndOxygentank, client); 
	if (TR_DidHit(trace))
	{			
		TR_GetEndPosition(hitpos, trace); 
		hit = true;
	}
	CloseHandle(trace); 
	return hit;
}

float GetRay(int client, float pos[3] , float angle[3], float hitpos[3], float normal[3], float offset = 0.0)
{
	Handle trace;
	float ret = 9999.0;
	float RayVec[3];
	trace = TR_TraceRayFilterEx(pos, angle, MASK_SOLID, RayType_Infinite, TraceRayDontHitSelfAndColoe, client); 
	if (TR_DidHit(trace))
	{			
		CopyVector(pos, RayVec);
		TR_GetEndPosition(hitpos, trace);
		TR_GetPlaneNormal(trace, normal);
		NormalizeVector(normal, normal); 
		if (offset!=0.0)
		{
			float t[3];
			GetAngleVectors(angle, t, NULL_VECTOR, NULL_VECTOR );
			NormalizeVector(t, t);
			ScaleVector(t, offset);
			AddVectors(hitpos, t, hitpos); 
		}
		ret = GetVectorDistance(RayVec,hitpos);
	}
	CloseHandle(trace); 
	return ret;
}

void CopyVector(float source[3], float target[3])
{
	target[0] = source[0];
	target[1] = source[1];
	target[2] = source[2];
}

void SetVector(float target[3], float x, float y, float z)
{
	target[0] = x;
	target[1] = y;
	target[2] = z;
}

public bool DontHitSelf(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	return true;
}

float AngleCovert(float angle)
{
	return angle / 180.0 * Pai;
}

float GetAngle(float x1[3], float x2[3])
{
	return ArcCosine(GetVectorDotProduct(x1, x2)/(GetVectorLength(x1)*GetVectorLength(x2)));
}

void GetProjection(float n[3], float t[3], float r[3])
{
	float A = n[0];
	float B = n[1];
	float C = n[2];
	
	float a = t[0];
	float b = t[1];
	float c = t[2];
	
	float p = -1.0 * (A * a + B * b + C * c) / (A * A + B * B + C * C);
	r[0] = A * p + a;
	r[1] = B * p + b;
	r[2] = C * p + c;
}

void RotateVector(float direction[3], float vec[3], float alfa, float result[3])
{
   	float v[3], u[3], uv[3], sinuv[3], uuv[3];
	CopyVector(vec,v);
	
	CopyVector(direction,u);
	NormalizeVector(u,u);
	
	GetVectorCrossProduct(u,v,uv);
	
	CopyVector(uv, sinuv);
	ScaleVector(sinuv, Sine(alfa));
	
	GetVectorCrossProduct(u,uv,uuv);
	ScaleVector(uuv, 2.0 * Pow(Sine(alfa * 0.5), 2.0));	
	
	AddVectors(v, sinuv, result);
	AddVectors(result, uuv, result);
} 

public bool TraceRayDontHitSelfAndColoe(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	else if (data >= 1 && data <= MaxClients)
	{
		if (entity == Colon[data])
		{
			return false; 
		}
	}
	return true;
}

public bool DontHitColoeAndOxygentank(int entity, int mask, any data)
{
	if (entity == data) 
	{
		return false; 
	}
	else if (data >= 1 && data <= MaxClients)
	{
		if (entity == Colon[data])
		{
			return false; 
		}
	}
	
	char classname[64];
	GetEdictClassname(entity, classname, sizeof(classname));
	
	if (StrEqual(classname, "prop_physics"))
	{
		GetEntPropString(entity, Prop_Data, "m_ModelName", classname, sizeof(classname));			
		if(StrEqual(classname, "models/props_equipment/oxygentank01.mdl"))
		{
			return false;
		}
	}
	return true;
}

void GotoThirdPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 0);
}

void GotoFirstPerson(int client)
{
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
}
