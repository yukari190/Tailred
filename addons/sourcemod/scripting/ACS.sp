#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <left4dhooks>
#include <colors>

#define PLUGIN_VERSION	"v1.2.2b"

#define TRANSLATION_ACS "ACS.phrases"

#define NUMBER_OF_CAMPAIGNS			14		/* CHANGE TO MATCH THE TOTAL NUMBER OF CAMPAIGNS */
#define NUMBER_OF_SCAVENGE_MAPS		13		/* CHANGE TO MATCH THE TOTAL NUMBER OF SCAVENGE MAPS */

#define WAIT_TIME_BEFORE_SWITCH_COOP			7.0
#define WAIT_TIME_BEFORE_SWITCH_VERSUS			9.0
#define WAIT_TIME_BEFORE_SWITCH_SCAVENGE		11.0

public Plugin myinfo = 
{
	name = "Automatic Campaign Switcher (ACS)",
	author = "Chris Pringle, Yukari190",
	description = "Automatically switches to the next campaign when the previous campaign is over",
	version = PLUGIN_VERSION,
	url = "http://forums.alliedmods.net/showthread.php?t=156392"
};

int
	g_iRoundEndCounter,				//Round end event counter for versus
	g_iCoopFinaleFailureCount;		//Number of times the Survivors have lost the current finale
bool
	g_bFinaleWon;				//Indicates whether a finale has be beaten or not

char
	g_strCampaignFirstMap[NUMBER_OF_CAMPAIGNS][32],		//Array of maps to switch to
	g_strCampaignLastMap[NUMBER_OF_CAMPAIGNS][32],		//Array of maps to switch from
	g_strCampaignCurMap[NUMBER_OF_CAMPAIGNS][8],
	g_strCampaignName[NUMBER_OF_CAMPAIGNS][32],			//Array of names of the campaign
	g_strScavengeMap[NUMBER_OF_SCAVENGE_MAPS][32],		//Array of scavenge maps
	g_strScavengeMapName[NUMBER_OF_SCAVENGE_MAPS][32];	//Name of scaveenge maps

ConVar
	g_hCVar_MaxFinaleFailures = null;

public void OnPluginStart()
{
	LoadTranslation();
	SetupMapStrings();
	
	CreateConVar("acs_version", PLUGIN_VERSION, "Version of Automatic Campaign Switcher (ACS) on this server", FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCVar_MaxFinaleFailures = CreateConVar("acs_max_coop_finale_failures", "0", "在切换到下一个战役之前, 幸存者在 Coop 中失败的次数  [0 = INFINITE FAILURES]", FCVAR_NONE, true, 0.0, false);
	
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);
	HookEvent("finale_win", Event_FinaleWin, EventHookMode_PostNoCopy);
	HookEvent("scavenge_match_finished", Event_ScavengeMapFinished, EventHookMode_PostNoCopy);
	
	//RegConsoleCmd("sm_acsmapname", Command_AcsMapName);
	//AutoExecConfig(true, "ACS");
}

/*public Action Command_AcsMapName(int client, int args)
{
	if (!client) return Plugin_Handled;
	char buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	int iMapIndex = StringToInt(buffer);
	CPrintToChat(client, "%t%s", "ChangeCampaign", g_strCampaignName[iMapIndex]);
	return Plugin_Handled;
}*/

public void OnMapStart()
{
	g_iRoundEndCounter = 0;			//Reset the round end counter on every map start
	g_iCoopFinaleFailureCount = 0;	//Reset the amount of Survivor failures
	g_bFinaleWon = false;			//Reset the finale won variable
}

public void OnClientDisconnect(int client)
{
    if (!IsFakeClient(client))
		CreateTimer(15.0, Disconnect_Timer);
}

public Action Disconnect_Timer(Handle timer)
{
	if (!IsHumansOnServer())
	{
		CheckMapForCurrent();
	}
}

