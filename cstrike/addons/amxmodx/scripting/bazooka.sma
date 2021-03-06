/*

	Bazooka_2_Slot3 (Knife)

Special thanks to:

	-=STN=- MaGe / KaOs / RadidEskimo / Freecode / EJL / JTP10181 / PaintLancer / Kaddar
	Vexd / twistedeuphoria / XxAvalanchexX / pimp daddy / Ronkkrop / Major_victory / Can't Shoot
	
	More for making the original bazooka plugin

	mike_cao for his awesome gore plugin
	
	and anyone else that over looked.
*/

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <engine>
#include <fun>
#include <fakemeta>
#include <fakemeta_util>
#pragma reqlib "dcapi"
native damagecar(id, damage)

#define BA_NORMAL 		(1<<0) // "a"
#define BA_HEAT	 		(1<<1) // "b"
#define BA_USER	 		(1<<2) // "c"
#define BA_NONE	 		(1<<3) // "d"

#define SEQ_IDLE 		0
#define SEQ_FIDGET 		1
#define SEQ_RELOAD 		2
#define SEQ_FIRE 		3
#define SEQ_HOLSTER1 		4
#define SEQ_DRAW1 		5
#define SEQ_HOLSTER2 		6
#define SEQ_DRAW2 		7
#define SEQ_IDLE2		8
#define SEQ_FIDGET2		9

new mod_name[33]
new g_buyzone[33]


new Bazooka_Ammo[33]

new Team_Kill_Count[33]

new bool:RoundEnd
new bool:is_cstrike

new bool:Has_Bazooka[33]
new bool:Allow_Shooting[33]
new bool:Bazooka_Active[33]
new bool:g_restart_attempt[33]

new RocketSmoke
new mdl_gib_head
new mdl_gib_lung
new mdl_gib_meat
new mdl_gib_flesh
new mdl_gib_spine
new spr_blood_drop
new spr_blood_spray
new mdl_gib_legbone
new g_sModelIndexSmoke
new g_sModelIndexFireball
new gmsgDeathMsg, gmsgScoreInfo
new grivity, cost
new bool:E_KeyPress_Delay[33]

new gravity;

static PLUGIN_NAME[]	=	"Bazooka_3_Slot3"
static PLUGIN_AUTHOR[] 	=	"man_s_our"
static PLUGIN_VERSION[]	=	"2"

public plugin_init () {

	register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR)


	register_concmd("bazooka","cmd_Drop_Bazooka",ADMIN_BAN)
	register_concmd("buybazooka","cmd_BuyBazooka",ADMIN_USER,"- Buys a bazooka")

	register_clcmd("say /buybazooka","cmd_BuyBazooka",ADMIN_USER,"- Buys a bazooka")
	register_clcmd("say_team /buybazooka","cmd_BuyBazooka",ADMIN_USER,"- Buys a bazooka")
	register_clcmd("bazooka_give","cmd_GiveBazooka",ADMIN_BAN,"<@all/ct/t>/userid - Gives free bazooka")
	register_clcmd("fullupdate","cmd_FullUpDate") 
	
	register_event("CurWeapon","Event_CurWeapon","be","1=1")
	register_event("DeathMsg","Event_DeathMsg","a")
	register_event("HLTV","Event_NewRound",	"a","1=0","2=0")
	register_event("ResetHUD","Event_HudReset","be")
	register_event("TextMsg","Event_WeaponDrop","be","2=#Weapon_Cannot_Be_Dropped")
	register_event("TextMsg","Event_RestartAttempt","a","2=#Game_will_restart_in")
	register_event("StatusIcon","Event_BuyZone","b","2=buyzone")
	
	register_logevent("LogEvent_RoundStart",2,"1=Round_Start")
	register_logevent("LogEvent_RoundEnd",2,"1=Round_End")
	
	register_forward(FM_CmdStart,"fw_CmdStart")
	register_forward(FM_EmitSound,"fw_EmitSound")

	gmsgDeathMsg = get_user_msgid("DeathMsg")
	gmsgScoreInfo = get_user_msgid("ScoreInfo")

	get_modname(mod_name,31)
	is_cstrike = equal(mod_name,"cstrike") ? true : false
	gravity = register_cvar("grav", "1",FCVAR_SERVER)
	cost = register_cvar("bazooka_cost", "5000",FCVAR_SERVER)
}

public plugin_precache ()  {
	
	precache_model("models/w_rpg.mdl")
	precache_model("models/v_rpg.mdl")
	precache_model("models/p_rpg.mdl")
	precache_model("models/rpgrocket.mdl")
	
	precache_model("models/v_knife.mdl")
	precache_model("models/p_knife.mdl")
	precache_model("models/shield/v_shield_knife.mdl")
	precache_model("models/shield/p_shield_knife.mdl")
	
	precache_sound("items/gunpickup4.wav")
	
	precache_sound("weapons/nuke_fly.wav")
	precache_sound("weapons/dryfire1.wav")
	precache_sound("weapons/mortarhit.wav")
	precache_sound("weapons/rocketfire1.wav")
	
	precache_sound("ambience/particle_suck2.wav")
	
	spr_blood_drop = precache_model("sprites/blood.spr")
	spr_blood_spray = precache_model("sprites/bloodspray.spr")
	
	mdl_gib_lung = precache_model("models/GIB_Lung.mdl")
	mdl_gib_meat = precache_model("models/GIB_B_Gib.mdl")
	mdl_gib_head = precache_model("models/GIB_Skull.mdl")
	mdl_gib_flesh = precache_model("models/Fleshgibs.mdl")
	mdl_gib_spine = precache_model("models/GIB_B_Bone.mdl")
	mdl_gib_legbone = precache_model("models/GIB_Legbone.mdl")
	
	g_sModelIndexSmoke  = precache_model("sprites/steam1.spr")
	g_sModelIndexFireball = precache_model("sprites/zerogxplode.spr")
	
	RocketSmoke = precache_model("sprites/smoke.spr")
	
}

