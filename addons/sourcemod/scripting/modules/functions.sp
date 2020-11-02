/*
	This program is free software: you can redistribute it and/or modify it under
	the terms of the GNU General Public License as published by the Free Software
	Foundation, either version 3 of the License, or (at your option) any later
	version.

	This program is distributed in the hope that it will be useful, but WITHOUT ANY
	WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A
	PARTICULAR PURPOSE.  See the GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along with
	this program.  If not, see <http://www.gnu.org/licenses/>.

	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved. 
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved. 
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase. 
	Source is Copyright (C) Valve Corporation. 

	Valve, the Valve logo, Left 4 Dead, Left 4 Dead 2, Steam, and the Steam
	logo are trademarks and/or registered trademarks of Valve Corporation.
	All other trademarks are property of their respective owners.
*/

#define CVAR_PREFIX			"lgofnoc_"
#define CVAR_PRIVATE		(FCVAR_DONTRECORD|FCVAR_PROTECTED)
#define CUSTOM_TAGS_VERSION 4
#define SV_TAG_SIZE 64

static Handle sv_tags;
static Handle custom_tags;
static bool are_tags_hooked = false;
static bool ignore_next_change = false;
static EngineVersion engine_version = Engine_Unknown;

/*Handle CreateConVarEx(const char[] name, const char[] defaultValue, const char[] description = "", int flags = 0, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 0.0)
{
	char sBuffer[128];
	Handle cvar;
	Format(sBuffer, sizeof(sBuffer), "%s%s", CVAR_PREFIX, name);
	cvar = CreateConVar(sBuffer, defaultValue, description, flags, hasMin, min, hasMax, max);
	return cvar;
}*/

int AddCustomServerTag(const char[] tag, bool force = false)
{
	if (sv_tags == INVALID_HANDLE && (sv_tags = FindConVar("sv_tags")) == INVALID_HANDLE) return; // game doesn't support sv_tags
	
	if (!force
		&& (engine_version != Engine_Unknown || (engine_version = GetEngineVersion()) != Engine_Unknown)
		&& engine_version >= Engine_Left4Dead2) return;
	
	if (custom_tags == INVALID_HANDLE)
	{
		custom_tags = CreateArray(SV_TAG_SIZE);
		PushArrayString(custom_tags, tag);
	}
	else if (FindStringInArray(custom_tags, tag) == -1) PushArrayString(custom_tags, tag);
	
	char current_tags[SV_TAG_SIZE];
	GetConVarString(sv_tags, current_tags, sizeof(current_tags));
	if (StrContains(current_tags, tag) > -1) return; // already have tag
	
	char new_tags[SV_TAG_SIZE];
	Format(new_tags, sizeof(new_tags), "%s%s%s", current_tags, (current_tags[0]!=0)?",":"", tag);
	
	int flags = GetConVarFlags(sv_tags);
	SetConVarFlags(sv_tags, flags & ~FCVAR_NOTIFY);
	ignore_next_change = true;
	SetConVarString(sv_tags, new_tags);
	ignore_next_change = false;
	SetConVarFlags(sv_tags, flags);
	
	if (!are_tags_hooked)
	{
		HookConVarChange(sv_tags, OnTagsChanged);
		are_tags_hooked = true;
	}
}

public int OnTagsChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	if (ignore_next_change) return;
	
	// reapply each custom tag
	for (int i = 0; i < GetArraySize(custom_tags); i++)
	{
		char tag[SV_TAG_SIZE];
		GetArrayString(custom_tags, i, tag, sizeof(tag));
		AddCustomServerTag(tag);
	}
}

int RemoveCustomServerTag(const char[] tag)
{
	if (sv_tags == INVALID_HANDLE && (sv_tags = FindConVar("sv_tags")) == INVALID_HANDLE) return;
	
	// we wouldn't have to check this if people aren't removing before adding, but... you know...
	if (custom_tags != INVALID_HANDLE)
	{
		int idx = FindStringInArray(custom_tags, tag);
		if (idx > -1) RemoveFromArray(custom_tags, idx);
	}
	
	char current_tags[SV_TAG_SIZE];
	GetConVarString(sv_tags, current_tags, sizeof(current_tags));
	if (StrContains(current_tags, tag) == -1) return;
	
	ReplaceString(current_tags, sizeof(current_tags), tag, "");
	ReplaceString(current_tags, sizeof(current_tags), ",,", "");
	
	int flags = GetConVarFlags(sv_tags);
	SetConVarFlags(sv_tags, flags & ~FCVAR_NOTIFY);
	ignore_next_change = true;
	SetConVarString(sv_tags, current_tags);
	ignore_next_change = false;
	SetConVarFlags(sv_tags, flags);
}

bool bIsPluginEnabled = false;

bool IsPluginEnabled(bool bSetStatus = false, bool bStatus = false)
{
	if (bSetStatus) bIsPluginEnabled = bStatus;
	return bIsPluginEnabled;
}

bool IsHumansOnServer()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if(IsClientConnected(i) && !IsFakeClient(i)) return true;
	}
	return false;
}
