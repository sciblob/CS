#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>

/*
	Thanks To M4M4LZ To Created
	The Models Of Weapon :) "MAGNUMBOLT"
*/

#define PLUGIN "[UNOFFICIAL CSO] MagnumBolt || NATIVE ONLY"
#define VERSION "1.0"
#define AUTHOR "AsepKhairulAnam || -RequiemID- || Facebook.com/asepdwa11"

// CONFIGURATION WEAPON
#define system_name		"magnumbolt"
#define system_base		"awp"
#define DRAW_TIME		1.33
#define CSW_BASE		CSW_AWP
#define WEAPON_KEY 		4529105
#define OLD_MODEL		"models/w_awp.mdl"
#define ANIMEXT			"rifle"

// ALL MACRO
#define ENG_NULLENT		-1
#define EV_INT_WEAPONKEY	EV_INT_impulse
#define write_coord_f(%1)	engfunc(EngFunc_WriteCoord,%1)

// ALL ANIM
#define ANIM_IDLE		0
#define ANIM_SHOOT		1
#define ANIM_DRAW		2

// All Models Of The Weapon
new V_MODEL[64] = "models/v_magnumbolt.mdl"
new W_MODEL[64] = "models/w_magnumbolt.mdl"
new P_MODEL[64] = "models/p_magnumbolt.mdl"
new MUZZLEFLASH[100] = "sprites/muzzleflash19.spr"

new const WeaponResources[][] =
{
	"sprites/asep/640hud2_2.spr",
	"sprites/asep/640hud122_2.spr",
	"sprites/asep/scope_magnumbolt1.spr",
	"sprites/asep/scope_magnumbolt2.spr"
}

// You Can Add Fire Sound Here
new const Fire_Sounds[][] = { "weapons/magnumbolt-1.wav", "weapons/magnumbolt_zoom.wav" , "weapons/magnumbolt_insight1.wav"}

// All Vars Here
new g_MaxPlayers, g_orig_event
new bool:g_has_weapon[33], oldweap[33], Trail, Float:g_zoom_delay[33][2]
new g_Muzzleflash_Ent[33], cvar_dmg, cvar_clip, g_Ammo[33], Float:TargetOrigin[33][3]
new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }

// Macros Again
new weapon_name_buffer_1[512]
new weapon_name_buffer_2[512]
new weapon_base_buffer[512]
		
