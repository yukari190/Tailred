#pragma tabsize 0
#pragma semicolon 1
//#pragma newdecls required
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <l4d2lib>
#include <l4d2util_stocks>

public Plugin myinfo =
{
	name = "L4D2 Advanced Special Infected AI",
	author = "def075 / 趴趴酱",
	description = "Advanced Special Infected AI",
	version = "0.5",
	url = ""
}

#define VEL_MAX          450.0
#define EYEANGLE_TICK      0.2
#define TEST_TICK          2.0
#define MOVESPEED_MAX     1000

enum AimTarget
{
	AimTarget_Eye,
	AimTarget_Body,
	AimTarget_Chest
};

float tankDamage;
float gascan_delay;
float throwForce[MAXPLAYERS + 1][3];

Handle sdkCallFling;

ConVar hCvarTankPunch;
ConVar hCvarTankSpeedUp;

bool SurvivorNearTank[MAXPLAYERS + 1];

public void OnPluginStart()
{
	Handle ConfigFile = LoadGameConfigFile("left4dhooks.l4d2");
	
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetFromConf(ConfigFile, SDKConf_Signature, "CTerrorPlayer_Fling");
	PrepSDKCall_AddParameter(SDKType_Vector, SDKPass_ByRef);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain);
	sdkCallFling = EndPrepSDKCall();
	if (sdkCallFling == INVALID_HANDLE) SetFailState("Cant initialize Fling SDKCall");
	delete ConfigFile;
	
	gascan_delay = GetConVarFloat(FindConVar("gascan_spit_time"));
	tankDamage = GetConVarFloat(FindConVar("vs_tank_damage"));
	
	hCvarTankPunch = CreateConVar("ai_tank_punch_fix", "1", "");
	hCvarTankSpeedUp = CreateConVar("ai_tank_speedup", "1", "");
	
	HookEvent("player_transitioned", ResetSurvivors);
}