void CheckMapForCurrent()
{
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game
	
	float fTime = 1.0;
	
	for (int iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
	{
		if (StrContains(strCurrentMap, g_strCampaignCurMap[iMapIndex], false) != -1)
		{
			if (IsMapValid(g_strCampaignFirstMap[iMapIndex]) == true)
			{
				CreateTimer(fTime, Timer_ChangeCampaign, iMapIndex);
			}
			else
			{
				LogError("Error: %s is an invalid map name, unable to switch map.", g_strCampaignFirstMap[iMapIndex]);
				
				CreateTimer(fTime, Timer_ChangeCampaign, 0);
			}
			return;
		}
	}
	
	CreateTimer(fTime, Timer_ChangeCampaign, 0);
}

public void Event_RoundEnd(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if (L4D_IsVersusMode() && OnFinaleOrScavengeMap() == true)
	{
		g_iRoundEndCounter++;
		
		if (/*g_iRoundEndCounter >= 4*/ InSecondHalfOfRound())	//This event must be fired on the fourth time Round End occurs.
			CheckMapForChange();	//This is because it fires twice during each round end for
									//some strange reason, and versus has two rounds in it.
	}
	//If in Coop and on a finale, check to see if the surviors have lost the max amount of times
	else if (L4D_IsCoopMode() && OnFinaleOrScavengeMap() == true &&
			g_hCVar_MaxFinaleFailures.IntValue > 0 && g_bFinaleWon == false &&
			++g_iCoopFinaleFailureCount >= g_hCVar_MaxFinaleFailures.IntValue)
	{
		CheckMapForChange();
	}
}

public void Event_FinaleWin(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	g_bFinaleWon = true;	//This is used so that the finale does not switch twice if this event
							//happens to land on a max failure count as well as this
	
	//Change to the next campaign
	if(L4D_IsCoopMode())
		CheckMapForChange();
}

public void Event_ScavengeMapFinished(Event hEvent, const char[] strName, bool bDontBroadcast)
{
	if(L4D2_IsScavengeMode())
		ChangeScavengeMap();
}


void CheckMapForChange()
{
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game
	
	float fTime = WAIT_TIME_BEFORE_SWITCH_COOP;
	
	if (L4D_IsVersusMode())
		fTime = WAIT_TIME_BEFORE_SWITCH_VERSUS;
	else if (L4D_IsCoopMode())
		fTime = WAIT_TIME_BEFORE_SWITCH_COOP;
	
	for (int iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
	{
		if (strcmp(strCurrentMap, g_strCampaignLastMap[iMapIndex]) == 0)
		{
			if (iMapIndex == NUMBER_OF_CAMPAIGNS - 1)	//Check to see if its the end of the array
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0
				
			if (IsMapValid(g_strCampaignFirstMap[iMapIndex + 1]) == true)
			{
				CPrintToChatAll("%t%s", "ChangeCampaign", g_strCampaignName[iMapIndex + 1]);
				
				CreateTimer(fTime, Timer_ChangeCampaign, iMapIndex + 1);
			}
			else
			{
				LogError("Error: %s is an invalid map name, unable to switch map.", g_strCampaignFirstMap[iMapIndex + 1]);
				
				CreateTimer(fTime, Timer_ChangeCampaign, 0);
			}
			return;
		}
	}
	
	CreateTimer(fTime, Timer_ChangeCampaign, 0);
}

void ChangeScavengeMap()
{
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap, 32);					//Get the current map from the game
	
	for (int iMapIndex = 0; iMapIndex < NUMBER_OF_SCAVENGE_MAPS; iMapIndex++)
	{
		if (strcmp(strCurrentMap, g_strScavengeMap[iMapIndex]) == 0)
		{
			if (iMapIndex == NUMBER_OF_SCAVENGE_MAPS - 1)//Check to see if its the end of the array
				iMapIndex = -1;							//If so, start the array over by setting to -1 + 1 = 0 
			
			if (IsMapValid(g_strScavengeMap[iMapIndex + 1]) == true)
			{
				CPrintToChatAll("%t%s", "ChangeScavenge", g_strScavengeMapName[iMapIndex + 1]);
				
				CreateTimer(WAIT_TIME_BEFORE_SWITCH_SCAVENGE, Timer_ChangeScavengeMap, iMapIndex + 1);
			}
			else
				LogError("Error: %s is an invalid map name, unable to switch map.", g_strScavengeMap[iMapIndex + 1]);
			
			return;
		}
	}
}

public Action Timer_ChangeCampaign(Handle timer, any iCampaignIndex)
{
	ForceChangeLevel(g_strCampaignFirstMap[iCampaignIndex], "");	//Change the campaign
	
	return Plugin_Stop;
}

public Action Timer_ChangeScavengeMap(Handle timer, any iMapIndex)
{
	ForceChangeLevel(g_strScavengeMap[iMapIndex], "");			//Change the map
	
	return Plugin_Stop;
}


void LoadTranslation()
{
	char sPath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof sPath, "translations/" ... TRANSLATION_ACS ... ".txt");
	if (!FileExists(sPath))
	{
		SetFailState("Missing translation file \"" ... TRANSLATION_ACS ... ".txt\"");
	}
	LoadTranslations(TRANSLATION_ACS);
}