const PRIMARY_WEAPONS_BIT_SUM = 
(1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<
CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
new const WEAPONENTNAMES[][] = { "", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
			"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
			"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
			"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
			"weapon_ak47", "weapon_knife", "weapon_p90" }

// START TO CREATE PLUGINS || AMXMODX FORWARD
public plugin_init()
{
	formatex(weapon_name_buffer_1, sizeof(weapon_name_buffer_1), "weapon_%s_1_asep", system_name)
	formatex(weapon_name_buffer_2, sizeof(weapon_name_buffer_2), "weapon_%s_2_asep", system_name)
	formatex(weapon_base_buffer, sizeof(weapon_base_buffer), "weapon_%s", system_base)
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Event And Message
	register_event("CurWeapon", "Forward_CurrentWeapon", "be", "1=1")
	register_message(get_user_msgid("DeathMsg"), "Forward_DeathMsg")
	
	// Ham Forward (Entity) || Ham_Use
	RegisterHam(Ham_Use, "func_tank", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankmortar", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tankrocket", "Forward_UseStationary_Post", 1)
	RegisterHam(Ham_Use, "func_tanklaser", "Forward_UseStationary_Post", 1)
	
	// Ham Forward (Entity) || Ham_TraceAttack
	RegisterHam(Ham_TraceAttack, "player", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_wall", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_breakable", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_door", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_door_rotating", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_rotating", "Forward_TraceAttack")
	RegisterHam(Ham_TraceAttack, "func_plat", "Forward_TraceAttack")
	
	// Ham Forward (Weapon)
	RegisterHam(Ham_Item_PostFrame, weapon_base_buffer, "Weapon_ItemPostFrame")
	RegisterHam(Ham_Weapon_Reload, weapon_base_buffer, "Weapon_Reload")
	RegisterHam(Ham_Item_AddToPlayer, weapon_base_buffer, "Weapon_AddToPlayer")
	
	for(new i = 1; i < sizeof WEAPONENTNAMES; i++)
		if(WEAPONENTNAMES[i][0]) RegisterHam(Ham_Item_Deploy, WEAPONENTNAMES[i], "Weapon_Deploy_Post", 1)
	
	// Fakemeta Forward
	register_forward(FM_SetModel, "Forward_SetModel")
	register_forward(FM_PlaybackEvent, "Forward_PlaybackEvent")
	register_forward(FM_UpdateClientData, "Forward_UpdateClientData_Post", 1)
	register_forward(FM_EmitSound, "Forward_EmitSound")
	
	// Muzzleflash Think (Engine)
	register_think("magnumbolt_muzzleflash", "Forward_MuzzleflashThink")
	
	// All Some Cvar
	cvar_clip = register_cvar("magnumbolt_clip", "25")
	cvar_dmg = register_cvar("magnumbolt_damage", "400")
	
	g_MaxPlayers = get_maxplayers()
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(MUZZLEFLASH)
	
	new Buffer[512]
	formatex(Buffer, sizeof(Buffer), "sprites/%s.txt", weapon_name_buffer_1)
	precache_generic(Buffer)
	formatex(Buffer, sizeof(Buffer), "sprites/%s.txt", weapon_name_buffer_2)
	precache_generic(Buffer)
	
	for(new i = 0; i < sizeof Fire_Sounds; i++)
		precache_sound(Fire_Sounds[i])
	for(new i = 0; i < sizeof WeaponResources; i++)
		precache_model(WeaponResources[i])
	
	precache_viewmodel_sound(V_MODEL)
	formatex(Buffer, sizeof(Buffer), "get_%s", system_name)
	
	register_clcmd(Buffer, "give_item")
	
	register_clcmd(weapon_name_buffer_1, "weapon_hook")
	register_clcmd(weapon_name_buffer_2, "weapon_hook")
	
	register_forward(FM_PrecacheEvent, "Forward_PrecacheEvent_Post", 1)
	Trail = precache_model("sprites/zbeam2.spr")
}

public plugin_natives()
{
	new Buffer[512]
	formatex(Buffer, sizeof(Buffer), "get_%s", system_name)
	register_native(Buffer, "give_item", 1)
	formatex(Buffer, sizeof(Buffer), "remove_%s", system_name)
	register_native(Buffer, "remove_item", 1)
}

// Reset Bitvar (Fix Bug) If You Connect Or Disconnect Server
public client_connect(id) remove_item(id)
public client_disconnect(id) remove_item(id)
/* ========= START OF REGISTER HAM TO SUPPORT BOTS FUNC ========= */
new g_HamBot
public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_RegisterHam", id)
	}
}

public Do_RegisterHam(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "Forward_TraceAttack")
}

/* ======== END OF REGISTER HAM TO SUPPORT BOTS FUNC ============= */
/* ============ START OF ALL FORWARD (FAKEMETA) ================== */
public Forward_PrecacheEvent_Post(type, const name[])
{
	new Buffer[512]
	formatex(Buffer, sizeof(Buffer), "events/%s.sc", system_base)
	if(equal(Buffer, name, 0))
	{
		g_orig_event = get_orig_retval()
		return FMRES_HANDLED
	}
	return FMRES_IGNORED
}

public Forward_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, OLD_MODEL))
	{
		static iStoredAugID
		iStoredAugID = find_ent_by_owner(ENG_NULLENT, weapon_base_buffer, entity)
			
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED

		if(g_has_weapon[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_WEAPONKEY, WEAPON_KEY)
			
			if(is_valid_ent(g_Muzzleflash_Ent[iOwner]))
			{
				remove_entity(g_Muzzleflash_Ent[iOwner])
				g_Muzzleflash_Ent[iOwner] = 0
			}
			
			g_has_weapon[iOwner] = false
			set_pev(iStoredAugID, pev_iuser1, g_Ammo[iOwner])
			
			entity_set_model(entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED
}

public Forward_UseStationary_Post(entity, caller, activator, use_type)
{
	if(!use_type && is_user_connected(caller))
		replace_weapon_models(caller, get_user_weapon(caller))
}

public Forward_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || (get_user_weapon(Player) != CSW_BASE || !g_has_weapon[Player]))
		return FMRES_IGNORED
	
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.001)
	return FMRES_HANDLED
}

