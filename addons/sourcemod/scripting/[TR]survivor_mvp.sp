#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <[LIB]left4dhooks>
#include <[LIB]l4d2library>
#undef REQUIRE_PLUGIN
#include <[LIB]readyup>
#define REQUIRE_PLUGIN

public Plugin myinfo =
{
    name = "Survivor MVP notification",
    author = "Tabun, Griffin, Blade",
    description = "Shows MVP for survivor team at end of round",
    version = "1.0",
    url = "nope"
};

ConVar g_hCvarTankHealth;
ConVar g_hCvarSurvivorLimit;

int iGotKills[MAXPLAYERS + 1];
int iGotCommon[MAXPLAYERS + 1];
int iDidDamage[MAXPLAYERS + 1];
int iDidDamageAll[MAXPLAYERS + 1];
int iDidDamageTank[MAXPLAYERS + 1];
int iDidDamageWitch[MAXPLAYERS + 1];
int iDidFF[MAXPLAYERS + 1];
int iTotalKills;
int iTotalCommon;
int iTotalDamage;
int iTotalDamageAll;
int iTotalFF;
int g_iLastTankHealth;
int g_iSurvivorLimit = 4;
int g_iDamage[MAXPLAYERS + 1];

float g_fMaxTankHealth;
float fMaxTankHealth;

bool g_bAnnounceTankDamage;

char sClientName[MAXPLAYERS + 1][64];
char sConsoleBuf[1024];
char sTmpString[MAX_NAME_LENGTH];

public void OnPluginStart()
{
	g_hCvarSurvivorLimit = FindConVar("survivor_limit");
	g_hCvarTankHealth = FindConVar("z_tank_health");
	
	g_hCvarSurvivorLimit.AddChangeHook(ConVarChange);
	g_hCvarTankHealth.AddChangeHook(ConVarChange);
	
	ConVarChange(view_as<ConVar>(INVALID_HANDLE), "", "");
	
    HookEvent("player_death", PlayerDeath_Event, EventHookMode_Post);
    HookEvent("infected_death", InfectedDeath_Event, EventHookMode_Post);
	
    RegConsoleCmd("sm_mvp", SurvivorMVP_Cmd, "Prints the current MVP for the survivor team");
    RegConsoleCmd("sm_mvpme", ShowMVPStats_Cmd, "Prints the client's own MVP-related stats");
}

public int ConVarChange(Handle convar, const char[] oldValue, const char[] newValue) 
{
	g_iSurvivorLimit = g_hCvarSurvivorLimit.IntValue;
	g_fMaxTankHealth = g_hCvarTankHealth.FloatValue;
}

public void OnClientPutInServer(int client)
{
    char tmpBuffer[64];
    GetClientName(client, tmpBuffer, sizeof(tmpBuffer));
    
    if (strcmp(tmpBuffer, sClientName[client], true) != 0)
    {
        iGotKills[client] = 0;
        iGotCommon[client] = 0;
        iDidDamage[client] = 0;
        iDidDamageAll[client] = 0;
        iDidDamageWitch[client] = 0;
        iDidDamageTank[client] = 0;
        iDidFF[client] = 0;
        
        strcopy(sClientName[client], 64, tmpBuffer);
    }
}

public void OnMapStart()
{
	fMaxTankHealth = (L4D2_IsVersus() ? g_fMaxTankHealth * 1.5 : g_fMaxTankHealth);
    if (fMaxTankHealth <= 0.0) fMaxTankHealth = 1.0;
}

public void L4D2_OnRealRoundStart()
{
	ClearTankDamage();
    for (int i = 1; i <= MAXPLAYERS; i++)
    {
        iGotKills[i] = 0;
        iGotCommon[i] = 0;
        iDidDamage[i] = 0;
        iDidDamageAll[i] = 0;
        iDidDamageWitch[i] = 0;
        iDidDamageTank[i] = 0;
        iDidFF[i] = 0;
    }
    iTotalKills = 0;
    iTotalCommon = 0;
    iTotalDamage = 0;
    iTotalDamageAll = 0;
    iTotalFF = 0;
}

public void L4D2_OnRealRoundEnd()
{
	if (g_bAnnounceTankDamage) PrintRemainingHealth();
	ClearTankDamage();
	CreateTimer(L4D2_IsScavenge() ? 2.0 : 4.0, delayedMVPPrint);
}

