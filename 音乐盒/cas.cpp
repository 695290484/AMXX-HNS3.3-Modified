// 要求 : AMXX 1.8.2 
// SQL : nick statsid scount
/* 注： 
	回合结束会显示统计数据（包括特殊信息，MVP，击杀榜）
	特殊信息比如xxx验证了万有引力定律，和MVP无关，只和该信息注册时的比重有关
	MVP根据注册特殊信息时设置的分数来计算（多条触发的总和）

	具体操作：
		1.当玩家触发你规定的条件时，使用updateStatsByStatsId()或updateStatsByIndex()来更新他对应的数据
		2.如果 提示内容中包含自定义数据，在上一步更新数据后立刻使用updateParamByStatsId()来传入自定义数据
		3.以上操作要在 回合开始后-结束前执行（不包括两个时间点），如要回合结束时更新请放在cas_fw_roundend()中
*/

#include<amxmodx>
#include<fakemeta>
#include <hamsandwich>

native wsc_has_item_by_name(id, wname[])
native wsc_using_item(mvp, box)

#define MAX_STATS 100
new gCount
new gStatsId[MAX_STATS]
new gStats[33][MAX_STATS]			// 总的
new gRoundStats[33][MAX_STATS]		// 回合
new gAchivname[MAX_STATS][128]
new gShowlevel[MAX_STATS]			// 决定短语显示
new gScore[MAX_STATS]			// 决定mvp得分
new gShowHudParam[MAX_STATS][32]

new gLastAchi = -1, gCurrent = 0, gReset

new gTempMvpMsg[64], gTempStatsMsg[192], gTempKillTopMsg[192]
new g_fwDummyResult, g_fwEnd, g_fwStart

new xKill[33], mKill
new xThrow[33], mThrow
new xFlash[33]
new xFirstKill[33]
new xAliveRound[33], mAR
new xAliveTime[33], mAT
new xKnifeCount[33], mKC
new mRoundTime

#define MAX_MUSIC 32
new gMusicCount
new gMusicName[MAX_MUSIC][32], gMusicPath[MAX_MUSIC][128]

new gRound, gMaxplayers
public plugin_init(){
	register_plugin("CS ACHIVEMNT SYSTEM", "1.0", "zhiJiaN")
	//register_logevent("eventEndRound"  ,2,"0=World triggered", "1=Round_Draw", "1=Round_End");
	register_event("SendAudio","eventEndRound", "a", "2&%!MRAD_terwin", "2&%!MRAD_ctwin", "2&%!MRAD_rounddraw");
	register_event("HLTV", "eventNewRound", "a", "1=0", "2=0");
	register_message(get_user_msgid("DeathMsg"), "msgDeathMsg")
	register_message(get_user_msgid("ScreenFade"), "msgScreenFade");
	register_forward(FM_SetModel, "fw_SetModel")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_post", 1)

	gMaxplayers = get_maxplayers()

	// 需要在回合结束统计 时调用
	g_fwEnd = CreateMultiForward("cas_fw_roundend", ET_IGNORE)

	// 回合开始，可用于重置回合相关的变量
	g_fwStart = CreateMultiForward("cas_fw_roundstart", ET_IGNORE)

	/* 
	// 注册一个数据项
	// @param statsid 自编唯一用于存入数据库，当有重复时注册失败
	// @param achiv 提示内容，[n]会自动替换为玩家名，允许使用1个%s传入自定义字符串(最大长度32字节，使用updateParamByStatsId接口)
	// @param showlevel 数据项显示比重，击杀3个及以上比重为50，最高则显示，比重相同时随机
	// @param score 显示数据项前会计算总分，最高为MVP，相同则随机
	// @return 返回数据项在数组中的索引index，并不是statsid，返回-1为错误，详情见控制台打印
	native cas_register_stats(statsid, const achiv[], showlevel, score)
	*/
	register_stats(1, "[n]消灭了%s个敌人!", 50, 10)
	register_stats(2, "[n]验证了万有引力定律!", 46, -2)
	register_stats(3, "[n]丢出了%s个投掷物!", 47, 1)
	register_stats(4, "[n]使用手雷解救了被冰冻的队友!", 47, 3)
	register_stats(5, "本回合只用了%s秒!", 47, 0)
	register_stats(6, "[n]在被闪光弹致盲时击杀了敌人!", 47, 1)
	register_stats(7, "[n]在本回合开始%s秒后第一个杀人!", 47, 1)
	register_stats(8, "[n]已经连续生存了%s回合!", 47, 1)
	register_stats(9, "[n]本回合在T队伍生存最久，%s秒!", 47, 1)
	register_stats(10, "[n]在被砍了%s刀后活了下来!", 47, 1)

	register_music("音乐盒-CSGO主题", "musicbox/ez4ence.mp3")

	register_clcmd("testmvp", "testmvp")
}

