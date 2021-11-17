#define CUSTOM_TAGS_VERSION 4

#define SV_TAG_SIZE 64

ConVar
	sv_tags;
ArrayList
	custom_tags;
bool
	are_tags_hooked,
	ignore_next_change;

void AddCustomServerTag(const char[] tag)
{
	if (sv_tags == INVALID_HANDLE && (sv_tags = FindConVar("sv_tags")) == INVALID_HANDLE)
	{
		return;
	}
	
	if (custom_tags == INVALID_HANDLE)
	{
		custom_tags = new ArrayList(SV_TAG_SIZE);
		custom_tags.PushString(tag);
	}
	else if (custom_tags.FindString(tag) == -1)
	{
		custom_tags.PushString(tag);
	}
	
	char current_tags[SV_TAG_SIZE];
	sv_tags.GetString(current_tags, sizeof(current_tags));
	if (StrContains(current_tags, tag) > -1)
	{
		return;
	}
	
	char new_tags[SV_TAG_SIZE];
	Format(new_tags, sizeof(new_tags), "%s%s%s", current_tags, (current_tags[0]!=0)?",":"", tag);
	
	int flags = sv_tags.Flags;
	sv_tags.Flags = flags & ~FCVAR_NOTIFY;
	ignore_next_change = true;
	sv_tags.SetString(new_tags);
	ignore_next_change = false;
	sv_tags.Flags = flags;
	
	if (!are_tags_hooked)
	{
		sv_tags.AddChangeHook(OnTagsChanged);
		are_tags_hooked = true;
	}
}

void RemoveCustomServerTag(const char[] tag)
{
	if (sv_tags == INVALID_HANDLE && (sv_tags = FindConVar("sv_tags")) == INVALID_HANDLE)
	{
		return;
	}
	
	if (custom_tags != INVALID_HANDLE)
	{
		int idx = custom_tags.FindString(tag);
		if (idx > -1)
		{
			custom_tags.Erase(idx);
		}
	}
	
	char current_tags[SV_TAG_SIZE];
	sv_tags.GetString(current_tags, sizeof(current_tags));
	if (StrContains(current_tags, tag) == -1)
	{
		return;
	}
	
	ReplaceString(current_tags, sizeof(current_tags), tag, "");
	ReplaceString(current_tags, sizeof(current_tags), ",,", "");
	
	int flags = sv_tags.Flags;
	sv_tags.Flags = flags & ~FCVAR_NOTIFY;
	ignore_next_change = true;
	sv_tags.SetString(current_tags);
	ignore_next_change = false;
	sv_tags.Flags = flags;
}

public void OnTagsChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (ignore_next_change)
	{
		return;
	}
	
	int cnt = custom_tags.Length;
	for (int i = 0; i < cnt; i++)
	{
		char tag[SV_TAG_SIZE];
		custom_tags.GetString(i, tag, sizeof(tag));
		AddCustomServerTag(tag);
	}
}