public Forward_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if((eventid != g_orig_event))
		return FMRES_IGNORED
	if(!(1 <= invoker <= g_MaxPlayers))
		return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}

public Forward_EmitSound(id, channel, sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_alive(id) || !g_has_weapon[id])
		return FMRES_IGNORED
		
	if(equal(sample, "weapons/zoom.wav"))
	{
		emit_sound(id, CHAN_ITEM, Fire_Sounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
		set_weapon_list(id, 1)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

/* ================= END OF ALL FAKEMETA FORWARD ================= */
/* ================= START OF ALL MESSAGE FORWARD ================ */
public Forward_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
	
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
	
	if(!is_user_connected(iAttacker) || iAttacker == iVictim)
		return PLUGIN_CONTINUE
	
	if(equal(szTruncatedWeapon, system_base) && get_user_weapon(iAttacker) == CSW_BASE)
	{
		if(g_has_weapon[iAttacker])
			set_msg_arg_string(4, system_name)
	}
	return PLUGIN_CONTINUE
}
/* ================== END OF ALL MESSAGE FORWARD ================ */
/* ================== START OF ALL EVENT FORWARD ================ */
public Forward_CurrentWeapon(id)
{
	replace_weapon_models(id, read_data(2))
}
/* ================== END OF ALL EVENT FORWARD =================== */
/* ================== START OF ALL ENGINE FORWARD ================ */
public Forward_MuzzleflashThink(ent)
{
	if(!pev_valid(ent))
		return
	
	new Float:Frame, Count, Owner
	Owner = pev(ent, pev_owner)
	Count = pev(ent, pev_iuser1)
	pev(ent, pev_frame, Frame)
	
	if(get_user_weapon(Owner) != CSW_BASE)
	{
		set_pev(ent, pev_renderamt, 0.0)
		return
	}
	
	if(!Frame && !Count)
	{
		set_pev(ent, pev_iuser1, 1)
		set_pev(ent, pev_renderamt, 250.0)
		set_pev(ent, pev_nextthink, get_gametime() + 0.03)
	}
	else if(!Frame && Count)
	{
		set_pev(ent, pev_frame, 1.0)
		set_pev(ent, pev_nextthink, get_gametime() + 0.03)
	}
	else if(Frame && Count)
	{
		set_pev(ent, pev_frame, 0.0)
		set_pev(ent, pev_renderamt, 0.0)
		set_pev(ent, pev_iuser1, 0)
	}
}
/* ================== END OF ALL ENGINE FORWARD ================== */
/* ================== START OF ALL HAM FORWARD =================== */
public Forward_TraceAttack(iEnt, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_connected(iAttacker))
		return
	if(get_user_weapon(iAttacker) != CSW_BASE || !g_has_weapon[iAttacker])
		return
		
	static Float:WallVector[3], iHitgroup
	get_tr2(ptr, TR_vecEndPos, TargetOrigin[iAttacker])
	get_tr2(ptr, TR_vecPlaneNormal, WallVector)
		
	if(iEnt)
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_DECAL)
		write_coord_f(TargetOrigin[iAttacker][0])
		write_coord_f(TargetOrigin[iAttacker][1])
		write_coord_f(TargetOrigin[iAttacker][2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		write_short(iEnt)
		message_end()
	}
	else
	{
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord_f(TargetOrigin[iAttacker][0])
		write_coord_f(TargetOrigin[iAttacker][1])
		write_coord_f(TargetOrigin[iAttacker][2])
		write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
		message_end()
	}
		
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_STREAK_SPLASH)
	engfunc(EngFunc_WriteCoord, TargetOrigin[iAttacker][0])
	engfunc(EngFunc_WriteCoord, TargetOrigin[iAttacker][1])
	engfunc(EngFunc_WriteCoord, TargetOrigin[iAttacker][2])
	engfunc(EngFunc_WriteCoord, WallVector[0] * random_float(25.0, 30.0))
	engfunc(EngFunc_WriteCoord, WallVector[1] * random_float(25.0, 30.0))
	engfunc(EngFunc_WriteCoord, WallVector[2] * random_float(25.0, 30.0))
	write_byte(7)
	write_short(50)
	write_short(3)
	write_short(90)	
	message_end()
			
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_GUNSHOTDECAL)
	write_coord_f(TargetOrigin[iAttacker][0])
	write_coord_f(TargetOrigin[iAttacker][1])
	write_coord_f(TargetOrigin[iAttacker][2])
	write_short(iAttacker)
	write_byte(GUNSHOT_DECALS[random_num (0, sizeof GUNSHOT_DECALS -1)])
	message_end()
	
	set_tr2(ptr, TR_iHitgroup, iHitgroup)
	
	new Float:MultifDamage, Float:NewDamage
	switch(iHitgroup)
	{
		case HIT_HEAD: MultifDamage  = 2.0
		case HIT_STOMACH: MultifDamage  = 1.25
		case HIT_LEFTLEG: MultifDamage  = 0.75
		case HIT_RIGHTLEG: MultifDamage  = 0.75
		default: MultifDamage  = 1.0
	}
	
	NewDamage = float(get_pcvar_num(cvar_dmg)) * MultifDamage
	SetHamParamFloat(3, NewDamage)
}

