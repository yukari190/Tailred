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
static const char CTag1[][] = {"{default}", "{green}", "{lightgreen}", "{red}", "{blue}", "{olive}"};
static const char CTag2[][] = {"{W}", "{O}", "{LG}", "{R}", "{B}", "{G}"};
static const char CTagCode[][] = {"\x01", "\x04", "\x03", "\x03", "\x03", "\x05"};
static const bool CTagReqSayText2[] = {false, false, true, true, true, false};

/* Left 4 Dead 2 profile */
static const int CProfile_TeamIndex[] = {NO_INDEX, NO_INDEX, SERVER_INDEX, 3, 2, NO_INDEX};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if (GetEngineVersion() != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}
	CreateNative("CPrintToChat", _native_CPrintToChat);
	CreateNative("CPrintToChatAll", _native_CPrintToChatAll);
	CreateNative("CPrintToChatEx", _native_CPrintToChatEx);
	CreateNative("CPrintToChatAllEx", _native_CPrintToChatAllEx);
	CreateNative("CReplyToCommand", _native_CReplyToCommand);
	CreateNative("CRemoveTags", _native_CRemoveTags);
	
	RegPluginLibrary("colors");
	return APLRes_Success;
}

public any _native_CPrintToChat(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char szMessage[MAX_MESSAGE_LENGTH];
	FormatNativeString(0, 2, 3, sizeof(szMessage), _, szMessage);
	CPrintToChat(client, "%s", szMessage);
}

public any _native_CPrintToChatAll(Handle plugin, int numParams)
{
	char szMessage[MAX_MESSAGE_LENGTH];
	char szBuffer[MAX_MESSAGE_LENGTH];
	FormatNativeString(0, 1, 2, sizeof(szMessage), _, szMessage);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, MAX_MESSAGE_LENGTH, szMessage, 2);
			CPrintToChat(i, "%s", szBuffer);
		}
	}
}

public any _native_CPrintToChatEx(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int author = GetNativeCell(2);
	char szMessage[MAX_MESSAGE_LENGTH];
	FormatNativeString(0, 3, 4, sizeof(szMessage), _, szMessage);
	CPrintToChatEx(client, author, "%s", szMessage);
}

public any _native_CPrintToChatAllEx(Handle plugin, int numParams)
{
	int author = GetNativeCell(1);
	char szMessage[MAX_MESSAGE_LENGTH];
	FormatNativeString(0, 2, 3, sizeof(szMessage), _, szMessage);
	
	if (author < 0 || author > MaxClients)
		ThrowError("Invalid client index %d", author);
	
	if (!IsClientInGame(author))
		ThrowError("Client %d is not in game", author);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
			
			CPrintToChatEx(i, author, "%s", szBuffer);
		}
	}
}

public any _native_CReplyToCommand(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	char szMessage[MAX_MESSAGE_LENGTH];
	FormatNativeString(0, 2, 3, sizeof(szMessage), _, szMessage);
	char szCMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	VFormat(szCMessage, sizeof(szCMessage), szMessage, 3);
	
	if (client == 0)
	{
		CRemoveTags(szCMessage, sizeof(szCMessage));
		PrintToServer("%s", szCMessage);
	}
	else if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		CRemoveTags(szCMessage, sizeof(szCMessage));
		PrintToConsole(client, "%s", szCMessage);
	}
	else
	{
		CPrintToChat(client, "%s", szCMessage);
	}
}

public any _native_CRemoveTags(Handle plugin, int numParams)
{
	int maxlength = GetNativeCell(2);
	char[] szMessage = new char[maxlength];
	GetNativeString(1, szMessage, maxlength);
	CRemoveTags(szMessage, maxlength);
	SetNativeString(1, szMessage, maxlength);
}

void CPrintToChat(int client, const char[] szMessage, any ...)
{
	if (client < 1 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH], szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	
	Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 3);
	
	int index = CFormat(szCMessage, sizeof(szCMessage));
	
	if (index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, index, szCMessage);
}

void CPrintToChatEx(int client, int author, const char[] szMessage, any ...)
{
	if (client < 1 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	if (author < 0 || author > MaxClients)
		ThrowError("Invalid client index %d", author);
	
	char szBuffer[MAX_MESSAGE_LENGTH], szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	
	Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 4);
	
	int index = CFormat(szCMessage, sizeof(szCMessage), author);
	
	if (index == NO_INDEX)
		PrintToChat(client, "%s", szCMessage);
	else
		CSayText2(client, author, szCMessage);
}

int CFormat(char[] szMessage, int maxlength, int author = NO_INDEX)
{
	int iRandomPlayer = NO_INDEX;
	
	/* If author was specified replace {teamcolor} tag */
	if (author != NO_INDEX)
	{
		ReplaceString(szMessage, maxlength, "{teamcolor}", "\x03", false);
		iRandomPlayer = author;
	}
	else
		ReplaceString(szMessage, maxlength, "{teamcolor}", "", false);
	
	/* For other color tags we need a loop */
	for (int i = 0; i < MAX_COLORS; i++)
	{
		char CTag[24];
		if (StrContains(szMessage, CTag1[i], false) != -1)
		{
			strcopy(CTag, 24, CTag1[i]);
		}
		else if (StrContains(szMessage, CTag2[i], false) != -1)
		{
			strcopy(CTag, 24, CTag2[i]);
		}
		else
		{
			continue;
		}
		
		if (!CTagReqSayText2[i])
		{
			ReplaceString(szMessage, maxlength, CTag, CTagCode[i], false);
		}
		/* Tag needs saytext2 */
		else
		{
			/* If random player for tag wasn't specified replace tag and find player */
			if (iRandomPlayer == NO_INDEX)
			{
				/* Searching for valid client for tag */
				iRandomPlayer = CFindRandomPlayerByTeam(CProfile_TeamIndex[i]);
				
				/* If player not found replace tag with green color tag */
				if (iRandomPlayer == NO_PLAYER)
					ReplaceString(szMessage, maxlength, CTag, CTagCode[Color_Green], false);

				/* If player was found simply replace */
				else
					ReplaceString(szMessage, maxlength, CTag, CTagCode[i], false);
				
			}
			/* If found another team color tag throw error */
			else
			{
				//ReplaceString(szMessage, maxlength, CTag, "");
				ThrowError("Using two team colors in one message is not allowed");
			}
		}
	}
	
	return iRandomPlayer;
}

void CSayText2(int client, int author, const char[] szMessage)
{
	Handle hBuffer = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	
	if(GetFeatureStatus(FeatureType_Native, "GetUserMessageType") == FeatureStatus_Available && GetUserMessageType() == UM_Protobuf) 
	{
		PbSetInt(hBuffer, "ent_idx", author);
		PbSetBool(hBuffer, "chat", true);
		PbSetString(hBuffer, "msg_name", szMessage);
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
		PbAddString(hBuffer, "params", "");
	}
	else
	{
		BfWriteByte(hBuffer, author);
		BfWriteByte(hBuffer, true);
		BfWriteString(hBuffer, szMessage);
	}
	
	EndMessage();
}

int CFindRandomPlayerByTeam(int color_team)
{
	if (color_team == SERVER_INDEX)
		return 0;
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}	
	}

	return NO_PLAYER;
}

void CRemoveTags(char[] szMessage, int maxlength)
{
	for (int i = 0; i < MAX_COLORS; i++)
	{
		ReplaceString(szMessage, maxlength, CTag1[i], "", false);
		ReplaceString(szMessage, maxlength, CTag2[i], "", false);
	}
	ReplaceString(szMessage, maxlength, "{teamcolor}", "", false);
}
