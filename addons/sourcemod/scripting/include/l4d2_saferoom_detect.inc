#include <l4d2lib>

/*
  Check if entity is in a saferoom
  returns bool (errors/incorrect data returns false)
*/
stock bool SAFEDETECT_IsEntityInStartSaferoom(int entity)
{
	return L4D2_IsEntityInSaferoom(entity) == Saferoom_Start;
}

stock bool SAFEDETECT_IsEntityInEndSaferoom(int entity)
{
	return L4D2_IsEntityInSaferoom(entity) == Saferoom_End;
}

stock bool SAFEDETECT_IsEntityInSaferoom(int entity)
{
	return L4D2_IsEntityInSaferoom(entity) == Saferoom_Both;
}
