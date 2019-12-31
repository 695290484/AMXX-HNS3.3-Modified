#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#tryinclude <fakemeta_util>

#if !defined _fakemeta_util_included
        #assert Fakemeta Utilities function library required! Read the below instructions:   \
                1. Download it at forums.alliedmods.net/showthread.php?t=28284   \
                2. Put it into amxmodx/scripting/include/ folder   \
                3. Compile this plugin locally, details: wiki.amxmodx.org/index.php/Compiling_Plugins_%28AMX_Mod_X%29   \
                4. Install compiled plugin, details: wiki.amxmodx.org/index.php/Configuring_AMX_Mod_X#Installing
#endif
#define PLUGIN 	"Hide N Seek"
#define VERSION "3.3"
#define AUTHOR 	"Jon"
#define HUDCHANNEL 1

#define BIT_BUYZONE (1<<0)
#define CS_GET_USER_MAPZONES(%1) get_pdata_int(%1, OFFSET, OFFSET_LINUX_DIFF)
#define CS_SET_USER_MAPZONES(%1,%2) set_pdata_int(%1, OFFSET, %2, OFFSET_LINUX_DIFF)
#define OFFSET_32BIT 235
#define OFFSET_64BIT 268
#define OFFSET_LINUX_DIFF 5
//#define PROCESSOR_TYPE 0
#if !defined PROCESSOR_TYPE // is automatic 32/64bit processor detection?
	#if cellbits == 32 // is the size of a cell 32 bits?
		// then considering processor as 32 bit
		#define OFFSET OFFSET_32BIT
	#else // in other case considering the size of a cell as 64 bits
		// and then considering processor as 64 bit
		#define OFFSET OFFSET_64BIT
	#endif
#else // processor type is specified by PROCESSOR_TYPE define
	#if PROCESSOR_TYPE == 0 // 32bit processor defined
		#define OFFSET OFFSET_32BIT
	#else // considering that defined 64bit processor
		#define OFFSET OFFSET_64BIT
	#endif
#endif

new gCvarEnabled;
new gCvarGameName;
new gCvarSkyName;
new gCvarLights;
new gCvarVoice;
new gCvarTimer;
new gCvarSwitch;
new gCvarSlash;
new gCvarFootsteps;
new gCvarNoFlash;
new gCvarRemoveWeapons;
new gCvarRemoveObjects;
new gCvarBlockKill;
new gCvarBlockChooseTeam;
new gCvarHudColor;
new gCvarHudPosition;
new gCvarFadeColor;
new gCvarTextColor;
new gCvarHidersKnife;
new gCvarHidersArmor;
new gCvarHidersFlashbangs;
new gCvarHidersSmokegrenade;
new gCvarHidersHegrenade;
new gCvarSeekersArmor;
new gCvarSeekersFlashbangs;
new gCvarSeekersSmokegrenade;
new gCvarSeekersHegrenade;
new gCvarMsgTimer;
new gCvarMsgTimesUp;
new gCvarMsgHiders;
new gCvarMsgSeekers;
new gCvarMsgSwitch;

new gTimer;
new gHostage;
new gBuyzone;
new gFakeEnt;
new gHudSyncObj;
new gRound;
new gMaxPlayers;
new gSwitch;
new gSlash;

new gMsgSendAudio;
new gMsgHudTextArgs;
new gMsgTextMsg;
new gMsgStatusIcon;
new gMsgScreenFade;
new gMsgTeamInfo;
new gMsgSayText;

enum {TA_T, TA_CT, TA_SIZE}

new const gIconC4[] = "c4";
new const gWeaponC4[] 	= "weapon_c4";
new const gSpawnedWithBomb[] = "triggered ^"Spawned_With_The_Bomb^"";
new const gHaveBomb[] = "#Hint_you_have_the_bomb";
new const gHostagesRescued[] = "#Hostages_Not_Rescued";
new const gTeamNames[TA_SIZE][] = {"TERRORIST", "CT"};
new const gTeamNames2[][] = {"", "TERRORIST", "CT", "SPECTATOR"}
new const gCounterSounds[][] = {"zero","one","two","three","four","five","six","seven","eight","nine","ten","eleven","twelve","thirteen","fourteen","fifteen"}
new const gEntityClassNames[][] = {"func_breakable", "func_door_rotating", "func_door", "func_vip_safetyzone", "func_escapezone", "hostage_entity", "monster_scientist", "func_bomb_target", "info_bomb_target"}