stock bool:has_shield(id) {
	
	new modelName[32]
	entity_get_string(id, EV_SZ_viewmodel, modelName, 31)

	if(containi(modelName, "v_shield_") != -1) return true
		
	return false
	
}

public Event_BuyZone(id) {
	
	g_buyzone[id] = read_data(1)
	
}

public client_connect (id) {
	
	Has_Bazooka[id] = false
	Allow_Shooting[id] = false
	Bazooka_Active[id] = false
	E_KeyPress_Delay[id] = false
	
}

public  client_disconnect (id) {
	
	Has_Bazooka[id] = false
	Allow_Shooting[id] = false
	Bazooka_Active[id] = false
	E_KeyPress_Delay[id] = false
	
}

// Freeze Time.
public Event_NewRound () {
	
	new iCurrent = find_ent_by_class(-1, "rpgrocket")
	while ((iCurrent = find_ent_by_class(-1, "rpgrocket")) != 0) {
		
		new id = entity_get_edict(iCurrent, EV_ENT_owner)
		remove_missile(id,iCurrent)
		
	}
	
}

// Player Spawn
public Event_PlayerSpawn  (id) {
	
	// Reset Bazooka's Ammo
	Bazooka_Ammo[id] = 5

	// Gibs - Unhide Players
	set_user_rendering(id,kRenderFxNone,0,0,0,kRenderTransAlpha,255)
	
	// Removed any rockets in world.
	new Rocket = find_ent_by_class(-1, "rpgrocket")
	while (Rocket > 0) {

		remove_entity(Rocket)
		Rocket = find_ent_by_class(Rocket, "rpgrocket")
		
	}
	
	// Removed any rpglancher in world.
	new RPG = find_ent_by_class(-1, "rpglancher")
	while (RPG > 0) {
		
		remove_entity(RPG)
		
		RPG = find_ent_by_class(RPG, "rpglancher")
		
	}
	
	new v_oldmodel[64], p_oldmodel[64]
		
	entity_get_string(id, EV_SZ_viewmodel, v_oldmodel, 63)
	entity_get_string(id, EV_SZ_weaponmodel, p_oldmodel, 63)
			
	if (equal(v_oldmodel, "models/v_rpg.mdl") || equal(p_oldmodel, "models/p_rpg.mdl")) {
			
		if (!Has_Bazooka[id]) {
			new weaponid, clip, ammo
			weaponid = get_user_weapon(id, clip, ammo)
			
			new weaponname[64]
			get_weaponname(weaponid, weaponname, 63)
					
			new v_model[64], p_model[64]
			format(v_model, 63, "%s", weaponname)
			format(p_model, 63, "%s", weaponname)
					
			replace(v_model, 63, "weapon_", "v_")
			format(v_model, 63, "models/%s.mdl", v_model)
			entity_set_string(id, EV_SZ_viewmodel, v_model)
			
			replace(p_model, 63, "weapon_", "p_")
			format(p_model, 63, "models/%s.mdl", p_model)
			entity_set_string(id, EV_SZ_weaponmodel, p_model)
				
		}
	}

	return PLUGIN_CONTINUE
	
}

// New Round - Freeze Time End.
public LogEvent_RoundStart () {
	
	RoundEnd = false

	new players[32], num
	get_players(players, num, "a")
    
	for (new i; i < num; ++i)
		if (Has_Bazooka[players[i]])
			Allow_Shooting[players[i]] = true
	
	return PLUGIN_CONTINUE

}

// Round End 
public LogEvent_RoundEnd () {
	
	RoundEnd = true
	
	new players[32], num
	get_players(players, num, "a")
    
	for (new i; i < num; ++i)
		if (Has_Bazooka[players[i]])
			Allow_Shooting[players[i]] = false
		
	return PLUGIN_CONTINUE

}

public cmd_FullUpDate () {
	
	return PLUGIN_HANDLED
    
}

public Event_RestartAttempt () {
	
	new players[32], num
	get_players(players, num, "a")
    
	for (new i; i < num; ++i)
		g_restart_attempt[players[i]] = true
	
}

public Event_HudReset (id) {
	
	if (g_restart_attempt[id]) {
    	
		g_restart_attempt[id] = false
	
		return
	
	}

	Event_PlayerSpawn (id)
    
}

public rpg_idle (data[]) {
		
		if (Bazooka_Ammo[data[0]] > 0)
			entity_set_int(data[0], EV_INT_weaponanim, SEQ_IDLE)
			
		if (Bazooka_Ammo[data[0]] <= 0)
			entity_set_int(data[0], EV_INT_weaponanim, SEQ_IDLE2)
					
}

public rpg_reload_start (data[]) {
		
	if ((Bazooka_Ammo[data[0]] > 0))
		entity_set_int(data[0], EV_INT_weaponanim, SEQ_RELOAD)
	else
		entity_set_int(data[0], EV_INT_weaponanim, SEQ_IDLE2)
}

