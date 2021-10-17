#if defined _current_included
 #endinput
#endif
#define _current_included


native int GetHighestSurvivorFlow();
native float GetBossProximity();

public SharedPlugin __pl_current = 
{
	name = "current",
	file = "current.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_current_SetNTVOptional()
{
	MarkNativeAsOptional("GetHighestSurvivorFlow");
	MarkNativeAsOptional("GetBossProximity");
}
#endif