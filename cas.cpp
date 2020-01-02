// SQL : nick statsid scount
// AMXX : statsid achiv showlevel

#include<amxmodx>
#include<fakemeta>

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

new xKill[33], mKill
new xThrow[33], mThrow
new xFlash[33]
new xFirstKill[33]

new gRound
public plugin_init(){
	register_plugin("CS ACHIVEMNT SYSTEM", "1.0", "zhiJiaN")
	register_logevent("eventEndRound"  ,2,"0=World triggered", "1=Round_Draw", "1=Round_End");
	register_event("HLTV", "eventNewRound", "a", "1=0", "2=0");
	register_message(get_user_msgid("DeathMsg"), "msgDeathMsg")
	register_message(get_user_msgid("ScreenFade"), "msgScreenFade");
	register_forward(FM_SetModel, "fw_SetModel")

	register_stats(1, "%s消灭了%s个敌人!", 50, 10)
	register_stats(2, "%s验证了万有引力定律!", 46, -2)
	register_stats(3, "%s丢出了%s个投掷物!", 47, 1)
	register_stats(4, "%s使用手雷解救了被冰冻的队友!", 47, 3)
	register_stats(5, "%s使用冰冻弹冻住了%s个敌人!", 47, 2)
	register_stats(6, "%s在被闪光弹致盲时击杀了敌人!", 46, 1)
	register_stats(7, "%s在本回合开始%d秒后第一个杀人!", 47, 1)
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
}

new gCountSec
public eventNewRound(){
	gRound++

	for(new id=1;id<33;++id){
		for(new i=0;i<gCount;++i){
			gRoundStats[id][i] = 0
		}
		xKill[id] = 0
		xThrow[id] = 0
		xFlash[id] = 0
		xFirstKill[id] = 0
	}
	mKill = 0
	mThrow = 0

	gCountSec = 0
	remove_task(3311)
	set_task(1.0, "task_c", 3311, _, _, "b")
}

public task_c(){
	gCountSec ++
}

public eventEndRound()
{
	if(!gRound)
		return

	updateKill()
	updateThrow()
	//TODO

	new achiv = getRndRoundStats()

	if( achiv > -1 && is_user_connected(gCurrent)){
		if(gLastAchi == achiv){
			gReset++
			if(gReset >= 1){
				gLastAchi = -1
				gReset = 0
			}
			return
		}

		gLastAchi = achiv

		new name[32]
		get_user_name(gCurrent, name, 31)

		client_print(0,print_chat,"acv:%d,%s",achiv,gShowHudParam[achiv])
		ShowMVP(gAchivname[achiv], name, gShowHudParam[achiv])
	}

	 
}


// 改

//  可拓展为接口
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

// 内部用
public updateStatsByIndex(id, index, count){

	gStats[id][index] += count
	gRoundStats[id][index] += count
}

public register_stats(statsid, const achiv[], showlevel, score){
	if(gCount >= MAX_STATS){
		server_print("achivement count over limit!")
		return -1
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
	for(new id=1;id<=get_maxplayers();++id){
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
	for(new id=1;id<=get_maxplayers();++id){
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


ShowMVP(const input[], any:...)
{
	new msg[191]
	vformat(msg, 190, input, 2)

	set_hudmessage(255, 125, 64, -1.0, 0.25, 0, 6.0, 4.5, 0.3, 0.1, 1)
	show_hudmessage(0, msg)
}


// ===== 消息和事件 =====


public msgDeathMsg(msg_id, msg_dest, msg_entity)
{
	new killer = get_msg_arg_int(1)
	new victim = get_msg_arg_int(2)

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

		if(gCountSec<25){
			remove_task(3311)
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


updateKill(){
	for(new id=1;id<=get_maxplayers();++id){
		if(!is_user_connected(id)) continue

		if(mKill == xKill[id] && mKill >= 3){
			updateStatsByStatsId(id, 1, 1)
			updateParamByStatsId(id, 1, "%d", mKill)
		}
	}
}

updateThrow(){
	for(new id=1;id<=get_maxplayers();++id){
		if(!is_user_connected(id)) continue

		if(mThrow == xThrow[id] && mThrow>= 3){
			updateStatsByStatsId(id, 3, 1)
			updateParamByStatsId(id, 3, "%d", mThrow)
		}
	}
}