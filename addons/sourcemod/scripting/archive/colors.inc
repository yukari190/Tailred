#if defined _colors_included
 #endinput
#endif
#define _colors_included

// 白色{W} 橙色{O} 浅绿{LG} 红色{R} 蓝色{B} 橄榄绿{G}

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
native void CPrintToChat(int client, const char[] szMessage, any ...);

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules)
 * @return			  No return
 */
native void CPrintToChatAll(const char[] szMessage, any ...);

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
native void CPrintToChatEx(int client, int author, const char[] szMessage, any ...);

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
native void CPrintToChatAllEx(int author, const char[] szMessage, any ...);

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
native void CReplyToCommand(int client, const char[] szMessage, any ...);

/**
 * Removes color tags from the string.
 *
 * @param szMessage   String.
 * @return			  No return
 */
native void CRemoveTags(char[] szMessage, int maxlength);

public SharedPlugin __pl_colors = 
{
	name = "colors",
	file = "colors.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_colors_SetNTVOptional()
{
	MarkNativeAsOptional("CPrintToChat");
	MarkNativeAsOptional("CPrintToChatAll");
	MarkNativeAsOptional("CPrintToChatEx");
	MarkNativeAsOptional("CPrintToChatAllEx");
	MarkNativeAsOptional("CReplyToCommand");
	MarkNativeAsOptional("CRemoveTags");
}
#endif
