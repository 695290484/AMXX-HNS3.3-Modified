#include <amxmodx>
#include <fakemeta>

new gCvarEnable;
new gCvarAlpha;
new gCvarShowNames;
new gMaxPlayers;
new gHudSyncObj;
new gPlayerTeam[33];

new bool:gPlayerSolid[33];
new bool:gPlayerRestore[33];

public plugin_init() 
{
	register_plugin("HNS_SEMICLIP", "1.0", "Jon");
		
	gCvarEnable = register_cvar("hns_teamsemiclip", "1");
	gCvarAlpha = register_cvar("hns_teamsemiclip_alpha", "200")
	gCvarShowNames = register_cvar("hns_teamsemiclip_shownames", "1")
	gMaxPlayers = get_maxplayers();
	
	register_forward(FM_AddToFullPack, "fwd_AddToFullPack", 1);
	register_forward(FM_PlayerPreThink, "fwd_PlayerPreThink", 0);
	register_forward(FM_PlayerPostThink, "fwd_PlayerPostThink", 0);
}

public plugin_precache()
	gHudSyncObj = CreateHudSyncObj();

public fwd_AddToFullPack(es, e, ent, host, hostflags, player, pSet)
{
	if(get_pcvar_num(gCvarEnable))
	{
		if(player)
		{
			if(gPlayerSolid[host] && gPlayerSolid[ent] && gPlayerTeam[host] == gPlayerTeam[ent])
			{
				set_es(es, ES_Solid, SOLID_NOT);
				set_es(es, ES_RenderMode, kRenderTransAlpha);
				set_es(es, ES_RenderAmt, get_pcvar_num(gCvarAlpha));
			}
		}
	}
}

FirstThink()
{
	for(new i = 1; i <= gMaxPlayers; i++)
	{
		if(!is_user_alive(i))
		{
			gPlayerSolid[i] = false;
			continue;
		}
		
		gPlayerTeam[i] = get_user_team(i);
		gPlayerSolid[i] = pev(i, pev_solid) == SOLID_SLIDEBOX ? true : false;
	}
}

public fwd_PlayerPreThink(id)
{
	if(get_pcvar_num(gCvarEnable))
	{
		if(get_pcvar_num(gCvarShowNames) && is_user_alive(id))
		{
			new Target
			new Temp
		
			get_user_aiming(id, Target, Temp, 9999)
			
			if(Target > 0 && get_user_team(id) == get_user_team(Target))
			{
				new TargetName[32]
				get_user_name(Target, TargetName, 31)
				
				switch(get_user_team(id))
				{
					case 1: set_hudmessage(255, 0, 0, -1.0, 0.50, 0, 0.0, 0.1, 0.0, 0.0, 2);
					case 2: set_hudmessage(0, 0, 255, -1.0, 0.50, 0, 0.0, 0.1, 0.0, 0.0, 2);
				}
				
				ShowSyncHudMsg(id, gHudSyncObj, "%s", TargetName)
			}
		}
		
		static i, LastThink;
		
		if(LastThink > id)
		{
			FirstThink();
		}
		
		LastThink = id;
	
		if(!gPlayerSolid[id]) 
			return;
		
		for(i = 1; i <= gMaxPlayers; i++)
		{
			if(!gPlayerSolid[i] || id == i) 
				continue;
			
			if(gPlayerTeam[i] == gPlayerTeam[id])
			{
				set_pev(i, pev_solid, SOLID_NOT);
				gPlayerRestore[i] = true;
			}
		}
	}
}

public fwd_PlayerPostThink(id)
{
	if(get_pcvar_num(gCvarEnable))
	{
		static i;
		
		for(i = 1; i <= gMaxPlayers; i++)
		{
			if(gPlayerRestore[i])
			{
				set_pev(i, pev_solid, SOLID_SLIDEBOX);
				gPlayerRestore[i] = false;
			}
		}
	}
}