public void OnMapStart()
{
	CreateTimer(1.0, timerMoveSpeed, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action L4D_OnFirstSurvivorLeftSafeArea()
{
	CreateTimer(2.0, Timer_ForceInfectedAssault, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_ForceInfectedAssault(Handle timer)
{
	CheatCommand("nb_assault");
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		if (StrEqual(classname, "weapon_gascan", false)) SDKHook(entity, SDKHook_OnTakeDamage, OnTakeDamage2);
	}
}

public Action OnTakeDamage2(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (IsValidEntity(victim) && inflictor)
	{
		char sInflictor[64];
		GetEdictClassname(inflictor, sInflictor, sizeof(sInflictor));
		
		if (GetEntProp(victim, Prop_Send, "m_glowColorOverride") != 16777215 && StrEqual(sInflictor, "insect_swarm", false)) CreateTimer(gascan_delay, timer_gascan, victim, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action timer_gascan(Handle timer, any victim)
{
	SDKHooks_TakeDamage(victim, 0, 0, 100.0, DMG_BURN);
}


public void L4D2_OnRealRoundStart()
{
	for (int i = 1; i <= MAXPLAYERS; i++)
	{
		SurvivorNearTank[i] = false;
		throwForce[i][0] = 0.0;
		throwForce[i][1] = 0.0;
		throwForce[i][2] = 0.0;
	}
    initStatus();
}

public void L4D2_OnPlayerTeamChanged(int client, int oldteam, int nowteam)
{
	if (!IsValidInGame(client) || !GetConVarBool(hCvarTankPunch)) return;
	if (nowteam == 2 && oldteam != 2) SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	else if (nowteam != 2 && oldteam == 2) SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3]) 
{
	if (!IsValidSurvivor(victim) || !IsTank(attacker)) return Plugin_Continue;
	char classname[64];
	if (attacker == inflictor) GetClientWeapon(inflictor, classname, sizeof(classname));
	else GetEdictClassname(inflictor, classname, sizeof(classname));
	if (StrContains(classname, "tank_claw", false) != -1)
	{
		for (int i = 0; i < NUM_OF_SURVIVORS; i++)
		{
			int index = L4D2_GetSurvivorOfIndex(i);
			if (index == 0 || index == victim || !SurvivorNearTank[index]) continue;
			
			if (!IsPlayerIncap(index)) SDKCall(sdkCallFling, index, throwForce[index], 96, attacker, 3.0); //76 is the 'got bounced' animation in L4D2
			SDKHooks_TakeDamage(index, attacker, attacker, tankDamage, DMG_GENERIC);
		}
	}
	return Plugin_Continue;
}

public void L4D2_OnTankFirstSpawn(int tankClient)
{
	if (GetConVarBool(hCvarTankPunch)) CreateTimer(0.01, Tank_Distance, tankClient, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action Tank_Distance(Handle timer, any client)
{
	if (!IsTank(client) || !IsPlayerAlive(client)) return Plugin_Stop;
	float survivorPos[3], tankPos[3];
	for (int i = 0; i < NUM_OF_SURVIVORS; i++)
	{
		int index = L4D2_GetSurvivorOfIndex(i);
		if (index == 0) continue;
		GetEntPropVector(index, Prop_Send, "m_vecOrigin", survivorPos);
		GetEntPropVector(client, Prop_Send, "m_vecOrigin", tankPos);
		if (GetVectorDistance(survivorPos, tankPos) <= 120)
		{
			NormalizeVector(survivorPos, survivorPos);
			NormalizeVector(tankPos, tankPos);
			throwForce[index][0] = Clamp((360000.0 * (survivorPos[0] - tankPos[0])), -400.0, 400.0);
			throwForce[index][1] = Clamp((90000.0 * (survivorPos[1] - tankPos[1])), -400.0, 400.0);
			throwForce[index][2] = 300.0;
			SurvivorNearTank[index] = true;
		}
		else
		{
			SurvivorNearTank[index] = false;
			throwForce[index][0] = 0.0;
			throwForce[index][1] = 0.0;
			throwForce[index][2] = 0.0;
		}
	}
	return Plugin_Continue;
}

public Action ResetSurvivors(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (IsValidSurvivor(client))
	{
		for (int i = 0; i < 5; i++)
		{
			int item = GetPlayerWeaponSlot(client, i);
			if (item > 0)
			{
				RemovePlayerItem(client, item);
			}
		}	
		GiveItem(client, "pistol");
		GiveItem(client, "health");
		SetEntPropFloat(client, Prop_Send, "m_healthBuffer", 0.0);		
		SetEntProp(client, Prop_Send, "m_currentReviveCount", 0); //reset incaps
		SetEntProp(client, Prop_Send, "m_bIsOnThirdStrike", false);
	}
}

void GiveItem(int client, char[] itemName)
{
	int flags = GetCommandFlags("give");
	SetCommandFlags("give", flags ^ FCVAR_CHEAT);
	FakeClientCommand(client, "give %s", itemName);
	SetCommandFlags("give", flags);
}

/* クライアントのキー入力処理
 *
 * ここでbotのキー入力を監視して書き換えることでbotをコントロールする
 *
 * buttons: 入力されたキー (enumはinclude/entity_prop_stock.inc参照)
 * vel: プレーヤーの速度？
 *      実プレーヤーだと
 *      [0]が↑↓入力で-450～+450.
 *      [1]が←→入力で-450～+450.
 *      botだと230
 *
 * angles: 視線の方向(マウスカーソルを向けている方向)？
 *      [0]がpitch(上下) -89～+89
 *      [1]がyaw(自分を中心に360度回転) -180～+180
 *
 *      これを変更しても視線は変わらないがIN_FORWARDに対する移動方向が変わる
 *
 * impulse: impules command なぞ
 *
 * buttons, vel, anglesは書き換えてPlugin_Changedを返せば操作に反映される.
 * ただ処理順の問題があってたとえばIN_USEのビットを落としてUSE Keyが使えないようにすると
 * 武器は取れないけどドアは開くみたいな事が起こりえる.
 *
 * ゲームフレームから呼ばれるようなのでできるだけ軽い処理にする.
 */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
                                                         float vel[3], float angles[3], int &weapon)
{
        // 特殊のBOTのみ処理
        if (isSpecialInfectedBot(client)) {
                // versusだとゴースト状態のBotがいるけど
                // Coopだとゴーストなしでいきなり沸いてる?
                // 今回ゴーストは考慮しない
                if (!isGhost(client)) {
                        // 種類ごとの処理
                        int zombie_class = GetInfectedClass(client);
                        Action ret = Plugin_Continue;

                        switch (zombie_class) {
							case ZC_TANK: { ret = onTankRunCmd(client,  buttons, vel, angles); }
                            case ZC_SMOKER: { ret = onSmokerRunCmd(client, buttons, vel, angles); }
                            case ZC_HUNTER: { ret = onHunterRunCmd(client, buttons, vel, angles); }
                            case ZC_JOCKEY: { ret =  onJockeyRunCmd(client, buttons, vel, angles); }
                            case ZC_BOOMER: { ret = onBoomerRunCmd(client, buttons, vel, angles); }
                            case ZC_SPITTER: { ret = onSpitterRunCmd(client, buttons, vel, angles); }
                            case ZC_CHARGER: { ret = onChargerRunCmd(client, buttons, vel, angles); }
                        }
                        // 最近のメイン攻撃時間を保存
                        if (buttons & IN_ATTACK) {
                                updateSIAttackTime();
                        }
                        return ret;
                }
        }
        return Plugin_Continue;
}

/**
 * スモーカーの処理
 *
 * チャンスがあれば舌を飛ばす
 */
#define SMOKER_ATTACK_SCAN_DELAY     0.5
#define SMOKER_ATTACK_TOGETHER_LIMIT 5.0
#define SMOKER_MELEE_RANGE           300.0
stock Action onSmokerRunCmd(int client, int &buttons, float vel[3], float angles[3])
{
        static Float:s_tounge_range = -1.0;
        new Action:ret = Plugin_Continue;

        if (s_tounge_range < 0.0) {
                // 舌が届く範囲
                s_tounge_range = GetConVarFloat(FindConVar("tongue_range"));
        }
        if (buttons & IN_ATTACK) {
                // botのトリガーはそのまま処理する
        } else if (delayExpired(client, 0, SMOKER_ATTACK_SCAN_DELAY)
                           && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                delayStart(client, 0);
                /* 他のSIが攻撃しているかターゲットからAIMを受けている場合に
                   舌が届く距離にターゲットがいたら即攻撃する */

                // botがターゲットしている生存者を取得
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
                        // 生存者で見えてたら
                        new Float:target_pos[3];
                        new Float:self_pos[3];
                        new Float:dist;

                        GetClientAbsOrigin(client, self_pos);
                        GetClientAbsOrigin(target, target_pos);
                        // ターゲットとの距離を計算
                        dist = GetVectorDistance(self_pos, target_pos);
                        if (dist < SMOKER_MELEE_RANGE) {
                                // ターゲットと近すぎる場合もうダメなので即攻撃する
                                buttons |= IN_ATTACK|IN_ATTACK2; // 舌がないことがあるので殴りも入れる
                                ret = Plugin_Changed;
                        } else if (dist < s_tounge_range) {
                                // 舌が届く範囲にターゲットがいる場合
                                if (GetGameTime() - getSIAttackTime() < SMOKER_ATTACK_TOGETHER_LIMIT) {
                                        // 最近SIが攻撃してたらチャンスっぽいので即攻撃する
                                        buttons |= IN_ATTACK;
                                        ret = Plugin_Changed;
                                } else {
                                        new target_aim = GetClientAimTarget(target, true);
                                        if (target_aim == client) {
                                                // ターゲットがこっちにAIMを向けてたら即攻撃する
                                                buttons |= IN_ATTACK;
                                                ret = Plugin_Changed;
                                        }
                                }
                                // 他はbotに任せる
                        }
                }
        }

        return ret;
}

/**
 * ジョッキーの処理
 *
 * たまにジャンプするのと生存者の近くで荒ぶる
 */
#define JOCKEY_JUMP_DELAY 2.0
#define JOCKEY_JUMP_NEAR_DELAY 0.1
#define JOCKEY_JUMP_NEAR_RANGE 400.0 // この範囲に生存者がいたら荒ぶる
#define JOCKEY_JUMP_MIN_SPEED 130.0
stock Action:onJockeyRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{

        if (
                // 速度がついてて↑入力があり地面の上で
                // ハシゴ中じゃないときはたまにジャンプする
                // さらに生存者がかなり近くにいるときは飛び跳ねまくる
                (getMoveSpeed(client)  > JOCKEY_JUMP_MIN_SPEED
                 && (buttons & IN_FORWARD)
                 && (GetEntityFlags(client) & FL_ONGROUND)
                 && GetEntityMoveType(client) != MOVETYPE_LADDER)
                && ((nearestSurvivorDistance(client) < JOCKEY_JUMP_NEAR_RANGE
                         && delayExpired(client, 0, JOCKEY_JUMP_NEAR_DELAY))
                        || delayExpired(client, 0, JOCKEY_JUMP_DELAY)))
        {
                // ジャンプと飛び乗り(PrimaryAttack)を交互に繰り返す
                vel[0] = VEL_MAX;
                if (getState(client, 0) == IN_JUMP) {
                        // 上のほうに飛び乗る動きをする
                        // anglesを変更しても視線が動かないので
                        // TeleportEntityで視線を変更する

                        // 上方向(ある程度ランダム)に視線を変更
                        if (angles[2] == 0.0) {
                                angles = angles;
                                angles[0] = GetRandomFloat(-50.0,-10.0);
                                TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                        }
                        // 飛び乗り
                        buttons |= IN_ATTACK;
                        setState(client, 0, IN_ATTACK);
                } else {
                        // 通常ジャンプ
                        // 殴りジャンプ
                        // ダッグジャンプ // しゃがみ押しっぱなしにしないとできないかも？
                        // をランダムに使う
                        if (angles[2] == 0.0) {
                                angles[0] = GetRandomFloat(-10.0, 0.0);
                                TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                        }
                        buttons |= IN_JUMP;
                        switch (GetRandomInt(0, 2)) {
                        case 0: { buttons |= IN_DUCK; }
                        case 1: { buttons |= IN_ATTACK2; }
                        }
                        setState(client, 0, IN_JUMP);
                }
                delayStart(client, 0);
                return Plugin_Changed;
        }
        return Plugin_Continue;
}

/**
 * チャージャーの処理
 *
 * なぐりまくる
 */
#define CHARGER_MELEE_DELAY     0.2
#define CHARGER_MELEE_RANGE 400.0
stock Action:onChargerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        // ハシゴ中以外で生存者近くにいるとき
        if (!(buttons & IN_ATTACK)
                && GetEntityMoveType(client) != MOVETYPE_LADDER
                && (GetEntityFlags(client) & FL_ONGROUND)
                && delayExpired(client, 0, CHARGER_MELEE_DELAY)
                && nearestSurvivorDistance(client) < CHARGER_MELEE_RANGE)
        {
                // 適当な間隔で殴りをいれる
                delayStart(client, 0);
                buttons |= IN_ATTACK2;
                return Plugin_Changed;
        }
        return Plugin_Continue;
}

/**
 * ハンターの処理
 *
 * 次のようにする
 * - 最初の飛び掛りのトリガーはBOTが自発的に行う
 * - BOTが飛び掛ったら一定の間攻撃モードをONにする
 * - 攻撃モードがONの場合さまざまな角度で連続的に飛びまくる動きと
 *   ターゲットを狙った飛びかかり（デフォルトの動き）を混ぜて飛び回る
 *
 * あと hunter_pounce_ready_range というCVARをを2000くらいに変更すると
 * 遠くにいるときでもしゃがむようになるの変更するとよい
 *
 * あと撃たれたときに後ろに飛んで逃げるっぽい動きに移行するのをやめさせたい
 */
#define HUNTER_FLY_DELAY             0.2
#define HUNTER_ATTACK_TIME           4.0
#define HUNTER_COOLDOWN_DELAY        2.0
#define HUNTER_FALL_DELAY            0.2
#define HUNTER_STATE_FLY_TYPE        0
#define HUNTER_STATE_FALL_FLAG       1
#define HUNTER_STATE_FLY_FLAG        2

#define HUNTER_REPEAT_SPEED          4
#define HUNTER_NEAR_RANGE          1000

stock Action:onHunterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        new Action:ret = Plugin_Continue;
        new bool:internal_trigger = false;

        if (!delayExpired(client, 1, HUNTER_ATTACK_TIME)
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                // 攻撃モード中はDUCK押しっぱなしかつATTACK連打する
                buttons |= IN_DUCK;
                if (GetRandomInt(0, HUNTER_REPEAT_SPEED) == 0) {
                        // ATTACKは離さないと効果がないので
                        // ランダムな間隔で押した状態を作る
                        buttons |= IN_ATTACK;
                        internal_trigger = true;
                }
                ret = Plugin_Changed;
        }
        if (!(GetEntityFlags(client) & FL_ONGROUND)
                && getState(client, HUNTER_STATE_FLY_FLAG) == 0)
        {
                // ジャンプ開始
                delayStart(client, 2);
                setState(client, HUNTER_STATE_FALL_FLAG, 0);
                setState(client, HUNTER_STATE_FLY_FLAG, 1);
        } else if (!(GetEntityFlags(client) & FL_ONGROUND)) {
                // 空中にいる場合
                if (getState(client, HUNTER_STATE_FLY_TYPE) == IN_FORWARD) {
                        // 角度を変えて飛ぶときは空中で↑入力を入れる
                        buttons |= IN_FORWARD;
                        vel[0] = VEL_MAX;
                        if (getState(client, HUNTER_STATE_FALL_FLAG) == 0
                                && delayExpired(client, 2, HUNTER_FALL_DELAY))
                        {
                                // 飛び始めてから少しして視線を変える
                                if (angles[2] == 0.0) {
                                        angles[0] = GetRandomFloat(-50.0, 20.0);
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                setState(client, HUNTER_STATE_FALL_FLAG, 1);
                        }
                        ret = Plugin_Changed;
                }
        } else if (getState(client, 2) == 1) {
                // 着地
        } else {
                setState(client, HUNTER_STATE_FLY_FLAG, 0);
        }
        if (delayExpired(client, 0, HUNTER_FLY_DELAY)
                && (buttons & IN_ATTACK)
                && (GetEntityFlags(client) & FL_ONGROUND))
        {
                // 飛びかかり開始
                new Float:dist = nearestSurvivorDistance(client);

                delayStart(client, 0);
                if (!internal_trigger
                        && !(buttons & IN_BACK)
                        && dist < HUNTER_NEAR_RANGE
                        && delayExpired(client, 1, HUNTER_ATTACK_TIME + HUNTER_COOLDOWN_DELAY))
                {
                        // BOTがトリガーを入れて生存者に近い場合は攻撃モードに移行する
                        delayStart(client, 1); // このdelayが切れるまで攻撃モード
                }
                // ランダムな飛び方と
                // ターゲットを狙ったデフォルトの飛び方をランダムに繰り返す.
                if (GetRandomInt(0, 1) == 0) {
                        // ランダムで飛ぶ
                        if (dist < HUNTER_NEAR_RANGE) {
                                if (angles[2] == 0.0) {
                                        if (GetRandomInt(0, 4) == 0) {
                                                // 高めに飛ぶ 1/5
                                                angles[0] = GetRandomFloat(-50.0, -30.0);
                                        } else {
                                                // 低めに飛ぶ
                                                angles[0] = GetRandomFloat(-10.0, 20.0);
                                        }
                                        // 視線を変更
                                        TeleportEntity(client, NULL_VECTOR, angles, NULL_VECTOR);
                                }
                                // 空中で前入力を入れるフラグをセット
                                setState(client, HUNTER_STATE_FLY_TYPE, IN_FORWARD);
                        } else {
                                // デフォルトの飛び掛り
                                setState(client, HUNTER_STATE_FLY_TYPE, 0);
                        }
                } else {
                        // デフォルトの飛び掛り
                        setState(client, HUNTER_STATE_FLY_TYPE, 0);
                }
                ret = Plugin_Changed;
        }

        return ret;
}

/**
 * ブーマーの処理
 *
 * Coopブーマーは積極的にゲロを吐かないというか
 * ゲロのリチャージができていないことがある？（要確認）
 * でウロウロしているだけなので
 * ゲロがかけれそうなら即かけるようにする
 */
#define BOMMER_SCAN_DELAY 0.5
stock Action:onBoomerRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        static Float:s_vomit_range = -1.0;
        if (s_vomit_range < 0.0) {
                // ゲロの飛距離
                s_vomit_range = GetConVarFloat(FindConVar("z_vomit_range"));
        }
        if (buttons & IN_ATTACK) {
                // BOTのトリガーは無視する
                buttons &= ~IN_ATTACK;
                return Plugin_Changed;
        } else if (delayExpired(client, 0, BOMMER_SCAN_DELAY)
                && GetEntityMoveType(client) != MOVETYPE_LADDER)
        {
                delayStart(client, 0);
                // ゲロが届く距離にターゲットがいればとにかくかける
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isSurvivor(target) && isVisibleTo(client, target)) {
                        new Float:target_pos[3];
                        new Float:self_pos[3];
                        new Float:dist;

                        GetClientAbsOrigin(client, self_pos);
                        GetClientAbsOrigin(target, target_pos);
                        dist = GetVectorDistance(self_pos, target_pos);
                        if (dist < s_vomit_range) {
                                buttons |= IN_ATTACK;
                                return Plugin_Changed;
                        }
                }
        }

        return Plugin_Continue;
}

/**
 * スピッターの処理
 *
 * スピッターはなんか特に意味なくジャンプしたりする
 */
#define SPITTER_RUN 200.0
#define SPITTER_SPIT_DELAY 2.0
#define SPITTER_JUMP_DELAY 0.1
stock Action:onSpitterRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
        if (getMoveSpeed(client) > SPITTER_RUN
                && delayExpired(client, 0, SPITTER_JUMP_DELAY)
                && (GetEntityFlags(client) & FL_ONGROUND))
        {
                // 逃げてるっぽいときジャンプする
                delayStart(client, 0);
                buttons |= IN_JUMP;
                if (getState(client, 0) == IN_MOVERIGHT) {
                        setState(client, 0, IN_MOVELEFT);
                        buttons |= IN_MOVERIGHT;
                        vel[1] = VEL_MAX;
                } else {
                        setState(client, 0, IN_MOVERIGHT);
                        buttons |= IN_MOVELEFT;
                        vel[1] = -VEL_MAX;
                }
                return Plugin_Changed;
        }

        if (buttons & IN_ATTACK) {
                // 吐くときついでにジャンプする
                if (delayExpired(client, 1, SPITTER_SPIT_DELAY)) {
                        delayStart(client, 1);
                        buttons |= IN_JUMP;
                        return Plugin_Changed;
                        // 吐く角度を変えたいけど
                        // 視線を真上にteleportさせても横に吐いてて
                        // 変更できなかった TODO
                }
        }

        return Plugin_Continue;
}

/**
 * タンクの処理
 *
 * - 近くに生存者がいればとにかく殴る
 * - 走っているときに直線的なジャンプで加速する
 * - 岩投げ中にターゲットしている人が見えなくなったらターゲットを変更する
 *   （投げる瞬間にターゲットが変わるとモーションと違う軌道に投げる）
 */
#define TANK_MELEE_SCAN_DELAY 0.5
#define TANK_BHOP_SCAN_DELAY  2.0
#define TANK_BHOP_TIME        1.6
#define TANK_ROCK_AIM_TIME    4.0
#define TANK_ROCK_AIM_DELAY   0.25
stock Action:onTankRunCmd(client, &buttons, Float:vel[3], Float:angles[3])
{
	if(GetConVarBool(hCvarTankSpeedUp))
	{
		//float tankPos[3];
		//GetClientAbsOrigin(client, tankPos);
		//if(GetSurvivorProximity(tankPos) > 500) ApplySlowdown(client, 2.0);
		ApplySlowdown(client, 1.3);
	}
	
	
		int flags = GetEntityFlags(client);
		
		
		int sequence = GetEntProp(client, Prop_Send, "m_nSequence");
		if (sequence == 54 || sequence == 55 || sequence == 57) SetEntProp(client, Prop_Send, "m_nSequence", 0);
		if (sequence == 56) buttons |= IN_ATTACK;
		if ((buttons & IN_ATTACK2)) buttons |= IN_ATTACK;
		
        float s_tank_attack_range = GetConVarFloat(FindConVar("tank_attack_range"));

        // 岩投げ
        /*if ((buttons & IN_ATTACK2)) {
                // BOTが岩投げ開始
                // この時間が切れるまでターゲットを探してAutoAimする
                delayStart(client, 3);
                delayStart(client, 4);
        }
        // 岩投げ中
        if (delayExpired(client, 4, TANK_ROCK_AIM_DELAY)
                && !delayExpired(client, 3, TANK_ROCK_AIM_TIME))
        {
                new target = GetClientAimTarget(client, true);
                if (target > 0 && isVisibleTo(client, target)) {
                        // BOTが狙っているターゲットが見えている場合
                } else {
                        // 見えて無い場合はタンクから見える範囲で一番近い生存者を検索
                        new new_target = -1;
                        new Float:min_dist = 100000.0;
                        new Float:self_pos[3], Float:target_pos[3];

                        GetClientAbsOrigin(client, self_pos);
                        for (new i = 1; i <= MaxClients; ++i) {
                                if (isSurvivor(i)
                                        && IsPlayerAlive(i)
                                        && !isIncapacitated(i)
                                        && isVisibleTo(client, i))
                                {
                                        new Float:dist;

                                        GetClientAbsOrigin(i, target_pos);
                                        dist = GetVectorDistance(self_pos, target_pos);
                                        if (dist < min_dist) {
                                                min_dist = dist;
                                                new_target = i;
                                        }
                                }
                        }
                        if (new_target > 0) {
                                // 新たなターゲットに照準を合わせる
                                if (angles[2] == 0.0) {
                                        new Float:aim_angles[3];
                                        computeAimAngles(client, new_target, aim_angles, AimTarget_Chest);
                                        aim_angles[2] = 0.0;
                                        TeleportEntity(client, NULL_VECTOR, aim_angles, NULL_VECTOR);
                                        return Plugin_Changed;
                                }
                        }
                }
        }*/

        // 殴り
        if (GetEntityMoveType(client) != MOVETYPE_LADDER
                && (flags & FL_ONGROUND)
                && IsPlayerAlive(client))
        {
                if (delayExpired(client, 0, TANK_MELEE_SCAN_DELAY)) {
                        // 殴りの当たる範囲に立っている生存者がいたら方向は関係なく殴る
                        delayStart(client, 0);
                        if (nearestActiveSurvivorDistance(client) < s_tank_attack_range * 0.95) {
                                buttons |= IN_ATTACK;
                                return Plugin_Changed;
                        }
                }
        }

        return Plugin_Continue;
}

void ApplySlowdown(int client, float value)
{
	if (value == -1.0) return;
	SetEntPropFloat(client, Prop_Send, "m_flLaggedMovementValue", value);
}

// clientの一番近くにいる生存者の距離を取得
//
// 今はトレースしていないので1階と2階とか隣の部屋とか
// 遮るものがあっても近くになってしまう
stock any:nearestSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && isSurvivor(i) && IsPlayerAlive(i)) {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}
stock any:nearestActiveSurvivorDistance(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;

        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i)
                        && isSurvivor(i)
                        && IsPlayerAlive(i)
                        && !isIncapacitated(client))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                        }
                }
        }
        return min_dist;
}