public rpg_fidget (data[]) {
	
	if (!RoundEnd)
		Allow_Shooting[data[0]] = true;

	if (Bazooka_Ammo[data[0]] > 0)
		entity_set_int(data[0], EV_INT_weaponanim, SEQ_FIDGET)
					
	if (Bazooka_Ammo[data[0]] <= 0)
		entity_set_int(data[0], EV_INT_weaponanim, SEQ_FIDGET2)
		
	set_task(6.0, "rpg_idle", data[0]+2023, data[0], 1)
	
	
}

public fw_EmitSound (id, channel, sample[]) {
	
	if(!is_user_alive(id) || !is_user_connected(id)) 
		return FMRES_IGNORED
	
	if(Bazooka_Active[id]) {
		
		if(containi(sample, "weapons/knife") != -1)
			return FMRES_SUPERCEDE
		
	}
		
	return FMRES_IGNORED
	
}

public fire_rocket (id) {
	
	new data[1]
	
	data[0] = id
	
	//Start reload animation.
	set_task(1.0, "rpg_reload_start", id+2021, data, 1)
	//Ends reload animation and enables fireing.
	set_task(3.1, "rpg_fidget", id+2022, data, 1)
	
	new Float:StartOrigin[3], Float:Angle[3]
	
	new PlayerOrigin[3]
	get_user_origin(id, PlayerOrigin, 1)
	
	StartOrigin[0] = float(PlayerOrigin[0])
	StartOrigin[1] = float(PlayerOrigin[1])
	StartOrigin[2] = float(PlayerOrigin[2])
	
	entity_get_vector(id, EV_VEC_v_angle, Angle)
	
	Angle[0] = Angle[0] * -1.0
	
	new RocketEnt = create_entity("info_target")
	
	entity_set_string(RocketEnt, EV_SZ_classname, "rpgrocket")
	entity_set_model(RocketEnt, "models/rpgrocket.mdl")
	entity_set_origin(RocketEnt, StartOrigin)
	entity_set_vector(RocketEnt, EV_VEC_angles, Angle)
	
	new Float:MinBox[3] = {-1.0, -1.0, -1.0}
	new Float:MaxBox[3] = {1.0, 1.0, 1.0}
	
	entity_set_vector(RocketEnt, EV_VEC_mins, MinBox)
	entity_set_vector(RocketEnt, EV_VEC_maxs, MaxBox)
	
	entity_set_int(RocketEnt, EV_INT_solid, 2)
	if(get_pcvar_num(gravity))
	{
		entity_set_int(RocketEnt, EV_INT_movetype, MOVETYPE_TOSS)
		set_pev(RocketEnt, pev_gravity, 0.1)
	}
	else
		entity_set_int(RocketEnt, EV_INT_movetype, MOVETYPE_FLY)
	entity_set_edict(RocketEnt, EV_ENT_owner, id)
	
	new Float:Velocity[3]
	
	VelocityByAim(id, 2000, Velocity)
	entity_set_vector(RocketEnt, EV_VEC_velocity, Velocity)	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(RocketEnt)
	write_short(RocketSmoke)
	write_byte(3)
	write_byte(5)
	write_byte(50)
	write_byte(50)
	write_byte(50)
	write_byte(254)
	message_end()
	
	emit_sound(RocketEnt, CHAN_WEAPON, "weapons/rocketfire1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(RocketEnt, CHAN_VOICE, "weapons/nuke_fly.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	Bazooka_Ammo[id]--;
	
	return PLUGIN_HANDLED
}

public entity_set_follow (entity, target, Float:speed) {
	
	if (!is_valid_ent(entity) || !is_valid_ent(target)) return
	
	new Float:entity_origin[3], Float:target_origin[3]
	entity_get_vector(entity, EV_VEC_origin, entity_origin)
	entity_get_vector(target, EV_VEC_origin, target_origin)
	
	new Float:diff[3]
	diff[0] = target_origin[0] - entity_origin[0]
	diff[1] = target_origin[1] - entity_origin[1]
	diff[2] = target_origin[2] - entity_origin[2]
	
	new Float:length = floatsqroot(floatpower(diff[0], 2.0) + floatpower(diff[1], 2.0) + floatpower(diff[2], 2.0))
	
	new Float:Velocity[3]
	Velocity[0] = diff[0] * (speed / length)
	Velocity[1] = diff[1] * (speed / length)
	Velocity[2] = diff[2] * (speed / length)
	
	entity_set_vector(entity, EV_VEC_velocity, Velocity)
	
	return
	
}

public remove_missile (id,missile) {
	
	new Float:fl_origin[3]
	
	entity_get_vector(missile, EV_VEC_origin, fl_origin)
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_IMPLOSION)
	write_coord(floatround(fl_origin[0]))
	write_coord(floatround(fl_origin[1]))
	write_coord(floatround(fl_origin[2]))
	write_byte (200)
	write_byte (40)
	write_byte (45)
	message_end()
	
	emit_sound(missile, CHAN_WEAPON, "ambience/particle_suck2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(missile, CHAN_VOICE, "ambience/particle_suck2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	
	attach_view(id,id)
	remove_entity(missile)
	
	return PLUGIN_CONTINUE
	
}

public pfn_touch (toucher, touched) {
	
	new ClassName1[32]
	new ClassName2[32]

	if(!is_valid_ent(toucher))
		return PLUGIN_CONTINUE

	if (is_valid_ent(toucher))
		entity_get_string(toucher, EV_SZ_classname, ClassName1, 31)
	
	if (is_valid_ent(touched))
		entity_get_string(touched, EV_SZ_classname, ClassName2, 31)
	
	if (equal(ClassName1, "rpgrocket")) {
		new vExplodeAt[3]
		new Float:fl_vExplodeAt[3]
		entity_get_vector(toucher, EV_VEC_origin, fl_vExplodeAt)

		vExplodeAt[0] = floatround(fl_vExplodeAt[0])
		vExplodeAt[1] = floatround(fl_vExplodeAt[1])
		vExplodeAt[2] = floatround(fl_vExplodeAt[2])

		emit_sound(toucher, CHAN_WEAPON, "weapons/mortarhit.wav", 1.0, 0.5, 0, PITCH_NORM)
 		emit_sound(toucher, CHAN_VOICE, "weapons/mortarhit.wav", 1.0, 0.5, 0, PITCH_NORM)

		for (new Explosion = 1; Explosion < 8; Explosion++) {
			
			// Random Explosion 8 Times
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_SPRITE)
			write_coord(vExplodeAt[0] + random_num(-60,60))
			write_coord(vExplodeAt[1] + random_num(-60,60))
			write_coord(vExplodeAt[2] +128)
			write_short(g_sModelIndexFireball)
			write_byte(random_num(30,65))
			write_byte(255)
			message_end()
			
		}

		for (new Smoke = 1; Smoke < 3; Smoke++) {
			
			// Random Smoke 3 Times
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_SMOKE)
			write_coord(vExplodeAt[0])
			write_coord(vExplodeAt[1])
			write_coord(vExplodeAt[2] + 256)
			write_short(g_sModelIndexSmoke)
			write_byte(random_num(80,150))
			write_byte(random_num(5,10))
			message_end()
		}
		
		// Create the burn decal
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		write_coord(vExplodeAt[0])
		write_coord(vExplodeAt[1])
		write_coord(vExplodeAt[2])
		write_short(0)			
		
		if (is_cstrike) write_byte(random_num(46,48))  // decal
		if (!is_cstrike) write_byte(random_num(58,60)) // decal

		message_end()

		new Max_Damage = 300
		new Damage_Radius = 300
		
		new PlayerPos[3], Distance, Damage
		
		for (new i = 1; i < 32; i++) {
			
			if (is_user_alive(i) == 1) {
				
				new team_kill = 0
				get_user_origin(i, PlayerPos)

				Distance = get_distance(PlayerPos, vExplodeAt)
				
				if (Distance <= Damage_Radius) {  // Screenshake Radius
					
					message_begin(MSG_ONE, get_user_msgid("ScreenShake"), {0,0,0}, i)  // Shake Screen
					write_short(1<<14)
					write_short(1<<14)
					write_short(1<<14)
					message_end()
					
					new attacker = entity_get_edict(toucher, EV_ENT_owner)

					Damage = Max_Damage - floatround(floatmul(float(Max_Damage), floatdiv(float(Distance), float(Damage_Radius))))
					
					if (!get_user_godmode(i)) {

						if(cvar_exists("mp_friendlyfire")) {

							if( get_cvar_num("mp_friendlyfire")) {

								if(get_user_team(i) == get_user_team(attacker))
									team_kill = 1

								do_victim(i,attacker,Damage,team_kill)

							}

							else {

								if(get_user_team(i) != get_user_team(attacker))
									do_victim(i,attacker,Damage,team_kill)
							
							}
							
						}

						else {
							
							do_victim(i,attacker,Damage,team_kill)
						
						}
						

					}

					else {
						
						do_victim(i,attacker,Damage,team_kill)
					
					}
					
				}
				
			}
			
		}
		
		new owner = entity_get_edict(toucher, EV_ENT_owner)
      		attach_view(owner, owner)
		remove_entity(toucher)
		if(equal(ClassName2, "func_vehicle") || equal(ClassName2, "func_tracktrain"))
			damagecar(touched, 100);
		
		//*****************************************//
		// destroy ents within 1/4 of Damage radius//
		//*****************************************//
		static Entity_List[21]
		
		new entites_in_radius
		entites_in_radius = find_sphere_class(0, "func_breakable",Damage_Radius * 0.20,Entity_List,20,fl_vExplodeAt)
		
		for(new i= 0;i < entites_in_radius; i++) {
			
			force_use(Entity_List[i],Entity_List[i])
			remove_task(Entity_List[i])
		}
		
	}
	
	if (equal(ClassName1, "rpglancher")) {

		if(Has_Bazooka[touched])
			return PLUGIN_CONTINUE
	
		if(has_shield(touched))
			return PLUGIN_CONTINUE
		
		new Picker[32]

		if (is_valid_ent(touched))
			entity_get_string(touched, EV_SZ_classname, Picker, 31)

		if (equal(Picker, "player")) {

			give_item(touched, "weapon_knife")
			
			Allow_Shooting[touched] = true
			Has_Bazooka[touched] = true
			
			Bazooka_Ammo[touched] = entity_get_int(toucher, EV_INT_iuser1)
			
			client_print(touched, print_chat, "[Bazooka] You have picked up a bazooka!")
			emit_sound(touched, CHAN_WEAPON, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			remove_entity(toucher)

			new temp[2], weaponID = get_user_weapon(touched, temp[0], temp[1])
			
			if(weaponID == CSW_KNIFE) {

				Bazooka_Active[touched] = true
				Event_CurWeapon(touched)	

				if (Bazooka_Ammo[touched] > 0) entity_set_int(touched, EV_INT_weaponanim, SEQ_RELOAD)
				if (Bazooka_Ammo[touched] <= 0) entity_set_int(touched, EV_INT_weaponanim, SEQ_IDLE2)

			}
			
		}
		
		
	}
	
	return PLUGIN_CONTINUE

}