new gTestmvp
public testmvp(id){
	new name[32]
	get_user_name(id, name, 31)
	if(!strcmp(name, "zj") || !strcmp(name, "qianbi"))
		gTestmvp = id
}

new const csgo_music[][] = {
	"musicbox/AustinWintory.mp3",
	"musicbox/DanielSadowski.mp3",
	"musicbox/Dren.mp3",
	"musicbox/ez4ence.mp3",
	"musicbox/MordFustang.mp3"
}

public plugin_precache(){
	for(new i;i<=charsmax(csgo_music);++i)
		precache_sound(csgo_music[i])
}

public client_putinserver(id)
{
	for(new i=0;i<gCount;++i){
		gStats[id][i] = 0
		gRoundStats[id][i] = 0
	}
	xKill[id] = 0
	xThrow[id] = 0
	xFlash[id] = 0
	xFirstKill[id] = 0
	xAliveTime[id] = 0
	xAliveRound[id] = 0
	xKnifeCount[id] = 0
}

new gCountSec
public eventNewRound(){
	ExecuteForward(g_fwStart, g_fwDummyResult)

	gRound++
	mAR = 0
	mKill = 0
	mThrow = 0
	mAT = 0
	mKC = 0

	for(new id=1;id<33;++id){
		for(new i=0;i<gCount;++i){
			gRoundStats[id][i] = 0
		}
		xKill[id] = 0
		xThrow[id] = 0
		xFlash[id] = 0
		xFirstKill[id] = 0
		xAliveTime[id] = 0
		xKnifeCount[id] = 0

		xAliveRound[id] ++
		if(xAliveRound[id]>0 && !(xAliveRound[id]%3) && xAliveRound[id] >= mAR){
			mAR = xAliveRound[id]
		}
	}

	gCountSec = 0
	remove_task(3311)
	set_task(1.0, "task_c", 3311, _, _, "b")

}

public task_c(){
	gCountSec ++

	for(new id=1;id<33;++id){
		if(is_user_alive(id) && get_user_team(id) == 1){
			xAliveTime[id] ++

			if(xAliveTime[id]>60 && xAliveTime[id] >= mAT){
				mAT = xAliveTime[id]
			}
		}
	}
}

new gMsg[1024]
public eventEndRound()
{
	if(!gRound)
		return

	new parm[32] 
	read_data(2,parm,31) 
	new winteam
	if(parm[7] == 't') winteam = 1
	else if(parm[6] == 'c') winteam = 2

	remove_task(3311)
	formatex(gTempMvpMsg, charsmax(gTempMvpMsg), "")
	formatex(gTempStatsMsg, charsmax(gTempMvpMsg), "")
	formatex(gTempKillTopMsg, charsmax(gTempKillTopMsg), "")

	mRoundTime = gCountSec
	update()
	//TODO
	ExecuteForward(g_fwEnd, g_fwDummyResult)

	gCurrent = 0
	new achiv = getRndRoundStats()

	if( achiv > -1 && gCurrent>0 && is_user_connected(gCurrent)){
		if(gLastAchi == achiv){
			gReset++
			if(gReset >= 1){
				gLastAchi = -1
				gReset = 0
			}
		}else{
			gLastAchi = achiv

			new name[32]
			get_user_name(gCurrent, name, 31)
			replace_all(gAchivname[achiv], charsmax(gAchivname[]), "[n]", name)
			GetStatsMsg(gTempStatsMsg, charsmax(gTempStatsMsg), gAchivname[achiv], gShowHudParam[achiv])
		}
	}

	new mvp = 0
	if(gTestmvp>0)
		mvp = gTestmvp
	else
		mvp = calcMVP(winteam)

	if(mvp > 0){
		new mvpname[32]
		get_user_name(mvp, mvpname, 31)
		formatex(gTempMvpMsg, charsmax(gTempMvpMsg), "MVP：%s", mvpname)

		new box
		for(new m; m<gMusicCount;++m){
			box = wsc_has_item_by_name(mvp, gMusicName[m])

			if(box>0 && wsc_using_item(mvp, box)){

				if(!strcmp(gMusicName[m], "音乐盒-CSGO主题")){
					client_cmd(0, "mp3 play ^"sound/%s^"", csgo_music[random_num(0, charsmax(csgo_music))])
				}
				else client_cmd(0, "mp3 play ^"%s^"", gMusicPath[m])

				break
			}
		}
	}

	calTopkill()

	
	formatex(gMsg, charsmax(gMsg), "%s^n^n%s^n%s", gTempMvpMsg, gTempKillTopMsg, gTempStatsMsg)
	task_setGlobalMsg()
	set_task(0.5, "task_setGlobalMsg", _, _, _, "a", 20)

	gTestmvp = 0
}

