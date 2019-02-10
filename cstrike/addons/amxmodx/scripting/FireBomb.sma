#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Fire Bomb"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define HOLYBOMB_DAMAGE 50
#define HOLYBOMB_BURNDAMAGE 10
#define HOLYBOMB_BURNDELAY 1.0
#define HOLYBOMB_BURNTIME 10.0
#define HOLYBOMB_RADIUS 175.0

#define SOUND_TYPE 2 // 1 = Real Sound | 2 = CSO Sound
#define HOLYBOMB_SECRETCODE 2165
#define HOLYFIREBURN_CLASSNAME "holyshit"

#define CSW_HOLYBOMB CSW_HEGRENADE
#define weapon_holybomb "weapon_hegrenade"

new const WeaponModel[3][] =
{
	"models/v_fgrenade.mdl",
	"models/p_fgrenade.mdl",
	"models/w_fgrenade.mdl"
}

new const WeaponExpSound[] = "weapons/exp_nade.wav"

new const WeaponRes[2][] =
{
	"sprites/flame_puff01.spr",
	"sprites/hfirebomb_burn.spr"
}

enum
{
	TEAM_NONE = 0,
	TEAM_T,
	TEAM_CT
}

// OFFSET
const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_WEAPONOWNER = 41

new g_had_holybomb[33]
new g_Exp_SprId, g_MaxPlayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_Touch, "fw_Touch")
	register_forward(FM_Think, "fw_Think")
	
	RegisterHam(Ham_Item_Deploy, weapon_holybomb, "fw_Item_Deploy_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	register_clcmd("say fire", "get_holybomb", ADMIN_KICK)
}

public plugin_precache()
{
	new i
	
	for(i = 0; i < sizeof(WeaponModel); i++)
		engfunc(EngFunc_PrecacheModel, WeaponModel[i])
	engfunc(EngFunc_PrecacheSound, WeaponExpSound)
	for(i = 0; i < sizeof(WeaponRes); i++)
	{
		if(i == 0) g_Exp_SprId = engfunc(EngFunc_PrecacheModel, WeaponRes[i])
		else engfunc(EngFunc_PrecacheModel, WeaponRes[i])
	}
}

public get_holybomb(id)
{
	if(!is_user_alive(id))
		return
		
	g_had_holybomb[id] = 1
	fm_give_item(id, weapon_holybomb)
}

public hook_weapon(id)
{
	client_cmd(id, weapon_holybomb)
	return PLUGIN_HANDLED
}

public Event_NewRound()
{
	remove_entity_name(HOLYFIREBURN_CLASSNAME)
}

