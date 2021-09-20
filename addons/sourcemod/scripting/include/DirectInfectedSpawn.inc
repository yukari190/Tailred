#if defined _DirectInfectedSpawn_included
 #endinput
#endif
#define _DirectInfectedSpawn_included

/*
 * Reposition the SI to a random point on a 2D grid around the survivors. 
 */
native bool GridSpawn(L4D2_Infected zombieClass, int attempts, float vecPos[3]);


native void TriggerSpawn(L4D2_Infected class, float[3] pos);

public SharedPlugin __pl_DirectInfectedSpawn = 
{
	name = "DirectInfectedSpawn",
	file = "DirectInfectedSpawn.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_DirectInfectedSpawn_SetNTVOptional()
{
	MarkNativeAsOptional("GridSpawn");
	MarkNativeAsOptional("TriggerSpawn");
}
#endif