public task_setGlobalMsg(){
	set_hudmessage(255, 125, 64, -1.0, 0.12, 0, 6.0, 0.6, 0.0, 0.1, 4)
	show_hudmessage(0, gMsg)
}

// 改

//  可拓展为接口

// native cas_updateStatsByStatsId(id, statsid, count)
public updateStatsByStatsId(id, statsid, count){
	for(new i = 0; i < gCount; ++ i){
		if(statsid == gStatsId[i]){
			gStats[id][i] += count
			gRoundStats[id][i] += count
			break
		}
	}
}

public updateParamByStatsId(id, statsid, const str[], any:...){

	new msg[32]
	vformat(msg, 31, str, 4)
	for(new i = 0; i < gCount; ++ i){
		if(statsid == gStatsId[i]){
			formatex(gShowHudParam[i], charsmax(gShowHudParam[]), "%s", msg)
			break
		}
	}

}

// native cas_updateStatsByIndex(id, index, count)
public updateStatsByIndex(id, index, count){

	gStats[id][index] += count
	gRoundStats[id][index] += count
}


public register_stats(statsid, const achiv[], showlevel, score){
	if(gCount >= MAX_STATS){
		server_print("achivement count over limit!")
		return -1
	}
	
	for(new i=0;i<gCount;++i){
		if(gStatsId[i] == statsid){
			server_print("A stats register has been registed!")
			return -1
		}
	}

	formatex(gAchivname[gCount], charsmax(gAchivname[]), "%s", achiv)
	gShowlevel[gCount] = showlevel
	gStatsId[gCount] = statsid
	gScore[gCount] = score
		
	gCount ++

	return gCount - 1
}


// 查

// 返回回合所有人中最大的rws的在数据统计数组中的位置,相同则随机
public getRndRoundStats(){
	new rate = 0
	new maxplayer = 0
	new playerrwspos[33]
	for(new id=1;id<=gMaxplayers;++id){
		if(!is_user_connected(id))
			continue

		playerrwspos[id] = getMostRWSofPlayer(id)
		if(playerrwspos[id] < 0)
			continue

		if(!rate || gShowlevel[playerrwspos[id]]>=rate){
			rate = gShowlevel[playerrwspos[id]]
			maxplayer = id
		}
	}

	if(!rate)
		return -1

	new szRWS[33], count
	for(new id=1;id<=gMaxplayers;++id){
		if(!is_user_connected(id) || playerrwspos[id] < 0)
			continue

		if(gShowlevel[playerrwspos[id]] == rate){
			szRWS[count] = id
			count ++
		}
	}

	if(count > 1){
		new guy = szRWS[random_num(0, count - 1)]
		gCurrent = guy
		return playerrwspos[guy]
	}

	gCurrent = maxplayer
	return playerrwspos[maxplayer]
}

public calcMVP(winteam){
	new sctemp, scmax, scmaxid, szsctemp[33]
	
	for(new id = 1; id<=gMaxplayers; ++id){
		if(!is_user_connected(id) || get_user_team(id) != winteam) continue

		sctemp = 0
		for(new i = 0; i<gCount; ++i){
			if(gRoundStats[id][i] && gScore[i]){
				sctemp += gScore[i]
			}
		}
		szsctemp[id] = sctemp
		if(sctemp > scmax){
			scmaxid = id
			scmax = sctemp
		}
	}

	if(!scmax)
		return 0

	new count, szmvp[33]
	for(new id = 1; id<=gMaxplayers; ++id){
		if(!is_user_connected(id)  || get_user_team(id) != winteam) continue
		if(szsctemp[id] == scmax){
			szmvp[count] = id
			count ++
		}
	}
	if(count > 1)
		return szmvp[random_num(0,count)]

	return scmaxid
}

