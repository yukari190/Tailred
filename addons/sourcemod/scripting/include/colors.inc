/**************************************************************************
 *                                                                        *
 *                       Colored Chat Functions                           *
 *                   Author: exvel                                        *
 *                           Version: 1.0.5                              *
 *                                                                        *
 **************************************************************************/

#if defined _colors_included
 #endinput
#endif
#define _colors_included

#define MAX_MESSAGE_LENGTH 250
#define MAX_COLORS 6

#define SERVER_INDEX 0
#define NO_INDEX -1
#define NO_PLAYER -2

enum
{
 	Color_Default = 0,
	Color_Green,
	Color_Lightgreen,
	Color_Red,
	Color_Blue,
	Color_Olive
};

/* Colors' properties */
// 											白色 			橙色 		浅绿 			红色 		蓝色 		橄榄绿
stock static const char CTag1[][] = 			{"{default}", 	"{green}", 	"{lightgreen}", 	"{red}", 	"{blue}", 	"{olive}"};
stock static const char CTag2[][] = 			{"{W}", 			"{O}", 		"{LG}", 			"{R}", 		"{B}", 		"{G}"};
stock static const char CTagCode[][] = 			{"\x01", 		"\x04", 		"\x03", 			"\x03", 		"\x03", 		"\x05"};
stock static const bool CTagReqSayText2[] = 	{false, 			false, 		true, 			true, 		true, 		false};

/* Left 4 Dead 2 profile */
stock static const int CProfile_TeamIndex[] = 	{NO_INDEX, 		NO_INDEX, 	SERVER_INDEX, 	3, 			2, 			NO_INDEX};

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void CPrintToChat(int client, const char[] szMessage, any ...)
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

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules)
 * @return			  No return
 */
stock void CPrintToChatAll(const char[] szMessage, any ...)
{
	char szBuffer[MAX_MESSAGE_LENGTH];
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

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags and teamcolor tag.
 *
 * @param client	  Client index.
 * @param author	  Author index whose color will be used for teamcolor tag.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the client or author are not connected an error will be thrown.
 */
stock void CPrintToChatEx(int client, int author, const char[] szMessage, any ...)
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

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags and teamcolor tag.
 *
 * @param author	  Author index whos color will be used for teamcolor tag.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the author is not connected an error will be thrown.
 */
stock void CPrintToChatAllEx(int author, const char[] szMessage, any ...)
{
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

/**
 * Reples to a message in a command. A client index of 0 will use PrintToServer().
 * If the command was from the console, PrintToConsole() is used. If the command was from chat, CPrintToChat() is used.
 * Supports color tags.
 *
 * @param client	  Client index, or 0 for server.
 * @param szMessage   Formatting rules.
 * @param ...         Variable number of format parameters.
 * @return			  No return
 * 
 * On error/Errors:   If the client is not connected or invalid.
 */
stock void CReplyToCommand(int client, const char[] szMessage, any ...)
{
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

/**
 * Removes color tags from the string.
 *
 * @param szMessage   String.
 * @return			  No return
 */
stock void CRemoveTags(char[] szMessage, int maxlength)
{
	for (int i = 0; i < MAX_COLORS; i++)
	{
		ReplaceString(szMessage, maxlength, CTag1[i], "", false);
		ReplaceString(szMessage, maxlength, CTag2[i], "", false);
	}
	ReplaceString(szMessage, maxlength, "{teamcolor}", "", false);
}

stock int CFormat(char[] szMessage, int maxlength, int author = NO_INDEX)
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

stock void CSayText2(int client, int author, const char[] szMessage)
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

stock int CFindRandomPlayerByTeam(int color_team)
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
