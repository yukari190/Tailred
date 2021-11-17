#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools_sound>
#include <colors>
#include <l4d2util>

#define PLUGIN_VERSION "1.3b"
#define DANG "ui/pickup_secret01.wav"

public Plugin myinfo = 
{
	name = "L4D2 Tank Announcer",
	author = "Visor, Forgetest, xoxo, Yukari190",
	description = "Announce in chat and via a sound when a Tank has spawned",
	version = PLUGIN_VERSION,
	url = "https://github.com/SirPlease/L4D2-Competitive-Rework"
};

public void OnMapStart()
{
	PrecacheSound(DANG);
}

public void L4D2_OnTankFirstSpawn(int iTankClient)
{
	char nameBuf[MAX_NAME_LENGTH];
	
	if (iTankClient > 0 && !IsFakeClient(iTankClient))
		FormatEx(nameBuf, sizeof(nameBuf), "%N", iTankClient);
	else
		FormatEx(nameBuf, sizeof(nameBuf), "AI");
	
	CPrintToChatAll("{red}[{default}!{red}] {olive}Tank{default}({red}控制者: %s{default}) 已产生!", nameBuf);
	EmitSoundToAll(DANG);
}

public void L4D2_OnTankPassControl(int iOldTank, int iNewTank)
{
	char oldNameBuf[MAX_NAME_LENGTH], nameBuf[MAX_NAME_LENGTH];
	
	if (IsValidAndInGame(iOldTank) && !IsFakeClient(iOldTank))
		FormatEx(oldNameBuf, sizeof(oldNameBuf), "%N", iOldTank);
	else
		FormatEx(oldNameBuf, sizeof(oldNameBuf), "AI");
	
	if (IsValidAndInGame(iNewTank) && !IsFakeClient(iNewTank))
		FormatEx(nameBuf, sizeof(nameBuf), "%N", iNewTank);
	else
		FormatEx(nameBuf, sizeof(nameBuf), "AI");
	
	
	CPrintToChatAll("{red}[{default}!{red}] {olive}Tank{default}({red}控制者: %s ====> %s{default}) 控制转换!", oldNameBuf, nameBuf);
}
