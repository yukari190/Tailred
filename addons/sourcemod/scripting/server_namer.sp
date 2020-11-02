#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

public void OnPluginStart()
{
	char sBuffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sBuffer, sizeof(sBuffer), "configs/hostname/hostname.txt");
	Handle hNameFile = OpenFile(sBuffer, "r");
	if (hNameFile == INVALID_HANDLE) LogError("找不到 <hostname.txt>.");
	char sName[128];
	ReadFileLine(hNameFile, sName, sizeof(sName));
	SetConVarString(FindConVar("hostname"), sName);
	delete hNameFile;
}
