#define CVAR_PREFIX			"confogl_"
#define CVAR_FLAGS FCVAR_SPONLY|FCVAR_NOTIFY

ConVar CreateConVarEx(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	char sBuffer[128];
	ConVar cvar = null;
	Format(sBuffer, sizeof(sBuffer), "%s%s",CVAR_PREFIX, name);
	flags = flags | CVAR_FLAGS;
	cvar = CreateConVar(sBuffer, defaultValue, description, flags, hasMin, min, hasMax, max);
	
	return cvar;
}

int GetURandomIntRange(int min, int max)
{
	return RoundToNearest((GetURandomFloat() * (max - min)) + min);
}

bool IsValidClient(int client)
{
    if (client <= 0 || client > MaxClients) return false;
    if (!IsClientInGame(client)) return false;
    return true;
}

void KillEntity(int iEntity)
{
	char pluginName[PLATFORM_MAX_PATH], classname[64];
	GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
	GetEdictClassname(iEntity, classname, 64);
	PrintToServer("[%s] Removed %s", pluginName, classname);
	
#if SOURCEMOD_V_MINOR > 8
	RemoveEntity(iEntity);
#else
	AcceptEntityInput(iEntity, "Kill");
#endif
}