public do_victim (victim,attacker,Damage,team_kill) {

	new namek[32],namev[32],authida[35],authidv[35],teama[32],teamv[32]

	get_user_name(victim,namev,31)
	get_user_name(attacker,namek,31)
	get_user_authid(victim,authidv,34)
	get_user_authid(attacker,authida,34)
	get_user_team(victim,teamv,31)
	get_user_team(attacker,teama,31)

	if(Damage >= get_user_health(victim)) {

		if(get_cvar_num("mp_logdetail") == 3) {
			
			log_message("^"%s<%d><%s><%s>^" attacked ^"%s<%d><%s><%s>^" with ^"missile^" (hit ^"chest^") (Damage ^"%d^") (health ^"0^")",
			namek,get_user_userid(attacker),authida,teama,namev,get_user_userid(victim),authidv,teamv,Damage)
		
		}

		client_print(attacker,print_chat,"[AMXX] You killed %s with that missile",namev)
		client_print(victim,print_chat,"[AMXX] You were killed by %s's missile",namek)

		if(team_kill == 0) {
			
			set_user_frags(attacker,get_user_frags(attacker) + 1 )
		
		}
		
		else {
			
			Team_Kill_Count[attacker] += 1
			client_print(attacker,print_center,"You killed a teammate")
			set_user_frags(attacker,get_user_frags(attacker) - 1 )
		
		}

		set_msg_block(gmsgDeathMsg,BLOCK_ONCE)
		set_msg_block(gmsgScoreInfo,BLOCK_ONCE)

		user_kill(victim,1)

		replace_dm(attacker,victim,0)

		log_message("^"%s<%d><%s><%s>^" killed ^"%s<%d><%s><%s>^" with ^"missile^"",
		namek,get_user_userid(attacker),authida,teama,namev,get_user_userid(victim),authidv,teamv)

		if (Damage > 100) {
									
			new iOrigin[3]
			get_user_origin(victim,iOrigin)
			set_user_rendering(victim,kRenderFxNone,0,0,0,kRenderTransAlpha,0)
			fx_gib_explode(iOrigin,3)
			fx_blood_large(iOrigin,5)
			fx_blood_small(iOrigin,15)
			iOrigin[2] = iOrigin[2] - 20
			set_user_origin(victim,iOrigin)

		}
		
	}

	else {
		
		set_user_health(victim,get_user_health(victim) - Damage )

		if(get_cvar_num("mp_logdetail") == 3) {
			
			log_message("^"%s<%d><%s><%s>^" attacked ^"%s<%d><%s><%s>^" with ^"missile^" (hit ^"chest^") (Damage ^"%d^") (health ^"%d^")",
			namek,get_user_userid(attacker),authida,teama,namev,get_user_userid(victim),authidv,teamv,Damage,get_user_health(victim))
		
		}

		client_print(attacker,print_chat,"[AMXX] You hurt %s with that missile",namev)
		client_print(victim,print_chat,"[AMXX] You were hurt by %s's missile",namek)

	}

	if (team_kill) {

		new players[32],pNum
		
		get_players(players,pNum,"e",teama)

		for(new i=0;i<pNum;i++) {
		
			client_print(players[i],print_chat,"%s attacked a teammate",namek)

			new punish1 = 0
			new punish2 = 30

			if (!(get_user_flags(attacker)&ADMIN_IMMUNITY)) {
				
				if (punish1 > 2) {

					user_kill(attacker,0)
					set_hudmessage(255,50,50, -1.0, 0.45, 0, 0.02, 10.0, 1.01, 1.1, 4)
					show_hudmessage(attacker,"YOU WERE KILLED FOR ATTACKING TEAMMATES.^nSEE THAT IT HAPPENS NO MORE!")
				
				}

				if((punish1) && (Team_Kill_Count[attacker] >= punish2 )) {

					if(punish1 == 1 || punish1 == 3) {
						
						client_cmd(attacker,"echo You were kicked for team killing;disconnect")
					}
					
					else if(punish1 == 2 || punish1 == 4) {

						client_cmd(attacker,"echo You were banned for team killing")

						if (equal("4294967295",authida)) {

							new ipa[32]
							get_user_ip(attacker,ipa,31,1)
							server_cmd("addip 180.0 %s;writeip",ipa)
						
						}

						else {
							
							server_cmd("banid 180.0 %s kick;writeid",authida)
						
						}
						
					}
					
				}
				
			}
			
		}
		
	}
	
}

