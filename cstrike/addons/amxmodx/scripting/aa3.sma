#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "AUG A3"
#define VERSION "1.0"
#define AUTHOR "GenDa"

// Data Config
#define MODEL_V "models/v_aa3.mdl"
#define MODEL_P "models/p_aa3.mdl"
#define MODEL_W "models/w_aa3.mdl"
#define MODEL_W_OLD "models/w_ak47.mdl"

#define CSWS_AA3 CSW_AK47
#define weapon_aa3 "weapon_ak47"

#define SUBMODEL -1 // can -1
#define WEAPON_CODE 3042018
#define WEAPON_EVENT "events/ak47.sc"

#define ANIME_SHOOT 3
#define ANIME_RELOAD 1 // can -1
#define ANIME_DRAW 2 // can -1
#define ANIME_IDLE 0 // can -1

new const WeaponSounds[2][] =
{
	"weapons/aa3-1.wav",
	"weapons/aa3-2.wav"
}

// Weapon Config
#define DAMAGE_A 43
#define ACCURACY 55
#define CLIP 41
#define BPAMMO 230
#define SPEED_A 0.08
#define SPEED_B 0.2
#define RECOIL 0.70
#define RELOAD_TIME 3.5

// Muzzleflash
#define MUZZLEFLASH1 "sprites/muzzleflash1.spr"
#define MUZZLEFLASH2 "sprites/muzzleflash2.spr"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

//new g_Base
new g_Had_Base, g_Clip[33], g_OldWeapon[33], Float:g_Recoil[33][3]
new g_Event_Base, g_SmokePuff_SprId, g_MsgCurWeapon, g_Hit_SprID, g_MaxPlayers
new g_Muzzleflash_Ent, g_Muzzleflash
new g_Muzzleflash_Ent2, g_Muzzleflash2

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	// Event
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	// Forward
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_AddToFullPack, "fw_AddToFullPack_Post", 1)
	register_forward(FM_CheckVisibility, "fw_CheckVisibility")
	
	// Ham
	RegisterHam(Ham_Item_Deploy, weapon_aa3, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_aa3, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_aa3, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_aa3, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_aa3, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_aa3, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_aa3, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_aa3, "fw_Weapon_PrimaryAttack_Post", 1)
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	// Cache
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MaxPlayers = get_maxplayers()
	
	// Get
	register_clcmd("aa3", "Get_AA3")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	g_Hit_SprID = precache_model("sprites/muzzleflash1.spr")
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	// Muzzleflash
	g_Muzzleflash_Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	g_Muzzleflash_Ent2 = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	
	precache_model(MUZZLEFLASH1)
	precache_model(MUZZLEFLASH2)
	
	engfunc(EngFunc_SetModel, g_Muzzleflash_Ent, MUZZLEFLASH1)
	engfunc(EngFunc_SetModel, g_Muzzleflash_Ent2, MUZZLEFLASH2)
	
	set_pev(g_Muzzleflash_Ent, pev_scale, 0.075)
	set_pev(g_Muzzleflash_Ent2, pev_scale, 0.1)
	
	set_pev(g_Muzzleflash_Ent, pev_rendermode, kRenderTransTexture)
	set_pev(g_Muzzleflash_Ent, pev_renderamt, 0.0)
	set_pev(g_Muzzleflash_Ent2, pev_rendermode, kRenderTransTexture)
	set_pev(g_Muzzleflash_Ent2, pev_renderamt, 0.0)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(WEAPON_EVENT, name)) g_Event_Base = get_orig_retval()		
}

public client_putinserver(id)
{
        Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
}
 
public Register_HamBot(id)
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}
 
public client_disconnect(id)
{
        Safety_Disconnected(id)
}
/*
public Mileage_WeaponGet(id, ItemID)
{
	if(ItemID == g_Base) Get_AA3(id)
}

public Mileage_WeaponRefillAmmo(id, ItemID)
{
	if(ItemID == g_Base) cs_set_user_bpammo(id, CSWS_AA3, BPAMMO)
}

public Mileage_WeaponRemove(id, ItemID)
{
	if(ItemID == g_Base) Remove_Base(id)
}*/

public Get_AA3(id)
{
	Set_BitVar(g_Had_Base, id)
	give_item(id, weapon_aa3)
	
	// Clip & Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSWS_AA3)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSWS_AA3, BPAMMO)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSWS_AA3)
	write_byte(CLIP)
	message_end()
	
	cs_set_weapon_silen(Ent, 0, 0)
}

public Remove_Base(id)
{
	UnSet_BitVar(g_Had_Base, id)
}

