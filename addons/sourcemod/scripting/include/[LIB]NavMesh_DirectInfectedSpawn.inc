#if defined _NavMesh_DirectInfectedSpawn_included
 #endinput
#endif
#define _NavMesh_DirectInfectedSpawn_included



native void NMDIS_NavMeshSpawn(const int SpawnQueue[MAXPLAYERS]);


native void NMDIS_TriggerSpawn(L4D2_Infected desiredClass, float pos[3], float ang[3]);


public SharedPlugin __pl_NavMesh_DirectInfectedSpawn = 
{
	name = "NavMesh_DirectInfectedSpawn",
	file = "NavMesh_DirectInfectedSpawn.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_NavMesh_DirectInfectedSpawn_SetNTVOptional()
{
	MarkNativeAsOptional("NMDIS_NavMeshSpawn");
	MarkNativeAsOptional("NMDIS_TriggerSpawn");
}
#endif