public replace_dm (id,tid,tbody) {

	//Update killers scorboard with new info
	message_begin(MSG_ALL,gmsgScoreInfo)
	write_byte(id)
	write_short(get_user_frags(id))
	write_short(get_user_deaths(id))
	write_short(0)
	write_short(get_user_team(id))
	message_end()

	//Update victims scoreboard with correct info
	message_begin(MSG_ALL,gmsgScoreInfo)
	write_byte(tid)
	write_short(get_user_frags(tid))
	write_short(get_user_deaths(tid))
	write_short(0)
	write_short(get_user_team(tid))
	message_end()

	//Headshot Kill
	if (tbody == 1) {

		message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0)
		write_byte(id)
		write_byte(tid)
		write_string(" missile")
		message_end()
		
	}

	//Normal Kill
	else {
		
		message_begin( MSG_ALL, gmsgDeathMsg,{0,0,0},0)
		write_byte(id)
		write_byte(tid)
		write_byte(0)
		write_string("missile")
		message_end()
		
	}

	return PLUGIN_CONTINUE
	
}

public cmd_Drop_Bazooka (id, level, cid) {
	
	if (!cmd_access(id, level, cid, 1))
		return PLUGIN_HANDLED
	
	drop_lancher(id,0)
	
	return PLUGIN_HANDLED
	
}