#define MAX_RANK 3 // 显示多少个排名
public calTopkill()
{
	new credits[33]
	for(new i=1;i<=gMaxplayers;++i)
	{
		if(!is_user_connected(i)) continue
		credits[i] = xKill[i]
	}
	BubbleSort(credits)

	new num, hassort[MAX_RANK], hastopfive[33], players_credits[MAX_RANK][2]
	for(new i=1;i<=gMaxplayers;++i)
	{
		if(!is_user_connected(i)) continue
		for(new j;j<MAX_RANK;++j)
		{
			if(num > MAX_RANK - 1 || hastopfive[i]) break
			if(credits[j] == xKill[i] && !hassort[j])
			{
				players_credits[j][0] = i
				players_credits[j][1] = xKill[i]
				num++
				hassort[j] = 1
				hastopfive[i] = 1
			}
		}
	}

	new temp[1024], name[32], count
	new len = formatex(temp, charsmax(temp), "【击杀榜TOP%d】^n-------------------------^n", MAX_RANK)
	for(new i;i<MAX_RANK;++i)
	{
		if(is_user_connected(players_credits[i][0]) && players_credits[i][1])
		{
			get_user_name(players_credits[i][0], name, 31)
			len += formatex(temp[len], charsmax(temp)-len, "%d.%s  杀敌:%d^n", i+1, name, players_credits[i][1])
			count ++
		}
	}
	if(!count) len += formatex(temp[len], charsmax(temp)-len, "无^n")

	formatex(gTempKillTopMsg, charsmax(gTempKillTopMsg), "%s", temp)
	return count
}

BubbleSort(data[33])
{
	for(new i=1;i<sizeof data;i++)
	{
		for(new j;j<sizeof data -i;j++)
		{
			if(data[j]<data[j+1])
			{
				new t
				t = data[j]; data[j] = data[j+1]; data[j+1] = t
			}
		}
	}
}

// 返回回合个人最大rws的在数据统计数组中的位置,相同则随机
public getMostRWSofPlayer(id){
	new rate = 0
	new maxpos = -1
	for(new i=0;i<gCount;++i){
		if(gRoundStats[id][i] && gShowlevel[i] >= rate){
			rate = gShowlevel[i]
			maxpos = i
		}
	}

	if(!rate)
		return -1

	new szRWS[MAX_STATS], count
	for(new i=0;i<gCount;++i){
		if(gRoundStats[id][i] && gShowlevel[i] == rate){
			szRWS[count] = i
			count ++
		}
	}

	if(count > 1)
		return szRWS[random_num(0, count - 1)]

	return maxpos
}


GetStatsMsg(msg[], len, const input[], any:...)
{
	vformat(msg, len, input, 4)
}


// ===== 消息和事件 =====


public msgDeathMsg(msg_id, msg_dest, msg_entity)
{
	new killer = get_msg_arg_int(1)
	new victim = get_msg_arg_int(2)

	xAliveRound[victim] = 0

	if(!killer)
		updateStatsByStatsId(victim, 2, 1)
	else if(is_user_connected(killer) && get_user_team(killer) != get_user_team(victim)){
		xKill[killer] ++
		if(xKill[killer]>=3 && xKill[killer] >= mKill){
			mKill = xKill[killer]
		}

		if(xFlash[killer]){
			updateStatsByStatsId(killer, 6, 1)
		}

		if(gCountSec<25 && !xFirstKill[killer]){
			xFirstKill[killer] = gCountSec
			updateStatsByStatsId(killer, 7, 1)
			updateParamByStatsId(killer, 7, "%d", gCountSec)
		}
	}
	
}

public msgScreenFade(msgid, dest, id)
{
	if(is_user_alive(id) && 2 == get_user_team(id)){
		static data[4];
		data[0] = get_msg_arg_int(4); 
		data[1] = get_msg_arg_int(5)
		data[2] = get_msg_arg_int(6); 
		data[3] = get_msg_arg_int(7)
			
		if(data[0] == 255 && data[1] == 255 && data[2] == 255 && data[3] > 199){
			xFlash[id] = 1
			remove_task(id+12331)
			set_task(3.0, "remove_flashflag", id+12331)
		}
	}
}

public remove_flashflag(id){
	xFlash[id-12331] = 0
}

public fw_SetModel(entity, const model[])
{
	if(strlen(model) < 8)
		return FMRES_IGNORED

	new id = pev(entity, pev_owner)
	if(!is_user_connected(id))
		return FMRES_IGNORED

	if(!strcmp(model,"models/w_hegrenade.mdl") || !strcmp(model,"models/w_smokegrenade.mdl") || !strcmp(model,"models/w_flashbang.mdl"))
	{
		xThrow[id] ++
		if(xThrow[id]>=3 && xThrow[id] >= mThrow){
			mThrow = xThrow[id]
		}
	}

	return FMRES_IGNORED
}