public fw_SetModel(ent, const Model[])
{
	if(!pev_valid(ent))
		return FMRES_IGNORED
		
	static Classname[32]; pev(ent, pev_classname, Classname, sizeof(Classname))
	if(equal(Model, "models/w_hegrenade.mdl"))
	{
		static id; id = pev(ent, pev_owner)
		
		if(g_had_holybomb[id])
		{
			engfunc(EngFunc_SetModel, ent, WeaponModel[2])
			
			set_pev(ent, pev_iuser1, get_player_team(id))
			set_pev(ent, pev_iuser2, HOLYBOMB_SECRETCODE)
			set_pev(ent, pev_dmgtime, 9999999.0)
			
			g_had_holybomb[id] = 0
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED	
}

public fw_Touch(toucher, touched)
{
	if(!pev_valid(toucher))
		return
		
	static Classname[32]; pev(toucher, pev_classname, Classname, sizeof(Classname))
	if(equal(Classname, "grenade"))
	{
		if(pev(toucher, pev_iuser2) != HOLYBOMB_SECRETCODE)
			return
			
		static Float:Origin[3]
		pev(toucher, pev_origin, Origin)

		HolyBomb_Exp(toucher, Origin, pev(toucher, pev_owner), pev(toucher, pev_iuser1))
		
		set_pev(toucher, pev_iuser2, 0)
		set_pev(toucher, pev_iuser2, 0)
		
		engfunc(EngFunc_RemoveEntity, toucher)
	}
}

public fw_Think(ent)
{
	if(!pev_valid(ent))
		return
	
	static Classname[32]; pev(ent, pev_classname, Classname, sizeof(Classname))
	if(!equal(Classname, HOLYFIREBURN_CLASSNAME))
		return
	
	static Float:fFrame
	pev(ent, pev_frame, fFrame)

	fFrame += 1.0
	if(fFrame > 15.0) fFrame = 0.0

	set_pev(ent, pev_frame, fFrame)
	
	static id; id = pev(ent, pev_owner)
	static NewHealth
	
	if(get_gametime() - HOLYBOMB_BURNDELAY > pev(ent, pev_fuser2))
	{
		NewHealth = get_user_health(id) - HOLYBOMB_BURNDAMAGE
		
		if(NewHealth > 1)
			set_user_health(id, NewHealth)
		else
		{
			engfunc(EngFunc_RemoveEntity, ent)
			return
		}
			
		set_pev(ent, pev_fuser2, get_gametime())
	}
	
	static Float:fTimeRemove
	pev(ent, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, ent)
		return;
	}	
	
	set_pev(ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_Item_Deploy_Post(ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(ent)
	if (!pev_valid(id))
		return
	
	if(!g_had_holybomb[id])
		return
		
	set_pev(id, pev_viewmodel2, WeaponModel[0])
	set_pev(id, pev_weaponmodel2, WeaponModel[1])
}

public HolyBomb_Exp(Ent, Float:Origin[3], Owner, Team)
{
	// Do Effect
	static ExpFlag; ExpFlag = 0
	
	ExpFlag |= 2
	ExpFlag |= 4
	ExpFlag |= 8
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
	write_short(g_Exp_SprId)
	write_byte(20)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(ExpFlag)	// flags
	message_end()  
	
	// Play Sound
	emit_sound(Ent, CHAN_BODY, WeaponExpSound, 1.0, ATTN_NORM, 0, PITCH_NORM)

	static Float:PlayerOrigin[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(get_player_team(i) == Team)
			continue
		pev(i, pev_origin, PlayerOrigin)
		if(get_distance_f(Origin, PlayerOrigin) > HOLYBOMB_RADIUS)
			continue
			
		if(!is_user_connected(Owner)) Owner = i
			
		ExecuteHamB(Ham_TakeDamage, i, "grenade", Owner, float(HOLYBOMB_DAMAGE), DMG_BLAST)
		if(is_user_alive(i) && (get_user_health(i) - HOLYBOMB_BURNDAMAGE) > 1) Make_HolyFire(i)
	}
}

public Make_HolyFire(id)
{
	static Ent, iEnt; Ent = fm_find_ent_by_owner(-1, HOLYFIREBURN_CLASSNAME, id)
	static Float:MyOrigin[3]
	if(!pev_valid(Ent))
	{
		iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
		pev(id, pev_origin, MyOrigin)
		
		// set info for ent
		set_pev(iEnt, pev_movetype, MOVETYPE_FOLLOW)
		set_pev(iEnt, pev_rendermode, kRenderTransAdd)
		set_pev(iEnt, pev_renderamt, 250.0)
		set_pev(iEnt, pev_fuser1, get_gametime() + HOLYBOMB_BURNTIME)
		set_pev(iEnt, pev_scale, 1.0)
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.5)
		
		set_pev(iEnt, pev_classname, HOLYFIREBURN_CLASSNAME)
		engfunc(EngFunc_SetModel, iEnt, WeaponRes[1])
		set_pev(iEnt, pev_owner, id)
		set_pev(iEnt, pev_aiment, id)
	} else {
		iEnt = Ent
		pev(id, pev_origin, MyOrigin)
		
		// set info for ent
		set_pev(iEnt, pev_movetype, MOVETYPE_FOLLOW)
		set_pev(iEnt, pev_rendermode, kRenderTransAdd)
		set_pev(iEnt, pev_renderamt, 250.0)
		set_pev(iEnt, pev_fuser1, get_gametime() + HOLYBOMB_BURNTIME)
		set_pev(iEnt, pev_scale, 1.0)
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.5)
		
		set_pev(iEnt, pev_classname, HOLYFIREBURN_CLASSNAME)
		engfunc(EngFunc_SetModel, iEnt, WeaponRes[1])
		set_pev(iEnt, pev_owner, id)
		set_pev(iEnt, pev_aiment, id)
	}
}

stock get_player_team(id)
{
	if(!is_user_alive(id))
		return TEAM_NONE
		
	if(cs_get_user_team(id) == CS_TEAM_T) return TEAM_T
	else if(cs_get_user_team(id) == CS_TEAM_CT) return TEAM_CT
	
	return TEAM_NONE
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	if (pev_valid(ent) != PDATA_SAFE)
		return -1
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