new Float:gBuyzoneMin[3] = {-8192.0, -8192.0, -8192.0}
new Float:gBuyzoneMax[3] = {-8191.0, -8191.0, -8191.0}
new Float:gHostageOrigin[3] = {0.0, 0.0, -55000.0}
new Float:gHostageMin[3] = {-1.0, -1.0, -1.0}
new Float:gHostageMax[3] = {1.0, 1.0, 1.0}

new bool:gIsConnected[33];
new bool:gRestartAttempt[33];
new bool:gAllowSlash;

new bool:gRoundendFight;

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	register_cvar("hns_version", VERSION, FCVAR_SERVER)
	
	gCvarEnabled = register_cvar("hns_enabled", "1")
	
	if(!get_pcvar_num(gCvarEnabled))
		return;
	
	new GameNameCvarValue[96];
	format(GameNameCvarValue, 95, "Hide N Seek %s", VERSION)
	
	gCvarGameName = register_cvar("hns_gamename", GameNameCvarValue)
	gCvarSkyName = register_cvar("hns_skyname", "backalley")
	gCvarLights = register_cvar("hns_lights", "m")
	gCvarVoice = register_cvar("hns_voice", "vox")
	gCvarTimer = register_cvar("hns_timer", "10")
	gCvarSwitch = register_cvar("hns_switch", "5")
	gCvarSlash = register_cvar("hns_slash", "3")
	gCvarNoFlash = register_cvar("hns_noflash", "1")
	gCvarFootsteps = register_cvar("hns_footsteps", "1")
	gCvarRemoveWeapons = register_cvar("hns_removeweapons", "1")
	gCvarRemoveObjects = register_cvar("hns_removeobjects", "1")
	gCvarBlockKill = register_cvar("hns_block_kill", "1")
	gCvarBlockChooseTeam = register_cvar("hns_block_chooseteam", "1")
	gCvarHudColor = register_cvar("hns_hudcolor", "0 100 255")
	gCvarHudPosition = register_cvar("hns_hudposition", "-1.0 0.85")
	gCvarFadeColor = register_cvar("hns_fadecolor", "100 120 150 225")
	gCvarTextColor = register_cvar("hns_textcolor", "red")
	gCvarHidersKnife = register_cvar("hns_hiders_knife", "0")
	gCvarHidersArmor = register_cvar("hns_hiders_armor", "100")
	gCvarHidersFlashbangs = register_cvar("hns_hiders_flashbangs", "2")
	gCvarHidersSmokegrenade = register_cvar("hns_hiders_smokegrenade", "1")
	gCvarHidersHegrenade = register_cvar("hns_hiders_hegrenade", "0")
	gCvarSeekersArmor = register_cvar("hns_seekers_armor", "0")
	gCvarSeekersFlashbangs = register_cvar("hns_seekers_flashbangs", "0")
	gCvarSeekersSmokegrenade = register_cvar("hns_seekers_smokegrenade", "0")
	gCvarSeekersHegrenade = register_cvar("hns_seekers_hegrenade", "0")
	gCvarMsgTimer = register_cvar("hns_msg_timer", "seconds to hide..")
	gCvarMsgTimesUp = register_cvar("hns_msg_timesup", "Ready or not, time's up!")
	gCvarMsgHiders = register_cvar("hns_msg_hiders", "Hiders win!")
	gCvarMsgSeekers = register_cvar("hns_msg_seekers", "Seekers win!")
	gCvarMsgSwitch = register_cvar("hns_msg_switch", "rounds have passed, switching teams..")
	
	gMaxPlayers = get_maxplayers();
	gSwitch = get_pcvar_num(gCvarSwitch)
	gSlash = get_pcvar_num(gCvarSlash)
	gMsgSendAudio = get_user_msgid("SendAudio")
	gMsgHudTextArgs = get_user_msgid("HudTextArgs")
	gMsgTextMsg = get_user_msgid("TextMsg")
	gMsgStatusIcon = get_user_msgid("StatusIcon")
	gMsgScreenFade = get_user_msgid("ScreenFade")
	gMsgTeamInfo = get_user_msgid("TeamInfo")
	gMsgSayText = get_user_msgid("SayText")
	gFakeEnt = fm_create_entity("info_target")
	
	register_logevent("eventStartRound",2,"0=World triggered", "1=Round_Start");
	register_logevent("eventEndRound"  ,2,"0=World triggered", "1=Round_Draw", "1=Round_End");
	register_event("HLTV", "eventNewRound", "a", "1=0", "2=0");
	register_event("TextMsg", "eventRestartAttempt", "a", "2=#Game_will_restart_in");
	register_event("ResetHUD", "eventResetHud", "be");
	register_event("DeathMsg", "eventDeathMsg", "a")
	
	register_message(gMsgHudTextArgs, "msgHudTextArgs");
	register_message(gMsgStatusIcon, "msgStatusIcon");
	register_message(gMsgSendAudio,"msgSendAudio");
	register_message(gMsgTextMsg,"msgTextMsg");
	register_message(gMsgScreenFade, "msgScreenFade");
	
	register_forward(FM_PlayerPreThink,"fwdPlayerPreThink");
	register_forward(FM_PlayerPostThink, "fwdPlayerPostThink")
	register_forward(FM_CmdStart, "fwdCmdStart");
	register_forward(FM_Think,"fwdThink");
	register_forward(FM_Touch, "fwdTouch");
	register_forward(FM_AlertMessage, "fwdAlertMessage");
	register_forward(FM_CreateNamedEntity, "fwdCreateNamedEntity");
	register_forward(FM_GetGameDescription,"fwdGetGameDescription");
	register_forward(FM_ClientKill, "fwdClientKill");
	
	register_clcmd("chooseteam", "clcmd_chooseteam")
	register_clcmd("fullupdate", "clcmd_fullupdate")
	register_clcmd("buy", "clcmd_buy");
	register_clcmd("buyequip", "clcmd_buy");
	
	set_task(1.0, "SetSky")
	set_task(1.0, "SetLights")
}