public drop_rpglancher (id) {

	drop_lancher(id,1)
	
	Bazooka_Ammo[id] = 0
	Has_Bazooka[id] = false
	Bazooka_Active[id] = false
	
	Event_CurWeapon(id)
	
	return PLUGIN_HANDLED
	
}

public drop_lancher (id, sel) {

	new Float:PlayerOrigin[3], Float:End[3], Float:Return[3], Float:TraceDirection[3], Float:Angles[3]

	if (sel == 0) VelocityByAim(id, 64, TraceDirection)
	if (sel == 1) VelocityByAim(id, 200, TraceDirection)
	
	entity_get_vector(id, EV_VEC_origin, PlayerOrigin)

	if (sel == 1) entity_get_vector(id, EV_VEC_angles, Angles)

	End[0] = TraceDirection[0] + PlayerOrigin[0]
	End[1] = TraceDirection[1] + PlayerOrigin[1]
	End[2] = TraceDirection[2] + PlayerOrigin[2]
	
	trace_line(id, PlayerOrigin, End, Return)

	Return[2] = PlayerOrigin[2]
	
	new RPG = create_entity("info_target")
	
	entity_set_string(RPG, EV_SZ_classname, "rpglancher")
	entity_set_model(RPG, "models/w_rpg.mdl")
	entity_set_origin(RPG, Return)
	
	if (sel == 1) {
		
		Angles[0] = 0.0
		Angles[2] = 0.0
		
	}
	
	if ( sel == 0) entity_set_vector(RPG, EV_VEC_angles, Angles)
	
	new Float:MinBox[3] = {-16.0, -16.0, 0.0}
	new Float:MaxBox[3] = {16.0, 16.0, 16.0}

	entity_set_vector(RPG, EV_VEC_mins, MinBox)
	entity_set_vector(RPG, EV_VEC_maxs, MaxBox)
	
	entity_set_int(RPG, EV_INT_solid, 1)
	entity_set_int(RPG, EV_INT_movetype, 6)

	if (sel == 0) entity_set_int(RPG, EV_INT_iuser1, 5)
	if (sel == 0) entity_set_int(RPG, EV_INT_iuser2, 0)
	if (sel == 0) entity_set_int(RPG, EV_INT_iuser3, 0)
	
	if (sel == 1) entity_set_int(RPG, EV_INT_iuser1, Bazooka_Ammo[id])

	return PLUGIN_HANDLED
	
}

public delay (data2[]) {
	
	E_KeyPress_Delay[data2[0]] = false
	
}

