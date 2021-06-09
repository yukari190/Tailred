#if defined _DirectInfectedSpawn_included
 #endinput
#endif
#define _DirectInfectedSpawn_included



native void TriggerSpawn(L4D2_Infected desiredClass, float pos[3], float ang[3]);


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
	MarkNativeAsOptional("TriggerSpawn");
}
#endif
