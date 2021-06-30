#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>

#define MAX_MESSAGE_LENGTH 250
#define MAX_COLORS 6

#define SERVER_INDEX 0
#define NO_INDEX -1
#define NO_PLAYER -2

public Plugin myinfo =
{
	name = "colors",
	description = "Colored Chat Functions",
	author = "exvel",
	version = "1.0.5",
	url = ""
};

enum
{
 	Color_Default = 0,
	Color_Green,
	Color_Lightgreen,
	Color_Red,
	Color_Blue,
	Color_Olive
}

/* Colors' properties */
static char CTag[][] = {"{W}", "{O}", "{LG}", "{R}", "{B}", "{G}"};
static char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static bool CTagReqSayText2[] = {false, false, true, true, true, false};

/* Left 4 Dead 2 profile */
static bool CProfile_Colors[] = {true, true, true, true, true, true};
static int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, 3, 2, NO_INDEX};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("CPrintToChat", _native_CPrintToChat);
	CreateNative("CPrintToChatAll", _native_CPrintToChatAll);
	
	RegPluginLibrary("colors");
	return APLRes_Success;
}

public int _native_CPrintToChat(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char szMessage[250];
	FormatNativeString(0, 2, 3, sizeof(szMessage), _, szMessage);
	CPrintToChat(client, "%s", szMessage);
}

public int _native_CPrintToChatAll(Handle plugin, int numParams)
{
	char szMessage[250];
	char szBuffer[250];
	FormatNativeString(0, 1, 2, sizeof(szMessage), _, szMessage);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, 250, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

void CPrintToChat(int client, const char[] szMessage, any ...)
{
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(szBuffer, sizeof(szBuffer), "\x01[SM]%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 3);
	
	int index = NO_INDEX;
	ReplaceString(szCMessage, sizeof(szCMessage), "{teamcolor}", "");
	for (int i = 0; i < MAX_COLORS; i++)
	{
		if (StrContains(szCMessage, CTag[i]) == -1) continue;
		else if (!CProfile_Colors[i])
		{
			ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[Color_Green]);
		}
		else if (!CTagReqSayText2[i])
		{
			ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[i]);
		}
		else
		{
			if (index == NO_INDEX)
			{
				if (CProfile_TeamIndex[i] == SERVER_INDEX)
				{
					index = 0;
				}
				else
				{
					for (int j = 1; j <= MaxClients; j++)
					{
						if (IsClientInGame(j) && GetClientTeam(j) == CProfile_TeamIndex[i])
						{
							index = j;
							break;
						}
						index = NO_PLAYER;
					}	
				}
				
				if (index == NO_PLAYER)
				{
					ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[Color_Green]);
				}
				else
				{
					ReplaceString(szCMessage, sizeof(szCMessage), CTag[i], CTagCode[i]);
				}
			}
			else
			{
				ThrowError("Using two team colors in one message is not allowed");
			}
			
		}
	}
	
	if (index == NO_INDEX)
	{
		PrintToChat(client, "%s", szCMessage);
	}
	else
	{
		Handle hBuffer = StartMessageOne("SayText2", client);
		BfWriteByte(hBuffer, index);
		BfWriteByte(hBuffer, true);
		BfWriteString(hBuffer, szCMessage);
		EndMessage();
	}
}