public plugin_cfg()
{
	new file[64]; 
	
	get_configsdir(file, 63)
	format(file, 63, "%s/hns.cfg", file)
	
	if(file_exists(file)) 
		server_cmd("exec %s", file), server_exec()
}

public plugin_precache() 
{
	gHudSyncObj = CreateHudSyncObj();
	
	gHostage = fm_create_entity("hostage_entity");
	engfunc(EngFunc_SetOrigin, gHostage, gHostageOrigin);
	engfunc(EngFunc_SetSize, gHostage, gHostageMin, gHostageMax);
	dllfunc(DLLFunc_Spawn, gHostage);
	
	gBuyzone =  fm_create_entity("func_buyzone");
	engfunc(EngFunc_SetSize, gBuyzone, gBuyzoneMin, gBuyzoneMax)
	dllfunc(DLLFunc_Spawn, gBuyzone)
}	

public SetSky()
{
	set_cvar_num("sv_skycolor_r", 0)
	set_cvar_num("sv_skycolor_g", 0)
	set_cvar_num("sv_skycolor_b", 0)
	
	new SkyName[32]
	get_pcvar_string(gCvarSkyName, SkyName, 31)
	
	if(strlen(SkyName) > 0)
		server_cmd("sv_skyname %s", SkyName)
}

public SetLights()
{
	new Lights[32]
	get_pcvar_string(gCvarLights, Lights, 31)
	
	if(strlen(Lights) > 0)
		engfunc(EngFunc_LightStyle, 0, Lights)
		
	set_task(10.0, "SetLights")
}

public eventStartRound()
{
	if(gRound == 0 || !PlayersInBothTeams())
		return PLUGIN_CONTINUE;
		
	gTimer = get_pcvar_num(gCvarTimer)
	set_pev(gFakeEnt, pev_nextthink, get_gametime() + 0.09);
		
	if(gSlash <= 0)
		gAllowSlash = true;
		
	return PLUGIN_CONTINUE;
}