public void L4D2_OnPlayerHurt(int victim, int attacker, int health, char[] weapon, int damage, int dmgtype)
{
    if (!L4D2_IsValidClient(attacker) || !L4D2_IsSurvivor(attacker)) return;
    L4D2_Team Team = view_as<L4D2_Team>(GetClientTeam(victim));
	L4D2_Infected zombieClass = L4D2_GetInfectedClass(victim);
	if (Team == L4D2Team_Infected)
	{
		if (zombieClass >= L4D2Infected_Smoker && zombieClass < L4D2Infected_Witch)
		{
			iDidDamage[attacker] += damage;
			iDidDamageAll[attacker] += damage;
			iTotalDamage += damage;
			iTotalDamageAll += damage;
		}
		else if (zombieClass == L4D2Infected_Tank && !L4D2_IsPlayerIncap(victim))
		{
			g_iDamage[attacker] += damage;
			g_iLastTankHealth = health;
		}
	}
	else if (Team == L4D2Team_Survivor)
	{
		if (!IsInReady())
		{
			iDidFF[attacker] += damage;
			iTotalFF += damage;
		}
	}
}

public void L4D2_OnTankDeath(int tankClient, int attacker)
{
    if (L4D2_IsValidClient(attacker)) g_iDamage[attacker] += g_iLastTankHealth;
	if (g_bAnnounceTankDamage)
	{
		L4D2_CPrintToChatAll("对 {B}Tank{W} ({G}%N{W}) 造成的{B}伤害", tankClient);
		PrintTankDamage();
	}
	ClearTankDamage();
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	g_bAnnounceTankDamage = true;
	g_iLastTankHealth = GetClientHealth(tankClient);
}


public Action PlayerDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (L4D2_IsValidClient(victim) && L4D2_IsValidClient(attacker) && L4D2_IsSurvivor(attacker))
    {
        L4D2_Infected zombieClass = L4D2_GetInfectedClass(victim);
        
        if (zombieClass >= L4D2Infected_Smoker && zombieClass < L4D2Infected_Witch)
        {
            iGotKills[attacker]++;
            iTotalKills++;
        }
    }
}

public Action InfectedDeath_Event(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    
    if (L4D2_IsValidClient(attacker) && L4D2_IsSurvivor(attacker))
    {
        iGotCommon[attacker]++;
        iTotalCommon++;
    }
}

public Action SurvivorMVP_Cmd(int client, int args)
{
    char printBuffer[512];
    
    printBuffer = GetMVPString();
    PrintConsoleReport(client);
    
    if (L4D2_IsValidClient(client)) L4D2_CPrintToChat(client, "{W}%s", printBuffer);
    else PrintToServer("%s", printBuffer);
}

public Action ShowMVPStats_Cmd(int client, int args)
{
    if (client && IsClientConnected(client))
    {
        char printBuffer[512];
        char tmpBuffer[256];
        
        printBuffer = "";
        
        if (iTotalDamageAll > 0)
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} (你) 特感: ({G}%d {W}伤害量 [{O}%.0f%%{W}],{G} %d {W}杀 [{O}%.0f%%{W}])\n", iDidDamageAll[client], (float(iDidDamageAll[client]) / float(iTotalDamageAll)) * 100, iGotKills[client], (float(iGotKills[client]) / float(iTotalKills)) * 100);
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else
        {
            StrCat(printBuffer, sizeof(printBuffer), "{W}{B}[{O}全场最佳{B}]{G} (你) 特感: (没什么)\n");
        }
        
            if (iTotalCommon > 0)
            {
                Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} (你) 一般感染者: ({G}%d {W}一般 [{O}%.0f%%{W}])\n", iGotCommon[client], (float(iGotCommon[client]) / float(iTotalCommon)) * 100);
                StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
            }
        
        L4D2_CPrintToChat(client, "%s", printBuffer);
        L4D2_CPrintToChat(client, "{B}[{O}全场最佳{B}]{G} (你) 队友伤害: ({G}%d {W}队友伤害 [{O}%.0f%%{W}])\n", iDidFF[client], (float(iDidFF[client]) / float(iTotalFF)) * 100);
    }
}