// clientから見える範囲で一番近い生存者を取得
stock any:nearestVisibleSurvivor(client)
{
        new Float:self[3];
        new Float:min_dist = 100000.0;
        new min_i = -1;
        GetClientAbsOrigin(client, self);
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i)
                        && isSurvivor(i)
                        && IsPlayerAlive(i)
                        && isVisibleTo(client, i))
                {
                        new Float:target[3];
                        GetClientAbsOrigin(i, target);
                        new Float:dist = GetVectorDistance(self, target);
                        if (dist < min_dist) {
                                min_dist = dist;
                                min_i = i;
                        }
                }
        }
        return min_i;
}

// 感染者か
stock bool:isInfected(i)
{
        return GetClientTeam(i) == 3;
}
// ゴーストか
stock bool:isGhost(i)
{
        return isInfected(i) && GetEntProp(i, Prop_Send, "m_isGhost");
}
// 特殊感染者ボットか
stock bool:isSpecialInfectedBot(i)
{
        return i > 0 && i <= MaxClients && IsClientInGame(i) && IsFakeClient(i) && isInfected(i);
}
// 生存者か
// 死んでるとかダウンしてるとか拘束されてるとかも見たほうがいいでしょう..
stock bool:isSurvivor(i)
{
        return i > 0 && i <= MaxClients && IsClientInGame(i) && GetClientTeam(i) == 2;
}