public Weapon_Deploy_Post(weapon_entity)
{
	static owner
	owner = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	static weaponid
	weaponid = cs_get_weapon_id(weapon_entity)
	
	replace_weapon_models(owner, weaponid)
}

public Weapon_AddToPlayer(weapon_entity, id)
{
	if(!is_valid_ent(weapon_entity) || !is_user_connected(id))
		return HAM_IGNORED
	
	if(entity_get_int(weapon_entity, EV_INT_WEAPONKEY) == WEAPON_KEY)
	{
		g_has_weapon[id] = true
		g_Ammo[id] = pev(weapon_entity, pev_iuser1)
		Create_Muzzleflash(id)
		set_weapon_list(id, 1)
		entity_set_int(weapon_entity, EV_INT_WEAPONKEY, 0)
		
		return HAM_HANDLED
	}
	else
	{
		set_weapon_list(id, 0)
	}
	
	return HAM_IGNORED
}

public Weapon_ItemPostFrame(weapon_entity) 
{
	if(!pev_valid(weapon_entity))
		return HAM_IGNORED
		
	new id = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	if(!is_user_connected(id))
		return HAM_IGNORED
	if(!g_has_weapon[id])
		return HAM_IGNORED
			
	if(g_Ammo[id] && get_pdata_float(id, 83, 5) <= 0.0 && get_pdata_float(weapon_entity, 46, 4) <= 0.0 ||
	get_pdata_float(weapon_entity, 47, 4) <= 0.0 || get_pdata_float(weapon_entity, 48, 4) <= 0.0)
	{
		if(pev(id, pev_button) & IN_ATTACK)
		{
			Do_Shoot(id)
			set_weapons_timeidle(id, CSW_BASE, 2.7)
			set_player_nextattackx(id, 2.7)
			cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
		}
	}
	
	if(get_gametime() - 0.1 > g_zoom_delay[id][0])
	{
		static Body, Target
		get_user_aiming(id, Target, Body, 99999999)
		
		if(cs_get_user_zoom(id) >= CS_SET_FIRST_ZOOM)
		{
			if(!is_user_alive(Target))
			{
				set_weapon_list(id, 1)
			}
			else
			{
				set_weapon_list(id, 2)
				if(get_gametime() - 0.5 > g_zoom_delay[id][1])
				{
					emit_sound(id, CHAN_ITEM, Fire_Sounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
					g_zoom_delay[id][1] = get_gametime()
				}	
			}
		}
		else set_weapon_list(id, 1)
		g_zoom_delay[id][0] = get_gametime()
	}
	
	return HAM_IGNORED
}

public Weapon_Reload(weapon_entity) 
{
	new Player = fm_cs_get_weapon_ent_owner(weapon_entity)
	
	if(!is_user_alive(Player))
		return HAM_IGNORED
	if(!g_has_weapon[Player])
		return HAM_SUPERCEDE
	
	return HAM_IGNORED
}

/* ===================== END OF ALL HAM FORWARD ====================== */
/* ================= START OF OTHER PUBLIC FUNCTION  ================= */
public give_item(id)
{
	drop_weapons(id, 1)
	new iWeapon = fm_give_item(id, weapon_base_buffer)
	if(iWeapon > 0)
	{
		g_Ammo[id] = get_pcvar_num(cvar_clip)
		emit_sound(id, CHAN_ITEM, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_weapon_anim(id, ANIM_DRAW)
		set_pdata_float(id, 83, DRAW_TIME, 5)
		
		set_weapon_list(id, 1)
		set_pdata_string(id, (492) * 4, ANIMEXT, -1 , 20)
	}
	
	g_has_weapon[id] = true
}

public remove_item(id)
{
	g_has_weapon[id] = false
}

public weapon_hook(id)
{
	engclient_cmd(id, weapon_base_buffer)
	return PLUGIN_HANDLED
}

public replace_weapon_models(id, weaponid)
{
	switch(weaponid)
	{
		case CSW_BASE:
		{
			if(g_has_weapon[id])
			{
				set_pev(id, pev_viewmodel2, V_MODEL)
				set_pev(id, pev_weaponmodel2, P_MODEL)
				
				if(oldweap[id] != CSW_BASE) 
				{
					set_weapon_anim(id, ANIM_DRAW)
					set_player_nextattackx(id, DRAW_TIME)
					set_weapons_timeidle(id, CSW_BASE, DRAW_TIME)
					set_weapon_list(id, 1)
					set_pdata_string(id, (492) * 4, ANIMEXT, -1 , 20)
				}
			}
		}
	}
	
	oldweap[id] = weaponid
}

public Do_Shoot(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	
	static weapon_ent
	weapon_ent = fm_find_ent_by_owner(-1, weapon_base_buffer, id)
	
	if(!pev_valid(weapon_ent))
		return
		
	ExecuteHamB(Ham_Weapon_PrimaryAttack, weapon_ent)
	
	g_Ammo[id] --
	set_weapon_list(id, 1)
	
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-2.0, 2.0)
	PunchAngles[1] = random_float(-2.0, 2.0)
	PunchAngles[2] = random_float(-2.0, 2.0)
	set_pev(id, pev_punchangle, PunchAngles)
	
	Show_Muzzleflash(id, 0.1)
	set_weapon_anim(id, ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, Fire_Sounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	static Float:StartOrigin[3]
	get_position(id, 40.0, 6.0, -7.0, StartOrigin)
	create_beampoints(StartOrigin, TargetOrigin[id], Trail, 0, 0, 10, 12, 0, 21, 228, 224, 127, 0)
	create_beampoints(StartOrigin, TargetOrigin[id], Trail, 0, 0, 10, 12, 0, 255, 255, 255, 127, 0)
}

public Show_Muzzleflash(id, Float:Delay)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return
	if(get_user_weapon(id) != CSW_BASE || !g_has_weapon[id])
		return
	
	set_pev(g_Muzzleflash_Ent[id], pev_nextthink, get_gametime() + Delay)
}

public Create_Muzzleflash(id)
{	
	g_Muzzleflash_Ent[id] = create_entity("info_target")
	set_pev(g_Muzzleflash_Ent[id], pev_classname, "magnumbolt_muzzleflash")
	engfunc(EngFunc_SetModel, g_Muzzleflash_Ent[id], MUZZLEFLASH)
	set_pev(g_Muzzleflash_Ent[id], pev_scale, 0.17)
	set_pev(g_Muzzleflash_Ent[id], pev_rendermode, kRenderTransAdd)
	set_pev(g_Muzzleflash_Ent[id], pev_renderamt, 0.0)
	set_pev(g_Muzzleflash_Ent[id], pev_aiment, id)
	set_pev(g_Muzzleflash_Ent[id], pev_body, 1)
	set_pev(g_Muzzleflash_Ent[id], pev_skin, id)
	set_pev(g_Muzzleflash_Ent[id], pev_frame, 0.0)
	set_pev(g_Muzzleflash_Ent[id], pev_iuser1, 0)
	set_pev(g_Muzzleflash_Ent[id], pev_owner, id)
	set_pev(g_Muzzleflash_Ent[id], pev_movetype, MOVETYPE_FOLLOW)
}

/* ============= END OF OTHER PUBLIC FUNCTION (Weapon) ============= */
/* ================= START OF ALL STOCK TO MACROS ================== */
stock create_beampoints(Float:StartPosition[3], Float:TargetPosition[3], SpritesID, StartFrame, Framerate, Life, LineWidth, Amplitude, Red, Green, Blue, Brightness, Speed)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartPosition[0])
	engfunc(EngFunc_WriteCoord, StartPosition[1])
	engfunc(EngFunc_WriteCoord, StartPosition[2])
	engfunc(EngFunc_WriteCoord, TargetPosition[0])
	engfunc(EngFunc_WriteCoord, TargetPosition[1])
	engfunc(EngFunc_WriteCoord, TargetPosition[2])
	write_short(SpritesID)
	write_byte(StartFrame)
	write_byte(Framerate)
	write_byte(Life)
	write_byte(LineWidth)
	write_byte(Amplitude)
	write_byte(Red)
	write_byte(Green)
	write_byte(Blue)
	write_byte(Brightness)
	write_byte(Speed)
	message_end()
}

