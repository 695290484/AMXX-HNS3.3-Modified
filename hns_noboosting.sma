#include <amxmodx>
#include <fakemeta>

new gCvarEnabled;
new gCvarDamage;
new gHudSyncObj;

new Float:gBoostDelay[33];
new Float:gBoostMessageDelay[33];

public plugin_init() 
{
	register_plugin("HNS_NOBOOSTING", "1.0", "Jon")
		
	gCvarEnabled = register_cvar("hns_blockboosting", "1")
	gCvarDamage = register_cvar("hns_blockboosting_damage", "0")
	gHudSyncObj = CreateHudSyncObj();
	
	register_forward(FM_Touch, "fwd_Touch");
}

public fwd_touch(ptr, ptd) 
{
	if(!get_pcvar_num(gCvarEnabled) 
	|| !pev_valid(ptr) 
	|| !pev_valid(ptd) 
	|| !is_user_alive(ptr) 
	|| !is_user_alive(ptd)
	|| get_user_team(ptr) != get_user_team(ptd))
		return FMRES_IGNORED;
	
	static Float:PtrOrigin[3], Float:PtdOrigin[3];
	
	pev(ptr, pev_origin, PtrOrigin);
	pev(ptd, pev_origin, PtdOrigin);
	
	if(!(49.0 < (PtdOrigin[2] - PtrOrigin[2]) < 73.0))
		return FMRES_IGNORED;
	
	new Float:gametime = get_gametime();
	
	if(gametime >= gBoostDelay[ptr-1])
	{
		custom_slap(ptr);
		gBoostDelay[ptr-1] = gametime + 0.5;
	}
	
	if(gametime >= gBoostDelay[ptd-1])
	{
		custom_slap(ptd);
		gBoostDelay[ptd-1] = gametime + 0.5;
	}
	
	if(gametime >= gBoostMessageDelay[ptr-1])
	{
		set_hudmessage(255, 255, 255, -1.0, 0.85, 0, 0.0, 3.0, 0.0, 0.0, 1);
		ShowSyncHudMsg(ptr, gHudSyncObj, "No boosting allowed!")
		
		gBoostMessageDelay[ptr-1] = gametime + 1.0;
	}
	
	if(gametime >= gBoostMessageDelay[ptd-1])
	{
		set_hudmessage(255, 255, 255, -1.0, 0.85, 0, 0.0, 3.0, 0.0, 0.0, 1);
		ShowSyncHudMsg(ptd, gHudSyncObj, "No boosting allowed!")
		
		gBoostMessageDelay[ptd-1] = gametime + 1.0;
	}
	return FMRES_IGNORED;
}

custom_slap(id)
{
	if(get_pcvar_num(gCvarDamage))
	{
		new Float:health;
		pev(id, pev_health, health);
		health -= float(get_pcvar_num(gCvarDamage))
		
		if(health <= 0)
			user_kill(id, 1);
			
		else
			set_pev(id, pev_health, health);
	}
	
	new Float:velocity[3], Float:angle[3];
	pev(id, pev_velocity, velocity);
	pev(id, pev_angles, angle);
	
	for(new i = 0; i < 3; i++)
	{
		velocity[i] += (random_num(0, 1) == 1) ? 300.0 : -300.0;
		if(i < 2)
			angle[i] += (random_num(0, 1) == 1) ? 35.0 : -35.0;
	}
	
	set_pev(id, pev_velocity, velocity);
	set_pev(id, pev_angles, angle);
}