public eventEndRound()
{
	if(gRound == 0)
		return PLUGIN_CONTINUE;
		
	new WinMsg[192], HudR, HudG, HudB, Float:HudX, Float:HudY;
		
	switch(GetWinningTeam())
	{
		case 1:
		{
			get_pcvar_string(gCvarMsgHiders, WinMsg, 191)
			GetHudColor(HudR, HudG, HudB)
			GetHudPosition(HudX, HudY)
			
			set_hudmessage(HudR, HudG, HudB, HudX, HudY, 0, 0.0, 5.0, 0.0, 0.0, HUDCHANNEL);
			ShowSyncHudMsg(0, gHudSyncObj, "%s", WinMsg)
			
			gSlash--;
			gSwitch--;
			client_cmd(0, "spk radio/terwin.wav")
		}
		
		case 2: 
		{
			get_pcvar_string(gCvarMsgSeekers, WinMsg, 191)
			GetHudColor(HudR, HudG, HudB)
			GetHudPosition(HudX, HudY)
			
			set_hudmessage(HudR, HudG, HudB, HudX, HudY, 0, 0.0, 5.0, 0.0, 0.0, HUDCHANNEL);
			ShowSyncHudMsg(0, gHudSyncObj, "%s", WinMsg)
			
			SwapTeams();
			gAllowSlash = false;
			gSwitch = get_pcvar_num(gCvarSwitch)
			gSlash = get_pcvar_num(gCvarSlash)
			client_cmd(0, "spk radio/ctwin.wav")
		}
		
		case 3:
		{
			get_pcvar_string(gCvarMsgSwitch, WinMsg, 191)
			GetHudColor(HudR, HudG, HudB)
			GetHudPosition(HudX, HudY)
			
			set_hudmessage(HudR, HudG, HudB, HudX, HudY, 0, 0.0, 5.0, 0.0, 0.0, HUDCHANNEL);
			ShowSyncHudMsg(0, gHudSyncObj, "%d %s", get_pcvar_num(gCvarSwitch), WinMsg)
				
			SwapTeams();
			gAllowSlash = false;
			gSwitch = get_pcvar_num(gCvarSwitch)
			gSlash = get_pcvar_num(gCvarSlash)
			client_cmd(0, "spk radio/terwin.wav")
		}
	}
	
	return PLUGIN_CONTINUE;
}

new changeroundtime
public eventNewRound()
{	
	if(get_pcvar_num(gCvarRemoveObjects) && gRound == 0)
		RemoveEntities();

	gRound++
	gRoundendFight = false

	new Float:fRoundtime = get_cvar_float("mp_roundtime")*60.0
	new Float:fFreezetime = get_cvar_float("mp_freezetime")

	remove_task(1133)
	set_task(fRoundtime+fFreezetime-16.0, "task_redraw", 1133)

	new num = get_playersnum()
	if(num > 11)
	{
		set_cvar_float("mp_roundtime", 2.5)
		if(!changeroundtime)
		{
			changeroundtime = 1
			client_color(0, "/y* /g服务器人数达到/y12/g人，回合时间调整为/y2.5/g分钟!")
		}
	}
	else
	{
		set_cvar_float("mp_roundtime", 3.0)
		if(changeroundtime)
		{
			changeroundtime = 0
			client_color(0, "/y* /g服务器人数少于/y12/g人，回合时间调整为/y3/g分钟!")
		}
	}

	return PLUGIN_CONTINUE;
}

public task_redraw()
{
	gRoundendFight = true
	client_color(0, "/y* /ctr回合快要结束了，现在T允许使用刀子！！！")
}

public eventRestartAttempt() 
{
	new players[32], num;
	get_players(players, num, "a");
	
	for (new i; i < num; ++i)
		gRestartAttempt[players[i]] = true;
}

public eventResetHud(id) 
{
	if(gRestartAttempt[id]) 
	{
		gRestartAttempt[id] = false;
		return;
	}
	
	eventPlayerSpawn(id);
}

public eventPlayerSpawn(id) 
	set_task(0.1, "GiveItems", id);

public eventDeathMsg()
{
	new id = read_data(2)
	
	if(gTimer > 0 && get_user_team(id) == 2)
		set_pev(id, pev_flags, pev(id, pev_flags) & ~FL_FROZEN);
}

