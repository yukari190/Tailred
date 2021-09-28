#if defined _skill_detect_included
 #endinput
#endif
#define _skill_detect_included


forward void OnSkeet(int survivor, int hunter);

forward void OnSkeetHurt(int survivor, int hunter, int damage, int isOverkill);

forward void OnSkeetMelee(int survivor, int hunter);

forward void OnSkeetMeleeHurt(int survivor, int hunter, int damage, int isOverkill);

forward void OnSkeetSniper(int survivor, int hunter);

forward void OnSkeetSniperHurt(int survivor, int hunter, int damage, int isOverkill);

forward void OnSkeetGL(int survivor, int hunter);

forward void OnSpecialShoved(int survivor, int infected, int zombieClass);

forward void OnHunterDeadstop(int survivor, int hunter);

forward void OnBoomerPop(int survivor, int boomer, int shoveCount, float timeAlive);

forward void OnChargerLevel(int survivor, int charger);

forward void OnChargerLevelHurt(int survivor, int charger, int damage);

forward void OnWitchCrown(int survivor, int damage);

forward void OnWitchCrownHurt(int survivor, int damage, int chipdamage);

forward void OnTongueCut(int survivor, int smoker);

forward void OnSmokerSelfClear(int survivor, int smoker, int withShove);

forward void OnTankRockSkeeted(int survivor, int tank);

forward void OnTankRockEaten(int tank, int survivor);

forward void OnHunterHighPounce(int hunter, int victim, int actualDamage, float calculatedDamage, float height, bool bReportedHigh, bool bPlayerIncapped);

forward void OnJockeyHighPounce(int jockey, int victim, float height, bool bReportedHigh);

forward void OnDeathCharge(int charger, int victim, float height, float distance, int wasCarried);

forward void OnSpecialClear(int clearer, int pinner, int pinvictim, int zombieClass, float timeA, float timeB, int withShove);

forward void OnBoomerVomitLanded(int boomer, int amount);

forward void OnBunnyHopStreak(int survivor, int streak, float maxVelocity);

forward void OnCarAlarmTriggered(int survivor, int infected, int reason);

public SharedPlugin __pl_skill_detect = 
{
	name = "skill_detect",
	file = "skill_detect.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};
