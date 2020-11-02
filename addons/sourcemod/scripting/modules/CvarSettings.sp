#define CVS_CVAR_MAXLEN 64

enum struct CVSEntry
{
	ConVar CVSE_cvar;
	char CVSE_oldval[CVS_CVAR_MAXLEN];
	char CVSE_newval[CVS_CVAR_MAXLEN];
}

ArrayList CvarSettingsArray;
bool bTrackingStarted;

void CVS_OnModuleStart()
{
	CvarSettingsArray = new ArrayList(sizeof(CVSEntry));
	RegServerCmd("lgofnoc_addcvar", CVS_AddCvar_Cmd, "Add a ConVar to be set by Lgofnoc");
	RegServerCmd("lgofnoc_setcvars", CVS_SetCvars_Cmd, "Starts enforcing ConVars that have been added.");
	RegServerCmd("lgofnoc_resetcvars", CVS_ResetCvars_Cmd, "Resets enforced ConVars.  Cannot be used during a match!");
}

void CVS_OnModuleEnd()
{
	ClearAllCvarSettings();
}

void CVS_OnConfigsExecuted()
{
	if (bTrackingStarted) SetEnforcedCvars();
}

public Action CVS_SetCvars_Cmd(int args)
{
	if (IsPluginEnabled())
	{
		if (bTrackingStarted)
		{
			PrintToServer("Tracking has already been started");
			return;
		}
		SetEnforcedCvars();
		bTrackingStarted = true;
	}
}

public Action CVS_AddCvar_Cmd(int args)
{
	if (args != 2)
	{
		PrintToServer("Usage: lgofnoc_addcvar <cvar> <newValue>");
		return Plugin_Handled;
	}
	char cvar[CVS_CVAR_MAXLEN], newval[CVS_CVAR_MAXLEN];
	GetCmdArg(1, cvar, sizeof(cvar));
	GetCmdArg(2, newval, sizeof(newval));
	AddCvar(cvar, newval);
	return Plugin_Handled;
}

public Action CVS_ResetCvars_Cmd(int args)
{
	if (IsPluginEnabled())
	{
		PrintToServer("Can't reset tracking in the middle of a match");
		return Plugin_Handled;
	}
	ClearAllCvarSettings();
	PrintToServer("Server CVar Tracking Information Reset!");
	return Plugin_Handled;
}

int ClearAllCvarSettings()
{
	bTrackingStarted = false;
	CVSEntry cvsetting;
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, cvsetting, sizeof(cvsetting));
		UnhookConVarChange(cvsetting.CVSE_cvar, CVS_ConVarChange);
		SetConVarString(cvsetting.CVSE_cvar, cvsetting.CVSE_oldval);
	}
	ClearArray(CvarSettingsArray);
}

int SetEnforcedCvars()
{
	CVSEntry cvsetting;
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, cvsetting, sizeof(cvsetting));
		SetConVarString(cvsetting.CVSE_cvar, cvsetting.CVSE_newval);
	}
}

int AddCvar(const char[] cvar, const char[] newval)
{
	if (bTrackingStarted) return;
	if (strlen(cvar) >= CVS_CVAR_MAXLEN)
	{
		LogError("[Lgofnoc] CvarSettings: CVar Specified (%s) is longer than max cvar/value length (%d)", cvar, CVS_CVAR_MAXLEN);
		return;
	}
	if (strlen(newval) >= CVS_CVAR_MAXLEN)
	{
		LogError("[Lgofnoc] CvarSettings: New Value Specified (%s) is longer than max cvar/value length (%d)", newval, CVS_CVAR_MAXLEN);
		return;
	}
	ConVar newCvar = FindConVar(cvar);
	if (newCvar == INVALID_HANDLE)
	{
		LogError("[Lgofnoc] CvarSettings: Could not find CVar specified (%s)", cvar);
		return;
	}
	CVSEntry newEntry;
	char cvarBuffer[CVS_CVAR_MAXLEN];
	for (int i; i < GetArraySize(CvarSettingsArray); i++)
	{
		CvarSettingsArray.GetArray(i, newEntry, sizeof(newEntry));
		GetConVarName(newEntry.CVSE_cvar, cvarBuffer, CVS_CVAR_MAXLEN);
		if (StrEqual(cvar, cvarBuffer, false))
		{
			LogError("[Lgofnoc] CvarSettings: Attempt to track ConVar %s, which is already being tracked.", cvar);
			return;
		}
	}
	GetConVarString(newCvar, cvarBuffer, CVS_CVAR_MAXLEN);
	newEntry.CVSE_cvar = newCvar;
	strcopy(newEntry.CVSE_oldval, CVS_CVAR_MAXLEN, cvarBuffer);
	strcopy(newEntry.CVSE_newval, CVS_CVAR_MAXLEN, newval);
	newCvar.AddChangeHook(CVS_ConVarChange);
	CvarSettingsArray.PushArray(newEntry, sizeof(newEntry)); 
}

public int CVS_ConVarChange(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (bTrackingStarted)
	{
		char name[CVS_CVAR_MAXLEN];
		GetConVarName(convar, name, sizeof(name));
		PrintToChatAll("!!! [Lgofnoc] Tracked Server CVar \"%s\" changed from \"%s\" to \"%s\" !!!", name, oldValue, newValue);
	}
}