public Event_CurWeapon(id)
{
	static CSWID; CSWID = read_data(2)
	static SubModel; SubModel = SUBMODEL
	
	if((CSWID == CSWS_AA3 && g_OldWeapon[id] != CSWS_AA3) && Get_BitVar(g_Had_Base, id))
	{
		if(SubModel != -1) Draw_NewWeapon(id, CSWID)
	} else if((CSWID == CSWS_AA3 && g_OldWeapon[id] == CSWS_AA3) && Get_BitVar(g_Had_Base, id)) {
		static Ent; Ent = fm_get_user_weapon_entity(id, CSWS_AA3)
		if(!pev_valid(Ent))
		{
			g_OldWeapon[id] = get_user_weapon(id)
			return
		}
		
		static Float:Speed
		if(cs_get_user_zoom(id) != CS_SET_AUGSG552_ZOOM) Speed = SPEED_A
		else Speed = SPEED_B
		
		set_pdata_float(Ent, 46, Speed, 4)
		set_pdata_float(Ent, 47, Speed, 4)
	} else if(CSWID != CSWS_AA3 && g_OldWeapon[id] == CSWS_AA3) {
		if(SubModel != -1) Draw_NewWeapon(id, CSWID)
	}
	
	g_OldWeapon[id] = get_user_weapon(id)
}

public Draw_NewWeapon(id, CSW_ID)
{
	if(CSW_ID == CSWS_AA3)
	{
		static ent
		ent = fm_get_user_weapon_entity(id, CSWS_AA3)
		
		if(pev_valid(ent) && Get_BitVar(g_Had_Base, id))
		{
			set_pev(ent, pev_effects, pev(ent, pev_effects) &~ EF_NODRAW) 
			engfunc(EngFunc_SetModel, ent, MODEL_P)	
			set_pev(ent, pev_body, SUBMODEL)
		}
	} else {
		static ent
		ent = fm_get_user_weapon_entity(id, CSWS_AA3)
		
		if(pev_valid(ent)) set_pev(ent, pev_effects, pev(ent, pev_effects) | EF_NODRAW) 			
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSWS_AA3 && Get_BitVar(g_Had_Base, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSWS_AA3 || !Get_BitVar(g_Had_Base, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Base)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	Set_WeaponAnim(invoker, ANIME_SHOOT)
	if(cs_get_user_zoom(invoker) != CS_SET_AUGSG552_ZOOM) emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))
	else {
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[1], 1.0, 0.4, 0, 94 + random_num(0, 15))
		Shock_Damage(invoker)
	}
	
	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, MODEL_W_OLD))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_aa3, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Base, iOwner))
		{
			set_pev(weapon, pev_impulse, WEAPON_CODE)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			set_pev(entity, pev_body, SUBMODEL)
		
			Remove_Base(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSWS_AA3 || !Get_BitVar(g_Had_Base, id))
		return FMRES_IGNORED
		
	static Button; Button = get_uc(uc_handle, UC_Buttons)	
	
	if(Button & IN_ATTACK2)
	{
		static Float:Time; Time = get_pdata_float(id, 83, 5)
		if(Time > 0.0) return FMRES_IGNORED
		
		if(cs_get_user_zoom(id) != CS_SET_AUGSG552_ZOOM) cs_set_user_zoom(id, CS_SET_AUGSG552_ZOOM, 1)
		else cs_set_user_zoom(id, CS_RESET_ZOOM, 0)
		
		Time = 0.25
		set_pdata_float(id, 83, Time, 5)
	}
	
	return FMRES_IGNORED
}

public fw_AddToFullPack_Post(esState, iE, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
	if(iEnt == g_Muzzleflash_Ent)
	{
		if(Get_BitVar(g_Muzzleflash, iHost))
		{
			set_es(esState, ES_Frame, float(random_num(0, 2)))
				
			set_es(esState, ES_RenderMode, kRenderTransAdd)
			set_es(esState, ES_RenderAmt, 255.0)
			
			UnSet_BitVar(g_Muzzleflash, iHost)
			//remove_task(iHost+WEAPON_CODE)
			set_task(0.001, "Set_NextMuzzleflash", iHost+WEAPON_CODE)
		}
			
		set_es(esState, ES_Skin, iHost)
		set_es(esState, ES_Body, 1)
		set_es(esState, ES_AimEnt, iHost)
		set_es(esState, ES_MoveType, MOVETYPE_FOLLOW)
	} else if(iEnt == g_Muzzleflash_Ent2) {
		if(Get_BitVar(g_Muzzleflash2, iHost))
		{
			set_es(esState, ES_Frame, float(random_num(0, 2)))
				
			set_es(esState, ES_RenderMode, kRenderTransAdd)
			set_es(esState, ES_RenderAmt, 255.0)
			
			UnSet_BitVar(g_Muzzleflash2, iHost)
		}
			
		set_es(esState, ES_Skin, iHost)
		set_es(esState, ES_Body, 1)
		set_es(esState, ES_AimEnt, iHost)
		set_es(esState, ES_MoveType, MOVETYPE_FOLLOW)
	}
}