/**
 * キー入力処理内でビジーループと状態維持に使っている変数
 *
 * 死んだときにクリアしないと前の情報が残ってるけど
 * あまり気にならないような作りにしてる
 */
// 1 client 8delayを持っとく
new Float:g_delay[MAXPLAYERS+1][8];
stock delayStart(client, no)
{
        g_delay[client][no] = GetGameTime();
}
stock bool:delayExpired(client, no, Float:delay)
{
        return GetGameTime() - g_delay[client][no] > delay;
}
// 1 player 8state を持っとく
new g_state[MAXPLAYERS+1][8];
stock setState(client, no, value)
{
        g_state[client][no] = value;
}
stock any:getState(client, no)
{
        return g_state[client][no];
}
stock initStatus()
{
        new Float:time = GetGameTime();
        for (new i = 0; i < MAXPLAYERS+1; ++i) {
                for (new j = 0; j < 8; ++j) {
                        g_delay[i][j] = time;
                        g_state[i][j] = 0;
                }
        }
}

// 特殊がメイン攻撃した時間
new Float:g_si_attack_time;
stock any:getSIAttackTime()
{
        return g_si_attack_time;
}
stock updateSIAttackTime()
{
        g_si_attack_time = GetGameTime();
}

/**
 * TODO: 主攻撃の準備ができているか（リジャージ中じゃないか）調べたいけど
 *       どうすればいいのか分からない
 */