public GiveItems(id)
{
	if(!is_user_connected(id))
		return;
		
	cs_reset_user_model(id)
	fm_strip_user_weapons(id)
	
	switch(get_user_team(id))
	{
		case 1:
		{
			if(get_pcvar_num(gCvarHidersKnife))
				fm_give_item(id, "weapon_knife")
				
			if(get_pcvar_num(gCvarHidersFlashbangs))
			{
				fm_give_item(id, "weapon_flashbang")
				cs_set_user_bpammo(id, CSW_FLASHBANG, get_pcvar_num(gCvarHidersFlashbangs))
			}
			
			if(get_pcvar_num(gCvarHidersSmokegrenade))
				fm_give_item(id, "weapon_smokegrenade")
				
			if(get_pcvar_num(gCvarHidersHegrenade))
				fm_give_item(id, "weapon_hegrenade")
				
			if(get_pcvar_num(gCvarHidersArmor))
				cs_set_user_armor(id, get_pcvar_num(gCvarHidersArmor), CS_ARMOR_KEVLAR)

			//fm_give_item(id, "weapon_hegrenade")
		}
		
		case 2:
		{
			fm_give_item(id, "weapon_knife")
				
			if(get_pcvar_num(gCvarSeekersFlashbangs))
			{
				fm_give_item(id, "weapon_flashbang")
				cs_set_user_bpammo(id, CSW_FLASHBANG, get_pcvar_num(gCvarSeekersFlashbangs))
			}
			
			if(get_pcvar_num(gCvarSeekersSmokegrenade))
				fm_give_item(id, "weapon_smokegrenade")
				
			if(get_pcvar_num(gCvarSeekersHegrenade))
				fm_give_item(id, "weapon_hegrenade")
				
			if(get_pcvar_num(gCvarSeekersArmor))
				cs_set_user_armor(id, get_pcvar_num(gCvarSeekersArmor), CS_ARMOR_KEVLAR)
		}
	}
}

