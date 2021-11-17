bool IsMapFinale() {return L4D_IsMissionFinalMap();}

public Action L4D_OnSpawnTank(const float vector[3], const float qangle[3])
{
	if(GT_OnTankSpawn_Forward() == Plugin_Handled)
		return Plugin_Handled;
	BS_OnTankSpawn_Forward();
	return Plugin_Continue;
}

public Action L4D_OnSpawnMob(int &amount)
{
	if(GT_OnSpawnMob_Forward(amount) == Plugin_Handled)
		return Plugin_Handled;
	
	return Plugin_Continue;
}

public Action L4D_OnTryOfferingTankBot(int tank_index, bool &enterStasis)
{
	if(GT_OnTryOfferingTankBot(enterStasis) == Plugin_Handled)
		return Plugin_Handled;
	return Plugin_Continue;
}

/*public Action OFSLA_ForceMobSpawnTimer(Handle timer)
{
	L4D2_CTimerStart(L4D2CT_MobSpawnTimer, GetRandomFloat(fMobSpawnTimeMin, fMobSpawnTimeMax));
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(0.1, OFSLA_ForceMobSpawnTimer);
}*/