public fw_CmdStart (id, uc_handle, seed) {
		
	if(!is_user_connected(id)) return FMRES_IGNORED
	if(!is_user_alive(id)) return FMRES_IGNORED
	if(!Has_Bazooka[id]) return FMRES_IGNORED
	
	if(has_shield(id)) {
		
		drop_rpglancher(id)
		return FMRES_IGNORED
		
	}

	if (Bazooka_Active[id]) ammo_hud(id, 1)
	if (!Bazooka_Active[id]) ammo_hud(id, 0)
	
	new weaponid, clip, ammo
	weaponid = get_user_weapon(id, clip, ammo)
	
	if (weaponid == CSW_KNIFE) {
		
		new buttons = get_uc(uc_handle, UC_Buttons)
		new inuse = get_user_button(id) & IN_USE
		new attack = get_user_button(id) & IN_ATTACK
		new oldinuse = get_user_oldbutton(id) & IN_USE
		new oldattack = get_user_oldbutton(id) & IN_ATTACK
		
		if((inuse) && (oldinuse) && (!E_KeyPress_Delay[id]))
			return FMRES_IGNORED

		if(buttons & IN_USE)
			buttons &= ~IN_USE
		
		if((buttons & IN_ATTACK) && Bazooka_Active[id])
			buttons &= ~IN_ATTACK


		set_uc(uc_handle, UC_Buttons, buttons)
		
		if((inuse) && !(oldinuse)) {
			
			new data2[1]
	
			data2[0] = id
			
			E_KeyPress_Delay[id] = true
			
			set_task(0.2,"delay", id+2023, data2, 1)
						
			if (Bazooka_Active[id])
				Bazooka_Active[id] = false
			
			else 
				Bazooka_Active[id] = true
			
			Event_CurWeapon(id)
			
		}
		
		else if (attack && !oldattack && Bazooka_Active[id])
		{
			
			emit_sound(id, CHAN_WEAPON, "weapons/dryfire1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				
			if (Allow_Shooting[id] && Bazooka_Ammo[id] > 0)
			{
				
				remove_task (id+2023) 
				
				Allow_Shooting[id] = false
				
				entity_set_int(id, EV_INT_weaponanim, SEQ_FIRE)

				fire_rocket(id)
				
			}
			
		}
				
	}
	
	return FMRES_HANDLED
	
}

public cmd_BuyBazooka (id) {
	
	if(!is_user_alive(id)) 
		client_print(id, print_center, "You cant buy when your dead!")
		
	else if(Has_Bazooka[id])
		client_print(id, print_center, "You already own that weapon.")
	else if(cs_get_user_money(id) < get_pcvar_num(cost))
		client_print(id, print_center, "Insuffisant funds, you need %d to buy the bazooka", get_pcvar_num(cost))

	else {
		cs_set_user_money(id, cs_get_user_money(id) - get_pcvar_num(cost), 1)
		give_item(id, "weapon_knife")
		
		Has_Bazooka[id] = true
		Allow_Shooting[id] = true
		
		Bazooka_Ammo[id] = 5


		client_print(id, print_chat, "[Bazooka] You have successfully bought a bazooka!")
		client_print(id, print_chat, "[Bazooka] What are you going to do now!?")
		
		new temp[2], weaponID = get_user_weapon(id, temp[0], temp[1])
			
		if(weaponID == CSW_KNIFE) {
				
			Bazooka_Active[id] = true
			Event_CurWeapon(id)	
			entity_set_int(id, EV_INT_weaponanim, SEQ_FIDGET)
				
		}
		
		else {
			
			Bazooka_Active[id] = true
			client_cmd(id, "weapon_knife")
			
		}
		
		emit_sound(id, CHAN_WEAPON, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
	}

	return PLUGIN_HANDLED

}

public cmd_GiveBazooka (id, level, cid) {
	
	if(!cmd_access(id, level, cid, 2))
		return PLUGIN_HANDLED
	
	new Arg1[64], target
	read_argv(1, Arg1, 63)
	
	new adminName[32]
	get_user_name(id, adminName, 31)
	
	new targetTeam
	new Players[32], iNum
	
	if(Arg1[0] == '@') {
		
		if(equali(Arg1[1], "all")) {
			
			targetTeam = 0
			get_players(Players, iNum, "a")
			
		} 
		
		else if(equali(Arg1[1], "t")) {
			
			targetTeam = 1
			get_players(Players, iNum, "ae" , "terrorist")
			
		} 
		
		else if(equali(Arg1[1], "ct")) {
			
			targetTeam = 2
			get_players(Players, iNum, "ae" , "ct")
			
		}
		
		for(new i = 0; i < iNum; ++i) {
			
			target = Players[i]
			
			give_item(target, "weapon_knife")
			
			Has_Bazooka[target] = true
			Allow_Shooting[target] = true
			
			Bazooka_Ammo[target] = 5
			
			new temp[2], weaponID = get_user_weapon(target, temp[0], temp[1])
			
			if(weaponID == CSW_KNIFE) {
				
				Bazooka_Active[target] = true
				Event_CurWeapon(target)	
				entity_set_int(target, EV_INT_weaponanim, SEQ_FIDGET)
				
			}
			
			else {
			
				Bazooka_Active[target] = true
				client_cmd(target, "weapon_knife")
			
			}
			
			emit_sound(target, CHAN_WEAPON, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			client_print(target, print_chat, "You have been given a bazooka")
			
		}
		
		switch(targetTeam) {
			
			case 0: client_print(0, print_chat, "Admin: %s has given everyone a bazooka", adminName)
			case 1: client_print(0, print_chat, "Admin: %s has given all terrorist a bazooka", adminName)
			case 2: client_print(0, print_chat, "Admin: %s has given all ct's a bazooka", adminName)
		
		}
		
	}
	
	else {
		
		target = cmd_target(id, Arg1, 0)
		
		if(!is_user_connected(target) || !is_user_alive(target))
			return PLUGIN_HANDLED
		
		new targetName[32]
		get_user_name(target, targetName, 31)
		
		give_item(target, "weapon_knife")
		
		Has_Bazooka[target] = true
		Allow_Shooting[target] = true
			
		Bazooka_Ammo[target] = 5
			
		new temp[2], weaponID = get_user_weapon(target, temp[0], temp[1])
			
		if(weaponID == CSW_KNIFE) {
				
			Bazooka_Active[target] = true
			Event_CurWeapon(target)	
			entity_set_int(target, EV_INT_weaponanim, SEQ_FIDGET)
				
		}
			
		else {
			
			Bazooka_Active[target] = true
			client_cmd(target, "weapon_knife")
			
		}
			
		emit_sound(target, CHAN_WEAPON, "items/gunpickup2.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		client_print(target, print_chat, "You have been given a bazooka.")
		client_print(target, print_chat, "Admin: %s has given you a bazooka", adminName)
	
	}
	
	return PLUGIN_HANDLED
	
}

public Event_CurWeapon (id) {
	
	if(!is_user_alive(id)) 
		return PLUGIN_CONTINUE
	
	new weaponid, clip, ammo
	
	weaponid = get_user_weapon(id, clip, ammo)
	
	if ((weaponid == CSW_KNIFE) && (Bazooka_Active[id])) {
		
		entity_set_string(id, EV_SZ_viewmodel, "models/v_rpg.mdl")
		entity_set_string(id, EV_SZ_weaponmodel, "models/p_rpg.mdl")
		entity_set_int(id, EV_INT_weaponanim, SEQ_FIDGET)
		emit_sound(id, CHAN_ITEM, "common/wpn_select.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	

		return PLUGIN_HANDLED
		
	}
		
	if ((weaponid == CSW_KNIFE) && (!Bazooka_Active[id])) {
		
		if(has_shield(id)) {
			
			entity_set_string(id, EV_SZ_viewmodel, "models/shield/v_shield_knife.mdl")
			entity_set_string(id, EV_SZ_weaponmodel, "models/shield/p_shield_knife.mdl")

		}
		
		else {
			
			entity_set_string(id, EV_SZ_viewmodel, "models/v_knife.mdl")
			entity_set_string(id, EV_SZ_weaponmodel, "models/p_knife.mdl")

		}
		
		emit_sound(id, CHAN_ITEM, "weapons/knife_deploy1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
		entity_set_int(id, EV_INT_weaponanim, SEQ_FIRE)
		
		ammo_hud(id, 0)
		
		return PLUGIN_HANDLED
	
	}
	
	if(Has_Bazooka[id] && Bazooka_Active[id])
		Bazooka_Active[id] = false
		
	return PLUGIN_CONTINUE
	
}

public ammo_hud (id, show) {
	
	new AmmoHud[65]
	
	format(AmmoHud, 64, "Rockets: %i", Bazooka_Ammo[id])
	
	if (show) {
		
		message_begin(MSG_ONE, get_user_msgid("StatusText"), {0,0,0}, id)
		write_byte(0)
		write_string(AmmoHud)
		message_end()
		
	}
	
	else {
		
		message_begin(MSG_ONE, get_user_msgid("StatusText"), {0,0,0}, id)
		write_byte(0)
		write_string("")
		message_end()
		
	}
	
}

public Event_DeathMsg () {
	
	new id = read_data(2)
	
	if(!is_user_connected(id) || !Has_Bazooka[id])
		return PLUGIN_CONTINUE

	drop_rpglancher(id)
	
	return PLUGIN_CONTINUE

}

public Event_WeaponDrop (id) {
	
	if(!is_user_alive(id) || !Has_Bazooka[id] || !Bazooka_Active[id])
		return PLUGIN_CONTINUE

	new weaponid, clip, ammo
	weaponid = get_user_weapon(id, clip, ammo)
	
	if (weaponid == CSW_KNIFE) {
		client_print(id, print_center, "")
		drop_rpglancher(id)
		
	}
	
	return PLUGIN_HANDLED

}

/************************************************************
* GIB FUNCTIONS (made by mike_cao)
************************************************************/

static fx_blood_small (origin[3],num) {
	
	// Small splash
	for (new blood_small = 0; blood_small< num; blood_small++) {
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord(origin[0]+random_num(-100,100))
		write_coord(origin[1]+random_num(-100,100))
		write_coord(origin[2]-36)
		
		if (is_cstrike) write_byte(random_num(190,197)) // Blood decals
		if (!is_cstrike) write_byte(random_num(202,209)) // Blood decals

		message_end()
		
	}
	
}

static fx_blood_large (origin[3],num) {
	
	// Large splash
	for (new blood_large = 0; blood_large < num; blood_large++) {
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		write_coord(origin[0] + random_num(-50,50))
		write_coord(origin[1] + random_num(-50,50))
		write_coord(origin[2]-36)

		if (is_cstrike) write_byte(random_num(204,205)) // Blood decals
		if (!is_cstrike) write_byte(random_num(216,217)) // Blood decals
		
		message_end()
		
	}
	
}

static fx_gib_explode (origin[3],num) {
	
	new flesh[3], x, y, z
	flesh[0] = mdl_gib_flesh
	flesh[1] = mdl_gib_meat
	flesh[2] = mdl_gib_legbone
	
	// Gib explosion
	// Head
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(random_num(-100,100))
	write_coord(random_num(-100,100))
	write_coord(random_num(100,200))
	write_angle(random_num(0,360))
	write_short(mdl_gib_head)
	write_byte(0)
	write_byte(500)
	message_end()
	
	// Spine
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	write_coord(origin[0])
	write_coord(origin[1])
	write_coord(origin[2])
	write_coord(random_num(-100,100))
	write_coord(random_num(-100,100))
	write_coord(random_num(100,200))
	write_angle(random_num(0,360))
	write_short(mdl_gib_spine)
	write_byte(0)
	write_byte(500)
	message_end()
	
	// Lung
	for(new Lung = 0; Lung < random_num(1,2); Lung++) {
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2])
		write_coord(random_num(-100,100))
		write_coord(random_num(-100,100))
		write_coord(random_num(100,200))
		write_angle(random_num(0,360))
		write_short(mdl_gib_lung)
		write_byte(0)
		write_byte(500)
		message_end()
		
	}
	
	// Parts, 5 times
	for(new Parts = 0; Parts < 5; Parts++) {
		
		message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
		write_byte(TE_MODEL)
		write_coord(origin[0])
		write_coord(origin[1])
		write_coord(origin[2])
		write_coord(random_num(-100,100))
		write_coord(random_num(-100,100))
		write_coord(random_num(100,200))
		write_angle(random_num(0,360))
		write_short(flesh[random_num(0,2)])
		write_byte(0)
		write_byte(500)
		message_end()
		
	}
	
	// Blood
	for(new Blood = 0; Blood < num; Blood++) {
		
		x = random_num(-100,100)
		y = random_num(-100,100)
		z = random_num(0,100)
		
		for(new j = 0; j < 5; j++) {
			
			message_begin(MSG_BROADCAST,SVC_TEMPENTITY)
			write_byte(TE_BLOODSPRITE)
			write_coord(origin[0]+(x*j))
			write_coord(origin[1]+(y*j))
			write_coord(origin[2]+(z*j))
			write_short(spr_blood_spray)
			write_short(spr_blood_drop)
			write_byte(248)
			write_byte(15)
			message_end()
			
		}
		
	}
	
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1036\\ f0\\ fs16 \n\\ par }
*/