public msgSendAudio(msg_id, msg_dest, msg_entity) 
{
	static message[10];
	get_msg_arg_string( 2, message, sizeof message - 1 );
		
	switch(message[7]) 
	{
		case 'c', 't', 'r': return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

public msgTextMsg(msg_id, msg_dest, msg_entity) 
{
	static message[3];
	get_msg_arg_string( 2, message, sizeof message - 1 );
		
	switch(message[1]) 
	{
		case 'C', 'T', 'R': return PLUGIN_HANDLED;
	}
		
	static buffer[32];
	get_msg_arg_string(2, buffer, sizeof buffer - 1);
	
	if(equali(buffer, gHostagesRescued))
		return 1;
		
	return PLUGIN_CONTINUE;
}

public msgHudTextArgs() 
{
	static arg[24];
	get_msg_arg_string(1, arg, 23);
	
	if (equal(arg, gHaveBomb))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public msgStatusIcon() 
{
	if (get_msg_arg_int(1) == 0)
		return PLUGIN_CONTINUE;
	
	static arg[4];
	new icon[8];
	get_msg_arg_string(2, icon, 7)
	get_msg_arg_string(2, arg, 3);
	
	if (equal(arg, gIconC4) || equal(icon, "buyzone"))
		return PLUGIN_HANDLED;
	
	return PLUGIN_CONTINUE;
}

public msgScreenFade(msgid, dest, id)
{
	if(is_user_alive(id) && get_pcvar_num(gCvarNoFlash) == get_user_team(id))
	{
		static data[4];
		data[0] = get_msg_arg_int(4); 
		data[1] = get_msg_arg_int(5)
		data[2] = get_msg_arg_int(6); 
		data[3] = get_msg_arg_int(7)
			
		if(data[0] == 255 && data[1] == 255 && data[2] == 255 && data[3] > 199)
			return PLUGIN_HANDLED;
	}
		
	return PLUGIN_CONTINUE
}

public fwdPlayerPreThink(id) 
{
	if(!is_user_alive(id))
		return FMRES_IGNORED;
		
	if(get_pcvar_num(gCvarFootsteps) == get_user_team(id))
		set_pev(id, pev_flTimeStepSound, 999);
	
	return FMRES_IGNORED;
}

public fwdPlayerPostThink(id)
{
	if(is_user_alive(id)) 
		CS_SET_USER_MAPZONES(id, CS_GET_USER_MAPZONES(id) & ~BIT_BUYZONE)
}


public fwdCmdStart(id, handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED;
		
	static temp, weapon;
	weapon = get_user_weapon(id, temp, temp);
	
	if(weapon == CSW_KNIFE && get_user_team(id) == 1)
	{
		static button
		button = get_uc(handle, UC_Buttons);
		
		if(gRoundendFight){
			if(button & IN_ATTACK && !gAllowSlash) 
				button = (button & ~IN_ATTACK) | IN_ATTACK2;
		}else{
			if((button & IN_ATTACK))
				button &= ~IN_ATTACK
				
			if((button & IN_ATTACK2))
				button &= ~IN_ATTACK2
		}
				
		set_uc(handle, UC_Buttons, button);
		
		return FMRES_SUPERCEDE;
	}
			
	else if(weapon == CSW_KNIFE && get_user_team(id) == 2) 
	{
		static button 
		button = get_uc(handle, UC_Buttons);
					
		if(button & IN_ATTACK && !gAllowSlash) 
			button = (button & ~IN_ATTACK) | IN_ATTACK2;
		
		set_uc(handle, UC_Buttons, button);
		
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public fwdTouch(ptr, ptd) 
{
	if(!get_pcvar_num(gCvarRemoveWeapons) || !pev_valid(ptr) || !is_user_connected(ptd)) 
		return FMRES_IGNORED;
		
	new classname[32];
	pev(ptr, pev_classname, classname, 31);
			
	if(equali(classname,"weaponbox")) 
	{        
		new ents = engfunc(EngFunc_NumberOfEntities);
				
		for(new inum=0; inum <= ents; inum++) 
		{
			if(!pev_valid(inum)) 
				continue;
					
			new class[32];
			pev(inum, pev_classname, class,31)
					
			if(containi(class, "weapon_") == -1) 
				continue;
					
			new owner = pev(inum, pev_owner);
				
			if(ptr == owner)
				engfunc(EngFunc_RemoveEntity,inum);
		}
		
		engfunc(EngFunc_RemoveEntity, ptr);
		
	}
	
	else if(containi(classname,"weapon_") != -1)
		engfunc(EngFunc_RemoveEntity, ptr);
		
	return FMRES_IGNORED;
}


public fwdCreateNamedEntity(iClassname) 
{
	static szClassname[sizeof gWeaponC4 + 1];
	
	engfunc(EngFunc_SzFromIndex, iClassname, szClassname, sizeof gWeaponC4);
	
	if (equal(szClassname, gWeaponC4))
		return FMRES_SUPERCEDE;
		
	return FMRES_IGNORED;
}

public fwdAlertMessage(at_type, message[]) 
{
	if(at_type != _:at_logged)
		return FMRES_IGNORED;
	
	if(contain(message, gSpawnedWithBomb) != -1) 
	{
		static players[32], num;
		get_players(players, num, "ae", gTeamNames[TA_T]);
		
		for (new i; i < num; ++i)
			set_pev(players[i], pev_body, 0);
			
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

public fwdGetGameDescription() 
{
	new GameName[32]
	get_pcvar_string(gCvarGameName, GameName, 31);
	forward_return(FMV_STRING, GameName)
	
	return FMRES_SUPERCEDE;
}

public fwdClientKill(id)
{
	if(get_pcvar_num(gCvarBlockKill))
		return FMRES_SUPERCEDE;
	
	return FMRES_IGNORED;
}
	
public fwdThink(ent) 
{
	if(!pev_valid(ent))
		return FMRES_IGNORED;
	
	if(ent == gFakeEnt) 
		FakeFrame(ent);
	
	return FMRES_IGNORED;
}

public client_connect(id)
	gIsConnected[id] = true;
	
public client_disconnect(id)
	gIsConnected[id] = false;

public clcmd_chooseteam(id)
{
	if(get_pcvar_num(gCvarBlockChooseTeam))
		return PLUGIN_HANDLED;
		
	return PLUGIN_CONTINUE;
}

public clcmd_buy(id)
	return PLUGIN_HANDLED;
	
public clcmd_fullupdate(id)
	return PLUGIN_HANDLED_MAIN;
	
GetWinningTeam()
{
	new WinId;
	
	for(new i = 1; i <= gMaxPlayers; i++) 
	{
		if(is_user_alive(i) && get_user_team(i) == 1)
		{
			WinId = 1;
			
			if(get_pcvar_num(gCvarSwitch) && gSwitch <= 0)
				WinId = 3
			
			return WinId;
		}
		
		else if(is_user_alive(i) && get_user_team(i) == 2)
			WinId = 2;
	}
	
	return WinId;
}

PlayersInBothTeams()
{
	new Count;
	
	for(new i = 1; i <= gMaxPlayers; i++)
	{
		if(get_user_team(i) == 1) 
			Count = 1
			
		if(get_user_team(i) == 2)
			Count = 2
			
		if(Count == 2)
			return 1;
	}
	
	return 0;
}

GetHudPosition(&Float:x, &Float:y)
{
	new Position[19], PositionX[6], PositionY[6]
	
	get_pcvar_string(gCvarHudPosition, Position, 18)
	parse(Position, PositionX, 6, PositionY, 6)
	
	x = str_to_float(PositionX)
	y = str_to_float(PositionY)
}
	
GetHudColor(&r, &g, &b)
{
	new Color[16], Red[4], Green[4], Blue[4]
	get_pcvar_string(gCvarHudColor, Color, 15)	
	
	parse(Color, Red, 3, Green, 3, Blue, 3)
	r = str_to_num(Red)
	g = str_to_num(Green)
	b = str_to_num(Blue)
}

GetFadeColor(&r, &g, &b, &a)
{
	new Color[16], Red[4], Green[4], Blue[4], Alpha[4];
	get_pcvar_string(gCvarFadeColor, Color, 15)
	
	parse(Color, Red, 3, Green, 3, Blue, 3, Alpha, 3)
	r = str_to_num(Red)
	g = str_to_num(Green)
	b = str_to_num(Blue)
	a = str_to_num(Alpha)
}
	
SwapTeams()
{
	for(new i = 1; i <= gMaxPlayers; i++)
	{
		switch(get_user_team(i))
		{
			case 1: cs_set_user_team(i, 2)
			case 2: cs_set_user_team(i, 1)
		}
	}
}

FakeFrame(entid) 
{
	if(gTimer > 0)
	{
		new TimerMsg[192], HudR, HudG, HudB, Float:HudX, Float:HudY;
		get_pcvar_string(gCvarMsgTimer, TimerMsg, 31)
		GetHudColor(HudR, HudG, HudB)
		GetHudPosition(HudX, HudY)
			
		set_hudmessage(HudR, HudG, HudB, HudX, HudY, 0, 0.0, 1.0, 0.0, 0.0, HUDCHANNEL);
		ShowSyncHudMsg(0, gHudSyncObj, "%i %s", gTimer, TimerMsg);
		
		if(get_pcvar_num(gCvarTimer) <= 15)
		{
			switch(GetVoiceType())
			{
				case 1: client_cmd(0, "spk vox/%s.wav", gCounterSounds[gTimer])
				case 2: client_cmd(0, "spk fvox/%s", gCounterSounds[gTimer]);
			}
		}
			
		for(new i = 1; i <= gMaxPlayers; i++) 
		{
			if(get_user_team(i) == 2 && is_user_alive(i)) 
			{
				FadeScreen(i, 1)
				set_pev(i, pev_flags, pev(i, pev_flags) | FL_FROZEN)
				set_pev(i, pev_velocity, Float:{0.0,0.0,0.0})
			}
		}
	}
		
	else if(gTimer == 0) 
	{
		if(get_pcvar_num(gCvarTimer) > 0)
		{
			new TimesUpMsg[192], HudR, HudG, HudB, Float:HudX, Float:HudY;
			get_pcvar_string(gCvarMsgTimesUp, TimesUpMsg, 31)
			GetHudColor(HudR, HudG, HudB)
			GetHudPosition(HudX, HudY)
				
			set_hudmessage(HudR, HudG, HudB, HudX, HudY, 0, 0.0, 2.0, 0.0, 0.0, HUDCHANNEL);
			ShowSyncHudMsg(0, gHudSyncObj, "%s", TimesUpMsg);
				
			for(new i = 1; i <= gMaxPlayers; i++) 
			{
				if(get_user_team(i) == 2 && is_user_alive(i)) 
				{
					FadeScreen(i, 0)
					set_pev(i, pev_flags, pev(i, pev_flags) & ~FL_FROZEN);
				}
			}
		}
		
		if(gSlash == 0)
			PrintColor(0, "[HNS] Seekers have lost %d rounds in a row, they can now use slash!", get_pcvar_num(gCvarSlash))
	}
	
	gTimer--;
	set_pev(entid, pev_nextthink, get_gametime() + 1.0);
	return PLUGIN_HANDLED;
}
			
GetVoiceType()
{
	new Type[5]
	get_pcvar_string(gCvarVoice, Type, 4)
	
	if(equal(Type, "vox"))
		return 1;
		
	else if(equal(Type, "fvox"))
		return 2;
		
	return 0;
}

FadeScreen(id, amount)
{
	new Red, Green, Blue, Alpha
	GetFadeColor(Red, Green, Blue, Alpha)
	
	message_begin(MSG_ONE, gMsgScreenFade, {0, 0, 0}, id);
	write_short(1 << amount * 15);
	write_short(1 << amount * 15);
	write_short(1 << 12); 
	write_byte(Red);
	write_byte(Green); 
	write_byte(Blue);
	write_byte(Alpha); 
	message_end();
}

RemoveEntities()
{
	for(new i; i < sizeof gEntityClassNames; i++)
	{
		new ent;
		
		while((ent = engfunc(EngFunc_FindEntityByString, ent, "classname", gEntityClassNames[i])) != 0)
		{
			if(!pev_valid(ent) || ent == gHostage)
				continue;
				
			else
				engfunc(EngFunc_RemoveEntity, ent);
		}
	}
}

PrintColor(id, const msg[], any:...)
{
	static message[256];
	new colortype[32];
	get_pcvar_string(gCvarTextColor, colortype, 31)
	
	if(equali(colortype, "yellow")) 
		message[0] = 0x01;
		
	else if(equali(colortype, "green"))
		message[0] = 0x04;
		
	else
		message[0] = 0x03;

	vformat(message[1], 251, msg, 3);
	message[192] = '^0';

	new team, ColorChange, index, MSG_Type;
	
	if(!id)
	{
		index = FindPlayer();
		MSG_Type = MSG_ALL;
	
	} 
	
	else 
	{
		MSG_Type = MSG_ONE;
		index = id;
	}
	
	team = get_user_team(index);	
	ColorChange = ColorSelection(index, MSG_Type, colortype);

	ShowColorMessage(index, MSG_Type, message);
		
	if(ColorChange)
		TeamInfo(index, MSG_Type, gTeamNames2[team]);
}

ShowColorMessage(id, type, message[])
{
	message_begin(type, gMsgSayText, _, id);
	write_byte(id)		
	write_string(message);
	message_end();	
}

TeamInfo(id, type, team[])
{
	message_begin(type, gMsgTeamInfo, _, id);
	write_byte(id);
	write_string(team);
	message_end();

	return 1;
}

ColorSelection(index, type, const colortype[])
{
	if(equali(colortype, "red")) 
		return TeamInfo(index, type, gTeamNames2[1]);
		
	if(equali(colortype, "blue")) 
		return TeamInfo(index, type, gTeamNames2[2]);
		
	if(equali(colortype, "grey")) 
		return TeamInfo(index, type, gTeamNames2[0]);
	
	return 0;
}

FindPlayer()
{
	new i = -1;

	while(i <= gMaxPlayers)
	{
		if(gIsConnected[++i])
			return i;
	}

	return -1;
}

client_color(const id, const input[], any:...)
{
	new msg[191], iLen = formatex(msg, 190, "^x03[Ser]^x04")
	vformat(msg[iLen], 190 - iLen, input, 3)
	replace_all(msg, 190, "/g", "^4")
	replace_all(msg, 190, "/y", "^1")
	replace_all(msg, 190, "/ctr", "^3")
	replace_all(msg, 190, "/w", "^0")
	message_begin(id ? MSG_ONE : MSG_BROADCAST, get_user_msgid( "SayText" ), _, id)
	write_byte(1)
	write_string(msg)
	message_end()
}
