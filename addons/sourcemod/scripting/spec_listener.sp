#include <sourcemod>
#include <sdktools>

#define VOICE_NORMAL	0	/**< Allow the client to listen and speak normally. */
#define VOICE_MUTED		1	/**< Mutes the client from speaking to everyone. */
#define VOICE_SPEAKALL	2	/**< Allow the client to speak to everyone. */
#define VOICE_LISTENALL	4	/**< Allow the client to listen to everyone. */
#define VOICE_TEAM		8	/**< Allow the client to always speak to team, even when dead. */
#define VOICE_LISTENTEAM	16	/**< Allow the client to always hear teammates, including dead ones. */

#define TEAM_SPEC 1

ConVar hAllTalk;

public Plugin myinfo = 
{
	name = "SpecLister",
	author = "waertf & bear modded by bman",
	description = "Allows spectator listen others team voice for l4d",
	version = "2.1.3",
	url = "http://forums.alliedmods.net/showthread.php?t=95474"
};

public void OnPluginStart()
{
	HookEvent("player_team",Event_PlayerChangeTeam);
	RegConsoleCmd("hear", Panel_hear);
	
	//Fix for End of round all-talk.
	hAllTalk = FindConVar("sv_alltalk");
	hAllTalk.AddChangeHook(OnAlltalkChange);
}

public void OnAlltalkChange(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (StringToInt(newValue) == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i) && GetClientTeam(i) == TEAM_SPEC)
			{
				SetClientListeningFlags(i, VOICE_LISTENALL);
				//PrintToChat(i,"Re-Enable Listen Because of All-Talk");
			}
		}
	}
}

public void Event_PlayerChangeTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int userTeam = event.GetInt("team");
	if (client <= 0 || client > MaxClients || !IsClientInGame(client) || IsFakeClient(client))
		return;

	//PrintToChat(client,"\x02X02 \x03X03 \x04X04 \x05X05 ");\\ \x02:color:default \x03:lightgreen \x04:orange \x05:darkgreen
	
	if (userTeam == TEAM_SPEC)
	{
		SetClientListeningFlags(client, VOICE_LISTENALL);
		//PrintToChat(client,"\x04[Listen Mode]\x03Enabled" )
		
	}
	else
	{
		SetClientListeningFlags(client, VOICE_NORMAL);
		//PrintToChat(client,"\x04[listen]\x03disable" )
	}
}

public Action Panel_hear(int client, int args)
{
	if (GetClientTeam(client) != TEAM_SPEC)
		return Plugin_Handled;
	Handle panel = CreatePanel();
	SetPanelTitle(panel, "Enable listen mode ?");
	DrawPanelItem(panel, "Yes");
	DrawPanelItem(panel, "No");
 
	SendPanelToClient(panel, client, PanelHandler1, 20);
 
	CloseHandle(panel);
 
	return Plugin_Handled;

}

public int PanelHandler1(Handle menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		PrintToConsole(param1, "You selected item: %d", param2)
		if (param2 == 1)
		{
			SetClientListeningFlags(param1, VOICE_LISTENALL);
			PrintToChat(param1,"\x04[Listen Mode]\x03Enabled");
		}
		else
		{
			SetClientListeningFlags(param1, VOICE_NORMAL);
			PrintToChat(param1,"\x04[Listen Mode]\x03Disabled");
		}
		
	} else if (action == MenuAction_Cancel)
	{
		PrintToServer("Client %d's menu was cancelled.  Reason: %d", param1, param2);
	}
}