public Action delayedMVPPrint(Handle timer)
{
    char printBuffer[512];
    char tmpBuffer[512];
    printBuffer = GetMVPString();
    PrintToServer("%s", printBuffer);
    L4D2_CPrintToChatAll("{W}%s", printBuffer);
    PrintConsoleReport(0);
    
    if (iTotalDamageAll > 0)
    {
        int mvp_SI = findMVPSI();
        int mvp_SI_losers[3];
        mvp_SI_losers[0] = findMVPSI(mvp_SI);
        mvp_SI_losers[1] = findMVPSI(mvp_SI, mvp_SI_losers[0]);
        mvp_SI_losers[2] = findMVPSI(mvp_SI, mvp_SI_losers[0], mvp_SI_losers[1]);
        
        for (int i = 0; i <= 2; i++)
        {
            if (L4D2_IsValidClient(mvp_SI_losers[i])) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} 你的排名 | 特感: <#{G}%d{W}> ({G}%d {W}伤害量 [{O}%.0f%%{W}],{G} %d {W}杀 [{O}%.0f%%{W}])", (i + 2), iDidDamageAll[mvp_SI_losers[i]], (float(iDidDamageAll[mvp_SI_losers[i]]) / float(iTotalDamageAll)) * 100, iGotKills[mvp_SI_losers[i]], (float(iGotKills[mvp_SI_losers[i]]) / float(iTotalKills)) * 100);
                L4D2_CPrintToChat(mvp_SI_losers[i], "{W}%s", tmpBuffer);
            }
        }
    }
    
    if (iTotalCommon > 0)
    {
        int mvp_CI = findMVPCommon();
        int mvp_CI_losers[3];
        mvp_CI_losers[0] = findMVPCommon(mvp_CI);
        mvp_CI_losers[1] = findMVPCommon(mvp_CI, mvp_CI_losers[0]);
        mvp_CI_losers[2] = findMVPCommon(mvp_CI, mvp_CI_losers[0], mvp_CI_losers[1]);
        
        for (int i = 0; i <= 2; i++)
        {
            if (L4D2_IsValidClient(mvp_CI_losers[i])) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} 你的排名 | 一般感染者: <#{G}%d{W}> ({G}%d {W}杀 [{O}%.0f%%{W}])", (i + 2), iGotCommon[mvp_CI_losers[i]], (float(iGotCommon[mvp_CI_losers[i]]) / float(iTotalCommon)) * 100);
                L4D2_CPrintToChat(mvp_CI_losers[i], "{W}%s", tmpBuffer);
            }
        }
    }
    
    if (iTotalFF > 0)
    {
        int mvp_FF = findLVPFF();
        int mvp_FF_losers[3];
        mvp_FF_losers[0] = findLVPFF(mvp_FF);
        mvp_FF_losers[1] = findLVPFF(mvp_FF, mvp_FF_losers[0]);
        mvp_FF_losers[2] = findLVPFF(mvp_FF, mvp_FF_losers[0], mvp_FF_losers[1]);
        
        for (int i = 0; i <= 2; i++)
        {
            if (L4D2_IsValidClient(mvp_FF_losers[i])) {
                    Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} 你的排名 | 队友伤害: <#{G}%d{W}> ({G}%d {W}伤害量 [{O}%.0f%%{W}])", (i + 2), iDidFF[mvp_FF_losers[i]], (float(iDidFF[mvp_FF_losers[i]]) / float(iTotalFF)) * 100);
                L4D2_CPrintToChat(mvp_FF_losers[i], "{W}%s", tmpBuffer);
            }
        }
    }
}

void PrintConsoleReport(int client)
{
    
    char buf[2048];
    Format(buf, sizeof(buf), "\n");
    Format(buf, sizeof(buf), "%s| 名字                 | 伤害     | 百分比  | 击杀特感 | 普通丧尸 | 百分比  | Tank   | Witch  | 友伤         |\n", buf);
    Format(buf, sizeof(buf), "%s|----------------------|----------|---------|----------|----------|---------|--------|--------|--------------|\n", buf);
    Format(buf, sizeof(buf), "%s%s", buf, sConsoleBuf);
    Format(buf, sizeof(buf), "%s|------------------------------------------------------------------------------------------------------------|", buf);
    
    if (!client)
	{
        PrintToConsoleAll("%s", buf);
    }
	else PrintToConsoleClient(client, "%s", buf);
}