stock bool:readyAbility(client)
{
        /*
        new ability = GetEntPropEnt(client, Prop_Send, "m_customAbility");
        new String:name[256];
        GetClientName(client, name, 256);

        if (ability > 0) {
            //new Float:time = GetEntPropFloat(ability, Prop_Send, "m_timestamp");
                //new used = GetEntProp(ability, Prop_Send, "m_hasBeenUsed");
                //new Float:duration = GetEntPropFloat(ability, Prop_Send, "m_duration");
                return time < GetGameTime();
        } else {
                // なぜかここにくることがある
        }
        */
        return true;
}

// 入力がどうなっているの確認に使ってるやつ
stock debugPrint(client, buttons, Float:vel[3], Float:angles[3])
{
        // 条件でフィルタしないと出すぎてやばいので適当に書き換えてデバッグしてる
        if (IsFakeClient(client)) {
                return; // 自分だけ表示
        }

        new String:name[256];
        GetClientName(client, name, 256);
}

/**
 * 各クライアントの現在の移動速度を計算する
 *
 * g_move_speedは生存者が直線に走ったときが220くらい
 * 走っているとか止まっている判定できる
 */
new Float:g_move_grad[MAXPLAYERS+1][3];
new Float:g_move_speed[MAXPLAYERS+1];
new Float:g_pos[MAXPLAYERS+1][3];
public Action:timerMoveSpeed(Handle:timer)
{
        for (new i = 1; i <= MaxClients; ++i) {
                if (IsClientInGame(i) && IsPlayerAlive(i)) {
                        new team = GetClientTeam(i);
                        if (team == 2 || team == 3) { // survivor or infected
                                new Float:pos[3];

                                GetClientAbsOrigin(i, pos);
                                g_move_grad[i][0] = pos[0] - g_pos[i][0];
                                 // yジャンプしてるときにおかしくなる..
                                g_move_grad[i][1] = pos[1] - g_pos[i][1];
                                g_move_grad[i][2] = pos[2] - g_pos[i][2];
                                // スピードに高さ方向は考慮しない
                                g_move_speed[i] =
                                        SquareRoot(g_move_grad[i][0] * g_move_grad[i][0] +
                                                           g_move_grad[i][1] * g_move_grad[i][1]);
                                if (g_move_speed[i] > MOVESPEED_MAX) {
                                        // ワープやリスポンしたっぽいときはクリア
                                        g_move_speed[i] = 0.0;
                                        g_move_grad[i][0] = 0.0;
                                        g_move_grad[i][1] = 0.0;
                                        g_move_grad[i][2] = 0.0;
                                }
                                g_pos[i] = pos;
                        }
                }
        }
        return Plugin_Continue;
}

