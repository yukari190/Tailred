#pragma tabsize 0
#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <left4dhooks>
#include <sdkhooks>
#include <sdktools>
#include <l4d2util_stocks>

public Plugin myinfo =
{
    name = "Shove Shenanigans - REVAMPED",
    author = "Sir",
    description = "Stops Shoves slowing the Tank and Charger, gives control over what happens when a Survivor is punched while having a melee out.",
    version = "1.2",
    url = ""
}

public void OnPluginStart()
{
    HookEvent("player_hurt", PlayerHit);
}

public Action PlayerHit(Event event, char[] event_name, bool dontBroadcast)
{
    int Player = GetClientOfUserId(event.GetInt("userid"));
    char Weapon[256];  
    event.GetString("weapon", Weapon, sizeof(Weapon));
    if (IsValidSurvivor(Player) && StrEqual(Weapon, "tank_claw"))
    {
        int activeweapon = GetEntPropEnt(Player, Prop_Send, "m_hActiveWeapon");
        if (IsValidEdict(activeweapon))
        {
            char weaponname[64];
            GetEdictClassname(activeweapon, weaponname, sizeof(weaponname));    
            
            if (StrEqual(weaponname, "weapon_melee", false) && GetPlayerWeaponSlot(Player, 0) != -1)
            {
                int PrimaryWeapon = GetPlayerWeaponSlot(Player, 0);
                SetEntPropEnt(Player, Prop_Send, "m_hActiveWeapon", PrimaryWeapon);
				SetEntPropFloat(PrimaryWeapon, Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + 0.1); // Prevent players instantly firing their Primary Weapon when they're holding down M1 with their melee.
            }
        }
    }
    return Plugin_Continue;
}

public Action L4D_OnShovedBySurvivor(int shover, int shovee, const float vector[3])
{
	if (!IsValidSurvivor(shover) || !IsInfectedAlive(shovee)) return Plugin_Continue;
	if (IsTankOrCharger(shovee) || (IsHunter(shovee) && !HasTarget(shovee))) return Plugin_Handled;
	return Plugin_Continue;
}

public Action L4D2_OnEntityShoved(int shover, int shovee_ent, int weapon, float vector[3], bool bIsHunterDeadstop)
{
	if (!IsValidSurvivor(shover) || !IsInfectedAlive(shovee_ent)) return Plugin_Continue;
	if (IsTankOrCharger(shovee_ent) || (IsHunter(shovee_ent) && !HasTarget(shovee_ent))) return Plugin_Handled;
	return Plugin_Continue;
}

bool IsTankOrCharger(int client)  
{
	int class = GetInfectedClass(client);
	return (class == ZC_CHARGER || class == ZC_TANK);
}

bool IsHunter(int client)
{
	return GetInfectedClass(client) == ZC_HUNTER;
}

bool HasTarget(int hunter)
{
	int target = GetEntPropEnt(hunter, Prop_Send, "m_pounceVictim");
	return IsValidSurvivor(target) && IsPlayerAlive(target);
}