char GetMVPString()
{
    char printBuffer[512];
    char tmpBuffer[256];
    
    char tmpName[64];
    char mvp_SI_name[64];
    char mvp_Common_name[64];
    char mvp_FF_name[64];
    
    printBuffer = "";
    int mvp_SI = 0;
    int mvp_Common = 0;
    int mvp_FF = 0;
	mvp_SI = findMVPSI();
	if (mvp_SI > 0)
	{
		if (IsClientConnected(mvp_SI))
		{
			GetClientName(mvp_SI, tmpName, sizeof(tmpName));
			if (IsFakeClient(mvp_SI))
			{
				StrCat(tmpName, 64, " {W}[BOT]");
			}
		}
		else strcopy(tmpName, 64, sClientName[mvp_SI]);
		mvp_SI_name = tmpName;
	}
	else mvp_SI_name = "(没有人)";

	mvp_Common = findMVPCommon();
	if (mvp_Common > 0)
	{
		if (IsClientConnected(mvp_Common))
		{
			GetClientName(mvp_Common, tmpName, sizeof(tmpName));
			if (IsFakeClient(mvp_Common))
			{
				StrCat(tmpName, 64, " {W}[BOT]");
			}
		}
		else strcopy(tmpName, 64, sClientName[mvp_Common]);
		mvp_Common_name = tmpName;
	}
	else mvp_Common_name = "(没有人)";

	mvp_FF = findLVPFF();
	if (mvp_FF > 0)
	{
		if (IsClientConnected(mvp_FF))
		{
			GetClientName(mvp_FF, tmpName, sizeof(tmpName));
			if (IsFakeClient(mvp_FF))
			{
				StrCat(tmpName, 64, " {W}[BOT]");
			}
		}
		else strcopy(tmpName, 64, sClientName[mvp_FF]);
		mvp_FF_name = tmpName;
	}
	else mvp_FF_name = "(没有人)";
    
    if (mvp_SI == 0 && mvp_Common == 0)
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} (行动还不够)\n");
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else
    {
        if (mvp_SI > 0)
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} 特感:{B} %s {W}({G}%d {W}伤害量[{O}%.0f%%{W}],{G} %d {W}杀 [{O}%.0f%%{W}])\n", mvp_SI_name, iDidDamageAll[mvp_SI], (float(iDidDamageAll[mvp_SI]) / float(iTotalDamageAll)) * 100, iGotKills[mvp_SI], (float(iGotKills[mvp_SI]) / float(iTotalKills)) * 100);
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
        else
        {
            StrCat(printBuffer, sizeof(printBuffer), "{B}[{O}全场最佳{B}]{G} 特感: (没有人)\n");
        }
        
        if (mvp_Common > 0)
        {
            Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{O}全场最佳{B}]{G} 一般感染者:{B} %s {W}({G}%d {W}一般 [{O}%.0f%%{W}])\n", mvp_Common_name, iGotCommon[mvp_Common], (float(iGotCommon[mvp_Common]) / float(iTotalCommon)) * 100);
            StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
        }
    }
    
    if (mvp_FF == 0)
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{G}全场最变异{B}]{O} 队友伤害: 没有误伤可言!\n");
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    else
    {
        Format(tmpBuffer, sizeof(tmpBuffer), "{B}[{G}全场最变异{B}]{O} 队友伤害:{B} %s {W}({G}%d {W}伤害量 [{O}%.0f%%{W}])\n", mvp_FF_name, iDidFF[mvp_FF], (float(iDidFF[mvp_FF]) / float(iTotalFF)) * 100);
        StrCat(printBuffer, sizeof(printBuffer), tmpBuffer);
    }
    
    sConsoleBuf = "";
    const int max_name_len = 20;
    char name[MAX_NAME_LENGTH];
    char sikills[15], sidamage[15], cikills[15];
    char siprc[15], ciprc[15];
    char tankdmg[15], witchdmg[15], ff[15];
    
    int teamCount = g_iSurvivorLimit;
    int i;
    int mpv_done[4];
    int mvp_losers[3];
    
    for (int j = 1; j <= teamCount; j++)
    {
        if (mvp_SI)
		{
            switch (j)
			{
                case 1: { i = mvp_SI; }
                case 2: { i = mvp_losers[j - 2] = findMVPSI(mvp_SI); }
                case 3: { i = mvp_losers[j - 2] = findMVPSI(mvp_SI, mvp_losers[0]); }
                case 4: { i = mvp_losers[j - 2] = findMVPSI(mvp_SI, mvp_losers[0], mvp_losers[1]); }
            }
            if (!i) { i = getSurvivor(mpv_done); }
        }
		else if (mvp_Common)
		{
            switch (j)
			{
                case 1: { i = mvp_Common; }
                case 2: { i = mvp_losers[j - 2] = findMVPCommon(mvp_Common); }
                case 3: { i = mvp_losers[j - 2] = findMVPCommon(mvp_Common, mvp_losers[0]); }
                case 4: { i = mvp_losers[j - 2] = findMVPCommon(mvp_Common, mvp_losers[0], mvp_losers[1]); }
            }
            if (!i) i = getSurvivor(mpv_done);
        } else i = getSurvivor(mpv_done);
        
        mpv_done[j - 1] = i;
        
        if (L4D2_IsValidClient(i) && IsClientConnected(i))
		{
            GetClientName(i, name, sizeof(name));
            if (IsFakeClient(i)) { StrCat(name, sizeof(name), " [BOT]"); }
        }
		else strcopy(name, sizeof(name), sClientName[i]);
        stripUnicode(name);
        name = sTmpString;
        name[max_name_len] = 0;
        
        Format(sidamage, sizeof(sidamage), "%8d", iDidDamageAll[i]);
        Format(siprc, sizeof(siprc), "%7.1f", (float(iDidDamageAll[i]) / float(iTotalDamageAll)) * 100 );
        Format(sikills, sizeof(sikills), "%8d", iGotKills[i]);
        Format(cikills, sizeof(cikills), "%8d", iGotCommon[i]);
        Format(ciprc, sizeof(ciprc), "%7.1f", (float(iGotCommon[i]) / float(iTotalCommon)) * 100 );
        Format(tankdmg, sizeof(tankdmg), "%6d", iDidDamageTank[i]);
        Format(witchdmg, sizeof(witchdmg), "%6d", iDidDamageWitch[i]);
        Format(ff, sizeof(ff), "%6d", iDidFF[i]);
        Format(sConsoleBuf, sizeof(sConsoleBuf),
            "%s| %20s | %8s | %7s | %8s | %8s | %7s | %6s | %6s | %6s       |\n",
            sConsoleBuf, name, sidamage, siprc, sikills, cikills, ciprc, tankdmg, witchdmg, ff
        );
            
    }
    
    return printBuffer;
}