stock set_weapon_list(id, set)
{
	if(!is_user_connected(id))
		return
	
	static weapon_ent
	weapon_ent = fm_find_ent_by_owner(-1, weapon_base_buffer, id)
	
	if(!pev_valid(weapon_ent))
		return
	
	message_begin(MSG_ONE, get_user_msgid("WeaponList"), _, id)
	if(!set) write_string(weapon_base_buffer)
	else if(set == 1) write_string(weapon_name_buffer_1)
	else if(set == 2) write_string(weapon_name_buffer_2)
	write_byte(1)
	write_byte(25)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(2)
	write_byte(CSW_BASE)
	write_byte(0)
	message_end()
		
	cs_set_weapon_ammo(weapon_ent, 1)
	cs_set_user_bpammo(id, CSW_BASE, 0)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_BASE)
	write_byte(-1)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(1)
	write_byte(g_Ammo[id])
	message_end()
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num = 0, i, weaponid
	get_user_weapons(id, weapons, num)
     
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
          
		if(dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_player_nextattackx(id, Float:nexttime)
{
	if(!is_user_alive(id))
		return
		
	set_pdata_float(id, 83, nexttime, 5)
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	if(!is_user_alive(id))
		return
		
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 1.0, 4)
}

stock set_weapon_anim(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(pev(Player, pev_body))
	message_end()
}