void SetupMapStrings()
{
	//First Maps of the Campaign
	Format(g_strCampaignFirstMap[0], 32, "c1m1_hotel");
	Format(g_strCampaignFirstMap[1], 32, "c6m1_riverbank");
	Format(g_strCampaignFirstMap[2], 32, "c2m1_highway");
	Format(g_strCampaignFirstMap[3], 32, "c3m1_plankcountry");
	Format(g_strCampaignFirstMap[4], 32, "c4m1_milltown_a");
	Format(g_strCampaignFirstMap[5], 32, "c5m1_waterfront");
	Format(g_strCampaignFirstMap[6], 32, "c13m1_alpinecreek");
	Format(g_strCampaignFirstMap[7], 32, "c8m1_apartment");
	Format(g_strCampaignFirstMap[8], 32, "c9m1_alleys");
	Format(g_strCampaignFirstMap[9], 32, "c10m1_caves");
	Format(g_strCampaignFirstMap[10], 32, "c11m1_greenhouse");
	Format(g_strCampaignFirstMap[11], 32, "c12m1_hilltop");
	Format(g_strCampaignFirstMap[12], 32, "c7m1_docks");
	Format(g_strCampaignFirstMap[13], 32, "c14m1_junkyard");
	
	//Last Maps of the Campaign
	Format(g_strCampaignLastMap[0], 32, "c1m4_atrium");
	Format(g_strCampaignLastMap[1], 32, "c6m3_port");
	Format(g_strCampaignLastMap[2], 32, "c2m5_concert");
	Format(g_strCampaignLastMap[3], 32, "c3m4_plantation");
	Format(g_strCampaignLastMap[4], 32, "c4m5_milltown_escape");
	Format(g_strCampaignLastMap[5], 32, "c5m5_bridge");
	Format(g_strCampaignLastMap[6], 32, "c13m4_cutthroatcreek");
	Format(g_strCampaignLastMap[7], 32, "c8m5_rooftop");
	Format(g_strCampaignLastMap[8], 32, "c9m2_lots");
	Format(g_strCampaignLastMap[9], 32, "c10m5_houseboat");
	Format(g_strCampaignLastMap[10], 32, "c11m5_runway");
	Format(g_strCampaignLastMap[11], 32, "c12m5_cornfield");
	Format(g_strCampaignLastMap[12], 32, "c7m3_port");
	Format(g_strCampaignLastMap[13], 32, "c14m2_lighthouse");
	
	//Current Maps of the Campaign
	Format(g_strCampaignCurMap[0], 8, "c1m");
	Format(g_strCampaignCurMap[1], 8, "c6m");
	Format(g_strCampaignCurMap[2], 8, "c2m");
	Format(g_strCampaignCurMap[3], 8, "c3m");
	Format(g_strCampaignCurMap[4], 8, "c4m");
	Format(g_strCampaignCurMap[5], 8, "c5m");
	Format(g_strCampaignCurMap[6], 8, "c13m");
	Format(g_strCampaignCurMap[7], 8, "c8m");
	Format(g_strCampaignCurMap[8], 8, "c9m");
	Format(g_strCampaignCurMap[9], 8, "c10m");
	Format(g_strCampaignCurMap[10], 8, "c11m");
	Format(g_strCampaignCurMap[11], 8, "c12m");
	Format(g_strCampaignCurMap[12], 8, "c7m");
	Format(g_strCampaignCurMap[13], 8, "c14m");
	
	//Campaign Names
	Format(g_strCampaignName[0], 32, "%t", "CampaignName_C1");
	Format(g_strCampaignName[1], 32, "%t", "CampaignName_C6");
	Format(g_strCampaignName[2], 32, "%t", "CampaignName_C2");
	Format(g_strCampaignName[3], 32, "%t", "CampaignName_C3");
	Format(g_strCampaignName[4], 32, "%t", "CampaignName_C4");
	Format(g_strCampaignName[5], 32, "%t", "CampaignName_C5");
	Format(g_strCampaignName[6], 32, "%t", "CampaignName_C13");
	Format(g_strCampaignName[7], 32, "%t", "CampaignName_C8");
	Format(g_strCampaignName[8], 32, "%t", "CampaignName_C9");
	Format(g_strCampaignName[9], 32, "%t", "CampaignName_C10");
	Format(g_strCampaignName[10], 32, "%t", "CampaignName_C11");
	Format(g_strCampaignName[11], 32, "%t", "CampaignName_C12");
	Format(g_strCampaignName[12], 32, "%t", "CampaignName_C7");
	Format(g_strCampaignName[13], 32, "%t", "CampaignName_C14");
	
	//Scavenge Maps
	Format(g_strScavengeMap[0], 32, "c8m1_apartment");
	Format(g_strScavengeMap[1], 32, "c8m5_rooftop");
	Format(g_strScavengeMap[2], 32, "c1m4_atrium");
	Format(g_strScavengeMap[3], 32, "c7m1_docks");
	Format(g_strScavengeMap[4], 32, "c7m2_barge");
	Format(g_strScavengeMap[5], 32, "c6m1_riverbank");
	Format(g_strScavengeMap[6], 32, "c6m2_bedlam");
	Format(g_strScavengeMap[7], 32, "c6m3_port");
	Format(g_strScavengeMap[8], 32, "c2m1_highway");
	Format(g_strScavengeMap[9], 32, "c3m1_plankcountry");
	Format(g_strScavengeMap[10], 32, "c4m1_milltown_a");
	Format(g_strScavengeMap[11], 32, "c4m2_sugarmill_a");
	Format(g_strScavengeMap[12], 32, "c5m2_park");
	
	//Scavenge Map Names
	Format(g_strScavengeMapName[0], 32, "%t", "Scavenge_Apartment");
	Format(g_strScavengeMapName[1], 32, "%t", "Scavenge_Rooftop");
	Format(g_strScavengeMapName[2], 32, "%t", "Scavenge_Atrium");
	Format(g_strScavengeMapName[3], 32, "%t", "Scavenge_Docks");
	Format(g_strScavengeMapName[4], 32, "%t", "Scavenge_Barge");
	Format(g_strScavengeMapName[5], 32, "%t", "Scavenge_Riverbank");
	Format(g_strScavengeMapName[6], 32, "%t", "Scavenge_Bedlam");
	Format(g_strScavengeMapName[7], 32, "%t", "Scavenge_Port");
	Format(g_strScavengeMapName[8], 32, "%t", "Scavenge_Highway");
	Format(g_strScavengeMapName[9], 32, "%t", "Scavenge_Plankcountry");
	Format(g_strScavengeMapName[10], 32, "%t", "Scavenge_Milltown");
	Format(g_strScavengeMapName[11], 32, "%t", "Scavenge_Sugarmill");
	Format(g_strScavengeMapName[12], 32, "%t", "Scavenge_Park");
}

bool OnFinaleOrScavengeMap()
{
	if (L4D2_IsScavengeMode())
		return true;
	
	if (L4D_IsSurvivalMode())
		return false;
	
	char strCurrentMap[32];
	GetCurrentMap(strCurrentMap,32);			//Get the current map from the game
	
	for (int iMapIndex = 0; iMapIndex < NUMBER_OF_CAMPAIGNS; iMapIndex++)
		if(strcmp(strCurrentMap, g_strCampaignLastMap[iMapIndex]) == 0)
			return true;
	
	if (L4D_IsMissionFinalMap())
		return true;
	
	return false;
}

bool InSecondHalfOfRound()
{
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}