int findMVPSI(int excludeMeA = 0, int excludeMeB = 0, int excludeMeC = 0)
{
    int maxIndex = 0;
    for(int i = 1; i < sizeof(iDidDamageAll); i++)
    {
        if(iDidDamageAll[i] > iDidDamageAll[maxIndex]  && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}

int findMVPCommon(int excludeMeA = 0, int excludeMeB = 0, int excludeMeC = 0)
{
    int maxIndex = 0;
    for(int i = 1; i < sizeof(iGotCommon); i++)
    {
        if(iGotCommon[i] > iGotCommon[maxIndex] && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}

int findLVPFF(int excludeMeA = 0, int excludeMeB = 0, int excludeMeC = 0)
{
    int maxIndex = 0;
    for(int i = 1; i < sizeof(iDidFF); i++)
    {
        if(iDidFF[i] > iDidFF[maxIndex]  && i != excludeMeA && i != excludeMeB && i != excludeMeC)
            maxIndex = i;
    }
    return maxIndex;
}

int getSurvivor(int exclude[4])
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && L4D2_IsSurvivor(i))
        {
			int tagged = false;
			for (int j = 0; j < 4; j++)
			{
				if (exclude[j] == i) { tagged = true; }
			}
			if (!tagged) return i;
		}
    }
    return 0;
}

void PrintToConsoleClient(int client, const char[] format, any ...)
{
    char buffer[2048];

    if(L4D2_IsValidClient(client))
    {
        VFormat(buffer, sizeof(buffer), format, 3);
        PrintToConsole(client, buffer);
    }
}


void stripUnicode(char testString[MAX_NAME_LENGTH])
{
    const int maxlength = MAX_NAME_LENGTH;
    sTmpString = testString;
    
    int uni=0;
    int currentChar;
    int tmpCharLength = 0;
    
    for (int i=0; i < maxlength - 3 && sTmpString[i] != 0; i++)
    {
        if ((sTmpString[i]&0x80) == 0)
        {
            currentChar=sTmpString[i]; tmpCharLength = 0;
        } else if (((sTmpString[i]&0xE0) == 0xC0) && ((sTmpString[i+1]&0xC0) == 0x80)) // two byte character?
        {
            currentChar=(sTmpString[i++] & 0x1f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f); 
            tmpCharLength = 1;
        } else if (((sTmpString[i]&0xF0) == 0xE0) && ((sTmpString[i+1]&0xC0) == 0x80) && ((sTmpString[i+2]&0xC0) == 0x80)) // three byte character?
        {
            currentChar=(sTmpString[i++] & 0x0f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f);
            tmpCharLength = 2;
        } else if (((sTmpString[i]&0xF8) == 0xF0) && ((sTmpString[i+1]&0xC0) == 0x80) && ((sTmpString[i+2]&0xC0) == 0x80) && ((sTmpString[i+3]&0xC0) == 0x80)) // four byte character?
        {
            currentChar=(sTmpString[i++] & 0x07); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i++] & 0x3f); currentChar=currentChar<<6;
            currentChar+=(sTmpString[i] & 0x3f);
            tmpCharLength = 3;
        } else 
        {
            currentChar = 160 + 1;
            tmpCharLength = 0;
        }
        
        if (currentChar > 160)
        {
            uni++;
            for (int j=tmpCharLength; j >= 0; j--) {
                sTmpString[i - j] = 95; 
            }
        }
    }
}


