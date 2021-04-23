#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <[TR]l4d2library>
#include <[TR]readyup>

int g_Sprite;
int g_HaloSprite;

public void OnPluginStart()
{
	HookEvent("bullet_impact", Event_BulletImpact);
}

public void OnMapStart()
{
	g_Sprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_HaloSprite = PrecacheModel("materials/sun/overlay.vmt");
}

public Action Event_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
	if (!IsInReady()) return;
	int client = GetClientOfUserId(event.GetInt("userid"));
 	if(!L4D2_IsValidClient(client) || !L4D2_IsSurvivor(client) || IsFakeClient(client)) return;
	
	// Check if the weapon is an enabled weapon type to tag
	if(GetWeaponType(client))
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
