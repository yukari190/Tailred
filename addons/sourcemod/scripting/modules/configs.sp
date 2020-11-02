#if defined __LGOFNOC_CONFIGS__
#endinput
#endif

#define __LGOFNOC_CONFIGS__

static const char customCfgDir[12] = "lgofnoc";

//public char :g_sCurrentConfig[PLATFORM_MAX_PATH]="";
static char configsPath[PLATFORM_MAX_PATH];
static char cfgPath[PLATFORM_MAX_PATH];
static char customCfgPath[PLATFORM_MAX_PATH];
static int DirSeparator;

void Configs_OnModuleStart()
{
	BuildPath(Path_SM, configsPath, sizeof(configsPath), "configs/lgofnoc/");
	BuildPath(Path_SM, cfgPath, sizeof(cfgPath), "../../cfg/");
	DirSeparator= cfgPath[strlen(cfgPath)-1];
}

bool SetCustomCfg(const char[] cfgname)
{
	if (!strlen(cfgname)) return false;
	
	Format(customCfgPath, sizeof(customCfgPath), "%s%s%c%s", cfgPath, customCfgDir, DirSeparator, cfgname);
	if (!DirExists(customCfgPath))
	{
		LogError("[Configs] Custom config directory %s does not exist!", customCfgPath);
		// Revert customCfgPath
		customCfgPath[0]=0;
		return false;
	}
	int thislen = strlen(customCfgPath);
	if (thislen+1 < sizeof(customCfgPath))
	{
		customCfgPath[thislen] = DirSeparator;
		customCfgPath[thislen+1] = 0;
	}
	else
	{
		LogError("[Configs] Custom config directory %s path too long!", customCfgPath);
		customCfgPath[0]=0;
		return false;
	}
	//strcopy(g_sCurrentConfig, sizeof(g_sCurrentConfig), cfgname);
	
	return true;	
}

stock int BuildConfigPath(char[] buffer, int maxlength, const char[] sFileName)
{
	if (customCfgPath[0])
	{
		Format(buffer, maxlength, "%s%s", customCfgPath, sFileName);
		if (FileExists(buffer))
		{
			LogMessage("[Configs] Built custom config path: %s", buffer);
			return;
		}
		else LogMessage("[Configs] Custom config not available: %s", buffer);
	}
	
	Format(buffer, maxlength, "%s%s", configsPath, sFileName);
	LogMessage("[Configs] Built default config path: %s", buffer);
}

int ExecuteConfigCfg(const char[] sFileName)
{
	if (strlen(sFileName) == 0) return;
	char sFilePath[PLATFORM_MAX_PATH];
	if (customCfgPath[0])
	{
		Format(sFilePath, sizeof(sFilePath), "%s%s", customCfgPath, sFileName);
		if (FileExists(sFilePath))
		{
			ServerCommand("exec %s%s", customCfgPath[strlen(cfgPath)], sFileName);
			return;
		}
	}
	Format(sFilePath, sizeof(sFilePath), "%s%s", cfgPath, sFileName);
	
	if (FileExists(sFilePath)) ServerCommand("exec %s", sFileName);
	else LogError("[Configs] Could not execute server config \"%s\", file not found", sFilePath);
}
