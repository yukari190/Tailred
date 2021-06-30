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
}
#endif