stock Float:getMoveSpeed(client)
{
        return g_move_speed[client];
}
stock Float:getMoveGradient(client, ax)
{
        return g_move_grad[client][ax];
}

public bool:traceFilter(entity, mask, any:self)
{
        return entity != self;
}

/* clientからtargetの頭あたりが見えているか判定 */
stock bool:isVisibleTo(client, target)
{
        new bool:ret = false;
        new Float:angles[3];
        new Float:self_pos[3];

        GetClientEyePosition(client, self_pos);
        computeAimAngles(client, target, angles);
        new Handle:trace = TR_TraceRayFilterEx(self_pos, angles, MASK_SOLID, RayType_Infinite, traceFilter, client);
        if (TR_DidHit(trace)) {
                new hit = TR_GetEntityIndex(trace);
                if (hit == target) {
                        ret = true;
                }
        }
        CloseHandle(trace);
        return ret;
}

// clientからtargetへのアングルを計算
stock computeAimAngles(client, target, Float:angles[3], AimTarget:type = AimTarget_Eye)
{
        new Float:target_pos[3];
        new Float:self_pos[3];
        new Float:lookat[3];

        GetClientEyePosition(client, self_pos);
        switch (type) {
        case AimTarget_Eye: {
                GetClientEyePosition(target, target_pos);
        }
        case AimTarget_Body: {
                GetClientAbsOrigin(target, target_pos);
        }
        case AimTarget_Chest: {
                GetClientAbsOrigin(target, target_pos);
                target_pos[2] += 45.0; // このくらい
        }
        }
        MakeVectorFromPoints(self_pos, target_pos, lookat);
        GetVectorAngles(lookat, angles);
}
// 生存者の場合ダウンしてるか？
stock bool:isIncapacitated(client)
{
        return isSurvivor(client)
                && GetEntProp(client, Prop_Send, "m_isIncapacitated", 1) == 1;
}

bool IsTank(int client)
{
	if (!IsValidInfected(client)) return false;
	if (GetInfectedClass(client) != ZC_TANK) return false;
	return true;
}

float Clamp(float value, float min, float max)
{
	if (value > max) return max;
	if (value < min) return min;
	return value;
}