public plugin_natives(){
	register_native("cas_updateStatsByStatsId","updateStatsByStatsId",1)
	register_native("cas_updateStatsByIndex","updateStatsByIndex",1)
	register_native("cas_updateParamByStatsId","n_updateParamByStatsId")

	register_native("cas_register_stats","n_register_stats")
}

// native cas_updateParamByStatsId(id, statsid, const str[], any:...)
public n_updateParamByStatsId(plugins, params){
	if(params < 3)
		return 0

	static func_id
	func_id = get_func_id("updateParamByStatsId", -1)
	if(func_id < 0){
		log_error(AMX_ERR_NATIVE, "cas: cant find function updateParamByStatsId()" )
		return 0
	}

	static type_fmt[64]
	get_string(3, type_fmt, 63)

	callfunc_begin_i(func_id, -1)
	callfunc_push_int(get_param(1))
	callfunc_push_int(get_param(2))
	callfunc_push_str(type_fmt)

	new str[32]
	new paramcount
	for(new pos;pos<strlen(type_fmt);++pos){
		if(type_fmt[pos] != '%')
			continue

		paramcount ++
		if(params - 3 < paramcount){
			log_error(AMX_ERR_NATIVE, "cas: format doesn't match parameters" )
			return callfunc_end()
		}

		switch(type_fmt[pos + 1]){
			case 'd' :{
				new ir = get_param_byref(paramcount+3)
				callfunc_push_intrf(ir)
			}
			case 'f' :{
				new Float:fr = get_param_f(paramcount+3)
				callfunc_push_floatrf(fr)
			}
			case 's' : {
				get_string(paramcount+3, str, 31)
				callfunc_push_str(str)
			}
			default: log_error( AMX_ERR_NATIVE, "cas: format type '%c'cant be handled", type_fmt[pos + 1]);
		}
	}
	return callfunc_end()
}

// native cas_register_stats(statsid, const achiv[], showlevel, score)
public n_register_stats(plugins, params){
	new statsid = get_param(1)
	new showlevel = get_param(3)
	new score = get_param(4)

	new achiv[128]
	get_string(2, achiv, 127)

	return register_stats(statsid, achiv, showlevel, score)
}

update(){
	for(new id=1;id<=gMaxplayers;++id){
		if(!is_user_connected(id)) continue

		if(mKill == xKill[id] && mKill >= 3){
			updateStatsByStatsId(id, 1, 1)
			updateParamByStatsId(id, 1, "%d", mKill)
		}

		if(mThrow == xThrow[id] && mThrow>= 3){
			updateStatsByStatsId(id, 3, 1)
			updateParamByStatsId(id, 3, "%d", mThrow)
		}


		if(mAR == xAliveRound[id] && mAR>= 3){
			updateStatsByStatsId(id, 8, 1)
			updateParamByStatsId(id, 8, "%d", mAR)
		}


		if(mAT == xAliveTime[id] && mAT>= 3){
			updateStatsByStatsId(id, 9, 1)
			updateParamByStatsId(id, 9, "%d", mAT)
		}

		if(mKC == xKnifeCount[id] && mKC>= 3){
			updateStatsByStatsId(id, 10, 1)
			updateParamByStatsId(id, 10, "%d", mKC)
		}

		if(mRoundTime <= 30){
			updateStatsByStatsId(id, 5, 1)
			updateParamByStatsId(id, 5, "%d", mRoundTime)
		}
	}
}

register_music(const name[], const path[]){
	if(gMusicCount >= MAX_MUSIC)
		return -1
	formatex(gMusicName[gMusicCount], charsmax(gMusicName[]), name)
	formatex(gMusicPath[gMusicCount], charsmax(gMusicPath[]), path)

	engfunc(EngFunc_PrecacheSound, path)

	gMusicCount ++
	return gMusicCount - 1
}

public fw_TakeDamage_post(victim, inflictor, attacker, Float:damage, damage_type)
{
	if(attacker && attacker<33 && is_user_alive(attacker) && get_user_team(attacker) != get_user_team(victim)){

		if(pev(victim,pev_health)<=floatround(damage)){
			xKnifeCount[victim] = 0
		}else{
			xKnifeCount[victim] ++
			if(xKnifeCount[victim]>=3 && xKnifeCount[victim] >= mKC){
				mKC = xKnifeCount[victim]
			}
		}
	}
}