void PrintRemainingHealth()
{
	int tankclient = L4D2_FindAnyTank();
	if (!tankclient) return;
	char name[MAX_NAME_LENGTH];
	if (IsFakeClient(tankclient)) name = "AI";
	else GetClientName(tankclient, name, sizeof(name));
	L4D2_CPrintToChatAll("{B}Tank{W} ({G}%s{W}) 还有 {G}%d{W} 的生命值 ", name, g_iLastTankHealth);
	PrintTankDamage();
}

void PrintTankDamage()
{
	int client, percent_total, damage_total, survivor_index = -1, percent_damage, damage;
	int[] survivor_clients = new int[g_iSurvivorLimit];
	for (client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client) || !L4D2_IsSurvivor(client)) continue;
		survivor_index++;
		survivor_clients[survivor_index] = client;
		damage = g_iDamage[client];
		damage_total += damage;
		percent_damage = GetDamageAsPercent(damage);
		percent_total += percent_damage;
	}
	SortCustom1D(survivor_clients, g_iSurvivorLimit, SortByDamageDesc);
	
	int percent_adjustment;
	if ((percent_total < 100 && float(damage_total) > (fMaxTankHealth - (fMaxTankHealth / 200.0)))) percent_adjustment = 100 - percent_total;
	int last_percent = 100;
	int adjusted_percent_damage;
	for (int i; i <= survivor_index; i++)
	{
		client = survivor_clients[i];
		damage = g_iDamage[client];
		percent_damage = GetDamageAsPercent(damage);
		if (percent_adjustment != 0 && damage > 0 && !IsExactPercent(damage))
		{
			adjusted_percent_damage = percent_damage + percent_adjustment;
			if (adjusted_percent_damage <= last_percent)
			{
				percent_damage = adjusted_percent_damage;
				percent_adjustment = 0;
			}
		}
		L4D2_CPrintToChatAll("{B}[{W}%4d{B}] ({W}%d%%{B}) {G}%N", damage, percent_damage, client);
	}
}

void ClearTankDamage()
{
	g_iLastTankHealth = 0;
	for (int i = 1; i <= MAXPLAYERS; i++) { g_iDamage[i] = 0; }
	g_bAnnounceTankDamage = false;
}

int GetDamageAsPercent(int damage)
{
	return RoundToFloor((float(damage) / fMaxTankHealth) * 100.0);
}

bool IsExactPercent(int damage)
{
	return (FloatAbs(float(GetDamageAsPercent(damage)) - ((float(damage) / fMaxTankHealth) * 100.0)) < 0.001) ? true:false;
}

int SortByDamageDesc(int elem1, int elem2, const int[] array, Handle hndl)
{
	if (g_iDamage[elem1] > g_iDamage[elem2]) return -1;
	else if (g_iDamage[elem2] > g_iDamage[elem1]) return 1;
	else if (elem1 > elem2) return -1;
	else if (elem2 > elem1) return 1;
	return 0;
}