stock precache_viewmodel_sound(const model[]) // I Get This From BTE
{
	new file, i, k
	if((file = fopen(model, "rt")))
	{
		new szsoundpath[64], NumSeq, SeqID, Event, NumEvents, EventID
		fseek(file, 164, SEEK_SET)
		fread(file, NumSeq, BLOCK_INT)
		fread(file, SeqID, BLOCK_INT)
		
		for(i = 0; i < NumSeq; i++)
		{
			fseek(file, SeqID + 48 + 176 * i, SEEK_SET)
			fread(file, NumEvents, BLOCK_INT)
			fread(file, EventID, BLOCK_INT)
			fseek(file, EventID + 176 * i, SEEK_SET)
			
			// The Output Is All Sound To Precache In ViewModels (GREAT :V)
			for(k = 0; k < NumEvents; k++)
			{
				fseek(file, EventID + 4 + 76 * k, SEEK_SET)
				fread(file, Event, BLOCK_INT)
				fseek(file, 4, SEEK_CUR)
				
				if(Event != 5004)
					continue
				
				fread_blocks(file, szsoundpath, 64, BLOCK_CHAR)
				
				if(strlen(szsoundpath))
				{
					strtolower(szsoundpath)
					engfunc(EngFunc_PrecacheSound, szsoundpath)
				}
			}
		}
	}
	
	fclose(file)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	return get_pdata_cbase(ent, 41, 4)
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs, vUp) //for player
	xs_vec_add(vOrigin, vUp, vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle, ANGLEVECTOR_FORWARD, vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle, ANGLEVECTOR_RIGHT, vRight)
	angle_vector(vAngle, ANGLEVECTOR_UP, vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock is_wall_between_points(Float:start[3], Float:end[3], ignore_ent)
{
	static ptr
	ptr = create_tr2()

	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ignore_ent, ptr)
	
	static Float:EndPos[3]
	get_tr2(ptr, TR_vecEndPos, EndPos)

	free_tr2(ptr)
	return floatround(get_distance_f(end, EndPos))
} 

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	xs_vec_add(fOrigin, fAttack, output)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	static Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	static Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	static iResult; iResult = get_angle_between_vectors(fV1, fV2)
	if(TargetSize > 0.0)
	{
		static Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		static fAngleToTargetSize; fAngleToTargetSize = floatround(floatatan(fTan, degrees))
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	static Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	static iResult; iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
}

/* ================= END OF ALL STOCK AND PLUGINS CREATED ================== */