public Set_NextMuzzleflash(id) Set_BitVar(g_Muzzleflash2, id-WEAPON_CODE)

public fw_CheckVisibility(iEntity, pSet)
{
	if(iEntity == g_Muzzleflash_Ent || iEntity == g_Muzzleflash_Ent2)
	{
		forward_return(FMV_CELL, 1)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Base, Id))
		return
		
	static SubModel; SubModel = SUBMODEL
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, SubModel != -1 ? "" : MODEL_P)
	
	static Draw; Draw = ANIME_DRAW
	if(Draw != -1) Set_WeaponAnim(Id, ANIME_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == WEAPON_CODE)
	{
		Set_BitVar(g_Had_Base, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Base, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSWS_AA3)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSWS_AA3, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Base, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSWS_AA3)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Base, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		
		static Reload; Reload = ANIME_RELOAD
		if(Reload != -1) Set_WeaponAnim(id, ANIME_RELOAD)
		Set_PlayerNextAttack(id, RELOAD_TIME)
	}
	
	return HAM_HANDLED
}

public fw_Weapon_WeaponIdle_Post( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(Id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Base, Id))
		return
		
	static Idle; Idle = ANIME_IDLE
	
	if(Idle != -1 && get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		Set_WeaponAnim(Id, ANIME_IDLE)
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSWS_AA3 || !Get_BitVar(g_Had_Base, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	if(cs_get_user_zoom(Attacker) != CS_SET_AUGSG552_ZOOM) SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSWS_AA3 || !Get_BitVar(g_Had_Base, Attacker))
		return HAM_IGNORED

	static Float:flEnd[3]
	get_tr2(Ptr, TR_vecEndPos, flEnd)	
		
	if(cs_get_user_zoom(Attacker) != CS_SET_AUGSG552_ZOOM) SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
}


public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id))
		return
	if(!Get_BitVar(g_Had_Base, id))
		return

	pev(id, pev_punchangle, g_Recoil[id])
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id))
		return
	if(!Get_BitVar(g_Had_Base, id))
		return

	static Float:Push[3]
	pev(id, pev_punchangle, Push)
	xs_vec_sub(Push, g_Recoil[id], Push)
	
	xs_vec_mul_scalar(Push, RECOIL, Push)
	xs_vec_add(Push, g_Recoil[id], Push)
	
	set_pev(id, pev_punchangle, Push)
	Set_BitVar(g_Muzzleflash, id)
	
	// Acc
	static Accena; Accena = ACCURACY
	if(Accena != -1)
	{
		static Float:Accuracy
		Accuracy = (float(100 - ACCURACY) * 1.5) / 100.0

		set_pdata_float(Ent, 62, Accuracy, 4);
	}
}

public Shock_Damage(id)
{
	static Float:Origin[3]; fm_get_aim_origin(id, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Hit_SprID)
	write_byte(6)
	write_byte(15)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_AK47)
	if(!pev_valid(Ent)) return
	
	static Float:Origin2[3]
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(id == i)
			continue
		pev(i, pev_origin, Origin2)
			continue
		
	}
}

/* ===============================
------------- SAFETY -------------
=================================*/
public Register_SafetyFunc()
{
	register_event("CurWeapon", "Safety_CurWeapon", "be", "1=1")
	
	RegisterHam(Ham_Spawn, "player", "fw_Safety_Spawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_Safety_Killed_Post", 1)
}

public Register_SafetyFuncBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_Safety_Killed_Post", 1)
}

public Safety_Connected(id)
{
	Set_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_Disconnected(id)
{
	UnSet_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSW; CSW = read_data(2)
	if(g_PlayerWeapon[id] != CSW) g_PlayerWeapon[id] = CSW
}

public fw_Safety_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsAlive, id)
}

public fw_Safety_Killed_Post(id)
{
	UnSet_BitVar(g_IsAlive, id)
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0

	return 1
}

public is_alive(id)
{
	if(!is_connected(id))
		return 0
	if(!Get_BitVar(g_IsAlive, id))
		return 0
		
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- END OF SAFETY  ---------
=================================*/

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}

stock Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
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

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock Set_WeaponIdleTime(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_PlayerNextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock Get_Position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
