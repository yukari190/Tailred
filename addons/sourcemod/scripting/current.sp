#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <left4dhooks>
#include <l4d2lib>
#include <l4d2util>

public Plugin myinfo =
{
	name = "L4D2 Survivor Progress",
	author = "CanadaRox, Visor, Yukari190", //update syntax A1m`
	description = "Print survivor progress in flow percents ",
	version = "2.0.2b",
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

ConVar
	l4d2_scripted_hud_hud1_text = null,
	hVsBossBuffer = null;
float
	fVersusBossBuffer;
int
	survivorCompletion;
char
	curtext[32];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("GetHighestSurvivorFlow", _native_GetHighestSurvivorFlow);
	CreateNative("GetBossProximity", _native_GetBossProximity);
	RegPluginLibrary("current");
	return APLRes_Success;
}

public any _native_GetHighestSurvivorFlow(Handle plugin, int numParams)
{
	return GetHighestSurvivorFlow();
}

public any _native_GetBossProximity(Handle plugin, int numParams)
{
	return GetBossProximity();
}

public void OnPluginStart()
{
	l4d2_scripted_hud_hud1_text = FindConVar("l4d2_scripted_hud_hud1_text");
	
	(hVsBossBuffer = FindConVar("versus_boss_buffer")).AddChangeHook(GameConVarChanged);
	fVersusBossBuffer	= hVsBossBuffer.FloatValue;

	RegConsoleCmd("sm_cur", CurrentCmd);
	RegConsoleCmd("sm_current", CurrentCmd);
	
	CreateTimer(1.0, HudDrawTimer, _, TIMER_REPEAT);
}

public void GameConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	fVersusBossBuffer	= hVsBossBuffer.FloatValue;
}

public Action HudDrawTimer(Handle hTimer)
{
	if (IsInTransition() || GetSeriousClientCount(true) == 0) return Plugin_Continue;
	if (l4d2_scripted_hud_hud1_text != null)
	{
		Format(curtext, sizeof(curtext), "进度: [ %d%% ]", GetHighestSurvivorFlow());
		l4d2_scripted_hud_hud1_text.SetString(curtext);
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

public Action CurrentCmd(int client, int args)
{
	PrintToChat(client, "\x01当前: \x04%d%%", GetHighestSurvivorFlow());
	return Plugin_Handled;
}

public void L4D2_OnRealRoundStart()
{
	survivorCompletion = 0;
}

int GetHighestSurvivorFlow()
{
	int flow = RoundToNearest(100.0 * GetBossProximity());
	if (survivorCompletion < flow)
	{
		survivorCompletion = flow;
	}
	return survivorCompletion;
}

float GetBossProximity()
{
	float flow = -1.0;
	int client = L4D_GetHighestFlowSurvivor();
	if (client > 0)
	{
		flow = (L4D2Direct_GetFlowDistance(client) + fVersusBossBuffer) / L4D2Direct_GetMapMaxFlowDistance();
	}
	return (flow > 1.0) ? 1.0 : flow;
}
