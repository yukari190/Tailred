#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdktools>

public Plugin myinfo =
{
	name = "L4D2 Shadow Removal",
	author = "Sir",
	description = "A plugin that removes Shadows so that Survivors can't see Infected Players their shadows through walls and the like.",
	version = "1.0",
	url = "Nope"
};

public void OnMapStart()
{
	CreateEntityByName("shadow_control");
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "shadow_control")) != -1)
	{
		SetVariantInt(1);
		AcceptEntityInput(ent, "SetShadowsDisabled");
	}
}
