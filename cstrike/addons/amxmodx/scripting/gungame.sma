// Thanks a lot to 3volution for helping me iron out some
// bugs and for giving me some helpful suggestions.
//
// Thanks a lot to raa for helping me pinpoint the crash,
// and discovering the respawn bug.
//
// Thanks a lot to BAILOPAN for binary logging, and for
// CSDM spawn files that I could leech off of. Oh, and
// also AMXX, etcetera.
//
// Thanks to VEN for Fakemeta Utilities to ease development.
//
// Thanks a lot to all of my supporters, but especially:
// 3volution, aligind4h0us3, arkshine, Curryking, Gunny,
// IdiotSavant, Mordekay, polakpolak, raa, Silver Dragon,
// and ToT | V!PER.
//
// Thanks especially to all of the translators:
// arkshine, b!orn, commonbullet, Curryking, Deviance,
// D o o m, e-N-z, Fr3ak0ut, godlike, harbu, iggy_bus,
// jopmako, KylixMynxAltoLAG, Morpheus759, SAMURAI16, TEG,
// ToT | V!PER, trawiator, Twilight Suzuka, and webpsiho.
//
// If I missed you, please yell at me. I mean, please tell me.

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <hamsandwich>

// defines to be left alone
new const GG_VERSION[] =	"2.10";
#define LANG_PLAYER_C		-76 // for gungame_print (arbitrary number)
#define TNAME_SAVE		pev_noise3 // for blocking game_player_equip and player_weaponstrip
#define WINSOUNDS_SIZE		(MAX_WINSOUNDS*MAX_WINSOUND_LEN)+1 // for gg_sound_winner

// more customizable-friendly defines
#define TOP_PLAYERS		10 // for !top10
#define MAX_WEAPONS		36 // for gg_weapon_order
#define MAX_WINSOUNDS		12 // for gg_sound_winnner
#define MAX_WINSOUND_LEN	48 // for gg_sound_winner
#define TEMP_SAVES		32 // for gg_save_temp
#define MAX_WEAPON_ORDERS	10 // for random gg_weapon_order
#define LEADER_DISPLAY_RATE	10.0 // for gg_leader_display
#define MAX_SPAWNS		128 // for gg_dm_spawn_random

// cs_set_user_money
#if cellbits == 32
#define OFFSET_CSMONEY	115
#else
#define OFFSET_CSMONEY	140
#endif
#define OFFSET_LINUX	5
	
// animations
#define USP_DRAWANIM	6
#define M4A1_DRAWANIM	5

// toggle_gungame
enum
{
	TOGGLE_FORCE = -1,
	TOGGLE_DISABLE,
	TOGGLE_ENABLE
};

// gg_status_display
enum
{
	STATUS_LEADERWPN = 1,
	STATUS_YOURWPN,
	STATUS_KILLSLEFT,
	STATUS_KILLSDONE
};

// value of bombStatus[3]
enum
{
	BOMB_PICKEDUP = -1,
	BOMB_DROPPED,
	BOMB_PLANTED
};

// task ids
#define TASK_END_STAR			200
#define TASK_RESPAWN			300
#define TASK_CLEAR_SAVE			500
#define TASK_CHECK_DEATHMATCH		600
#define TASK_REMOVE_PROTECTION	700
#define TASK_TOGGLE_GUNGAME		800
#define TASK_WARMUP_CHECK		900
#define TASK_VERIFY_WEAPON		1000
#define TASK_DELAYED_SUICIDE		1100
#define TASK_REFRESH_NADE		1200
#define TASK_LEADER_DISPLAY		1300
#define TASK_PLAY_LEAD_SOUNDS		1400
#define TASK_NOTIFY_PLAYER_SPAWN	1500

//**********************************************************************
// VARIABLE DEFINITIONS
//**********************************************************************

// pcvar holders
new gg_enabled, gg_ff_auto, gg_vote_setting, gg_map_setup, gg_join_msg,
gg_weapon_order, gg_max_lvl, gg_triple_on, gg_turbo, gg_knife_pro,
gg_worldspawn_suicide, gg_handicap_on, gg_top10_handicap, gg_warmup_timer_setting,
gg_warmup_weapon, gg_sound_levelup, gg_sound_leveldown, gg_sound_levelsteal,
gg_sound_nade, gg_sound_knife, gg_sound_welcome, gg_sound_triple, gg_sound_winner,
gg_kills_per_lvl, gg_vote_custom, gg_changelevel_custom, gg_ammo_amount,
gg_stats_file, gg_stats_prune, gg_refill_on_kill, gg_colored_messages, gg_tk_penalty,
gg_save_temp, gg_stats_mode, gg_pickup_others, gg_stats_winbonus, gg_map_iterations,
gg_warmup_multi, gg_stats_ip, gg_extra_nades, gg_endmap_setup, gg_autovote_rounds,
gg_autovote_ratio, gg_autovote_delay, gg_autovote_time, gg_ignore_bots, gg_nade_refresh,
gg_block_equips, gg_leader_display, gg_leader_display_x, gg_leader_display_y,
gg_sound_takenlead, gg_sound_tiedlead, gg_sound_lostlead, gg_lead_sounds, gg_knife_elite,
gg_teamplay, gg_teamplay_melee_mod, gg_teamplay_nade_mod, gg_suicide_penalty, gg_winner_motd,
gg_bomb_defuse_lvl, gg_nade_glock, gg_nade_smoke, gg_nade_flash, gg_give_armor, gg_give_helmet,
gg_dm, gg_dm_sp_time, gg_dm_sp_mode, gg_dm_spawn_random, gg_dm_spawn_delay, gg_dm_corpses, gg_awp_oneshot,
gg_host_touch_reward, gg_host_rescue_reward, gg_host_kill_reward, gg_dm_countdown, gg_status_display,
gg_dm_spawn_afterplant, gg_block_objectives, gg_host_kill_penalty, gg_dm_start_random, gg_allow_changeteam,
gg_teamplay_timeratio, gg_disable_money;

// weapon information
new maxClip[31] = { -1, 13, -1, 10, 1, 7, -1, 30, 30, 1, 30, 20, 25, 30, 35, 25, 12, 20,
		10, 30, 100, 8, 30, 30, 20, 2, 7, 30, 30, -1, 50 };

new maxAmmo[31] = { -1, 52, -1, 90, -1, 32, 1, 100, 90, -1, 120, 100, 100, 90, 90, 90, 100, 100,
		30, 120, 200, 32, 90, 120, 60, -1, 35, 90, 90, -1, 100 };
		
new weaponSlots[31] = { -1, 2, -1, 1, 4, 1, 5, 1, 1, 4, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1, 1, 1, 1,
		4, 2, 1, 1, 3, 1 };

// misc
new weapons_menu, scores_menu, level_menu, warmup = -1, warmupWeapon[24], len, voted, won, trailSpr, roundEnded,
menuText[512], dummy[2], tempSave[TEMP_SAVES][30], czero, maxPlayers, mapIteration = 1, cfgDir[32],
autovoted, autovotes[2], roundsElapsed, gameCommenced, cycleNum = -1, ham_registered,
czbot_ham_registered, mp_friendlyfire, winSounds[MAX_WINSOUNDS][MAX_WINSOUND_LEN+1], numWinSounds,
currentWinSound, hudSyncWarmup, hudSyncReqKills, hudSyncLDisplay, shouldWarmup, ggActive, teamLevel[3],
teamLvlWeapon[3][24], teamScore[3], bombMap, hostageMap, bombStatus[4], c4planter, Float:spawns[MAX_SPAWNS][9],
spawnCount, csdmSpawnCount, hudSyncCountdown, Array:statsArray, statsSize, weaponName[MAX_WEAPONS+1][24],
Float:weaponGoal[MAX_WEAPONS+1], weaponNum, initTeamplay = -1;

// stats file stuff
new sfFile[64], sfAuthid[24], sfWins[6], sfPoints[8], sfName[32], sfTimestamp[12], sfLineData[81], glStatsMode;

// event ids
new gmsgSayText, gmsgCurWeapon, gmsgStatusIcon, gmsgBombDrop, gmsgBombPickup, gmsgHideWeapon,
gmsgCrosshair, gmsgScenario;

// player values
new level[33], levelsThisRound[33], score[33], lvlWeapon[33][24], star[33], welcomed[33],
page[33], lastKilled[33], hosties[33][2], silenced[33], respawn_timeleft[33], Float:lastSwitch[33],
spawnSounds[33], spawnProtected[33], statsPosition[33], Float:teamTimes[33][2], pointsExtraction[33][3];

//**********************************************************************
// INITIATION FUNCTIONS
//**********************************************************************

// plugin load
public plugin_init()
{
	register_plugin("GunGame AMXX",GG_VERSION,"Avalanche");
	register_cvar("gg_version",GG_VERSION,FCVAR_SERVER);
	set_cvar_string("gg_version",GG_VERSION);

	// mehrsprachige unterstützung (nein, spreche ich nicht Deutsches)
	register_dictionary("gungame.txt");
	register_dictionary("common.txt");
	register_dictionary("adminvote.txt");

	// event ids
	gmsgSayText = get_user_msgid("SayText");
	gmsgCurWeapon = get_user_msgid("CurWeapon");
	gmsgStatusIcon = get_user_msgid("StatusIcon");
	gmsgScenario = get_user_msgid("Scenario");
	gmsgBombDrop = get_user_msgid("BombDrop");
	gmsgBombPickup = get_user_msgid("BombPickup");
	gmsgHideWeapon = get_user_msgid("HideWeapon");
	gmsgCrosshair = get_user_msgid("Crosshair");

	// events
	register_event("ResetHUD","event_resethud","be");
	register_event("HLTV","event_new_round","a","1=0","2=0");
	register_event("CurWeapon","event_curweapon","be","1=1");
	register_event("AmmoX","event_ammox","be");
	register_event("30","event_intermission","a");
	register_event("TextMsg","event_round_restart","a","2=#Game_Commencing","2=#Game_will_restart_in");
	register_event("23","event_bomb_detonation","a","1=17","6=-105","7=17"); // planted bomb exploded
	
	// forwards
	register_forward(FM_SetModel,"fw_setmodel");
	register_forward(FM_EmitSound,"fw_emitsound");
	
	// logevents
	register_logevent("event_bomb_detonation",6,"3=Target_Bombed"); // another bomb exploded event, for security
	register_logevent("logevent_bomb_planted",3,"2=Planted_The_Bomb"); // bomb planted
	register_logevent("logevent_bomb_defused",3,"2=Defused_The_Bomb"); // bomb defused
	register_logevent("logevent_round_end",2,"1=Round_End"); // round ended
	register_logevent("logevent_hostage_touched",3,"2=Touched_A_Hostage");
	register_logevent("logevent_hostage_rescued",3,"2=Rescued_A_Hostage");
	register_logevent("logevent_hostage_killed",3,"2=Killed_A_Hostage");
	register_logevent("logevent_team_join",3,"1=joined team");
	
	// messages
	register_message(gmsgScenario,"message_scenario");
	register_message(get_user_msgid("ClCorpse"),"message_clcorpse");
	register_message(get_user_msgid("Money"),"message_money");
	register_message(gmsgBombDrop,"message_bombdrop");
	register_message(gmsgBombPickup,"message_bombpickup");
	register_message(get_user_msgid("WeapPickup"),"message_weappickup"); // for gg_block_objectives
	register_message(get_user_msgid("AmmoPickup"),"message_ammopickup"); // for gg_block_objectives
	register_message(get_user_msgid("TextMsg"),"message_textmsg"); // for gg_block_objectives
	register_message(get_user_msgid("HostagePos"),"message_hostagepos"); // for gg_block_objectives
		
	// hams
	RegisterHam(Ham_Touch,"weaponbox","ham_weapon_touch",0);
	RegisterHam(Ham_Touch,"armoury_entity","ham_weapon_touch",0);

	// commands
	register_clcmd("joinclass","cmd_joinclass"); // new menus
	register_menucmd(register_menuid("Terrorist_Select",1),511,"cmd_joinclass"); // old menus
	register_menucmd(register_menuid("CT_Select",1),511,"cmd_joinclass"); // old menus
	register_concmd("amx_gungame","cmd_gungame",ADMIN_CVAR,"<0|1> - toggles the functionality of GunGame.");
	register_concmd("amx_gungame_level","cmd_gungame_level",ADMIN_BAN,"<target> <level> - sets target's level. use + or - for relative, otherwise it's absolute.");
	register_concmd("amx_gungame_vote","cmd_gungame_vote",ADMIN_VOTE,"- starts a vote to toggle GunGame.");
	register_concmd("amx_gungame_win","cmd_gungame_win",ADMIN_BAN,"[target] - if target, forces target to win. if no target, forces highest level player to win.");
	register_concmd("amx_gungame_teamplay","cmd_gungame_teamplay",ADMIN_BAN,"<0|1> [killsperlvl] [suicidepenalty] - toggles teamplay mode. optionally specify new cvar values.");
	register_concmd("amx_gungame_restart","cmd_gungame_restart",ADMIN_BAN,"[delay] [full] - restarts GunGame. optionally specify a delay, in seconds. if full, reloads config and everything.");
	register_srvcmd("gg_reloadweapons","cmd_reloadweapons",ADMIN_CVAR,"- reloads the weapon order and kills per level from cvars");
	register_clcmd("fullupdate","cmd_fullupdate");
	register_clcmd("say","cmd_say");
	register_clcmd("say_team","cmd_say");

	// menus
	register_menucmd(register_menuid("autovote_menu"),MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,"autovote_menu_handler");
	register_menucmd(register_menuid("welcome_menu"),1023,"welcome_menu_handler");
	register_menucmd(register_menuid("restart_menu"),MENU_KEY_1|MENU_KEY_0,"restart_menu_handler");
	weapons_menu = register_menuid("weapons_menu");
	register_menucmd(weapons_menu,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0,"weapons_menu_handler");
	register_menucmd(register_menuid("top10_menu"),MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0,"top10_menu_handler");
	scores_menu = register_menuid("scores_menu");
	register_menucmd(scores_menu,MENU_KEY_1|MENU_KEY_2|MENU_KEY_3|MENU_KEY_0,"scores_menu_handler");
	level_menu = register_menuid("level_menu");
	register_menucmd(level_menu,1023,"level_menu_handler");

	// basic cvars
	gg_enabled = register_cvar("gg_enabled","1");
	gg_vote_setting = register_cvar("gg_vote_setting","2");
	gg_vote_custom = register_cvar("gg_vote_custom","");
	gg_changelevel_custom = register_cvar("gg_changelevel_custom","");
	gg_map_setup = register_cvar("gg_map_setup","mp_timelimit 45; mp_winlimit 0; sv_alltalk 0; mp_chattime 10; mp_c4timer 25");
	gg_endmap_setup = register_cvar("gg_endmap_setup","");
	gg_join_msg = register_cvar("gg_join_msg","1");
	gg_colored_messages = register_cvar("gg_colored_messages","1");
	gg_save_temp = register_cvar("gg_save_temp","300"); // = 5 * 60 = 5 minutes
	gg_status_display = register_cvar("gg_status_display","1");
	gg_map_iterations = register_cvar("gg_map_iterations","1");
	gg_ignore_bots = register_cvar("gg_ignore_bots","0");
	gg_block_equips = register_cvar("gg_block_equips","0");
	gg_leader_display = register_cvar("gg_leader_display","1");
	gg_leader_display_x = register_cvar("gg_leader_display_x","-1.0");
	gg_leader_display_y = register_cvar("gg_leader_display_y","0.0");
	gg_allow_changeteam = register_cvar("gg_allow_changeteam","2");
	gg_disable_money = register_cvar("gg_disable_money","1");
	gg_winner_motd = register_cvar("gg_winner_motd","1");

	// autovote cvars
	gg_autovote_rounds = register_cvar("gg_autovote_rounds","0");
	gg_autovote_delay = register_cvar("gg_autovote_delay","8.0");
	gg_autovote_ratio = register_cvar("gg_autovote_ratio","0.51");
	gg_autovote_time = register_cvar("gg_autovote_time","10.0");

	// stats cvars
	gg_stats_file = register_cvar("gg_stats_file","gungame.stats");
	gg_stats_ip = register_cvar("gg_stats_ip","0");
	gg_stats_prune = register_cvar("gg_stats_prune","2592000"); // = 60 * 60 * 24 * 30 = 30 days
	gg_stats_mode = register_cvar("gg_stats_mode","2");
	gg_stats_winbonus = register_cvar("gg_stats_winbonus","1.5");
	
	// deathmatch cvars
	gg_dm = register_cvar("gg_dm","1");
	gg_dm_sp_time = register_cvar("gg_dm_sp_time","1.0");
	gg_dm_sp_mode = register_cvar("gg_dm_sp_mode","1");
	gg_dm_spawn_random = register_cvar("gg_dm_spawn_random","2");
	gg_dm_start_random = register_cvar("gg_dm_start_random","1");
	gg_dm_spawn_delay = register_cvar("gg_dm_spawn_delay","3.0");
	gg_dm_spawn_afterplant = register_cvar("gg_dm_spawn_afterplant","1");
	gg_dm_corpses = register_cvar("gg_dm_corpses","1");
	gg_dm_countdown = register_cvar("gg_dm_countdown","2");
	
	// objective cvars
	gg_block_objectives = register_cvar("gg_block_objectives","0");
	gg_bomb_defuse_lvl = register_cvar("gg_bomb_defuse_lvl","1");
	gg_host_touch_reward = register_cvar("gg_host_touch_reward","2");
	gg_host_rescue_reward = register_cvar("gg_host_rescue_reward","2");
	gg_host_kill_reward = register_cvar("gg_host_kill_reward","1");
	gg_host_kill_penalty = register_cvar("gg_host_kill_penalty","1");
	
	// teamplay cvars
	gg_teamplay = register_cvar("gg_teamplay","0");
	gg_teamplay_melee_mod = register_cvar("gg_teamplay_melee_mod","0.33");
	gg_teamplay_nade_mod = register_cvar("gg_teamplay_nade_mod","0.50");
	gg_teamplay_timeratio = register_cvar("gg_teamplay_timeratio","1");

	// gameplay cvars
	gg_ff_auto = register_cvar("gg_ff_auto","1");
	gg_weapon_order = register_cvar("gg_weapon_order","glock18,usp,p228,deagle,fiveseven,elite,m3,xm1014,tmp,mac10,mp5navy,ump45,p90,galil,famas,ak47,scout,m4a1,sg552,aug,m249,hegrenade,knife");
	gg_max_lvl = register_cvar("gg_max_lvl","3");
	gg_triple_on = register_cvar("gg_triple_on","0");
	gg_turbo = register_cvar("gg_turbo","1");
	gg_knife_pro = register_cvar("gg_knife_pro","1");
	gg_knife_elite = register_cvar("gg_knife_elite","0");
	gg_suicide_penalty = register_cvar("gg_suicide_penalty","1");
	gg_worldspawn_suicide = register_cvar("gg_worldspawn_suicide","1");
	gg_pickup_others = register_cvar("gg_pickup_others","0");
	gg_handicap_on = register_cvar("gg_handicap_on","1");
	gg_top10_handicap = register_cvar("gg_top10_handicap","1");
	gg_warmup_timer_setting = register_cvar("gg_warmup_timer_setting","60");
	gg_warmup_weapon = register_cvar("gg_warmup_weapon","knife");
	gg_warmup_multi = register_cvar("gg_warmup_multi","0");
	gg_nade_glock = register_cvar("gg_nade_glock","1");
	gg_nade_smoke = register_cvar("gg_nade_smoke","0");
	gg_nade_flash = register_cvar("gg_nade_flash","0");
	gg_extra_nades = register_cvar("gg_extra_nades","1");
	gg_nade_refresh = register_cvar("gg_nade_refresh","5.0");
	gg_kills_per_lvl = register_cvar("gg_kills_per_lvl","2");
	gg_give_armor = register_cvar("gg_give_armor","100");
	gg_give_helmet = register_cvar("gg_give_helmet","1");
	gg_ammo_amount = register_cvar("gg_ammo_amount","200");
	gg_refill_on_kill = register_cvar("gg_refill_on_kill","1");
	gg_tk_penalty = register_cvar("gg_tk_penalty","1");
	gg_awp_oneshot = register_cvar("gg_awp_oneshot","1");
	
	// sound cvars done in plugin_precache now

	// random weapon order cvars
	new i, cvar[20];
	for(i=1;i<=MAX_WEAPON_ORDERS;i++)
	{
		formatex(cvar,19,"gg_weapon_order%i",i);
		register_cvar(cvar,"");
	}
	
	// update status immediately
	ggActive = get_pcvar_num(gg_enabled);

	// make sure to setup amx_nextmap incase nextmap.amxx isn't running
	if(!cvar_exists("amx_nextmap")) register_cvar("amx_nextmap","",FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);
	
	// make sure we have this to trick mapchooser.amxx into working
	if(!cvar_exists("mp_maxrounds")) register_cvar("mp_maxrounds","0",FCVAR_SERVER|FCVAR_EXTDLL|FCVAR_SPONLY);

	// collect some other information that would be handy
	maxPlayers = get_maxplayers();
	
	// create hud sync objects
	hudSyncWarmup = CreateHudSyncObj();
	hudSyncReqKills = CreateHudSyncObj();
	hudSyncLDisplay = CreateHudSyncObj();
	hudSyncCountdown = CreateHudSyncObj();
	
	// remember the mod
	new modName[7];
	get_modname(modName,6);
	if(equal(modName,"czero")) czero = 1;
	
	// identify this as a bomb map
	if(fm_find_ent_by_class(maxPlayers,"info_bomb_target") || fm_find_ent_by_class(1,"func_bomb_target"))
		bombMap = 1;

	// identify this as a hostage map
	if(fm_find_ent_by_class(maxPlayers,"hostage_entity"))
		hostageMap = 1;
	
	// get spawns for deathmatch
	init_spawns();

	// delay for server.cfg
	set_task(1.0,"toggle_gungame",TASK_TOGGLE_GUNGAME + TOGGLE_FORCE);

	// manage pruning (longer delay for toggle_gungame)
	set_task(2.0,"manage_pruning");
	
	// map configs take 6.1 seconds to load
	set_task(6.2,"setup_weapon_order");
}

// the hams that need to be hooked
hook_hams(id)
{
	RegisterHamFromEntity(Ham_Killed,id,"ham_player_killed_pre",0);
	RegisterHamFromEntity(Ham_Killed,id,"ham_player_killed_post",1);
	RegisterHamFromEntity(Ham_CS_RoundRespawn,id,"ham_player_respawn",1);
}

// plugin precache
public plugin_precache()
{
	// used in set_sounds_from_confg()
	get_configsdir(cfgDir,31);

	// sound cvars
	gg_sound_levelup = register_cvar("gg_sound_levelup","sound/gungame/smb3_powerup.wav");
	gg_sound_leveldown = register_cvar("gg_sound_leveldown","sound/gungame/smb3_powerdown.wav");
	gg_sound_levelsteal = register_cvar("gg_sound_levelsteal","sound/gungame/smb3_1-up.wav");
	gg_sound_nade = register_cvar("gg_sound_nade","sound/gungame/nade_level.wav");
	gg_sound_knife = register_cvar("gg_sound_knife","sound/gungame/knife_level.wav");
	gg_sound_welcome = register_cvar("gg_sound_welcome","sound/gungame/gungame2.wav");
	gg_sound_triple = register_cvar("gg_sound_triple","sound/gungame/smb_star.wav");
	gg_sound_winner = register_cvar("gg_sound_winner","media/Half-Life03.mp3;media/Half-Life08.mp3;media/Half-Life11.mp3;media/Half-Life17.mp3");
	gg_sound_takenlead = register_cvar("gg_sound_takenlead","sound/gungame/takenlead.wav");
	gg_sound_tiedlead = register_cvar("gg_sound_tiedlead","sound/gungame/tiedlead.wav");
	gg_sound_lostlead = register_cvar("gg_sound_lostlead","sound/gungame/lostlead.wav");
	gg_lead_sounds = register_cvar("gg_lead_sounds","0.8");
	
	mp_friendlyfire = get_cvar_pointer("mp_friendlyfire");

	// load sound values from gungame.cfg
	set_sounds_from_config();
	
	// really precache them
	precache_sound_by_cvar(gg_sound_levelup);
	precache_sound_by_cvar(gg_sound_leveldown);
	precache_sound_by_cvar(gg_sound_levelsteal);
	precache_sound_by_cvar(gg_sound_nade);
	precache_sound_by_cvar(gg_sound_knife);
	precache_sound_by_cvar(gg_sound_welcome);
	precache_sound_by_cvar(gg_sound_triple);
	
	if(get_pcvar_float(gg_lead_sounds) > 0.0)
	{
		precache_sound_by_cvar(gg_sound_takenlead);
		precache_sound_by_cvar(gg_sound_tiedlead);
		precache_sound_by_cvar(gg_sound_lostlead);
	}
	
	// win sounds enabled
	get_pcvar_string(gg_sound_winner,dummy,1);
	if(dummy[0])
	{
		// gg_sound_winner might contain multiple sounds
		new buffer[WINSOUNDS_SIZE], temp[MAX_WINSOUND_LEN+1], pos;
		get_pcvar_string(gg_sound_winner,buffer,WINSOUNDS_SIZE-1);
	
		while(numWinSounds < MAX_WINSOUNDS)
		{
			pos = contain(buffer,";");
		
			// no more after this, precache what we have left
			if(pos == -1)
			{
				precache_generic(buffer);
				formatex(winSounds[numWinSounds++],MAX_WINSOUND_LEN,"%s",buffer);

				break;
			}
		
			// copy up to the semicolon and precache that
			formatex(temp,pos,"%s",buffer);
			precache_generic(temp);

			formatex(winSounds[numWinSounds++],MAX_WINSOUND_LEN,"%s",temp);

			// copy everything after the semicolon
			format(buffer,WINSOUNDS_SIZE-1,"%s",buffer[pos+1]);
		}
	}

	// some generic, non-changing things
	precache_sound("gungame/brass_bell_C.wav");
	precache_sound("buttons/bell1.wav");
	precache_sound("common/null.wav");

	// for the star
	trailSpr = precache_model("sprites/laserbeam.spr");
}

// plugin ends, prune stats file maybe
public plugin_end()
{
	// run endmap setup on plugin close
	if(ggActive)
	{
		// reset random teamplay
		if(initTeamplay != -1) set_pcvar_num(gg_teamplay,initTeamplay);

		new setup[512];
		get_pcvar_string(gg_endmap_setup,setup,511);
		if(setup[0]) server_cmd(setup);
	}
}

//**********************************************************************
// FORWARDS
//**********************************************************************

// client gets a steamid
public client_authorized(id)
{
	clear_values(id);

	static authid[24];
	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	// load temporary save
	if(ggActive && get_pcvar_num(gg_save_temp))
	{
		new i, save = -1;

		// find our possible temp save
		for(i=0;i<TEMP_SAVES;i++)
		{
			if(equal(authid,tempSave[i],23))
			{
				save = i;
				break;
			}
		}

		// we found a save
		if(save > -1)
		{
			if(!get_pcvar_num(gg_teamplay))
			{
				// these are solo-only
				level[id] = tempSave[save][24];
				score[id] = tempSave[save][25];
				get_level_weapon(level[id],lvlWeapon[id],23);
			}

			statsPosition[id] = tempSave[save][26];
			teamTimes[id][0] = float(tempSave[save][27]);
			teamTimes[id][1] = float(tempSave[save][28]);
			// 29th index is the time of the save

			// clear it
			clear_save(TASK_CLEAR_SAVE+save);
		}
	}

	// cache our position if we didn't get it from a save
	if(!statsPosition[id]) statsPosition[id] = stats_get_position(authid);
}

// client leaves, reset values
public client_disconnect(id)
{
	// remove certain tasks
	remove_task(TASK_VERIFY_WEAPON+id);
	remove_task(TASK_REFRESH_NADE+id);
	remove_task(TASK_RESPAWN+id);
	remove_task(TASK_CHECK_DEATHMATCH+id);
	remove_task(TASK_REMOVE_PROTECTION+id);
	remove_task(TASK_DELAYED_SUICIDE+id);
	
	// don't bother saving if in winning period or warmup
	if(!won && warmup <= 0)
	{
		new save_temp = get_pcvar_num(gg_save_temp);

		// temporarily save values
		if(ggActive && save_temp && (level[id] > 1 || score[id] > 0))
		{
			// keep track of times
			new team = _:cs_get_user_team(id);
			if(team == 1 || team == 2) teamTimes[id][team-1] += get_gametime() - lastSwitch[id];

			new freeSave = -1, oldestSave = -1, i;

			for(i=0;i<TEMP_SAVES;i++)
			{
				// we found a free one
				if(!tempSave[i][0])
				{
					freeSave = i;
					break;
				}

				// keep track of one soonest to expire
				if(oldestSave == -1 || tempSave[i][29] < tempSave[oldestSave][29])
					oldestSave = i;
			}

			// no free, use oldest
			if(freeSave == -1) freeSave = oldestSave;

			if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,tempSave[freeSave],23);
			else get_user_authid(id,tempSave[freeSave],23);

			tempSave[freeSave][24] = level[id];
			tempSave[freeSave][25] = score[id];
			tempSave[freeSave][26] = statsPosition[id];
			tempSave[freeSave][27] = floatround(get_gametime());
			tempSave[freeSave][28] = floatround(teamTimes[id][0]);
			tempSave[freeSave][29] = floatround(teamTimes[id][1]);

			set_task(float(save_temp),"clear_save",TASK_CLEAR_SAVE+freeSave);
		}
	}

	clear_values(id);
	statsPosition[id] = 0;
}

// someone joins, monitor ham hooks
public client_putinserver(id)
{
	if(!ham_registered) set_task(1.0,"hook_ham",id);
	if(czero && !czbot_ham_registered) set_task(1.0,"czbot_hook_ham",id);
}

// delay for private data to initialize
public hook_ham(id)
{
	if(ham_registered || !is_user_connected(id)) return;

	// probably NOT a czero bot
	if(!czero || !(pev(id,pev_flags) & FL_FAKECLIENT) || get_cvar_num("bot_quota") <= 0)
	{
		hook_hams(id);
		ham_registered = 1;
	}
}

// delay for private data to initialize
public czbot_hook_ham(id)
{
	if(czbot_ham_registered || !is_user_connected(id)) return;

	// probably a czero bot (if czero check done before set_task)
	if((pev(id,pev_flags) & FL_FAKECLIENT) && get_cvar_num("bot_quota") > 0)
	{
		hook_hams(id);
		czbot_ham_registered = 1;
	}
}

// remove a save
public clear_save(taskid)
{
	remove_task(taskid);
	tempSave[taskid-TASK_CLEAR_SAVE][0] = 0;
}

// my info... it's changed!
public client_infochanged(id)
{
	// lots of things that we don't care about
	if(!is_user_connected(id) || !ggActive || !get_pcvar_num(gg_teamplay))
		return PLUGIN_CONTINUE;
	
	// invalid team
	new team = _:cs_get_user_team(id); // get_user_team will be old team
	if(team != 1 && team != 2) return PLUGIN_CONTINUE;
	
	// something is out of synch
	if(teamLevel[team] && (level[id] != teamLevel[team] || score[id] != teamScore[team] || !equal(lvlWeapon[id],teamLvlWeapon[team])))
	{
		// set them directly
		level[id] = teamLevel[team];
		lvlWeapon[id] = teamLvlWeapon[team];
		score[id] = teamScore[team];
		
		// gimme mah weapon!
		if(is_user_alive(id)) give_level_weapon(id);
	}
	
	return PLUGIN_CONTINUE;
}

//**********************************************************************
// FORWARD HOOKS
//**********************************************************************

// an entity is given a model, check for silenced/burst status
public fw_setmodel(ent,model[])
{
	if(!ggActive) return FMRES_IGNORED;

	new owner = pev(ent,pev_owner);

	// no owner
	if(!is_user_connected(owner)) return FMRES_IGNORED;

	static classname[24]; // the extra space is used later
	pev(ent,pev_classname,classname,10);

	// not a weapon
	// checks for weaponbox, weapon_shield
	if(classname[8] != 'x' && !(classname[6] == '_' && classname[7] == 's' && classname[8] == 'h'))
		return FMRES_IGNORED;

	// makes sure we don't get memory access error,
	// but also helpful to narrow down matches
	new len = strlen(model);

	// ignore weaponboxes whose models haven't been set to correspond with their weapon types yet
	// checks for models/w_weaponbox.mdl
	if(len == 22 && model[17] == 'x') return FMRES_IGNORED;

	// ignore C4
	// checks for models/w_backpack.mdl
	if(len == 21 && model[9] == 'b') return FMRES_IGNORED;

	// checks for models/w_usp.mdl, usp, models/w_m4a1.mdl, m4a1
	if((len == 16 && model[10] == 's' && lvlWeapon[owner][1] == 's')
	|| (len == 17 && model[10] == '4' && lvlWeapon[owner][1] == '4') )
	{
		copyc(model,len-1,model[contain(model,"_")+1],'.'); // strips off models/w_ and .mdl
		formatex(classname,23,"weapon_%s",model);

		// remember silenced status
		new wEnt = fm_find_ent_by_owner(maxPlayers,classname,ent);
		if(pev_valid(wEnt)) silenced[owner] = cs_get_weapon_silen(wEnt);
	}

	// checks for models/w_glock18.mdl, glock18, models/w_famas.mdl, famas
	else if((len == 20 && model[15] == '8' && lvlWeapon[owner][6] == '8')
	|| (len == 18 && model[9] == 'f' && model[10] == 'a' && lvlWeapon[owner][0] == 'f' && lvlWeapon[owner][1] == 'a') )
	{
		copyc(model,len-1,model[contain(model,"_")+1],'.'); // strips off models/w_ and .mdl
		formatex(classname,23,"weapon_%s",model);

		// remember burst status
		new wEnt = fm_find_ent_by_owner(maxPlayers,classname,ent);
		if(pev_valid(wEnt)) silenced[owner] = cs_get_weapon_burst(wEnt);
	}
		
	// if owner is dead, remove it if we need to
	if(get_user_health(owner) <= 0 && get_pcvar_num(gg_dm) && !get_pcvar_num(gg_pickup_others))
	{
		dllfunc(DLLFunc_Think,ent);
		return FMRES_SUPERCEDE;
	}

	return FMRES_IGNORED;
}

// HELLO HELLo HELlo HEllo Hello hello
public fw_emitsound(ent,channel,sample[],Float:volume,Float:atten,flags,pitch)
{
	if(!ggActive || !is_user_connected(ent) || !get_pcvar_num(gg_dm) || spawnSounds[ent])
		return FMRES_IGNORED;

	// used to stop spawn sounds in deathmatch
	return FMRES_SUPERCEDE;
}

//**********************************************************************
// EVENT HOOKS
//**********************************************************************

// respawnish
public event_resethud(id)
{
	if(!ggActive || !is_user_connected(id))
		return;
	
	// re-entrancy fix
	static Float:lastThis[33];
	new Float:now = get_gametime();
	if(now <= lastThis[id]) return;
	lastThis[id] = now+0.15; // 0.15 for our task
	
	// bug fix for when you join in middle of round -- ham_player_spawn is not called
	remove_task(TASK_NOTIFY_PLAYER_SPAWN+id);
	set_task(0.1,"notify_player_spawn_delay",TASK_NOTIFY_PLAYER_SPAWN+id);

	// UPDATE THE DISPLAY!!!
	status_display(id);
}

// delay, because removed in ham_player_spawn
public notify_player_spawn_delay(taskid)
{
	new id = taskid-TASK_NOTIFY_PLAYER_SPAWN;
	if(is_user_alive(id)) player_spawn(id,1); // skip delay
}

// someone changes weapons
public event_curweapon(id)
{
	if(!ggActive) return;

	// keep star speed
	if(star[id]) fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)*1.5);
	
	if(!get_pcvar_num(gg_awp_oneshot)) return;

	// have at least one bullet in AWP clip
	if(read_data(2) == CSW_AWP && read_data(3) > 1)
	{
		new wEnt = get_weapon_ent(id,CSW_AWP);
		if(pev_valid(wEnt)) cs_set_weapon_ammo(wEnt,1);

		message_begin(MSG_ONE,gmsgCurWeapon,_,id);
		write_byte(1); // current?
		write_byte(CSW_AWP); // weapon
		write_byte(1); // clip
		message_end();
	}
}

// a new round has begun
public event_new_round()
{
	static armourysHidden = 0;

	roundEnded = 0;
	roundsElapsed++;
	
	c4planter = 0;
	bombStatus[3] = BOMB_PICKEDUP;

	if(!autovoted)
	{
		new autovote_rounds = get_pcvar_num(gg_autovote_rounds);

		if(autovote_rounds && gameCommenced && roundsElapsed >= autovote_rounds)
		{
			autovoted = 1;
			set_task(get_pcvar_float(gg_autovote_delay),"autovote_start");
		}
	}

	// game_player_equip
	manage_equips();

	if(!ggActive) return;
	
	// we should probably warmup...
	// don't ask me where I'm getting this from.
	if(shouldWarmup)
	{
		shouldWarmup = 0;
		start_warmup();
	}
	
	if(warmup <= 0)
	{
		new leader = get_leader();

		if(equal(lvlWeapon[leader],"hegrenade")) play_sound_by_cvar(0,gg_sound_nade);
		else if(equal(lvlWeapon[leader],"knife")) play_sound_by_cvar(0,gg_sound_knife);
	}
	
	// reset leader display
	remove_task(TASK_LEADER_DISPLAY);
	set_task(0.5,"show_leader_display"); // wait to initialize levels

	new pickup_others = get_pcvar_num(gg_pickup_others);
	if(!pickup_others /*&& !armourysHidden*/) // they show up again on new round
	{
		set_task(0.1,"hide_armory_entitys");
		armourysHidden = 1;
	}
	else if(pickup_others && armourysHidden)
	{
		set_task(0.1,"show_armory_entitys");
		armourysHidden = 0;
	}

	// block hostages
	if(hostageMap)
	{
		// block hostages
		if(get_pcvar_num(gg_block_objectives))
			set_task(0.1,"move_hostages");
		else
		{
			// reset hostage info
			new i;
			for(i=0;i<33;i++)
			{
				hosties[i][0] = 0;
				hosties[i][1] = 0;
			}
		}
	}

	// start in random positions at round start
	if(get_pcvar_num(gg_dm) && get_pcvar_num(gg_dm_start_random))
		set_task(0.1,"randomly_place_everyone");
}

// hide the armoury_entity's so players cannot pick them up
public hide_armory_entitys()
{
	new ent = maxPlayers;
	while((ent = fm_find_ent_by_class(ent,"armoury_entity")))
	{
		set_pev(ent,pev_solid,SOLID_NOT);
		fm_set_entity_visibility(ent,0);
	}
}

// reveal the armoury_entity's so players CAN pick them up
public show_armory_entitys()
{
	new ent = maxPlayers;
	while((ent = fm_find_ent_by_class(ent,"armoury_entity")))
	{
		set_pev(ent,pev_solid,SOLID_TRIGGER);
		fm_set_entity_visibility(ent,1);
	}
}

// move the hostages so that CTs can't get to them
public move_hostages()
{
	new ent = maxPlayers;
	while((ent = fm_find_ent_by_class(ent,"hostage_entity")))
		set_pev(ent,pev_origin,Float:{8192.0,8192.0,8192.0});
}

// round is restarting (TAG: sv_restartround)
public event_round_restart()
{
	// re-entrancy fix
	static Float:lastThis;
	new Float:now = get_gametime();
	if(now == lastThis) return;
	lastThis = now;

	static message[17];
	read_data(2,message,16);

	if(equal(message,"#Game_Commencing"))
	{
		// don't reset values on game commencing,
		// if it has already commenced once
		if(gameCommenced) return;
		gameCommenced = 1;
		
		// start warmup
		if(ggActive)
		{
			clear_all_values();

			shouldWarmup = 0;
			start_warmup();
			
			return;
		}
	}
	else if(ggActive) // #Game_will_restart_in
	{
		read_data(3,message,4); // time to restart in
		new Float:time = floatstr(message) - 0.1;
		set_task((time < 0.1) ? 0.1 : time,"clear_all_values");
	}
}

// a delayed clearing
public clear_all_values()
{
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player)) clear_values(player,1);
	}
	
	clear_team_values(1);
	clear_team_values(2);
}

// the bomb explodes
public event_bomb_detonation()
{
	if(!ggActive || get_pcvar_num(gg_bomb_defuse_lvl) != 2 || !c4planter)
		return;
	
	// re-entrancy fix
	static Float:lastThis;
	new Float:now = get_gametime();
	if(now == lastThis) return;
	lastThis = now;

	new id = c4planter;
	c4planter = 0;

	if(!is_user_connected(id)) return;

	if(!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife") && level[id] < weaponNum)
	{
		change_level(id,1);
		//score[id] = 0;
	}
	else if(is_user_alive(id)) refill_ammo(id);
}

// ammo amount changes
public event_ammox(id)
{
	new type = read_data(1);

	// not HE grenade ammo, or not on the grenade level
	if(type != 12 || !equal(lvlWeapon[id],"hegrenade")) return;

	new amount = read_data(2);

	// still have some left, ignore
	if(amount > 0)
	{
		remove_task(TASK_REFRESH_NADE+id);
		return;
	}

	new Float:refresh = get_pcvar_float(gg_nade_refresh);

	// refreshing is disabled, or we are already giving one out
	if(refresh <= 0.0 || task_exists(TASK_REFRESH_NADE+id)) return;

	// start the timer for the new grenade
	set_task(refresh,"refresh_nade",TASK_REFRESH_NADE+id);
}

// map is changing
public event_intermission()
{
	if(!ggActive || won) return;
	
	new player, found;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && on_valid_team(player))
		{
			found = 1;
			break;
		}
	}
	
	// did not find any players on a valid team, game over man
	if(!found) return;
	
	// teamplay, easier to decide
	if(get_pcvar_num(gg_teamplay))
	{
		new winner;

		// clear winner
		if(teamLevel[1] > teamLevel[2]) winner = 1;
		else if(teamLevel[2] > teamLevel[1]) winner = 2;
		else
		{
			// tied for level, check score
			if(teamScore[1] > teamScore[2]) winner = 1;
			else if(teamScore[2] > teamScore[1]) winner = 2;
			else
			{
				// tied for level and score, pick random
				winner = random_num(1,2);
			}
		}
		
		// grab a player from the winning and losing teams
		new plWinner, plLoser;
		for(player=1;player<=maxPlayers;player++)
		{
			if(is_user_connected(player) && on_valid_team(player))
			{
				if(!plWinner && _:cs_get_user_team(player) == winner) plWinner = player;
				else if(!plLoser) plLoser = player;
				
				if(plWinner && plLoser) break;
			}
		}
		
		win(plWinner,plLoser);
		return;
	}

	// grab highest level
	new leaderLevel;
	get_leader(leaderLevel);

	// grab player list
	new players[32], pNum, winner, i;
	get_players(players,pNum);
	
	// no one here
	if(pNum <= 0) return;

	new topLevel[32], tlNum;

	// get all of the highest level players
	for(i=0;i<pNum;i++)
	{
		player = players[i];
		
		if(level[player] == leaderLevel)
			topLevel[tlNum++] = player;
	}

	// only one on top level
	if(tlNum == 1) winner = topLevel[0];
	else
	{
		new highestKills, frags;

		// get the most kills
		for(i=0;i<tlNum;i++)
		{
			frags = get_user_frags(topLevel[i]);

			if(frags >= highestKills)
				highestKills = frags;
		}

		new topKillers[32], tkNum;

		// get all of the players with highest kills
		for(i=0;i<tlNum;i++)
		{
			if(get_user_frags(topLevel[i]) == highestKills)
				topKillers[tkNum++] = topLevel[i];
		}

		// only one on top kills
		if(tkNum == 1) winner = topKillers[0];
		else
		{
			new leastDeaths, deaths;

			// get the least deaths
			for(i=0;i<tkNum;i++)
			{
				deaths = cs_get_user_deaths(topKillers[i]);
				if(deaths <= leastDeaths) leastDeaths = deaths;
			}

			new leastDead[32], ldNum;

			// get all of the players with lowest deaths
			for(i=0;i<tkNum;i++)
			{
				if(cs_get_user_deaths(topKillers[i]) == leastDeaths)
					leastDead[ldNum++] = topKillers[i];
			}

			leastDead[random_num(0,ldNum-1)];
		}
	}

	// crown them
	win(winner,0);
}

//**********************************************************************
// MESSAGE HOOKS
//**********************************************************************

// bomb is dropped, remember for DM
public message_bombdrop(msg_id,msg_dest,msg_entity)
{
	if(ggActive && get_pcvar_num(gg_block_objectives))
		return PLUGIN_HANDLED;

	// you can't simply get_msg_arg_int the coords
	bombStatus[0] = floatround(get_msg_arg_float(1));
	bombStatus[1] = floatround(get_msg_arg_float(2));
	bombStatus[2] = floatround(get_msg_arg_float(3));
	bombStatus[3] = get_msg_arg_int(4);

	return PLUGIN_CONTINUE;
}

// bomb is picked up, remember for DM
public message_bombpickup(msg_id,msg_dest,msg_entity)
{
	bombStatus[3] = BOMB_PICKEDUP;
	return PLUGIN_CONTINUE;
}

// scenario changes
public message_scenario(msg_id,msg_dest,msg_entity)
{
	// disabled
	if(!ggActive) return PLUGIN_CONTINUE;

	// don't override our custom display, if we have one
	if(get_pcvar_num(gg_status_display))
		return PLUGIN_HANDLED;

	// block hostage display if we disabled objectives
	else if(get_msg_args() > 1 && get_pcvar_num(gg_block_objectives))
	{
		new sprite[8];
		get_msg_arg_string(2,sprite,7);

		if(equal(sprite,"hostage"))
			return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// remove c4 if we disabled objectives
public message_weappickup(msg_id,msg_dest,msg_entity)
{
	if(!bombMap || !ggActive || !get_pcvar_num(gg_block_objectives))
		return PLUGIN_CONTINUE;

	if(get_msg_arg_int(1) == CSW_C4)
	{
		set_task(0.1,"strip_c4",msg_entity);
		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// delay, since weappickup is slightly before we actually get the weapon
public strip_c4(id)
{
	ham_strip_weapon(id,"weapon_c4");
	
	// remove it from HUD
	message_begin(MSG_ONE,gmsgStatusIcon,_,id);
	write_byte(0);
	write_string("c4");
	message_end();
}

// block c4 ammo message if we disabled objectives
public message_ammopickup(msg_id,msg_dest,msg_entity)
{
	if(!bombMap || !ggActive || !get_pcvar_num(gg_block_objectives))
		return PLUGIN_CONTINUE;

	if(get_msg_arg_int(1) == 14) // C4
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

// block dropped the bomb message if we disabled objectives
public message_textmsg(msg_id,msg_dest,msg_entity)
{
	if(!bombMap || !ggActive || !get_pcvar_num(gg_block_objectives))
		return PLUGIN_CONTINUE;

	static message[16];
	get_msg_arg_string(2,message,15);

	if(equal(message,"#Game_bomb_drop"))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

// block hostages from appearing on radar if we disabled objectives
public message_hostagepos(msg_id,msg_dest,msg_entity)
{
	if(!ggActive || !get_pcvar_num(gg_block_objectives))
		return PLUGIN_CONTINUE;

	return PLUGIN_HANDLED;
}

// a corpse is to be set, stop player shells bug (thanks sawce)
public message_clcorpse(msg_id,msg_dest,msg_entity)
{
	if(!ggActive || get_msg_args() < 12)
		return PLUGIN_CONTINUE;

	if(get_pcvar_num(gg_dm) && !get_pcvar_num(gg_dm_corpses))
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

// money money money!
public message_money(msg_id,msg_dest,msg_entity)
{
	if(!ggActive || !is_user_connected(msg_entity) || !is_user_alive(msg_entity) || !get_pcvar_num(gg_disable_money))
		return PLUGIN_CONTINUE;

	// this now just changes the value of the message, passes it along,
	// and then modifies the pdata, instead of calling another cs_set_user_money
	// and sending out more messages than needed.

	set_msg_arg_int(1,ARG_LONG,0); // money
	set_msg_arg_int(2,ARG_BYTE,0); // flash

	set_pdata_int(msg_entity,OFFSET_CSMONEY,0,OFFSET_LINUX);
	return PLUGIN_CONTINUE;
}

//**********************************************************************
// LOG EVENT HOOKS
//**********************************************************************

// someone planted the bomb
public logevent_bomb_planted()
{
	if(!ggActive || !get_pcvar_num(gg_bomb_defuse_lvl) || roundEnded)
		return;

	new id = get_loguser_index();
	if(!is_user_connected(id)) return;

	if(get_pcvar_num(gg_bomb_defuse_lvl) == 2) c4planter = id;
	else
	{
		if(!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife") && level[id] < weaponNum)
		{
			change_level(id,1);
		}
		else refill_ammo(id);
	}

}

// someone defused the bomb
public logevent_bomb_defused()
{
	if(!ggActive || !get_pcvar_num(gg_bomb_defuse_lvl))
		return;

	new id = get_loguser_index();
	if(!is_user_connected(id)) return;

	if(!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife") && level[id] < weaponNum)
	{
		change_level(id,1);
	}
	else refill_ammo(id);
}

// the round ends
public logevent_round_end()
{
	roundEnded = 1;
}

// hostage is touched
public logevent_hostage_touched()
{
	new reward = get_pcvar_num(gg_host_touch_reward);

	if(!ggActive || !reward || roundEnded)
		return;

	new id = get_loguser_index();
	if(!is_user_connected(id) || hosties[id][0] == -1) return;

	hosties[id][0]++;

	if(hosties[id][0] >= reward)
	{
		if((!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife") && level[id] < weaponNum)
			|| score[id] + 1 < get_level_goal(level[id],id))
		{		
			// didn't level off of it
			if(!change_score(id,1)) show_required_kills(id);
		}
		else refill_ammo(id);

		hosties[id][0] = -1;
		
		if(get_pcvar_num(gg_teamplay))
		{
			new CsTeams:team = cs_get_user_team(id), i;
			for(i=1;i<=maxPlayers;i++)
			{
				// one per team
				if(is_user_connected(i) && cs_get_user_team(i) == team)
					hosties[i][0] = -1;
			}
		}
	}
}

// hostage is rescued
public logevent_hostage_rescued()
{
	new reward = get_pcvar_num(gg_host_rescue_reward);

	if(!ggActive || !reward || roundEnded)
		return;

	new id = get_loguser_index();
	if(!is_user_connected(id) || hosties[id][1] == -1) return;

	hosties[id][1]++;

	if(hosties[id][1] >= reward)
	{
		if(!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife") && level[id] < weaponNum)
			change_level(id,1);
		else
			refill_ammo(id);

		hosties[id][1] = -1;
		
		if(get_pcvar_num(gg_teamplay))
		{
			new CsTeams:team = cs_get_user_team(id), i;
			for(i=1;i<=maxPlayers;i++)
			{
				// one per team
				if(is_user_connected(i) && cs_get_user_team(i) == team)
					hosties[i][1] = -1;
			}
		}
	}
}

// hostage is killed
public logevent_hostage_killed()
{
	new penalty = get_pcvar_num(gg_host_kill_penalty);

	if(!ggActive || !penalty)
		return;

	new id = get_loguser_index();
	if(!is_user_connected(id)) return;
	
	new teamplay = get_pcvar_num(gg_teamplay), name[32];
	
	if(teamplay) get_user_team(id,name,9);
	else get_user_name(id,name,31);

	if(score[id] - penalty < 0)
		gungame_print(0,id,1,"%L",LANG_PLAYER_C,(teamplay) ? "HK_LEVEL_DOWN_TEAM" : "HK_LEVEL_DOWN",name,(level[id] > 1) ? level[id]-1 : level[id]);
	else
		gungame_print(0,id,1,"%L",LANG_PLAYER_C,(teamplay) ? "HK_SCORE_DOWN_TEAM" : "HK_SCORE_DOWN",name,penalty);

	change_score(id,-penalty);
}

// someone joins a team
public logevent_team_join()
{
	if(!ggActive) return;

	new id = get_loguser_index();
	if(!is_user_connected(id)) return;

	new oldTeam = get_user_team(id), newTeam = _:cs_get_user_team(id);
	player_teamchange(id,oldTeam,newTeam);
	
	// teamplay, team switch allowed
	if(get_pcvar_num(gg_teamplay))
	{
		remove_task(TASK_DELAYED_SUICIDE+id);
		
		// I was the one who planted the bomb
		if(c4planter == id)
		{
			// clear in case we don't find anyone
			c4planter = 0;
			
			new player;
			for(player=1;player<=maxPlayers;player++)
			{
				if(player != id && is_user_connected(player) && cs_get_user_team(player) == CS_TEAM_T)
				{
					// assign it to someone else so terrorists get points
					c4planter = player;
					break;
				}
			}
		}
			
		return;
	}
	
	// no (valid) previous team or didn't switch teams, ignore (suicide)
	if(oldTeam < 1 || oldTeam > 2 || newTeam < 1 || newTeam > 2 || oldTeam == newTeam)
		return;

	// check to see if the team change was beneficial
	if(get_pcvar_num(gg_allow_changeteam) == 2)
	{
		new teamCount[2], i;
		for(i=1;i<=maxPlayers;i++)
		{
			if(!is_user_connected(i))
				continue;

			switch(cs_get_user_team(i))
			{
				case CS_TEAM_T: teamCount[0]++;
				case CS_TEAM_CT: teamCount[1]++;
			}
		}

		if(teamCount[newTeam-1] <= teamCount[oldTeam-1])
			remove_task(TASK_DELAYED_SUICIDE+id);
	}
	else remove_task(TASK_DELAYED_SUICIDE+id);
}

//**********************************************************************
// HAM HOOKS
//**********************************************************************

// a player respawned
public ham_player_respawn(id)
{
	if(!ggActive) return HAM_IGNORED;

	remove_task(TASK_CHECK_DEATHMATCH+id);
	remove_task(TASK_NOTIFY_PLAYER_SPAWN+id); // stop resethud's spawn notice
	
	// wait for inventory to initialize
	if(get_pcvar_num(gg_pickup_others))
		set_task(0.1,"strip_starting_pistols",id);

	player_spawn(id);
	
	return HAM_IGNORED;
}

// what do you think happened here?
public ham_player_killed_pre(victim,killer,gib)
{
	if(!ggActive || won || !is_user_connected(victim)) return HAM_IGNORED;

	// allow us to join in on deathmatch
	if(!get_pcvar_num(gg_dm))
	{
		remove_task(TASK_CHECK_DEATHMATCH+victim);
		set_task(10.0,"check_deathmatch",TASK_CHECK_DEATHMATCH+victim);
	}

	// respawn us
	else
	{
		remove_task(TASK_RESPAWN+victim);
		remove_task(TASK_REMOVE_PROTECTION+victim);
		begin_respawn(victim);
		fm_set_user_rendering(victim); // clear spawn protection
	}

	// stops defusal kits from dropping in deathmatch mode
	if(bombMap && get_pcvar_num(gg_dm)) cs_set_user_defuse(victim,0);

	// remember victim's silenced status
	if(equal(lvlWeapon[victim],"usp") || equal(lvlWeapon[victim],"m4a1"))
	{
		new wEnt = get_weapon_ent(victim,_,lvlWeapon[victim]);
		if(pev_valid(wEnt)) silenced[victim] = cs_get_weapon_silen(wEnt);
	}

	// or, remember burst status
	else if(equal(lvlWeapon[victim],"glock18") || equal(lvlWeapon[victim],"famas"))
	{
		new wEnt = get_weapon_ent(victim,_,lvlWeapon[victim]);
		if(pev_valid(wEnt)) silenced[victim] = cs_get_weapon_burst(wEnt);
	}
	
	// some sort of death that we don't want to count
	if(killer == victim || !is_user_connected(killer) || cs_get_user_team(killer) == cs_get_user_team(victim))
		return HAM_IGNORED;

	// award for killing hostage carrier
	new host_kill_reward = get_pcvar_num(gg_host_kill_reward);

	// note that this doesn't work with CZ hostages
	if(hostageMap && !czero && host_kill_reward && !equal(lvlWeapon[killer],"hegrenade") && !equal(lvlWeapon[killer],"knife"))
	{
		// check for hostages following this player
		new hostage = maxPlayers;
		while((hostage = fm_find_ent_by_class(hostage,"hostage_entity")))
		{
			if(cs_get_hostage_foll(hostage) == victim && pev(hostage,pev_deadflag) == DEAD_NO)
				break;
		}

		// award bonus score if victim had hostages
		if(hostage)
		{
			if(!equal(lvlWeapon[killer],"hegrenade") && !equal(lvlWeapon[killer],"knife") && level[killer] < weaponNum)
			{
				// didn't level off of it
				if(!change_score(killer,host_kill_reward) || score[killer])
					show_required_kills(killer);
			}
		}
	}
	
	return HAM_IGNORED;
}

// it's just that easy (multiplay_gamerules.cpp, ln 709)
public ham_player_killed_post(victim,killer,gib)
{
	if(!ggActive || won) return HAM_IGNORED;
	
	// log in bounds
	if(killer > 0 && killer < 33 && victim > 0 && victim < 33)
		lastKilled[killer] = victim;

	if(!is_user_connected(victim)) return HAM_IGNORED;

	remove_task(TASK_VERIFY_WEAPON+victim);

	star[victim] = 0;
	remove_task(TASK_END_STAR+victim);

	static wpnName[24];
	get_killer_weapon(killer,pev(victim,pev_dmg_inflictor),wpnName,23);
	
	// grenade death
	if(equal(wpnName,"grenade"))
	{
		new inflictor = pev(victim,pev_dmg_inflictor);
		
		if(pev_valid(inflictor))
		{
			new Float:dmgtime;
			pev(inflictor,pev_dmgtime,dmgtime);
		
			// a C4 kill will be reported as hegrenade. however, C4 has no
			// pev_dmgtime, while a real hegrenade does. so distinguish between hegrenade
			// and C4, and ignore C4 kills. also note that we can't compare models,
			// because at this stage both an hegrenade and C4 have no model.
			if(!dmgtime) return 0;
		}

		// fix name
		formatex(wpnName,23,"hegrenade");
	}

	// killed self with world
	if(killer == victim && equal(wpnName,"world") && is_user_connected(killer))
	{
		// this might be a valid team switch, wait it out
		if(!roundEnded && get_pcvar_num(gg_allow_changeteam))
		{
			set_task(0.1,"delayed_suicide",TASK_DELAYED_SUICIDE+victim);
			return 0; // in the meantime, don'tpenalize the suicide
		}

		player_suicided(killer);
		return 1; 
	}

	// other player had spawn protection
	if(spawnProtected[victim])
	{
		new name[32];
		get_user_name(victim,name,31);

		gungame_print(killer,victim,1,"%L",killer,"SPAWNPROTECTED_KILL",name,floatround(get_pcvar_float(gg_dm_sp_time)));
		return 0;
	}

	// killed self with worldspawn (fall damage usually)
	if(equal(wpnName,"worldspawn"))
	{
		if(get_pcvar_num(gg_worldspawn_suicide)) player_suicided(victim);
		return HAM_IGNORED;
	}

	// killed self not with worldspawn
	if(!killer || killer == victim)
	{
		player_suicided(victim);
		return HAM_IGNORED;
	}
	
	// a non-player entity killed this man!
	if(!is_user_connected(killer))
	{
		// not linked so return is hit either way
		if(pev_valid(killer))
		{
			static classname[14];
			pev(killer,pev_classname,classname,13);
			
			// killed by a trigger_hurt, count as suicide
			if(equal(classname,"trigger_hurt"))
				player_suicided(victim);
		}
		
		return HAM_IGNORED;
	}
	
	new teamplay = get_pcvar_num(gg_teamplay), penalty = get_pcvar_num(gg_tk_penalty);

	// team kill
	if(is_user_connected(victim) && cs_get_user_team(killer) == cs_get_user_team(victim) && penalty >= 0)
	{
		if(penalty > 0)
		{
			new name[32];
			if(teamplay) get_user_team(killer,name,9);
			else get_user_name(killer,name,31);

			if(score[killer] - penalty < 0)
				gungame_print(0,killer,1,"%L",LANG_PLAYER_C,(teamplay) ? "TK_LEVEL_DOWN_TEAM" : "TK_LEVEL_DOWN",name,(level[killer] > 1) ? level[killer]-1 : level[killer]);
			else
				gungame_print(0,killer,1,"%L",LANG_PLAYER_C,(teamplay) ? "TK_SCORE_DOWN_TEAM" : "TK_SCORE_DOWN",name,penalty);

			change_score(killer,-penalty);
		}

		return HAM_IGNORED;
	}

	new canLevel = 1, scored;

	// already reached max levels this round
	new max_lvl = get_pcvar_num(gg_max_lvl);
	if(!get_pcvar_num(gg_teamplay) && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[killer] >= max_lvl)
		canLevel = 0;
	
	new nade = equal(lvlWeapon[killer],"hegrenade");

	// was it a melee kill, and does it matter?
	if(equal(wpnName,"knife") && get_pcvar_num(gg_knife_pro) && !equal(lvlWeapon[killer],"knife"))
	{
		static killerName[32], victimName[32], authid[24], teamName[10];
		get_user_name(killer,killerName,31);
		get_user_name(victim,victimName,31);
		get_user_authid(killer,authid,23);
		get_user_team(killer,teamName,9);
		
		log_message("^"%s<%i><%s><%s>^" triggered ^"Stole_Level^"",killerName,get_user_userid(killer),authid,teamName);
		
		new tpGainPoints, tpLosePoints, tpOverride;
		if(teamplay)
		{
			tpGainPoints = get_level_goal(level[killer],0);
			tpLosePoints = get_level_goal(level[victim],0);
			gungame_print(0,killer,1,"%L",LANG_PLAYER_C,"STOLE_LEVEL_TEAM",killerName,tpLosePoints,victimName,tpGainPoints);
			
			// allow points awarded on nade or final level if it won't level us
			tpOverride = (score[killer] + tpGainPoints < get_level_goal(level[killer],killer));
		}
		else gungame_print(0,killer,1,"%L",LANG_PLAYER_C,"STOLE_LEVEL",killerName,victimName);

		if(tpOverride || (canLevel && !nade))
		{
			if(tpOverride || level[killer] < weaponNum)
			{
				if(teamplay)
				{
					// gain points and possibly show kills
					if(!change_score(killer,tpGainPoints))
						show_required_kills(killer);
				}
				else change_level(killer,1,_,_,_,0); // don't play sounds
			}
		}

		play_sound_by_cvar(killer,gg_sound_levelsteal); // use this one instead!

		if(level[victim] > 1 || teamplay)
		{
			if(teamplay) change_score(victim,-tpLosePoints);
			else change_level(victim,-1);
		}
	}

	// otherwise, if he killed with his appropiate weapon, give him a point
	else if(canLevel && equal(lvlWeapon[killer],wpnName))
	{
		scored = 1;

		// didn't level off of it
		if(!change_score(killer,1)) show_required_kills(killer);
	}
	
	// refresh grenades
	if(nade && get_pcvar_num(gg_extra_nades))
	{
		remove_task(TASK_REFRESH_NADE+killer);
		
		// instant refresh, and refresh_nade makes sure we don't already have a nade
		refresh_nade(TASK_REFRESH_NADE+killer);
	}

	if((!scored || !get_pcvar_num(gg_turbo)) && get_pcvar_num(gg_refill_on_kill))
		refill_ammo(killer,1);
	
	return HAM_IGNORED;
}

// a player is touching a weaponbox or armoury_entity, possibly disallow
public ham_weapon_touch(weapon,other)
{
	// gungame off, non-player or dead-player, or allowed to pick up others
	if(!ggActive || !is_user_alive(other) || get_pcvar_num(gg_pickup_others))
		return HAM_IGNORED;
	
	static model[24];
	pev(weapon,pev_model,model,23);

	// strips off models/w_ and .mdl
	copyc(model,23,model[contain(model,"_")+1],'.');
	
	// weaponbox model is no good, but C4 is okay
	// checks for weaponbox, backpack
	if(model[8] == 'x' || model[0] == 'b') return HAM_IGNORED;
	
	// weapon is weapon_mp5navy, but model is w_mp5.mdl
	// checks for mp5
	if(model[1] == 'p' && model[2] == '5') model = "mp5navy";

	// check hegrenade exceptions
	// checks for hegrenade
	if(lvlWeapon[other][0] == 'h')
	{
		// checks for glock18, smokegrenade, flashbang
		if((model[6] == '8' && get_pcvar_num(gg_nade_glock))
			|| (model[0] == 's' && model[1] == 'm' && get_pcvar_num(gg_nade_smoke))
			|| (model[0] == 'f' && model[1] == 'l' && get_pcvar_num(gg_nade_flash)))
			return HAM_IGNORED;
	}
	
	// this is our weapon, don't mess with it
	if(equal(lvlWeapon[other],model)) return HAM_IGNORED;

	return HAM_SUPERCEDE;
}

//**********************************************************************
// COMMAND HOOKS
//**********************************************************************

// turning GunGame on or off
public cmd_gungame(id,level,cid)
{
	// no access, or GunGame ending anyway
	if(!cmd_access(id,level,cid,2) || won)
		return PLUGIN_HANDLED;

	// already working on toggling GunGame
	if(task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_FORCE)
	|| task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_DISABLE)
	|| task_exists(TASK_TOGGLE_GUNGAME + TOGGLE_ENABLE))
	{
		console_print(id,"[GunGame] GunGame is already being turned on or off");
		return PLUGIN_HANDLED;
	}

	new arg[32], oldStatus = ggActive, newStatus;
	read_argv(1,arg,31);

	if(equali(arg,"on") || str_to_num(arg))
		newStatus = 1;

	// no change
	if((!oldStatus && !newStatus) || (oldStatus && newStatus))
	{
		console_print(id,"[GunGame] GunGame is already %s!",(newStatus) ? "on" : "off");
		return PLUGIN_HANDLED;
	}

	restart_round(5);
	set_task(4.8,"toggle_gungame",TASK_TOGGLE_GUNGAME+newStatus);

	if(!newStatus)
	{
		set_pcvar_num(gg_enabled,0);
		ggActive = 0;
	}

	console_print(id,"[GunGame] Turned GunGame %s",(newStatus) ? "on" : "off");

	return PLUGIN_HANDLED;
}

// voting for GunGame
public cmd_gungame_vote(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	autovote_start();
	console_print(id,"[GunGame] Started a vote to play GunGame");

	return PLUGIN_HANDLED;
}

// setting players levels
public cmd_gungame_level(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,3))
		return PLUGIN_HANDLED;

	new arg1[32], arg2[32], targets[32], name[32], tnum, i;
	read_argv(1,arg1,31);
	read_argv(2,arg2,31);

	// get player list
	if(equali(arg1,"*") || equali(arg1,"@ALL"))
	{
		get_players(targets,tnum);
		name = "ALL PLAYERS";
	}
	else if(arg1[0] == '@')
	{
		new players[32], team[10], pnum;
		get_players(players,pnum);

		for(i=0;i<pnum;i++)
		{
			get_user_team(players[i],team,9);
			if(equali(team,arg1[1])) targets[tnum++] = players[i];
		}

		formatex(name,31,"ALL %s",arg1[1]);
	}
	else
	{
		targets[tnum++] = cmd_target(id,arg1,2);
		if(!targets[0]) return PLUGIN_HANDLED;

		get_user_name(targets[0],name,31);
	}

	new intval = str_to_num(arg2);

	// relative
	if(arg2[0] == '+' || arg2[0] == '-')
		for(i=0;i<tnum;i++) change_level(targets[i],intval,_,_,1); // always score

	// absolute
	else
		for(i=0;i<tnum;i++) change_level(targets[i],intval-level[targets[i]],_,_,1); // always score

	console_print(id,"[GunGame] Changed %s's level to %s",name,arg2);

	return PLUGIN_HANDLED;
}

// forcing a win
public cmd_gungame_win(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;
	
	new arg[32];
	read_argv(1,arg,31);
	
	// no target given, select best player
	if(!arg[0])
	{
		console_print(id,"[GunGame] Forcing the best player to win...");
		event_intermission();
		return PLUGIN_HANDLED;
	}
	
	new target = cmd_target(id,arg,2);
	if(!target) return PLUGIN_HANDLED;

	new name[32];
	get_user_name(target,name,31);
	console_print(id,"[GunGame] Forcing %s to win (cheater)...",name);
	
	// make our target win (oh, we're dirty!)
	win(target,0);
	
	return PLUGIN_HANDLED;
}

// turn teamplay on or off
public cmd_gungame_teamplay(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,2))
		return PLUGIN_HANDLED;

	new oldValue = get_pcvar_num(gg_teamplay);

	new arg1[32], arg2[8], arg3[8];
	read_argv(1,arg1,31);
	read_argv(2,arg2,7);
	read_argv(3,arg3,7);

	new teamplay = str_to_num(arg1);
	new Float:killsperlvl = floatstr(arg2);
	new suicideloselvl = str_to_num(arg3);
	
	new result[128];
	len = formatex(result,127,"[GunGame] Turned Teamplay Mode %s",(teamplay) ? "on" : "off");

	server_cmd("gg_teamplay %i",teamplay);
	if(killsperlvl > 0.0)
	{
		server_cmd("gg_kills_per_lvl %f",killsperlvl);
		len += formatex(result[len],127-len,", set kills per level to %f",killsperlvl);
	}
	if(arg3[0])
	{
		server_cmd("gg_suicide_penalty %i",suicideloselvl);
		len += formatex(result[len],127-len,", set suicide penalty to %i",suicideloselvl);
	}

	console_print(id,"%s",result);
	
	if(teamplay != oldValue) restart_round(1);

	return PLUGIN_HANDLED;
}

// restarts GunGame
public cmd_gungame_restart(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;

	new arg[8];
	read_argv(1,arg,7);
	
	new Float:time = floatstr(arg);
	if(time < 0.2) time = 0.2;

	restart_round(floatround(time,floatround_ceil));
	console_print(id,"[GunGame] Restarting GunGame in %i seconds",floatround(time,floatround_ceil));
	
	read_argv(2,arg,1);
	if(str_to_num(arg)) set_task(time-0.1,"toggle_gungame",TASK_TOGGLE_GUNGAME+TOGGLE_ENABLE);

	return PLUGIN_HANDLED;
}

// reload weapon order
public cmd_reloadweapons(id,lvl,cid)
{
	if(!cmd_access(id,lvl,cid,1))
		return PLUGIN_HANDLED;
	
	setup_weapon_order();
	console_print(id,"* Reloaded the weapon order");
	
	return PLUGIN_HANDLED;
}

// block fullupdate
public cmd_fullupdate(id)
{
	return PLUGIN_HANDLED;
}

// hook say
public cmd_say(id)
{
	if(!ggActive) return PLUGIN_CONTINUE;

	static message[10];
	read_argv(1,message,9);

	// doesn't begin with !, ignore
	if(message[0] != '!') return PLUGIN_CONTINUE;

	if(equali(message,"!rules") || equali(message,"!help"))
	{
		new num = 1, max_lvl = get_pcvar_num(gg_max_lvl), turbo = get_pcvar_num(gg_turbo);

		console_print(id,"-----------------------------");
		console_print(id,"-----------------------------");
		console_print(id,"*** Avalanche's %L %s %L ***",id,"GUNGAME",GG_VERSION,id,"RULES");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE1",num++);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE2",num++);
		if(get_pcvar_num(gg_bomb_defuse_lvl)) console_print(id,"%L",id,"RULES_CONSOLE_LINE3",num++);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE4",num++);
		if(get_pcvar_num(gg_ff_auto)) console_print(id,"%L",id,"RULES_CONSOLE_LINE5",num++);
		if(turbo || !max_lvl) console_print(id,"%L",id,"RULES_CONSOLE_LINE6A",num++);
		else if(max_lvl == 1) console_print(id,"%L",id,"RULES_CONSOLE_LINE6B",num++);
		else if(max_lvl > 1) console_print(id,"%L",id,"RULES_CONSOLE_LINE6C",num++,max_lvl);
		console_print(id,"%L",id,"RULES_CONSOLE_LINE7",num++);
		if(get_pcvar_num(gg_knife_pro)) console_print(id,"%L",id,"RULES_CONSOLE_LINE8",num++);
		if(turbo) console_print(id,"%L",id,"RULES_CONSOLE_LINE9",num++);
		if(get_pcvar_num(gg_knife_elite)) console_print(id,"%L",id,"RULES_CONSOLE_LINE10",num++);
		if(get_pcvar_num(gg_dm) || get_cvar_num("csdm_active")) console_print(id,"%L",id,"RULES_CONSOLE_LINE11",num++);
		if(get_pcvar_num(gg_teamplay)) console_print(id,"%L",id,"RULES_CONSOLE_LINE12",num++);
		console_print(id,"****************************************************************");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE13");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE14");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE15");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE16");
		console_print(id,"%L",id,"RULES_CONSOLE_LINE17");
		console_print(id,"-----------------------------");
		console_print(id,"-----------------------------");

		len = formatex(menuText,511,"%L^n",id,"RULES_MESSAGE_LINE1");
		len += formatex(menuText[len],511-len,"\d----------\w^n");
		len += formatex(menuText[len],511-len,"%L^n",id,"RULES_MESSAGE_LINE2");
		len += formatex(menuText[len],511-len,"\d----------\w^n");
		len += formatex(menuText[len],511-len,"%L^n",id,"RULES_MESSAGE_LINE3");
		len += formatex(menuText[len],511-len,"\d----------\w^n%L",id,"PRESS_KEY_TO_CONTINUE");

		show_menu(id,1023,menuText);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!weapons") || equali(message,"!guns"))
	{
		page[id] = 1;
		//show_weapons_menu(id);
		weapons_menu_handler(id,2); // jump to me

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!top",4) && !str_count(message,' ')) // !topANYTHING
	{
		get_pcvar_string(gg_stats_file,sfFile,1);

		// stats disabled
		if(!sfFile[0] || !get_pcvar_num(gg_stats_mode))
		{
			client_print(id,print_chat,"%L",id,"NO_WIN_LOGGING");
			return PLUGIN_HANDLED;
		}

		page[id] = 1;
		//show_top10_menu(id);
		top10_menu_handler(id,2); // jump to me

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!score") || equali(message,"!scores"))
	{
		page[id] = 1;
		//show_scores_menu(id);
		scores_menu_handler(id,2); // jump to me

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!level"))
	{
		show_level_menu(id);

		return PLUGIN_HANDLED;
	}
	else if(equali(message,"!restart") || equali(message,"!reset"))
	{
		if(level[id] <= 1)
		{
			client_print(id,print_chat,"%L",id,"STILL_LEVEL_ONE");
			return PLUGIN_HANDLED;
		}

		len = formatex(menuText,511,"%L^n^n",id,"RESET_QUERY");
		len += formatex(menuText[len],511-len,"1. %L^n",id,"YES");
		len += formatex(menuText[len],511-len,"0. %L",id,"CANCEL");
		show_menu(id,MENU_KEY_1|MENU_KEY_0,menuText,-1,"restart_menu");

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

// joining a team
public cmd_joinclass(id)
{
	if(!ggActive) return PLUGIN_CONTINUE;

	// allow us to join in on deathmatch
	if(!get_pcvar_num(gg_dm))
	{
		remove_task(TASK_CHECK_DEATHMATCH+id);
		set_task(10.0,"check_deathmatch",TASK_CHECK_DEATHMATCH+id);
		return PLUGIN_CONTINUE;
	}

	if(roundEnded || (bombStatus[3] == BOMB_PLANTED && !get_pcvar_num(gg_dm_spawn_afterplant)))
		return PLUGIN_CONTINUE;

	set_task(5.0,"check_joinclass",id);
	return PLUGIN_CONTINUE;
}

// wait a bit after joinclass to see if we should jump in
public check_joinclass(id)
{
	if(!is_user_connected(id)) return;

	// already respawning
	if(task_exists(TASK_RESPAWN+id) || is_user_alive(id))
		return;

	// not on a valid team
	if(!on_valid_team(id)) return;

	respawn(TASK_RESPAWN+id);
}

//**********************************************************************
// RESPAWN FUNCTIONS
//**********************************************************************

// get all of our spawns into their arrays
init_spawns()
{
	// grab CSDM file
	new mapName[32], csdmFile[64], lineData[64];
	get_configsdir(cfgDir,31);
	get_mapname(mapName,31);
	formatex(csdmFile,63,"%s/csdm/%s.spawns.cfg",cfgDir,mapName);

	// collect CSDM spawns
	if(file_exists(csdmFile))
	{
		new csdmData[10][6];

		new file = fopen(csdmFile,"rt");
		while(file && !feof(file))
		{
			fgets(file,lineData,63);

			// invalid spawn
			if(!lineData[0] || str_count(lineData,' ') < 2)
				continue;

			// BREAK IT UP!
			parse(lineData,csdmData[0],5,csdmData[1],5,csdmData[2],5,csdmData[3],5,csdmData[4],5,csdmData[5],5,csdmData[6],5,csdmData[7],5,csdmData[8],5,csdmData[9],5);

			// origin
			spawns[spawnCount][0] = floatstr(csdmData[0]);
			spawns[spawnCount][1] = floatstr(csdmData[1]);
			spawns[spawnCount][2] = floatstr(csdmData[2]);

			// angles
			spawns[spawnCount][3] = floatstr(csdmData[3]);
			spawns[spawnCount][4] = floatstr(csdmData[4]);
			spawns[spawnCount][5] = floatstr(csdmData[5]);

			// team, csdmData[6], unused

			// vangles
			spawns[spawnCount][6] = floatstr(csdmData[7]);
			spawns[spawnCount][7] = floatstr(csdmData[8]);
			spawns[spawnCount][8] = floatstr(csdmData[9]);

			spawnCount++;
			csdmSpawnCount++;
			if(spawnCount >= MAX_SPAWNS) break;
		}
		if(file) fclose(file);
	}

	// collect regular, boring spawns
	else
	{
		collect_spawns("info_player_deathmatch");
		collect_spawns("info_player_start");
	}
}

// collect boring spawns into our spawn data
collect_spawns(classname[])
{
	new ent = maxPlayers, Float:spawnData[3];
	while((ent = fm_find_ent_by_class(ent,classname)))
	{
		// origin
		pev(ent,pev_origin,spawnData);
		spawns[spawnCount][0] = spawnData[0];
		spawns[spawnCount][1] = spawnData[1];
		spawns[spawnCount][2] = spawnData[2];

		// angles
		pev(ent,pev_angles,spawnData);
		spawns[spawnCount][3] = spawnData[0];
		spawns[spawnCount][4] = spawnData[1];
		spawns[spawnCount][5] = spawnData[2];

		// vangles
		spawns[spawnCount][6] = spawnData[0];
		spawns[spawnCount][7] = spawnData[1];
		spawns[spawnCount][8] = spawnData[2];

		spawnCount++;
		if(spawnCount >= MAX_SPAWNS) break;
	}
}

// bring someone back to life
public begin_respawn(id)
{
	if(!ggActive || !get_pcvar_num(gg_dm) || !is_user_connected(id))
		return;

	// now on spectator
	if(!on_valid_team(id)) return;

	// alive, and not in the broken sort of way
	if(is_user_alive(id) && !pev(id,pev_iuser1))
		return;

	// round is over, or bomb is planted
	if(roundEnded || (bombStatus[3] == BOMB_PLANTED && !get_pcvar_num(gg_dm_spawn_afterplant)))
		return;

	new Float:delay = get_pcvar_float(gg_dm_spawn_delay);
	if(delay < 0.1) delay = 0.1;

	new dm_countdown = get_pcvar_num(gg_dm_countdown);

	if((dm_countdown & 1) || (dm_countdown & 2))
	{
		respawn_timeleft[id] = floatround(delay);
		respawn_countdown(id);
	}

	remove_task(TASK_RESPAWN+id);
	set_task(delay,"respawn",TASK_RESPAWN+id);
}

// show the respawn countdown to a player
public respawn_countdown(id)
{
	if(!is_user_connected(id) || is_user_alive(id))
	{
		respawn_timeleft[id] = 0;
		return;
	}

	new dm_countdown = get_pcvar_num(gg_dm_countdown);

	if(dm_countdown & 1)
		client_print(id,print_center,"%L",id,"RESPAWN_COUNTDOWN",respawn_timeleft[id]);
	
	if(dm_countdown & 2)
	{
		set_hudmessage(255,255,255,-1.0,0.75,0,6.0,1.0,0.1,0.5);
		ShowSyncHudMsg(id,hudSyncCountdown,"%L",id,"RESPAWN_COUNTDOWN",respawn_timeleft[id]);
	}

	if(--respawn_timeleft[id] >= 1) set_task(1.0,"respawn_countdown",id);
}

// REALLY bring someone back to life
public respawn(taskid)
{
	new id = taskid-TASK_RESPAWN;
	if(!is_user_connected(id) || !ggActive) return;

	// round is over, or bomb is planted
	if(roundEnded || (bombStatus[3] == BOMB_PLANTED && !get_pcvar_num(gg_dm_spawn_afterplant)))
		return;

	// now on spectator
	if(!on_valid_team(id)) return;

	// clear countdown
	new dm_countdown = get_pcvar_num(gg_dm_countdown);
	if(dm_countdown & 1) client_print(id,print_center," ");
	if(dm_countdown & 2) ClearSyncHud(id,hudSyncCountdown);

	// alive, and not in the broken sort of way
	if(is_user_alive(id)) return;
	
	static model[22];

	// remove his dropped weapons from before
	new ent = maxPlayers;
	while((ent = fm_find_ent_by_class(ent,"weaponbox")))
	{
		pev(ent,pev_model,model,21);

		// don't remove the bomb!! (thanks ToT | V!PER)
		if(equal(model,"models/w_c4.mdl",15) || equal(model,"models/w_backpack.mdl"))
			continue;

		// this is mine
		if(pev(ent,pev_owner) == id) dllfunc(DLLFunc_Think,ent);
	}

	new spawn_random = get_pcvar_num(gg_dm_spawn_random);
	if(spawn_random) spawnSounds[id] = 0;

	ExecuteHamB(Ham_CS_RoundRespawn,id); // note the B

	if(spawn_random)
	{
		do_random_spawn(id,spawn_random);
		spawnSounds[id] = 1;

		// to be fair, play a spawn noise at new location
		engfunc(EngFunc_EmitSound,id,CHAN_ITEM,"items/gunpickup2.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM);
	}

	new Float:time = get_pcvar_float(gg_dm_sp_time);
	new mode = get_pcvar_num(gg_dm_sp_mode);

	// spawn protection
	if(time > 0.0 && mode)
	{
		spawnProtected[id] = 1;
		if(mode == 2)
		{
			fm_set_user_godmode(id,1);
			fm_set_rendering(id,kRenderFxGlowShell,200,200,100,kRenderNormal,1); // goldenish
		}
		else fm_set_rendering(id,kRenderFxGlowShell,100,100,100,kRenderNormal,1); // gray/white

		set_task(time,"remove_spawn_protection",TASK_REMOVE_PROTECTION+id);
	}
}

// place a user at a random spawn
do_random_spawn(id,spawn_random)
{
	// not even alive, don't brother
	if(!is_user_alive(id)) return;

	// no spawns???
	if(spawnCount <= 0) return;

	// no CSDM spawns, mode 2
	if(spawn_random == 2 && !csdmSpawnCount)
		return;

	static Float:vecHolder[3];
	new sp_index = random_num(0,spawnCount-1);

	// get origin for comparisons
	vecHolder[0] = spawns[sp_index][0];
	vecHolder[1] = spawns[sp_index][1];
	vecHolder[2] = spawns[sp_index][2];

	// this one is taken
	if(!is_hull_vacant(vecHolder,HULL_HUMAN) && spawnCount > 1)
	{
		// attempt to pick another random one up to three times
		new i;
		for(i=0;i<3;i++)
		{
			sp_index = random_num(0,spawnCount-1);

			vecHolder[0] = spawns[sp_index][0];
			vecHolder[1] = spawns[sp_index][1];
			vecHolder[2] = spawns[sp_index][2];
			
			if(is_hull_vacant(vecHolder,HULL_HUMAN)) break;
		}

		// we made it through the entire loop, no free spaces
		if(i == 3)
		{
			// just find the first available
			for(i=sp_index+1;i!=sp_index;i++)
			{
				// start over when we reach the end
				if(i >= spawnCount) i = 0;

				vecHolder[0] = spawns[i][0];
				vecHolder[1] = spawns[i][1];
				vecHolder[2] = spawns[i][2];

				// free space! office space!
				if(is_hull_vacant(vecHolder,HULL_HUMAN))
				{
					sp_index = i;
					break;
				}
			}
		}
	}

	// origin
	vecHolder[0] = spawns[sp_index][0];
	vecHolder[1] = spawns[sp_index][1];
	vecHolder[2] = spawns[sp_index][2];
	engfunc(EngFunc_SetOrigin,id,vecHolder);

	// angles
	vecHolder[0] = spawns[sp_index][3];
	vecHolder[1] = spawns[sp_index][4];
	vecHolder[2] = spawns[sp_index][5];
	set_pev(id,pev_angles,vecHolder);

	// vangles
	vecHolder[0] = spawns[sp_index][6];
	vecHolder[1] = spawns[sp_index][7];
	vecHolder[2] = spawns[sp_index][8];
	set_pev(id,pev_v_angle,vecHolder);

	set_pev(id,pev_fixangle,1);
}

// get rid of the spawn protection effects
public remove_spawn_protection(taskid)
{
	new id = taskid-TASK_REMOVE_PROTECTION;

	if(!is_user_connected(id)) return;

	spawnProtected[id] = 0;
	if(get_pcvar_num(gg_dm_sp_mode) == 2) fm_set_user_godmode(id,0);
	
	fm_set_rendering(id); // reset back to normal
}

// keep checking if a player needs to rejoin
public check_deathmatch(taskid)
{
	new id = taskid-TASK_CHECK_DEATHMATCH;

	// left the game, or gungame is now disabled
	if(!is_user_connected(id) || !ggActive) return;

	// now on spectator
	if(!on_valid_team(id)) return;

	// DM still not enabled, keep waiting
	if(!get_pcvar_num(gg_dm))
	{
		set_task(10.0,"check_deathmatch",taskid);
		return;
	}

	// DM is enabled, respawn
	if(!is_user_alive(id)) respawn(TASK_RESPAWN+id);
}

// what do you think??
public randomly_place_everyone()
{
	// count number of legitimate players
	new player, validNum;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && on_valid_team(player))
			validNum++;
	}

	// not enough CSDM spawns for everyone
	if(validNum > csdmSpawnCount)
		return;

	// now randomly place them
	for(player=1;player<=maxPlayers;player++)
	{
		// not spectator or unassigned
		if(is_user_connected(player) && on_valid_team(player))
			do_random_spawn(player,2);
	}
}

//**********************************************************************
// MENU FUNCTIONS
//**********************************************************************

// handle the welcome menu
public welcome_menu_handler(id,key)
{
	// just save welcomed status and let menu close
	welcomed[id] = 1;
	return PLUGIN_HANDLED;
}

// this menu does nothing but display stuff
public level_menu_handler(id,key)
{
	return PLUGIN_HANDLED;
}

// handle the reset level menu
public restart_menu_handler(id,key)
{
	if(get_pcvar_num(gg_teamplay))
	{
		client_print(id,print_chat,"%L",id,"RESET_NOT_ALLOWED");
		return PLUGIN_HANDLED;
	}

	if(level[id] <= 1)
	{
		client_print(id,print_chat,"%L",id,"STILL_LEVEL_ONE");
		return PLUGIN_HANDLED;
	}

	// 1. Yes
	if(key == 0)
	{
		new name[32];
		get_user_name(id,name,31);

		change_level(id,-(level[id]-1),_,_,1); // back to level 1 -- always score
		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"PLAYER_RESET",name);
	}

	return PLUGIN_HANDLED;
}

// show the level display
show_level_menu(id)
{
	new goal, tied, leaderNum, leaderList[128], name[32];
	
	new leaderLevel, numLeaders, leader, runnerUp;
	new teamplay = get_pcvar_num(gg_teamplay), team;
		
	if(teamplay) leader = teamplay_get_lead_team(leaderLevel,numLeaders,runnerUp);
	else leader = get_leader(leaderLevel,numLeaders,runnerUp);
	
	len = 0;

	if(numLeaders > 1) tied = 1;
	
	if(teamplay)
	{
		team = _:cs_get_user_team(id);

		if(numLeaders == 1)
		{
			new team1[10];
			get_team_name(CsTeams:leader,team1,9);
			len += formatex(leaderList[len],127-len,"%s %L",team1,id,"TEAM");
		}
		else
		{
			new team1[10], team2[10];
			get_team_name(CS_TEAM_T,team1,9);
			get_team_name(CS_TEAM_CT,team2,9);
			len += formatex(leaderList[len],127-len,"%s %L, %s %L",team1,id,"TEAM",team2,id,"TEAM");
		}
	}
	else
	{
		new players[32], num, i, player;
		get_players(players,num);

		// check for multiple leaders
		for(i=0;i<num;i++)
		{
			player = players[i];
			
			if(level[player] == leaderLevel)
			{
				if(++leaderNum == 5)
				{
					len += formatex(leaderList[len],127-len,", ...");
					break;
				}

				if(leaderList[0]) len += formatex(leaderList[len],127-len,", ");
				get_user_name(player,name,31);
				len += formatex(leaderList[len],127-len,"%s",name);
			}
		}
	}

	goal = get_level_goal(level[id],id);

	new displayWeapon[16];
	if(level[id]) formatex(displayWeapon,15,"%s",lvlWeapon[id]);
	else formatex(displayWeapon,15,"%L",id,"NONE");

	len = formatex(menuText,511,"%L %i (%s)^n",id,(teamplay) ? "ON_LEVEL_TEAM" : "ON_LEVEL",level[id],displayWeapon);
	len += formatex(menuText[len],511-len,"%L^n",id,(teamplay) ? "LEVEL_MESSAGE_LINE1B" : "LEVEL_MESSAGE_LINE1A",score[id],goal);

	// winning
	if(!tied && ((teamplay && leader == team) || (!teamplay && leader == id)))
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM1",teamLevel[leader]-teamLevel[runnerUp]);
		else len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY1",level[id]-level[runnerUp]);
	}
	
	// tied
	else if(tied)
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM2");
		else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE2B");
	}
	
	// losing
	else
	{
		if(teamplay) len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY_TEAM3",teamLevel[leader]-teamLevel[runnerUp]);
		else len += formatex(menuText[len],511-len,"%L^n",id,"PROGRESS_DISPLAY4",leaderLevel-level[id]);
	}

	len += formatex(menuText[len],511-len,"\d----------\w^n");

	new authid[24], wins, points;

	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	stats_get_data(authid,wins,points,dummy,1,dummy[0],id);

	new stats_mode = get_pcvar_num(gg_stats_mode);

	if(stats_mode)
	{
		if(statsPosition[id])
		{
			new statsSuffix[3];
			get_number_suffix(statsPosition[id],statsSuffix,2);
			
			if(stats_mode == 1) len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE3C",wins,statsPosition[id],statsSuffix);
			else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE3D",points,wins,statsPosition[id],statsSuffix);
		}
		else
		{
			if(stats_mode == 1) len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE3A",wins);
			else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE3B",points,wins);
		}

		len += formatex(menuText[len],511-len,"\d----------\w^n");
	}

	if(leaderNum > 1) len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE4A",leaderList);
	else len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE4B",leaderList);

	if(teamplay)
	{
		if(teamLevel[leader]) formatex(displayWeapon,15,"%s",teamLvlWeapon[leader]);
		else formatex(displayWeapon,15,"%L",id,"NONE");
	}
	else
	{
		if(level[leader]) formatex(displayWeapon,15,"%s",lvlWeapon[leader]);
		else formatex(displayWeapon,15,"%L",id,"NONE");
	}

	len += formatex(menuText[len],511-len,"%L^n",id,"LEVEL_MESSAGE_LINE5",leaderLevel,displayWeapon);
	len += formatex(menuText[len],511-len,"\d----------\w^n");

	len += formatex(menuText[len],511-len,"%L",id,"PRESS_KEY_TO_CONTINUE");
	show_menu(id,1023,menuText,-1,"level_menu");
}

// show the top10 list menu
show_top10_menu(id)
{
	new playersPerPage = 10, stats_mode = get_pcvar_num(gg_stats_mode);

	new totalPlayers = playersPerPage * floatround(float(statsSize) / float(playersPerPage),floatround_ceil),
	pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);
	
	if(pageTotal < 1) pageTotal = 1;
	if(totalPlayers < playersPerPage) totalPlayers = playersPerPage;

	if(page[id] < 1) page[id] = 1;
	if(page[id] > pageTotal) page[id] = pageTotal;

	len = formatex(menuText,511-len,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"TOP_10",page[id],pageTotal);
	//len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new start = (playersPerPage * (page[id]-1)), i;
	
	new authid[24];
	if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
	else get_user_authid(id,authid,23);

	for(i=start;i<start+playersPerPage;i++)
	{
		if(i > totalPlayers) break;

		// blank
		if(i >= statsSize)
		{
			len += formatex(menuText[len],511-len,"\w#%i \d%L\w^n",i+1,id,"NONE");
			continue;
		}

		ArrayGetString(statsArray,i,sfLineData,80);

		// get rid of authid
		strtok(sfLineData,sfAuthid,23,sfLineData,80,'^t');

		// isolate wins
		strtok(sfLineData,sfWins,5,sfLineData,80,'^t');

		// isolate name
		strtok(sfLineData,sfName,31,sfLineData,80,'^t');

		// break off timestamp and get points
		strtok(sfLineData,sfTimestamp,1,sfPoints,7,'^t');

		if(stats_mode == 1)
			len += formatex(menuText[len],511-len,"%s#%i %s (%s %L)^n",(equal(authid,sfAuthid)) ? "\r" : "\w",i+1,sfName,sfWins,id,"WINS");
		else
			len += formatex(menuText[len],511-len,"%s#%i %s (%i %L, %s %L)^n",(equal(authid,sfAuthid)) ? "\r" : "\w",i+1,sfName,str_to_num(sfPoints),id,"POINTS",sfWins,id,"WINS");
	}

	len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new keys = MENU_KEY_0;

	if(page[id] > 1)
	{
		len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
		keys |= MENU_KEY_1;
	}
	if(page[id] < pageTotal)
	{
		len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
		keys |= MENU_KEY_2;
	}
	if(statsPosition[id])
	{
		len += formatex(menuText[len],511-len,"3. %L^n",id,"JUMP_TO_ME");
		keys |= MENU_KEY_3;
	}
	len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");

	show_menu(id,keys,menuText,-1,"top10_menu");
}

// someone pressed a key on the top10 list menu page
public top10_menu_handler(id,key)
{
	new playersPerPage = 10;

	new totalPlayers = playersPerPage * floatround(float(statsSize) / float(playersPerPage),floatround_ceil),
	pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);
	if(pageTotal < 1) pageTotal = 1;

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_top10_menu(id);

		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_top10_menu(id);

		return;
	}
	
	// 3. Jump to me
	else if(key == 2)
	{
		if(statsPosition[id]) page[id] = floatround(float(statsPosition[id]) / float(playersPerPage),floatround_ceil);
		show_top10_menu(id);
	}

	// 0. Close
	// do nothing, menu closes automatically
}

// show the weapon list menu
show_weapons_menu(id)
{
	new totalWeapons = weaponNum, wpnsPerPage = 10;
	new pageTotal = floatround(float(totalWeapons) / float(wpnsPerPage),floatround_ceil);

	if(page[id] < 1) page[id] = 1;
	if(page[id] > pageTotal) page[id] = pageTotal;

	len = formatex(menuText,511-len,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"WEAPONS",page[id],pageTotal);
	//len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new start = (wpnsPerPage * (page[id]-1)) + 1, i;

	// are there any custom kill requirements?
	new customKills, Float:expected, Float:killsperlvl = get_pcvar_float(gg_kills_per_lvl);
	for(i=0;i<weaponNum;i++)
	{
		if(equal(weaponName[i],"knife") || equal(weaponName[i],"hegrenade")) expected = 1.0;
		else expected = killsperlvl;
	
		if(weaponGoal[i] != expected)
		{
			customKills = 1;
			break;
		}
	}

	for(i=start;i<start+wpnsPerPage;i++)
	{
		if(i > totalWeapons) break;

		if(customKills)
			len += formatex(menuText[len],511-len,"%s%L %i: %s (%i)^n",(i == level[id]) ? "\r" : "\w",id,"LEVEL",i,weaponName[i-1],get_level_goal(i));
		else
			len += formatex(menuText[len],511-len,"%s%L %i: %s^n",(i == level[id]) ? "\r" : "\w",id,"LEVEL",i,weaponName[i-1]);
	}

	len += formatex(menuText[len],511-len,"\d-----------\w^n");

	new keys = MENU_KEY_0;

	if(page[id] > 1)
	{
		len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
		keys |= MENU_KEY_1;
	}
	if(page[id] < pageTotal)
	{
		len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
		keys |= MENU_KEY_2;
	}

	len += formatex(menuText[len],511-len,"3. %L^n",id,"JUMP_TO_ME");
	keys |= MENU_KEY_3;

	len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");

	show_menu(id,keys,menuText,-1,"weapons_menu");
}

// someone pressed a key on the weapon list menu page
public weapons_menu_handler(id,key)
{
	new wpnsPerPage = 10, pageTotal = floatround(float(weaponNum) / float(wpnsPerPage),floatround_ceil);

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_weapons_menu(id);
		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_weapons_menu(id);
		return;
	}
	
	// 3. Jump to me
	else if(key == 2)
	{
		page[id] = clamp(floatround(float(level[id]) / float(wpnsPerPage),floatround_ceil),1,pageTotal);
		show_weapons_menu(id);
	}

	// 0. Close
	// do nothing, menu closes automatically
}

// show the score list menu
show_scores_menu(id)
{
	new keys;

	if(get_pcvar_num(gg_teamplay))
	{
		if(page[id] != 1) page[id] = 1;
		
		new leader = teamplay_get_lead_team(), otherTeam = (leader == 1) ? 2 : 1;
		new displayWeapon[24], teamName[10];

		len = formatex(menuText,511,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"SCORES",page[id],1);
		
		new team, myTeam = _:cs_get_user_team(id);
		for(team=leader;team>0;team=otherTeam)
		{
			if(teamLevel[team] && teamLvlWeapon[team][0]) formatex(displayWeapon,23,"%s",teamLvlWeapon[team]);
			else formatex(displayWeapon,23,"%L",id,"NONE");

			get_team_name(CsTeams:team,teamName,9);
			len += formatex(menuText[len],511-len,"%s#%i %s %L, %L %i (%s) %i/%i^n",(team == myTeam) ? "\r" : "\w",(team == leader) ? 1 : 2,teamName,id,"TEAM",id,"LEVEL",teamLevel[team],displayWeapon,teamScore[team],teamplay_get_team_goal(team));
			
			// finished
			if(team == otherTeam) break;
		}

		// nice separator!
		len += formatex(menuText[len],511-len,"\d-----------\w^n");

		keys = MENU_KEY_0;
		len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");
	}
	else
	{
		new totalPlayers = get_playersnum(), playersPerPage = 8, stats_mode = get_pcvar_num(gg_stats_mode);
		new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

		if(page[id] < 1) page[id] = 1;
		if(page[id] > pageTotal) page[id] = pageTotal;

		new players[32], num;
		get_players(players,num);

		// order by highest level first
		SortCustom1D(players,num,"score_custom_compare");

		len = formatex(menuText,511,"\y%L %L (%i/%i)\w^n",id,"GUNGAME",id,"SCORES",page[id],pageTotal);
		//len += formatex(menuText[len],511-len,"\d-----------\w^n");

		new start = (playersPerPage * (page[id]-1)), i, name[32], player, authid[24], wins, points;

		// check for stats
		get_pcvar_string(gg_stats_file,sfFile,1);

		new stats_ip = get_pcvar_num(gg_stats_ip), displayWeapon[24], statsSuffix[3];

		for(i=start;i<start+playersPerPage;i++)
		{
			if(i >= totalPlayers) break;

			player = players[i];
			get_user_name(player,name,31);

			if(level[player] && lvlWeapon[player][0]) formatex(displayWeapon,23,"%s",lvlWeapon[player]);
			else formatex(displayWeapon,23,"%L",id,"NONE");

			if(sfFile[0] && stats_mode)
			{
				if(stats_ip) get_user_ip(player,authid,23);
				else get_user_authid(player,authid,23);

				stats_get_data(authid,wins,points,dummy,1,dummy[0],player);

				if(statsPosition[player])
				{
					get_number_suffix(statsPosition[player],statsSuffix,2);
					len += formatex(menuText[len],511-len,"%s#%i %s, %L %i (%s) %i/%i, %i %L (%i%s)^n",(player == id) ? "\r" : "\w",i+1,name,id,"LEVEL",level[player],displayWeapon,score[player],get_level_goal(level[player]),(stats_mode == 1) ? wins : points,id,(stats_mode == 1) ? "WINS" : "POINTS",statsPosition[player],statsSuffix);
				}
				else len += formatex(menuText[len],511-len,"%s#%i %s, %L %i (%s) %i/%i, %i %L (%L)^n",(player == id) ? "\r" : "\w",i+1,name,id,"LEVEL",level[player],displayWeapon,score[player],get_level_goal(level[player]),(stats_mode == 1) ? wins : points,id,(stats_mode == 1) ? "WINS" : "POINTS",id,"UNRANKED");
			}
			else len += formatex(menuText[len],511-len,"#%i %s, %L %i (%s) %i/%i^n",i+1,name,id,"LEVEL",level[player],displayWeapon,score[player],get_level_goal(level[player]));
		}

		len += formatex(menuText[len],511-len,"\d-----------\w^n");

		keys = MENU_KEY_0;

		if(page[id] > 1)
		{
			len += formatex(menuText[len],511-len,"1. %L^n",id,"PREVIOUS");
			keys |= MENU_KEY_1;
		}
		if(page[id] < pageTotal)
		{
			len += formatex(menuText[len],511-len,"2. %L^n",id,"NEXT");
			keys |= MENU_KEY_2;
		}

		len += formatex(menuText[len],511-len,"3. %L^n",id,"JUMP_TO_ME");
		keys |= MENU_KEY_3;

		len += formatex(menuText[len],511-len,"0. %L",id,"CLOSE");
	}

	show_menu(id,keys,menuText,-1,"scores_menu");
}

// sort list of players with their level first
public score_custom_compare(elem1,elem2)
{
	// invalid players
	if(elem1 < 1 || elem1 > 32 || elem2 < 1 || elem2 > 32)
		return 0;

	// tied levels, compare scores
	if(level[elem1] == level[elem2])
	{
		if(score[elem1] > score[elem2]) return -1;
		else if(score[elem1] < score[elem2]) return 1;
		else return 0;
	}

	// compare levels
	else if(level[elem1] > level[elem2]) return -1;
	else if(level[elem1] < level[elem2]) return 1;

	return 0; // equal
}

// someone pressed a key on the score list menu page
public scores_menu_handler(id,key)
{
	new totalPlayers = get_playersnum(), playersPerPage = 8;
	new pageTotal = floatround(float(totalPlayers) / float(playersPerPage),floatround_ceil);

	if(page[id] < 1 || page[id] > pageTotal) return;

	// 1. Previous
	if(key == 0)
	{
		page[id]--;
		show_scores_menu(id);
		return;
	}

	// 2. Next
	else if(key == 1)
	{
		page[id]++;
		show_scores_menu(id);
		return;
	}
	
	// 3. Jump to me
	else if(key == 2)
	{
		new players[32], num, i;
		get_players(players,num);
		SortCustom1D(players,num,"score_custom_compare");
		
		for(i=0;i<num;i++)
		{
			if(players[i] == id) break;
		}

		page[id] = floatround(float(i+1) / float(playersPerPage),floatround_ceil);
		show_scores_menu(id);
	}

	// 0. Close
	// do nothing, menu closes automatically
}

//**********************************************************************
// MAIN FUNCTIONS
//**********************************************************************

// toggle the status of gungame
public toggle_gungame(taskid)
{
	new status = taskid-TASK_TOGGLE_GUNGAME, i;

	// clear player tasks and values
	for(i=1;i<=32;i++) clear_values(i);
	
	clear_team_values(1);
	clear_team_values(2);

	// clear temp saves
	for(i=0;i<TEMP_SAVES;i++) clear_save(TASK_CLEAR_SAVE+i);

	if(status == TOGGLE_FORCE || status == TOGGLE_ENABLE)
	{
		new cfgFile[64];
		get_gg_config_file(cfgFile,63);

		// run the gungame config
		if(cfgFile[0] && file_exists(cfgFile))
		{
			new command[512], file, i;

			file = fopen(cfgFile,"rt");
			while(file && !feof(file))
			{
				fgets(file,command,511);
				new len = strlen(command) - 2;

				// stop at a comment
				for(i=0;i<len;i++)
				{
					// only check config-style (;) comments as first character,
					// since they could be used ie in gg_map_setup to separate
					// commands. also check for coding-style (//) comments
					if((i == 0 && command[i] == ';') || (command[i] == '/' && command[i+1] == '/'))
					{
						copy(command,i,command);
						break;
					}
				}

				// this will effect GunGame's status
				if(containi(command,"gg_enabled") != -1)
				{
					// don't override our setting from amx_gungame
					if(status == TOGGLE_ENABLE) continue;
					
					new val[8];
					parse(command,dummy,1,val,7);
					
					// update active status
					ggActive = str_to_num(val);
				}

				trim(command);
				if(command[0]) server_cmd(command);
			}
			if(file) fclose(file);
		}
	}

	// set to what we chose from amx_gungame
	if(status != TOGGLE_FORCE)
	{
		set_pcvar_num(gg_enabled,status);
		ggActive = status;
	}

	// execute all of those cvars that we just set
	server_exec();

	// run appropiate cvars
	map_start_cvars(); // this sets up weapon order

	// reset some things
	if(!ggActive)
	{
		// clear HUD message
		if(warmup > 0) ClearSyncHud(0,hudSyncWarmup);

		warmup = -1;
		warmupWeapon[0] = 0;
		voted = 0;
		won = 0;

		remove_task(TASK_WARMUP_CHECK);
	}

	stats_get_top_players();

	// game_player_equip
	manage_equips();
	
	// start (or stop) the leader display
	remove_task(TASK_LEADER_DISPLAY);
	show_leader_display();
	
	// warmup weapon may've change
	if(warmup > 0) get_pcvar_string(gg_warmup_weapon,warmupWeapon,23);
}

// run cvars that should be run on map start
public map_start_cvars()
{
	new setup[512];

	// gungame is disabled, run endmap_setup
	if(!ggActive)
	{
		get_pcvar_string(gg_endmap_setup,setup,511);
		if(setup[0]) server_cmd(setup);
	}
	else
	{
		// run map setup
		get_pcvar_string(gg_map_setup,setup,511);
		if(setup[0]) server_cmd(setup);
		
		do_rOrder(); // also does random teamplay
		setup_weapon_order();
		
		// random win sounds
		currentWinSound = do_rWinSound();
	}
}

// sift through the config to check for custom sounds
set_sounds_from_config()
{
	new cfgFile[64];
	get_gg_config_file(cfgFile,63);

	// run the gungame config
	if(cfgFile[0] && file_exists(cfgFile))
	{
		new command[WINSOUNDS_SIZE+32], cvar[32], value[WINSOUNDS_SIZE], file, i;

		file = fopen(cfgFile,"rt");
		while(file && !feof(file))
		{
			fgets(file,command,WINSOUNDS_SIZE+31);
			new len = strlen(command) - 2;

			// stop at a comment
			for(i=0;i<len;i++)
			{
				// only check config-style (;) comments as first character,
				// since they could be used ie in gg_map_setup to separate
				// commands. also check for coding-style (//) comments
				if((i == 0 && command[i] == ';') || (command[i] == '/' && command[i+1] == '/'))
				{
					copy(command,i,command);
					break;
				}
			}

			// this is a sound
			if(equal(command,"gg_sound_",9) || equal(command,"gg_lead_sounds"))
			{
				parse(command,cvar,31,value,WINSOUNDS_SIZE-1);
				set_cvar_string(cvar,value);
			}
		}
		if(file) fclose(file);
	}
}

// manage stats pruning
public manage_pruning()
{
	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist/pruning disabled
	if(!sfFile[0] || !get_pcvar_num(gg_stats_prune)) return;

	// get how many plugin ends more until we prune
	new prune_in_str[3], prune_in;
	get_localinfo("gg_prune_in",prune_in_str,2);
	prune_in = str_to_num(prune_in_str);

	// localinfo not set yet
	if(!prune_in)
	{
		set_localinfo("gg_prune_in","9");
		return;
	}

	// time to prune
	if(prune_in == 1)
	{
		// prune and log
		log_amx("%L",LANG_SERVER,"PRUNING",sfFile,stats_prune());

		// reset our prune count
		set_localinfo("gg_prune_in","10");
		return;
	}

	// decrement our count
	num_to_str(prune_in-1,prune_in_str,2);
	set_localinfo("gg_prune_in",prune_in_str);
}

// manage warmup mode
public warmup_check(taskid)
{
	warmup--;
	set_hudmessage(255,255,255,-1.0,0.4,0,6.0,1.0,0.1,0.2);

	if(warmup <= 0)
	{
		warmup = -13;
		warmupWeapon[0] = 0;

		ShowSyncHudMsg(0,hudSyncWarmup,"%L",LANG_PLAYER,"WARMUP_ROUND_OVER");
		restart_round(1);
		
		return;
	}

	ShowSyncHudMsg(0,hudSyncWarmup,"%L",LANG_PLAYER,"WARMUP_ROUND_DISPLAY",warmup);
	set_task(1.0,"warmup_check",taskid);
}

// show the leader display
public show_leader_display()
{
	static Float:lastDisplay, lastLeader, lastLevel, leaderName[32];

	if(!ggActive || !get_pcvar_num(gg_leader_display))
	{
		remove_task(TASK_LEADER_DISPLAY);
		return 0;
	}
	
	// keep it going
	if(!task_exists(TASK_LEADER_DISPLAY))
		set_task(LEADER_DISPLAY_RATE,"show_leader_display",TASK_LEADER_DISPLAY,_,_,"b");

	// don't show during warmup or game over
	if(warmup > 0 || won) return 0;
	
	new leaderLevel, numLeaders, leader, teamplay = get_pcvar_num(gg_teamplay);
	
	if(teamplay) leader = teamplay_get_lead_team(leaderLevel,numLeaders);
	else leader = get_leader(leaderLevel,numLeaders);

	if(!leader || leaderLevel <= 0) return 0;
	
	// we just displayed the same message, don't flood
	new Float:time = get_gametime();
	if(lastLevel == leaderLevel &&  lastLeader == leader && lastDisplay == time) return 0;

	// remember for later
	lastDisplay = time;
	lastLeader = leader;
	lastLevel = leaderLevel;
	
	if(teamplay) get_team_name(CsTeams:leader,leaderName,9);
	else get_user_name(leader,leaderName,31);
	
	set_hudmessage(200,200,200,get_pcvar_float(gg_leader_display_x),get_pcvar_float(gg_leader_display_y),_,_,LEADER_DISPLAY_RATE+0.5,0.0,0.0);
	
	if(numLeaders > 1)
	{
		if(teamplay)
		{
			static otherName[10];
			get_team_name((leader == 1) ? CS_TEAM_CT : CS_TEAM_T,otherName,9);

			ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s + %s (%i - %s)",LANG_PLAYER,"LEADER",leaderName,otherName,leaderLevel,teamLvlWeapon[leader])
		}
		else ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s +%i (%i - %s)",LANG_PLAYER,"LEADER",leaderName,numLeaders-1,leaderLevel,lvlWeapon[leader]);
	}
	else ShowSyncHudMsg(0,hudSyncLDisplay,"%L: %s (%i - %s)",LANG_PLAYER,"LEADER",leaderName,leaderLevel,(teamplay) ? teamLvlWeapon[leader] : lvlWeapon[leader]);
	
	return 1;
}

// show the nice HUD progress display
show_progress_display(id)
{
	static statusString[48];
	
	// weapon-specific warmup
	if(warmup > 0 && warmupWeapon[0]) return;

	new teamplay = get_pcvar_num(gg_teamplay);
	if(teamplay)
	{
		new team = _:cs_get_user_team(id), otherTeam = (team == 1) ? 2 : 1;
		if(team != 1 && team != 2) return;

		new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);
		
		// tied
		if(numLeaders > 1) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM2");
		
		// leading
		else if(leader == team) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM1",teamLevel[team]-teamLevel[otherTeam]);

		// losing
		else formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY_TEAM3",teamLevel[otherTeam]-teamLevel[team]);
	}
	else
	{
		new leaderLevel, numLeaders, runnerUp;
		new leader = get_leader(leaderLevel,numLeaders,runnerUp);
		
		if(level[id] == leaderLevel)
		{
			if(numLeaders == 1) formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY1",leaderLevel-level[runnerUp]);
			else if(numLeaders == 2)
			{
				new otherLeader;
				if(leader != id) otherLeader = leader;
				else
				{
					new player;
					for(player=1;player<=maxPlayers;player++)
					{
						if(is_user_connected(player) && level[player] == leaderLevel && player != id)
						{
							otherLeader = player;
							break;
						}
					}
				}
				
				static otherName[32];
				get_user_name(otherLeader,otherName,31);
				
				formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY2",otherName);
			}
			else
			{
				static numWord[16];
				num_to_word(numLeaders-1,numWord,15);
				trim(numWord);
				formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY3",numWord);
			}
		}
		else formatex(statusString,47,"%L",id,"PROGRESS_DISPLAY4",leaderLevel-level[id]);
	}

	gungame_hudmessage(id,5.0,"%L %i (%s)^n%s",id,(teamplay) ? "ON_LEVEL_TEAM" : "ON_LEVEL",level[id],lvlWeapon[id],statusString);
}

// play the taken/tied/lost lead sounds
public play_lead_sounds(id,oldLevel,Float:playDelay)
{
	// id: the player whose level changed
	// oldLevel: his level before it changed
	// playDelay: how long to wait until we play id's sounds
	
	if(get_pcvar_num(gg_teamplay))
	{
		// redirect to other function
		teamplay_play_lead_sounds(id,oldLevel,Float:playDelay);
		return;
	}
	
	// warmup or game over, no one cares
	if(warmup > 0 || won) return;

	// no level change
	if(level[id] == oldLevel) return;
	
	//
	// monitor MY stuff first
	//

	new leaderLevel, numLeaders;
	get_leader(leaderLevel,numLeaders);
	
	// I'm now on the leader level
	if(level[id] == leaderLevel)
	{
		// someone else here?
		if(numLeaders > 1)
		{
			new params[2];
			params[0] = id;
			params[1] = gg_sound_tiedlead;
			
			remove_task(TASK_PLAY_LEAD_SOUNDS+id);
			set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);
		}
		
		// just me, I'm the winner!
		else
		{
			// did I just pass someone?
			if(level[id] > oldLevel && num_players_on_level(oldLevel))
			{
				new params[2];
				params[0] = id;
				params[1] = gg_sound_takenlead;
				
				remove_task(TASK_PLAY_LEAD_SOUNDS+id);
				set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);
			}
		}
	}
	
	// WAS I on the leader level?
	else if(oldLevel == leaderLevel)
	{
		new params[2];
		params[0] = id;
		params[1] = gg_sound_lostlead;
		
		remove_task(TASK_PLAY_LEAD_SOUNDS+id);
		set_task(playDelay,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+id,params,2);

		//return; // will not effect other players
	}
	
	// nothing of importance
	else return; // will not effect other players
	
	//
	// now monitor other players.
	// if we get this far, id is now in the lead level
	//
	
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player) || player == id) continue;
		
		// PLAYER tied with ID
		if(level[player] == level[id])
		{
			// don't tell him if he already got it from another player
			if(num_players_on_level(level[id]) <= 2
			|| (oldLevel > level[id] && leaderLevel == level[id])) // dropped into tied position
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_tiedlead;
				
				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}
		
		// PLAYER passed by ID
		else if(level[id] > level[player] && level[player] == oldLevel)
		{
			// don't tell him if he already got it from another player
			if(num_players_on_level(level[id]) <= 1)
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_lostlead;
				
				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}
		
		// ID passed by PLAYER
		else if(level[player] > level[id] && leaderLevel == level[player])
		{		
			// I stand alone!
			if(num_players_on_level(level[player]) <= 1)
			{
				new params[2];
				params[0] = player;
				params[1] = gg_sound_takenlead;
				
				remove_task(TASK_PLAY_LEAD_SOUNDS+player);
				set_task(0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
			}

			continue;
		}
	}
}

// manage game_player_equip and player_weaponstrip entities
public manage_equips()
{
	static classname[20], targetname[24];
	new ent, i, block_equips = get_pcvar_num(gg_block_equips), enabled = ggActive;

	// go through both entities to monitor
	for(i=0;i<4;i++)
	{
		// get classname for current iteration
		switch(i)
		{
			case 0: classname = "game_player_equip";
			case 1: classname = "game_player_equip2";
			case 2: classname = "player_weaponstrip";
			default: classname = "player_weaponstrip2";
		}

		// go through whatever entity
		ent = 0;
		while((ent = fm_find_ent_by_class(ent,classname)))
		{
			// allowed to have this, reverse possible changes
			if(!enabled || !block_equips || (i >= 2 && block_equips < 2)) // player_weaponstrip switch
			{
				pev(ent,pev_targetname,targetname,23);

				// this one was blocked
				if(equal(targetname,"gg_block_equips"))
				{
					pev(ent,TNAME_SAVE,targetname,23);

					set_pev(ent,pev_targetname,targetname);
					set_pev(ent,TNAME_SAVE,"");
					
					switch(i)
					{
						case 0, 1: set_pev(ent,pev_classname,"game_player_equip");
						default: set_pev(ent,pev_classname,"player_weaponstrip");
					}
				}
			}

			// not allowed to pickup others, make possible changes
			else
			{
				pev(ent,pev_targetname,targetname,23);

				// needs to be blocked, but hasn't been yet
				if(targetname[0] && !equal(targetname,"gg_block_equips"))
				{
					set_pev(ent,TNAME_SAVE,targetname);
					set_pev(ent,pev_targetname,"gg_block_equips");
					
					// classname change is required sometimes for some reason
					switch(i)
					{
						case 0, 1: set_pev(ent,pev_classname,"game_player_equip2");
						default: set_pev(ent,pev_classname,"player_weaponstrip2");
					}
				}
			}
		}
	}
}

// someone respawned
stock player_spawn(id,skipDelay=0)
{
	if(!ggActive || !is_user_connected(id))
		return 0;

	// have not joined yet
	if(!on_valid_team(id)) return 0;
	
	// re-entrancy fix
	static Float:lastThis[33];
	new Float:now = get_gametime();
	if(now == lastThis[id]) return 0;
	lastThis[id] = now;
	
	// the delay is already taken care of
	if(skipDelay)
	{
		post_spawn(id);
		return 1;
	}

	// an unfortunately necessary delay because we
	// have to wait for the inventory to initialize
	set_task(0.1,"post_spawn",id);
	
	return 1;
}

// our delay
public post_spawn(id)
{
	if(!is_user_connected(id)) return;
	
	// should be frozen?
	if(won)
	{
		new iterations = get_pcvar_num(gg_map_iterations);
		if(mapIteration < iterations || !iterations)
		{
			// not done yet, just freeze players
			set_pev(id,pev_flags,pev(id,pev_flags) | FL_FROZEN);
			fm_set_user_godmode(id,1);
		}

		// done, make sure HUD is hidden
		message_begin(MSG_ALL,gmsgHideWeapon);
		write_byte((1<<0)|(1<<1)|(1<<3)|(1<<4)|(1<<5)|(1<<6)); // can't use (1<<2) or text disappears
		message_end();
		
		message_begin(MSG_ALL,gmsgCrosshair);
		write_byte(0); // hide
		message_end();
		
		return;
	}

	levelsThisRound[id] = 0;

	// just joined
	if(!level[id])
	{
		// handicap
		new handicapMode = get_pcvar_num(gg_handicap_on), teamplay = get_pcvar_num(gg_teamplay);
		if(handicapMode && !teamplay)
		{
			new rcvHandicap = 1;

			get_pcvar_string(gg_stats_file,sfFile,1);

			// top10 doesn't receive handicap -- also make sure we are using top10
			if(!get_pcvar_num(gg_top10_handicap) && sfFile[0] && get_pcvar_num(gg_stats_mode))
			{
				static authid[24];

				if(get_pcvar_num(gg_stats_ip)) get_user_ip(id,authid,23);
				else get_user_authid(id,authid,23);

				new i;
				for(i=0;i<TOP_PLAYERS;i++)
				{
					// blank
					if(i >= statsSize) continue;

					// isolate authid
					ArrayGetString(statsArray,i,sfLineData,23);
					strtok(sfLineData,sfAuthid,23,dummy,1,'^t');

					// I'm in top10, don't give me handicap
					if(equal(authid,sfAuthid))
					{
						rcvHandicap = 0;
						break;
					}
				}
			}

			if(rcvHandicap)
			{
				new player;

				// find lowest level (don't use bots unless we have to)
				if(handicapMode == 2)
				{
					new isBot, myLevel, lowestLevel, lowestBotLevel;
					for(player=1;player<=maxPlayers;player++)
					{
						if(!is_user_connected(player) || player == id)
							continue;

						isBot = is_user_bot(player);
						myLevel = level[player];

						if(!myLevel) continue;

						if(!isBot && (!lowestLevel || myLevel < lowestLevel))
							lowestLevel = myLevel;
						else if(isBot && (!lowestBotLevel || myLevel < lowestBotLevel))
							lowestBotLevel = myLevel;
					}

					// CLAMP!
					if(!lowestLevel) lowestLevel = 1;
					if(!lowestBotLevel) lowestBotLevel = 1;

					change_level(id,(lowestLevel > 1) ? lowestLevel : lowestBotLevel,1,_,1); // just joined, always score
				}

				// find average level
				else
				{
					new Float:average, num;
					for(player=1;player<=maxPlayers;player++)
					{
						if(is_user_connected(player) && level[player])
						{
							average += float(level[player]);
							num++;
						}
					}

					average /= float(num);
					change_level(id,(average >= 0.5) ? floatround(average) : 1,1,_,1); // just joined, always score
				}
			}

			// not eligible for handicap (in top10 with gg_top10_handicap disabled)
			else change_level(id,1,1_,1); // just joined, always score
		}

		// no handicap enabled or playing teamplay
		else
		{
			if(teamplay)
			{
				new team = _:cs_get_user_team(id);
				
				if(team == 1 || team == 2)
				{
					// my team has a level already
					if(teamLevel[team])
					{
						change_level(id,teamLevel[team],1,_,1,_,0); // just joined, always score, don't effect team
						if(teamScore[team]) change_score(id,teamScore[team],_,0); // don't effect team
					}
					
					// my team just started
					else
					{
						// initialize its values
						teamplay_update_level(team,1,id);
						teamplay_update_score(team,0,id);

						change_level(id,teamLevel[team],1,_,1,_,0); // just joined, always score, don't effect team
					}
				}
			}
			
			// solo-play
			else change_level(id,1,1,_,1); // just joined, always score
		}
	}

	// didn't just join
	else
	{
		if(star[id])
		{
			end_star(TASK_END_STAR+id);
			remove_task(TASK_END_STAR+id);
		}
		
		if(get_pcvar_num(gg_teamplay))
		{
			new team = _:cs_get_user_team(id);
			
			// my team just started
			if((team == 1 || team == 2) && !teamLevel[team])
			{
				// initialize its values
				teamplay_update_level(team,1,id);
				teamplay_update_score(team,0,id);

				change_level(id,teamLevel[team]-level[id],_,_,1,_,0); // always score, don't effect team
				change_score(id,teamScore[team]-score[id],_,0); // don't effect team
			}
		}

		give_level_weapon(id);
		refill_ammo(id);
	}

	// show welcome message
	if(!welcomed[id] && get_pcvar_num(gg_join_msg))
		show_welcome(id);
	
	// update bomb for DM
	if(cs_get_user_team(id) == CS_TEAM_T && !get_pcvar_num(gg_block_objectives) && get_pcvar_num(gg_dm))
	{
		if(bombStatus[3] == BOMB_PICKEDUP)
		{
			message_begin(MSG_ONE,gmsgBombPickup,_,id);
			message_end();
		}
		else if(bombStatus[0] || bombStatus[1] || bombStatus[2])
		{
			message_begin(MSG_ONE,gmsgBombDrop,_,id);
			write_coord(bombStatus[0]);
			write_coord(bombStatus[1]);
			write_coord(bombStatus[2]);
			write_byte(bombStatus[3]);
			message_end();
		}
	}

	if(get_pcvar_num(gg_disable_money)) hide_money(id);
	
	// switch to our appropiate weapon, for those without the switch to new weapon option
	if(((warmup > 0 && warmupWeapon[0] && equal(warmupWeapon,"knife")) || (get_pcvar_num(gg_knife_elite) && levelsThisRound[id] > 0)) || equal(lvlWeapon[id],"knife"))
	{
		engclient_cmd(id,"weapon_knife");
		client_cmd(id,"weapon_knife");
	}
	else if(get_pcvar_num(gg_nade_glock) && equal(lvlWeapon[id],"hegrenade"))
	{
		engclient_cmd(id,"weapon_glock18");
		client_cmd(id,"weapon_glock18");
	}
	else if(lvlWeapon[id][0])
	{
		static wpnName[24];
		formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);

		engclient_cmd(id,wpnName);
		client_cmd(id,wpnName);
	}
}

// player changed his team
player_teamchange(id,oldTeam,newTeam)
{
	if(!ggActive) return 0;
	
	// keep track of time
	new Float:time = get_gametime();
	if(oldTeam == 1 || oldTeam == 2) teamTimes[id][oldTeam-1] += time - lastSwitch[id];
	lastSwitch[id] = time;
	
	// we already have a level, set our values to our new team's
	if(level[id] && get_pcvar_num(gg_teamplay) && (newTeam == 1 || newTeam == 2))
	{
		// set them directly
		level[id] = teamLevel[newTeam];
		lvlWeapon[id] = teamLvlWeapon[newTeam];
		score[id] = teamScore[newTeam];
	}
	
	return 1;
}

// restart the round
public restart_round(time)
{
	// clear values
	/*new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player)) clear_values(player,1); // ignore welcome
	}

	// reset teams as well
	clear_team_values(1);
	clear_team_values(2);*/

	set_cvar_num("sv_restartround",time);
}

// select a random weapon order
do_rOrder()
{
	// manage random teamplay
	if(initTeamplay == -1) initTeamplay = get_pcvar_num(gg_teamplay);
	if(initTeamplay == 2) set_pcvar_num(gg_teamplay,random_num(0,1));

	new i, maxRandom, cvar[20], weaponOrder[(MAX_WEAPONS*16)+1];
	for(i=1;i<=MAX_WEAPON_ORDERS+1;i++) // +1 so we can detect final
	{
		formatex(cvar,19,"gg_weapon_order%i",i);
		get_cvar_string(cvar,weaponOrder,MAX_WEAPONS*16);
		trim(weaponOrder);

		// found a blank one, stop here
		if(!weaponOrder[0])
		{
			maxRandom = i - 1;
			break;
		}
	}

	// we found some random ones
	if(maxRandom)
	{
		new randomOrder[30], lastOIstr[6], lastOI, orderAmt;
		get_localinfo("gg_rand_order",randomOrder,29);
		get_localinfo("gg_last_oi",lastOIstr,5);
		lastOI = str_to_num(lastOIstr);
		orderAmt = get_rOrder_amount(randomOrder);

		// no random order yet, or amount of random orders changed
		if(!randomOrder[0] || orderAmt != maxRandom)
		{
			shuffle_rOrder(randomOrder,29,maxRandom);
			lastOI = 0;
		}

		// reached the end, reshuffle while avoiding this one
		else if(get_rOrder_index_val(orderAmt,randomOrder) == get_rOrder_index_val(lastOI,randomOrder))
		{
			shuffle_rOrder(randomOrder,29,maxRandom,lastOI);
			lastOI = 0;
		}

		new choice = get_rOrder_index_val(lastOI+1,randomOrder);

		// get its weapon order
		formatex(cvar,19,"gg_weapon_order%i",choice);
		get_cvar_string(cvar,weaponOrder,MAX_WEAPONS*16);

		// set as current
		set_pcvar_string(gg_weapon_order,weaponOrder);

		// remember for next time
		num_to_str(lastOI+1,lastOIstr,5);
		set_localinfo("gg_last_oi",lastOIstr);
	}
}

// get the value of an order index in an order string
get_rOrder_index_val(index,randomOrder[])
{
	// only one listed
	if(str_count(randomOrder,',') < 1)
		return str_to_num(randomOrder);

	// find preceding comma
	new search = str_find_num(randomOrder,',',index-1);

	// go until succeeding comma
	new extract[6];
	copyc(extract,5,randomOrder[search+1],',');

	return str_to_num(extract);
}

// gets the amount of orders in an order string
get_rOrder_amount(randomOrder[])
{
	return str_count(randomOrder,',')+1;
}

// shuffle up our random order
stock shuffle_rOrder(randomOrder[],len,maxRandom,avoid=-1)
{
	randomOrder[0] = 0;

	// fill up array with order indexes
	new order[MAX_WEAPON_ORDERS], i;
	for(i=0;i<maxRandom;i++) order[i] = i+1;

	// shuffle it
	SortCustom1D(order,maxRandom,"sort_shuffle");

	// avoid a specific number as the starting number
	while(avoid > 0 && order[0] == avoid)
		SortCustom1D(order,maxRandom,"sort_shuffle");

	// get them into a string
	for(i=0;i<maxRandom;i++)
	{
		format(randomOrder,len,"%s%s%i",randomOrder,(i>0) ? "," : "",order[i]);
		set_localinfo("gg_rand_order",randomOrder);
	}
}

// play a random win sound
do_rWinSound()
{
	// just one, no one cares
	if(numWinSounds <= 1)
	{
		return 0; // 1 minus 1
	}

	new randomOrder[30], lastWSIstr[6], lastWSI, orderAmt;
	get_localinfo("gg_winsound_order",randomOrder,29);
	get_localinfo("gg_last_wsi",lastWSIstr,5);
	lastWSI = str_to_num(lastWSIstr);
	orderAmt = get_rWinSound_amount(randomOrder);

	// no random order yet, or amount of random orders changed
	if(!randomOrder[0] || orderAmt != numWinSounds)
	{
		shuffle_rWinSound(randomOrder,29);
		lastWSI = 0;
	}

	// reached the end, reshuffle while avoiding this one
	else if(get_rWinSound_index_val(orderAmt,randomOrder) == get_rWinSound_index_val(lastWSI,randomOrder))
	{
		shuffle_rWinSound(randomOrder,29,lastWSI);
		lastWSI = 0;
	}

	new choice = get_rWinSound_index_val(lastWSI+1,randomOrder);

	// remember for next time
	num_to_str(lastWSI+1,lastWSIstr,5);
	set_localinfo("gg_last_wsi",lastWSIstr);
	
	return choice-1;
}

// get the value of an order index in an order string
get_rWinSound_index_val(index,randomOrder[])
{
	// only one listed
	if(str_count(randomOrder,',') < 1)
		return str_to_num(randomOrder);

	// find preceding comma
	new search = str_find_num(randomOrder,',',index-1);

	// go until succeeding comma
	new extract[6];
	copyc(extract,5,randomOrder[search+1],',');

	return str_to_num(extract);
}

// gets the amount of orders in an order string
get_rWinSound_amount(randomOrder[])
{
	return str_count(randomOrder,',')+1;
}

// shuffle up our random order
stock shuffle_rWinSound(randomOrder[],len,avoid=-1)
{
	randomOrder[0] = 0;

	// fill up array with order indexes
	new order[MAX_WINSOUNDS], i;
	for(i=0;i<numWinSounds;i++) order[i] = i+1;

	// shuffle it
	SortCustom1D(order,numWinSounds,"sort_shuffle");

	// avoid a specific number as the starting number
	while(avoid > 0 && order[0] == avoid)
		SortCustom1D(order,numWinSounds,"sort_shuffle");

	// get them into a string
	for(i=0;i<numWinSounds;i++)
	{
		format(randomOrder,len,"%s%s%i",randomOrder,(i>0) ? "," : "",order[i]);
		set_localinfo("gg_winsound_order",randomOrder);
	}
}

// shuffle an array
public sort_shuffle(elem1,elem2)
{
	return random_num(-1,1);
}

// clear all saved values
clear_values(id,ignoreWelcome=0)
{
	level[id] = 0;
	levelsThisRound[id] = 0;
	score[id] = 0;
	lvlWeapon[id][0] = 0;
	star[id] = 0;
	if(!ignoreWelcome) welcomed[id] = 0;
	page[id] = 0;
	lastKilled[id] = 0;
	respawn_timeleft[id] = 0;
	silenced[id] = 0;
	spawnSounds[id] = 1;
	spawnProtected[id] = 0;
	teamTimes[id][0] = 0.0;
	teamTimes[id][1] = 0.0;
	lastSwitch[id] = get_gametime();

	if(c4planter == id) c4planter = 0;
	
	remove_task(TASK_RESPAWN+id);
	remove_task(TASK_CHECK_DEATHMATCH+id);
	remove_task(TASK_REMOVE_PROTECTION+id);

	return 1;
}

// clears a TEAM's values
clear_team_values(team)
{
	if(team != 1 && team != 2) return;

	teamLevel[team] = 0;
	teamLvlWeapon[team][0] = 0;
	teamScore[team] = 0;
}

// possibly start a warmup round
start_warmup()
{
	new warmup_value = get_pcvar_num(gg_warmup_timer_setting);
	
	// warmup is set to -13 after its finished if gg_warmup_multi is 0,
	// so this stops multiple warmups for multiple map iterations
	if(warmup_value > 0 && warmup != -13)
	{
		warmup = warmup_value;
		get_pcvar_string(gg_warmup_weapon,warmupWeapon,23);
		set_task(0.1,"warmup_check",TASK_WARMUP_CHECK);
		
		// now that warmup is in effect, reset player weapons
		new player;
		for(player=1;player<=maxPlayers;player++)
		{
			if(is_user_connected(player))
			{
				// just joined for all intents and purposes
				change_level(player,-MAX_WEAPONS,1,_,1,0,0); // just joined, always score, don't play sounds, don't effect team
			}
		}
		
		// a single team update instead of for everyone
		if(get_pcvar_num(gg_teamplay))
		{
			teamplay_update_score(1,0);
			teamplay_update_score(2,0);
			teamplay_update_level(1,1);
			teamplay_update_level(2,1);
		}
		
		// clear leader display for warmup
		if(warmup > 0) ClearSyncHud(0,hudSyncLDisplay);
	}
}

// refresh a player's hegrenade stock
public refresh_nade(taskid)
{
	new id = taskid-TASK_REFRESH_NADE;

	// player left, player died, or GunGame turned off
	if(!is_user_connected(id) || !is_user_alive(id) || !ggActive) return;

	// on the grenade level, and lacking that aforementioned thing
	if(equal(lvlWeapon[id],"hegrenade") && !user_has_weapon(id,CSW_HEGRENADE))
		ham_give_weapon(id,"weapon_hegrenade");
	
	// get bots to use the grenade
	if(is_user_bot(id))
	{
		engclient_cmd(id,"weapon_hegrenade");
		client_cmd(id,"weapon_hegrenade");
	}
}

// refill a player's ammo
stock refill_ammo(id,current=0)
{
	if(!is_user_alive(id)) return 0;

	// weapon-specific warmup
	if(warmup > 0 && warmupWeapon[0])
	{
		// no ammo for knives only
		if(equal(warmupWeapon,"knife")) return 0;
	}

	// get weapon name and index
	static fullName[24], curWpnName[24];
	new wpnid, curWpnMelee, curweapon = get_user_weapon(id);

	// re-init start of strings
	fullName[0] = 0;
	curWpnName[0] = 0;

	// we have a valid current weapon (stupid runtime errors)
	if(curweapon)
	{
		get_weaponname(curweapon,curWpnName,23);
		curWpnMelee = equal(curWpnName,"weapon_knife");
	}

	// if we are refilling our current weapon instead of our level weapon,
	// we actually have a current weapon, and this isn't a melee weapon or the
	// other alternative, our level weapon, is a melee weapon
	if(current && curweapon && (!curWpnMelee || equal(lvlWeapon[id],"knife")))
	{
		// refill our current weapon
		get_weaponname(curweapon,fullName,23);
		wpnid = curweapon;
	}
	else
	{
		// refill our level weapon
		formatex(fullName,23,"weapon_%s",lvlWeapon[id]);
		wpnid = get_weaponid(fullName);
		
		// so that we know for sure
		current = 0;
	}
	
	new armor = get_pcvar_num(gg_give_armor), helmet = get_pcvar_num(gg_give_helmet);

	// giving armor and helmets away like candy
	if(helmet) cs_set_user_armor(id,armor,CS_ARMOR_VESTHELM);
	else cs_set_user_armor(id,armor,CS_ARMOR_KEVLAR);

	// didn't find anything valid to refill somehow
	if(wpnid < 1 || wpnid > 30 || !fullName[0])
		return 0;
	
	// no reason to refill a melee weapon, or a bomb.
	// make use of our curWpnMelee cache here
	if((current && curWpnMelee) || wpnid == CSW_KNIFE || wpnid == CSW_C4)
		return 1;

	new ammo, wEnt;
	ammo = get_pcvar_num(gg_ammo_amount);

	// don't give away hundreds of grenades
	if(wpnid != CSW_HEGRENADE)
	{
		// set clip ammo
		wEnt = get_weapon_ent(id,wpnid);
		if(pev_valid(wEnt)) cs_set_weapon_ammo(wEnt,maxClip[wpnid]);
		
		// glock on the nade level
		if(wpnid == CSW_GLOCK18 && equal(lvlWeapon[id],"hegrenade"))
			cs_set_user_bpammo(id,CSW_GLOCK18,50);
		else
		{
			// set backpack ammo
			if(ammo > 0) cs_set_user_bpammo(id,wpnid,ammo);
			else cs_set_user_bpammo(id,wpnid,maxAmmo[wpnid]);
		}

		// update display if we need to
		if(curweapon == wpnid)
		{
			message_begin(MSG_ONE,gmsgCurWeapon,_,id);
			write_byte(1);
			write_byte(wpnid);
			write_byte(maxClip[wpnid]);
			message_end();
		}
	}

	// now do stupid grenade stuff
	else
	{
		// we don't have this nade yet
		if(!user_has_weapon(id,wpnid))
		{
			ham_give_weapon(id,fullName);
			remove_task(TASK_REFRESH_NADE+id);
		}
		
		if(get_pcvar_num(gg_nade_glock))
		{
			// set clip ammo
			new wEnt = get_weapon_ent(id,CSW_GLOCK18);
			if(pev_valid(wEnt)) cs_set_weapon_ammo(wEnt,20);

			// set backpack ammo
			cs_set_user_bpammo(id,CSW_GLOCK18,50);
				
			new curweapon = get_user_weapon(id);

			// update display if we need to
			if(curweapon == CSW_GLOCK18)
			{
				message_begin(MSG_ONE,gmsgCurWeapon,_,id);
				write_byte(1);
				write_byte(CSW_GLOCK18);
				write_byte(20);
				message_end();
			}
		}

		if(get_pcvar_num(gg_nade_smoke) && !cs_get_user_bpammo(id,CSW_SMOKEGRENADE))
			ham_give_weapon(id,"weapon_smokegrenade");

		if(get_pcvar_num(gg_nade_flash) && !cs_get_user_bpammo(id,CSW_FLASHBANG))
			ham_give_weapon(id,"weapon_flashbang");
	}
	
	// keep melee weapon out if we had it out
	if(curweapon && curWpnMelee)
	{
		engclient_cmd(id,curWpnName);
		client_cmd(id,curWpnName);
	}

	return 1;
}

// show someone a welcome message
public show_welcome(id)
{
	if(welcomed[id]) return;

	new menuid, keys;
	get_user_menu(id,menuid,keys);

	// another old-school menu opened
	if(menuid > 0)
	{
		// wait and try again
		set_task(3.0,"show_welcome",id);
		return;
	}

	play_sound_by_cvar(id,gg_sound_welcome);

	len = formatex(menuText,511,"\y%L\w^n",id,"WELCOME_MESSAGE_LINE1",GG_VERSION);
	len += formatex(menuText[len],511-len,"\d---------------\w^n");

	new special;
	if(get_pcvar_num(gg_knife_pro))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE2");
		special = 1;
	}
	if(get_pcvar_num(gg_turbo))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE3");
		special = 1;
	}
	if(get_pcvar_num(gg_knife_elite))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE4");
		special = 1;
	}
	if(get_pcvar_num(gg_dm) || get_cvar_num("csdm_active"))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE5");
		special = 1;
	}
	if(get_pcvar_num(gg_teamplay))
	{
		len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE6");
		special = 1;
	}

	if(special) len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L^n",id,"WELCOME_MESSAGE_LINE7",weaponNum);
	len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L",id,"WELCOME_MESSAGE_LINE8");
	len += formatex(menuText[len],511-len,"\d---------------\w^n");
	len += formatex(menuText[len],511-len,"%L",id,"PRESS_KEY_TO_CONTINUE");

	show_menu(id,1023,menuText,-1,"welcome_menu");
}

// show the required kills message
stock show_required_kills(id,always_individual=0)
{
	// weapon-specific warmup, who cares
	if(warmup > 0 && warmupWeapon[0]) return 0;

	if(always_individual || !get_pcvar_num(gg_teamplay))
		return gungame_hudmessage(id,3.0,"%L: %i / %i",id,"REQUIRED_KILLS",score[id],get_level_goal(level[id],id));
	
	new player, myTeam = _:cs_get_user_team(id), goal = get_level_goal(teamLevel[myTeam],id);
	for(player=1;player<=maxPlayers;player++)
	{
		if(player == id || (is_user_connected(player) && _:cs_get_user_team(player) == myTeam))
			gungame_hudmessage(player,3.0,"%L: %i / %i",player,"REQUIRED_KILLS",teamScore[myTeam],goal);
	}
	
	return 1;
}

// player killed himself
player_suicided(id)
{
	static name[32];

	// we still have protection (round ended, new one hasn't started yet)
	// or, suicide level downs are disabled
	if(roundEnded || !get_pcvar_num(gg_suicide_penalty)) return 0;
	
	// weapon-specific warmup, no one cares
	if(warmup > 0 && warmupWeapon[0]) return 0;
		
	if(!get_pcvar_num(gg_teamplay))
	{
		get_user_name(id,name,31);

		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_LEVEL_DOWN",name);
	
		// this is going to start a respawn counter HUD message
		if(get_pcvar_num(gg_dm) && (get_pcvar_num(gg_dm_countdown) & 2))
			return change_level(id,-1,_,0,1); // don't show message, always score

		// show with message
		return change_level(id,-1,_,_,1); // always score
	}
	else
	{
		new team = _:cs_get_user_team(id);
		if(team != 1 && team != 2) return 0;
		
		new penalty = get_level_goal(teamLevel[team],0);
		if(penalty > 0)
		{
			get_user_team(id,name,9);

			if(teamScore[team] - penalty < 0)
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_LEVEL_DOWN_TEAM",name,(teamLevel[team] > 1) ? teamLevel[team]-1 : teamLevel[team]);
			else
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"SUICIDE_SCORE_DOWN_TEAM",name,penalty);

			return change_score(id,-penalty);
		}
	}
	
	return 0;
}

// player scored or lost a point
stock change_score(id,value,refill=1,effect_team=1)
{
	// don't bother scoring up on weapon-specific warmup
	if(warmup > 0 && warmupWeapon[0] && value > 0)
		return 0;

	if(!can_score(id)) return 0;
	
	// already won, isn't important
	if(level[id] > weaponNum) return 0;

	new oldScore = score[id], goal = get_level_goal(level[id],id);
	
	new teamplay = get_pcvar_num(gg_teamplay), team;
	if(teamplay) team = _:cs_get_user_team(id);

	// if this is going to level us
	if(score[id] + value >= goal)
	{
		new max_lvl = get_pcvar_num(gg_max_lvl);

		// already reached max levels this round
		if(!teamplay && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[id] >= max_lvl)
		{
			// put it as high as we can without leveling
			score[id] = goal - 1;
		}
		else score[id] += value;
	}
	else score[id] += value;

	// check for level up
	if(score[id] >= goal)
	{
		score[id] = 0;

		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct

		change_level(id,1);
		return 1;
	}

	// check for level down
	if(score[id] < 0)
	{
		if(value < 0) show_required_kills(id);

		// can't go down below level 1
		if(level[id] <= 1)
		{
			score[id] = 0;

			if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
				teamplay_update_score(team,score[id],id,1); // direct
				
			new sdisplay = get_pcvar_num(gg_status_display);
			if(sdisplay == STATUS_KILLSLEFT || sdisplay == STATUS_KILLSDONE)
				status_display(id);

			return 0;
		}
		else
		{
			goal = get_level_goal(level[id] > 1 ? level[id]-1 : 1,id);

			score[id] = (oldScore + value) + goal; // carry over points
			if(score[id] < 0) score[id] = 0;
			
			if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
				teamplay_update_score(team,score[id],id,1); // direct

			change_level(id,-1);
			return -1;
		}
	}

	// refresh menus
	new menu;
	get_user_menu(id,menu,dummy[0]);
	if(menu == level_menu) show_level_menu(id);

	if(refill && get_pcvar_num(gg_refill_on_kill)) refill_ammo(id);
	
	if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
		teamplay_update_score(team,score[id],id,1); // direct

	if(value < 0) show_required_kills(id);
	else client_cmd(id,"speak ^"buttons/bell1.wav^"");
	
	new sdisplay = get_pcvar_num(gg_status_display);
	if(sdisplay == STATUS_KILLSLEFT || sdisplay == STATUS_KILLSDONE)
		status_display(id);

	return 0;
}

// player gained or lost a level
stock change_level(id,value,just_joined=0,show_message=1,always_score=0,play_sounds=1,effect_team=1)
{
	// can't score
	if(level[id] > 0 && !always_score && !can_score(id))
		return 0;

	// don't bother leveling up on weapon-specific warmup
	if(level[id] > 0 && warmup > 0 && warmupWeapon[0] && value > 0)
		return 0;
	
	new oldLevel = level[id], oldValue = value;
	
	new teamplay = get_pcvar_num(gg_teamplay), team;
	if(teamplay) team = _:cs_get_user_team(id);
	
	// teamplay, on a valid team
	if(teamplay && (team == 1 || team == 2) && value != -MAX_WEAPONS) // ignore warmup reset
	{
		// not effecting team, but setting me to something that doesn't match team
		// OR
		// effecting team, and not even starting on same thing as team
		if((!effect_team && level[id] + value != teamLevel[team]) || (effect_team && level[id] != teamLevel[team]))
		{
			log_amx("MISSYNCH -- id: %i, value: %i, just_joined: %i, show_message: %i, always_score: %i, play_sounds: %i, effect_team: %i, team: %i, level: %i, teamlevel: %i, usertime: %i, score: %i, teamscore: %i, lvlweapon: %s, teamlvlweapon: %s",
				id,value,just_joined,show_message,always_score,play_sounds,effect_team,team,level[id],teamLevel[team],get_user_time(id,1),score[id],teamScore[team],lvlWeapon[id],teamLvlWeapon[team]);
			
			log_message("MISSYNCH -- id: %i, value: %i, just_joined: %i, show_message: %i, always_score: %i, play_sounds: %i, effect_team: %i, team: %i, level: %i, teamlevel: %i, usertime: %i, score: %i, teamscore: %i, lvlweapon: %s, teamlvlweapon: %s",
				id,value,just_joined,show_message,always_score,play_sounds,effect_team,team,level[id],teamLevel[team],get_user_time(id,1),score[id],teamScore[team],lvlWeapon[id],teamLvlWeapon[team]);
		}
	}

	// this will put us below level 1
	if(level[id] + value < 1)
	{
		value = 1 - level[id]; // go down only to level 1
		
		// bottom out the score
		score[id] = 0;
		
		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
	}

	// going up
	if(value > 0)
	{
		new max_lvl = get_pcvar_num(gg_max_lvl);

		// already reached max levels for this round
		if(!teamplay && !get_pcvar_num(gg_turbo) && max_lvl > 0 && levelsThisRound[id] >= max_lvl)
			return 0;
	}
	
	// can't win on the warmup round
	if(level[id] + value > weaponNum && warmup > 0)
	{
		score[id] = get_level_goal(level[id],id) - 1;
		
		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
			
		return 0;
	}

	level[id] += value;
	if(!just_joined)	levelsThisRound[id] += value;

	silenced[id] = 0; // for going to Glock->USP, for example

	// win???
	if(level[id] > weaponNum)
	{
		// already won, ignore this
		if(won) return 1;
		
		// bot, and not allowed to win
		if(is_user_bot(id) && get_pcvar_num(gg_ignore_bots) == 2 && !only_bots())
		{
			change_level(id,-value,just_joined,_,1); // always score
			return 1;
		}

		// cap out score
		score[id] = get_level_goal(level[id],id);
		
		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
		
		if(teamplay && effect_team && (team == 1 || team == 2) && teamLevel[team] != level[id])
			teamplay_update_level(team,level[id],id,1); // direct

		// crown the winner
		win(id,lastKilled[id]);

		return 1;
	}
	
	// set weapon based on it
	get_level_weapon(level[id],lvlWeapon[id],23);
	
	// update the status display
	new sdisplay = get_pcvar_num(gg_status_display);
	if(sdisplay == STATUS_LEADERWPN) status_display(0); // to all
	else if(sdisplay) status_display(id); // only to me
	
	new nade = equal(lvlWeapon[id],"hegrenade");
	
	// I'm a leader!
	if(warmup <= 0 && level[get_leader()] == level[id])
	{
		new sound_cvar;
		if(nade) sound_cvar = gg_sound_nade;
		else if(equal(lvlWeapon[id],"knife")) sound_cvar = gg_sound_knife;
		
		if(sound_cvar)
		{
			// only play sound if we reached this level first
			if(num_players_on_level(level[id]) == 1) play_sound_by_cvar(0,sound_cvar);
		}
	}
	
	// NOW play level up sounds, so that they potentially
	// override the global "Player is on X level" sounds

	if(play_sounds)
	{
		// level up!
		if(oldValue >= 0) play_sound_by_cvar(id,gg_sound_levelup);

		// level down :(
		else play_sound_by_cvar(id,gg_sound_leveldown);
	}

	// remember to modify changes
	new oldTeamLevel;
	if(team == 1 || team == 2) oldTeamLevel = teamLevel[team];

	if(teamplay && effect_team && (team == 1 || team == 2) && teamLevel[team] != level[id])
		teamplay_update_level(team,level[id],id);

	// refresh menus
	new player, menu;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		get_user_menu(player,menu,dummy[0]);

		if(menu == scores_menu) show_scores_menu(player);
		else if(menu == level_menu) show_level_menu(player);
		else if(player == id && menu == weapons_menu) show_weapons_menu(player);
	}

	// make sure we don't have more than required now
	new goal = get_level_goal(level[id],id);
	if(score[id] >= goal)
	{
		score[id] = goal-1; // 1 under
		
		if(teamplay && effect_team && (team == 1 || team == 2) && teamScore[team] != score[id])
			teamplay_update_score(team,score[id],id,1); // direct
	}
	
	new turbo = get_pcvar_num(gg_turbo);

	// give weapon right away?
	if((turbo || just_joined) && is_user_alive(id)) give_level_weapon(id);
	else show_progress_display(id); // still show display anyway
	
	// update the leader display (cvar check done in that function)
	if(!just_joined)
	{
		remove_task(TASK_LEADER_DISPLAY);
		show_leader_display();
		
		new Float:lead_sounds = get_pcvar_float(gg_lead_sounds);
		if(lead_sounds > 0.0 && (!teamplay || effect_team)) play_lead_sounds(id,oldLevel,lead_sounds);
	}

	new vote_setting = get_pcvar_num(gg_vote_setting), map_iterations = get_pcvar_num(gg_map_iterations);

	// the level to start a map vote on
	if(!voted && warmup <= 0 && vote_setting > 0
	&& level[id] >= weaponNum - (vote_setting - 1)
	&& mapIteration >= map_iterations && map_iterations > 0)
	{
		new mapCycleFile[64];
		get_gg_mapcycle_file(mapCycleFile,63);

		// start map vote?
		if(!mapCycleFile[0] || !file_exists(mapCycleFile))
		{
			voted = 1;

			// check for a custom vote
			new custom[256];
			get_pcvar_string(gg_vote_custom,custom,255);

			if(custom[0]) server_cmd(custom);
			else start_mapvote();
		}
	}

	// grab my name
	static name[32];
	if(!teamplay) get_user_name(id,name,31);

	// only calculate position if we didn't just join
	if(!just_joined && show_message)
	{
		if(teamplay)
		{
			// is the first call for this level change
			if((team == 1 || team == 2) && teamLevel[team] != oldTeamLevel)
			{
				new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);
				
				// tied
				if(numLeaders > 1) gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_TEAM",leaderLevel,teamLvlWeapon[team]);
				
				// leading
				else if(leader == team)
				{
					get_user_team(id,name,9);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"LEADING_ON_LEVEL_TEAM",name,leaderLevel,teamLvlWeapon[team]);
				}
				
				// trailing
				else
				{
					get_user_team(id,name,9);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TRAILING_ON_LEVEL_TEAM",name,teamLevel[team],teamLvlWeapon[team]);
				}
			}
		}
		else
		{
			new leaderLevel, numLeaders, leader = get_leader(leaderLevel,numLeaders);
			
			// tied
			if(level[id] == leaderLevel && numLeaders > 1 && level[id] > 1)
			{
				if(numLeaders == 2)
				{
					new otherLeader;
					if(leader != id) otherLeader = leader;
					else
					{
						new player;
						for(player=1;player<=maxPlayers;player++)
						{
							if(is_user_connected(player) && level[player] == leaderLevel && player != id)
							{
								otherLeader = player;
								break;
							}
						}
					}
					
					static otherName[32];
					get_user_name(otherLeader,otherName,31);
					
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_ONE",name,leaderLevel,lvlWeapon[id],otherName);
				}
				else
				{
					static numWord[16];
					num_to_word(numLeaders-1,numWord,15);
					trim(numWord);
					gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TIED_LEADER_MULTI",name,leaderLevel,lvlWeapon[id],numWord);
				}
			}

			// I'M THE BEST!!!!!!!
			else if(leader == id && level[id] > 1)
			{
				gungame_print(0,id,1,"%L",LANG_PLAYER_C,"LEADING_ON_LEVEL",name,level[id],lvlWeapon[id]);
			}
		}
	}
	
	// teamplay, didn't grab name yet
	if(teamplay) get_user_name(id,name,31);
	
	// triple bonus!
	if(levelsThisRound[id] == 3 && get_pcvar_num(gg_triple_on) && !turbo)
	{
		star[id] = 1;

		new sound[64];
		get_pcvar_string(gg_sound_triple,sound,63);

		fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)*1.5);
		if(sound[0]) emit_sound(id,CHAN_VOICE,sound,VOL_NORM,ATTN_NORM,0,PITCH_NORM);
		set_pev(id,pev_effects,pev(id,pev_effects) | EF_BRIGHTLIGHT);
		fm_set_rendering(id,kRenderFxGlowShell,255,255,100,kRenderNormal,1);
		fm_set_user_godmode(id,1);

		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(22); // TE_BEAMFOLLOW
		write_short(id); // entity
		write_short(trailSpr); // sprite
		write_byte(20); // life
		write_byte(10); // width
		write_byte(255); // r
		write_byte(255); // g
		write_byte(100); // b
		write_byte(100); // brightness
		message_end();

		gungame_print(0,id,1,"%L",LANG_PLAYER_C,"TRIPLE_LEVELED",name);
		set_task(10.0,"end_star",TASK_END_STAR+id);
	}
	
	// does this mod support friendlyfire?
	if(mp_friendlyfire)
	{
		// we don't bother with pcvars in here because they have some sketchy bugs about them!
		// maybe these are fixed in AMXX 1.8? who knows!

		new ff_auto = get_pcvar_num(gg_ff_auto), ff = get_cvar_num("mp_friendlyfire");

		// turn on FF?
		if(ff_auto && !ff && nade)
		{
			server_cmd("mp_friendlyfire 1"); // so console is notified
			set_cvar_num("mp_friendlyfire",1); // so it changes instantly

			gungame_print(0,0,1,"%L",LANG_PLAYER_C,"FRIENDLYFIRE_ON");

			client_cmd(0,"speak ^"gungame/brass_bell_C.wav^"");
		}

		// turn off FF?
		else if(ff_auto && ff)
		{
			new keepFF, player;

			for(player=1;player<=maxPlayers;player++)
			{
				if(equal(lvlWeapon[player],"hegrenade") || equal(lvlWeapon[player],"knife"))
				{
					keepFF = 1;
					break;
				}
			}

			// no one is on nade or knife level anymore
			if(!keepFF)
			{
				server_cmd("mp_friendlyfire 0"); // so console is notified
				set_cvar_num("mp_friendlyfire",0); // so it changes instantly
			}
		}
	}
	
	return 1;
}

// forces a player to a level, skipping a lot of important stuff.
// it's assumed that this is used as a result of "id" being leveled
// up because his teammate leveled up in teamplay.
stock set_level_noifandsorbuts(id,newLevel,play_sounds=1)
{
	// okay, this is our only but
	if(!is_user_connected(id)) return 0;

	new oldLevel = level[id];

	level[id] = newLevel;
	get_level_weapon(level[id],lvlWeapon[id],23);

	if(play_sounds)
	{
		// level up!
		if(newLevel >= oldLevel) play_sound_by_cvar(id,gg_sound_levelup);

		// level down :(
		else play_sound_by_cvar(id,gg_sound_leveldown);
	}

	// refresh menus
	new player, menu;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		get_user_menu(player,menu,dummy[0]);

		if(menu == scores_menu) show_scores_menu(player);
		else if(menu == level_menu) show_level_menu(player);
	}

	// give weapon right away?
	if(get_pcvar_num(gg_turbo) && is_user_alive(id)) give_level_weapon(id);
	else show_progress_display(id); // still show display anyway

	return 1;
}

// get rid of a player's star
public end_star(taskid)
{
	new id = taskid - TASK_END_STAR;
	if(!star[id]) return;

	star[id] = 0;
	//gungame_print(id,0,1,"Your star has run out!");

	if(is_user_alive(id))
	{
		fm_set_user_maxspeed(id,fm_get_user_maxspeed(id)/1.5);
		emit_sound(id,CHAN_VOICE,"common/null.wav",VOL_NORM,ATTN_NORM,0,PITCH_NORM); // stop sound
		set_pev(id,pev_effects,pev(id,pev_effects) & ~EF_BRIGHTLIGHT);
		fm_set_rendering(id);
		fm_set_user_godmode(id,0);

		message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
		write_byte(99); // TE_KILLBEAM
		write_short(id); // entity
		message_end();
	}
}

// give a player a weapon based on his level
stock give_level_weapon(id,notify=1,verify=1)
{
	if(!is_user_alive(id) || level[id] <= 0) return 0;
	
	// not warming up, didn't just win
	if(notify && warmup <= 0 && level[id] > 0 && level[id] <= weaponNum)
		show_progress_display(id);
	
	// stop attacks from bleeding over into the new weapon
	//client_cmd(id,"-attack;-attack2");
	
	// give CTs defuse kits on bomb maps
	if(bombMap && !get_pcvar_num(gg_block_objectives) && cs_get_user_team(id) == CS_TEAM_CT)
		cs_set_user_defuse(id,1);

	new armor = get_pcvar_num(gg_give_armor), helmet = get_pcvar_num(gg_give_helmet);

	// giving armor and helmets away like candy
	if(helmet) cs_set_user_armor(id,armor,CS_ARMOR_VESTHELM);
	else cs_set_user_armor(id,armor,CS_ARMOR_KEVLAR);

	new oldWeapon = get_user_weapon(id);

	static wpnName[24];
	new weapons = pev(id,pev_weapons), wpnid, alright, myCategory, hasMain;

	new ammo = get_pcvar_num(gg_ammo_amount);
	new knife_elite = get_pcvar_num(gg_knife_elite);
	new pickup_others = get_pcvar_num(gg_pickup_others);
	new mainCategory = get_weapon_category(_,lvlWeapon[id]);

	new hasGlock, hasSmoke, hasFlash;
	new nade_level = (equal(lvlWeapon[id],"hegrenade"));
	new nade_glock = get_pcvar_num(gg_nade_glock);
	new nade_smoke = get_pcvar_num(gg_nade_smoke);
	new nade_flash = get_pcvar_num(gg_nade_flash);

	new melee_only = ((warmup > 0 && warmupWeapon[0] && equal(warmupWeapon,"knife")) || (knife_elite && levelsThisRound[id] > 0));

	// remove stuff first
	for(wpnid=1;wpnid<31;wpnid++)
	{
		// don't have this, or it's the C$
		if(!(weapons & (1<<wpnid)) || wpnid == CSW_C4) continue;

		alright = 0;
		get_weaponname(wpnid,wpnName,23);

		if(melee_only)
		{
			if(wpnid == CSW_KNIFE)
			{
				alright = 1;
				hasMain = 1;
			}
		}
		else
		{
			replace(wpnName,23,"weapon_","");

			// this is our designated weapon
			if(equal(lvlWeapon[id],wpnName))
			{
				alright = 1;
				hasMain = 1;
			}
			
			// nade extras
			else if(nade_level)
			{
				if(nade_glock && wpnid == CSW_GLOCK18)
				{
					alright = 1;
					hasGlock = 1;
				}
				else if(nade_smoke && wpnid == CSW_SMOKEGRENADE)
				{
					alright = 1;
					hasSmoke = 1;
				}
				else if(nade_flash && wpnid == CSW_FLASHBANG)
				{
					alright = 1;
					hasFlash = 1;
				}
			}
			
			// get the tag back on there
			format(wpnName,23,"weapon_%s",wpnName);
		}
		
		// don't do anything about the knife
		if(wpnid != CSW_KNIFE)
		{
			// was it alright?
			if(alright)
			{
				// reset ammo
				if(wpnid != CSW_HEGRENADE && wpnid != CSW_FLASHBANG && wpnid != CSW_SMOKEGRENADE)
				{
					if(nade_level && nade_glock && wpnid == CSW_GLOCK18)
						cs_set_user_bpammo(id,CSW_GLOCK18,50);
					else
					{
						if(ammo > 0) cs_set_user_bpammo(id,wpnid,ammo);
						else cs_set_user_bpammo(id,wpnid,maxAmmo[wpnid]);
					}
				}
				else cs_set_user_bpammo(id,wpnid,1); // grenades
			}
			
			// we should probably remove this weapon
			else
			{
				// pistol in the way of glock, remove it
				if(nade_glock && (wpnid == CSW_USP || wpnid == CSW_DEAGLE
					|| wpnid == CSW_P228 || wpnid == CSW_FIVESEVEN || wpnid == CSW_ELITE))
				{
					ham_strip_weapon(id,wpnName);
				}
				else
				{
					myCategory = get_weapon_category(wpnid);

					// we aren't allowed to have any other weapons,
					// or this is in the way of the weapon that I want.
					if(!pickup_others || myCategory == mainCategory)
					{
						// if this isn't a melee weapon, disregard this. if it is, only strip
						// it if it's really in the way of the weapon that I want.
						if(!equal(wpnName,"weapon_knife") || myCategory == mainCategory)	
							ham_strip_weapon(id,wpnName);
					}
				}
			}/*not alright*/
		}/*not a knife*/
	}/*wpnid for-loop*/

	// I should have a weapon but don't
	if(lvlWeapon[id][0] && !hasMain)
	{
		formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);

		// give a player his weapon
		ham_give_weapon(id,wpnName);

		remove_task(TASK_REFRESH_NADE+id);

		if(!equal(lvlWeapon[id],"hegrenade") && !equal(lvlWeapon[id],"knife"))
		{
			wpnid = get_weaponid(wpnName);

			if(!wpnid) log_amx("INVALID WEAPON ID FOR ^"%s^"",lvlWeapon[id]);
			else
			{
				if(ammo > 0) cs_set_user_bpammo(id,wpnid,ammo);
				else cs_set_user_bpammo(id,wpnid,maxAmmo[wpnid]);
			}
		}
	}
	
	if(nade_level)
	{
		if(nade_glock && !hasGlock)
		{
			ham_give_weapon(id,"weapon_glock18");
			cs_set_user_bpammo(id,CSW_GLOCK18,50);
		}
		if(nade_smoke && !hasSmoke) ham_give_weapon(id,"weapon_smokegrenade");
		if(nade_flash && !hasFlash) ham_give_weapon(id,"weapon_flashbang");
	}

	new weapon = get_user_weapon(id);
	
	// using a knife probably
	if(melee_only || equal(lvlWeapon[id],"knife"))
	{
		// draw knife on knife warmup and knife level... this is so that
		// the terrorist that spawns with the C4 won't be spawned with his
		// C4 selected, but instead his knife
		engclient_cmd(id,"weapon_knife");
		client_cmd(id,"weapon_knife");
	}

	// switch back to knife if we had it out. also don't do this when called
	// by the verification check, because their old weapon will obviously be
	// a knife and they will want to use their new one.
	else if(verify && !notify)
	{
		get_weaponname(oldWeapon,wpnName,23);
		if(wpnName[0] && equal(wpnName,"weapon_knife"))
		{
			engclient_cmd(id,wpnName);
			client_cmd(id,wpnName);
		}
		else if(lvlWeapon[id][0])
		{
			formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
			engclient_cmd(id,wpnName);
			client_cmd(id,wpnName);
		}
	}
	
	// switch to glock for nade level
	else if(weapon != CSW_KNIFE && equal(lvlWeapon[id],"hegrenade") && nade_glock)
	{
		engclient_cmd(id,"weapon_glock18");
		client_cmd(id,"weapon_glock18");
	}

	// otherwise, switch to our new weapon
	else if(lvlWeapon[id][0])
	{
		formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
		engclient_cmd(id,wpnName);
		client_cmd(id,wpnName);
	}

	// make sure that we get this...
	if(verify)
	{
		remove_task(TASK_VERIFY_WEAPON+id);
		set_task(1.0,"verify_weapon",TASK_VERIFY_WEAPON+id);
	}
	
	// remember burst or silenced status
	if(silenced[id])
	{
		if(equal(lvlWeapon[id],"usp") || equal(lvlWeapon[id],"m4a1"))
		{
			new wEnt = get_weapon_ent(id,_,lvlWeapon[id]);
			if(pev_valid(wEnt))
			{
				cs_set_weapon_silen(wEnt,1,0);

				// play draw with silencer animation
				if(lvlWeapon[id][0] == 'u') set_pev(id,pev_weaponanim,USP_DRAWANIM);
				else set_pev(id,pev_weaponanim,M4A1_DRAWANIM);
			}
		}
		else if(equal(lvlWeapon[id],"glock18") || equal(lvlWeapon[id],"famas"))
		{
			new wEnt = get_weapon_ent(id,_,lvlWeapon[id]);
			if(pev_valid(wEnt)) cs_set_weapon_burst(wEnt,1);
		}

		silenced[id] = 0;
	}
	
	return 1;
}

// verify that we have our stupid weapon
public verify_weapon(taskid)
{
	new id = taskid-TASK_VERIFY_WEAPON;

	if(!is_user_alive(id)) return;

	static wpnName[24];
	formatex(wpnName,23,"weapon_%s",lvlWeapon[id]);
	new wpnid = get_weaponid(wpnName);

	if(!wpnid) return;

	// we don't have it, but we want it
	if(!user_has_weapon(id,wpnid)) give_level_weapon(id,0,0);
}

// crown a winner
win(winner,loser)
{
	// we have an invalid winner here
	if(won || !is_user_connected(winner) || !can_score(winner))
		return;

	won = 1;
	roundEnded = 1;

	server_cmd("sv_alltalk 1");
	play_sound(0,winSounds[currentWinSound]);

	new map_iterations = get_pcvar_num(gg_map_iterations), restart,
	player, Float:chattime = get_cvar_float("mp_chattime");

	// final playthrough, get ready for next map
	if(mapIteration >= map_iterations && map_iterations > 0)
	{
		set_nextmap();
		set_task(chattime,"goto_nextmap");

		// as of GG1.16, we always send a non-emessage intermission, because
		// other map changing plugins (as well as StatsMe) intercepting it
		// was causing problems.

		// as of GG1.20, we no longer do this because it closes the MOTD.

		// as of GG2.10, we use finale, which freezes players like the
		// intermission but doesn't otherwise do any intermission stuff.
		message_begin(MSG_ALL,SVC_FINALE);
		write_string(""); // although you could put a nice typewrite-style centersay here
		message_end();
		
		// freeze and godmode everyone
		new fullName[32];
		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_alive(player)) continue;
			
			// finale won't stop players from shooting technically
			formatex(fullName,31,"weapon_%s",lvlWeapon[player]);
			ham_strip_weapon(player,fullName);
		}
	}

	// get ready to go again!!
	else
	{
		restart = 1;

		// freeze and godmode everyone
		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_connected(player)) continue;
			
			client_cmd(player,"-attack;-attack2");
			set_pev(player,pev_flags,pev(player,pev_flags) | FL_FROZEN);
			fm_set_user_godmode(player,1);
			set_pev(player,pev_viewmodel2,"");
		}
	}
	
	message_begin(MSG_ALL,gmsgHideWeapon);
	write_byte((1<<0)|(1<<1)|(1<<3)|(1<<4)|(1<<5)|(1<<6)); // can't use (1<<2) or text disappears
	message_end();
	
	message_begin(MSG_ALL,gmsgCrosshair);
	write_byte(0); // hide
	message_end();
	
	new winnerName[32], i, teamplay = get_pcvar_num(gg_teamplay);
	if(teamplay) get_user_team(winner,winnerName,9);
	else get_user_name(winner,winnerName,31);
	
	// old-fashioned
	for(i=0;i<5;i++)
	{
		if(teamplay) gungame_print(0,winner,1,"%L!!",LANG_PLAYER_C,"WON_TEAM",winnerName);
		else gungame_print(0,winner,1,"%%n%s%%e %L!",winnerName,LANG_PLAYER_C,"WON");
	}
	
	// our new super function
	stats_award_points(winner);
	
	// finally show it off
	if(get_pcvar_num(gg_winner_motd))
	{
		new params[2];
		params[0] = winner;
		params[1] = loser;
		set_task(1.0,"show_win_screen",_,params,2);
	}
	
	// we can restart now (do it after calculations because points might get reset)
	if(restart)
	{
		// delay it, because it will reset stuff
		set_task(1.1,"restart_round",floatround(chattime-1.1));

		set_task(chattime-0.1,"restart_gungame",czero ? get_cvar_num("bot_stop") : 0);
		set_task(chattime+5.0,"stop_win_sound");
		
		if(czero) server_cmd("bot_stop 1"); // freeze CZ bots
	}
}

// restart gungame, for the next map iteration
public restart_gungame(old_bot_stop_value)
{
	won = 0;
	mapIteration++;
	
	/*new i;
	for(i=0;i<sizeof teamLevel;i++)
		clear_team_values(i);*/
	
	// game already commenced, but we are restarting, allow us to warmup again
	if(gameCommenced) shouldWarmup = 1;

	toggle_gungame(TASK_TOGGLE_GUNGAME + TOGGLE_ENABLE); // reset stuff
	do_rOrder(); // also does random teamplay
	setup_weapon_order();
	currentWinSound = do_rWinSound(); // pick the next win sound

	// unfreeze and ungodmode everyone
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		
		set_pev(player,pev_flags,pev(player,pev_flags) & ~FL_FROZEN);
		fm_set_user_godmode(player,0);
		welcomed[player] = 1; // also don't show welcome again
	}
	if(czero) server_cmd("bot_stop %i",old_bot_stop_value); // unfreeze CZ bots

	// only have warmup once?
	if(!get_pcvar_num(gg_warmup_multi)) warmup = -13; // -13 is the magical stop number
	else warmup = -1; // -1 isn't magical at all... :(
	
	warmupWeapon[0] = 0;
}

// stop the winner sound (for multiple map iterations)
public stop_win_sound()
{
	// stop winning sound
	if(containi(winSounds[currentWinSound],".mp3") != -1) client_cmd(0,"mp3 stop");
	else client_cmd(0,"speak null");
}

// calculate the winner screen... severely cut down from before
public show_win_screen(params[2]) // [winner,loser]
{
	new winner = params[0], loser = params[1], motd[2048], len, header[32];

	new teamplay = get_pcvar_num(gg_teamplay), stats_mode = get_pcvar_num(gg_stats_mode),
	timeratio = get_pcvar_num(gg_teamplay_timeratio), iterations = get_pcvar_num(gg_map_iterations),
	roundsleft = iterations - mapIteration, nextmap[32];

	get_cvar_string("amx_nextmap",nextmap,31);
	
	new winnerTeam[10], winnerName[32], winnerColor[8], winnerWinSuffix[3],
	winningTeam = _:cs_get_user_team(winner), losingTeam = _:(!(winningTeam-1)) + 1;

	get_user_team(winner,winnerTeam,9);
	get_user_name(winner,winnerName,31);
	get_team_color(CsTeams:winningTeam,winnerColor,7);
	get_number_suffix(pointsExtraction[winner][0],winnerWinSuffix,2);
	
	new loserDC, loserName[32], loserColor[8];
	if(is_user_connected(loser))
	{
		get_user_name(loser,loserName,31);
		get_team_color(cs_get_user_team(loser),loserColor,7);
	}
	else
	{
		loserDC = 1;
		loserColor = "gray";
	}
	
	// format for each language
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;

		if(loserDC) formatex(loserName,31,"%L",player,"NO_ONE");
		formatex(header,31,"%L",player,"WIN_MOTD_LINE1",winnerName);
	
		len = formatex(motd,2047,"<html><body bgcolor=black style=^"line-height:1.0^"><center><font color=#00CC00 size=7 face=Georgia>[GUNGAME] AMXX<p>");

		len += formatex(motd[len],2047-len,"<font color=%s size=6 style=^"letter-spacing:2px^">",winnerColor);
		len += formatex(motd[len],2047-len,"<table height=1 width=80%% cellpadding=0 cellspacing=0 bgcolor=%s><tr><td> </td></tr></table>",winnerColor);
		if(teamplay) len += formatex(motd[len],2047-len,"%L",player,"WIN_MOTD_LINE2",winnerTeam); else len += formatex(motd[len],2047-len,"%s",winnerName);
		len += formatex(motd[len],2047-len,"<table height=1 width=80%% cellpadding=0 cellspacing=0 bgcolor=%s><tr><td> </td></tr></table>",winnerColor);
		len += formatex(motd[len],2047-len,"<font size=4 color=white style=^"letter-spacing:1px^">%L<p>",player,"WIN_MOTD_LINE3");

		if(!teamplay) len += formatex(motd[len],2047-len,"<font size=3>%L<font color=white>.<br>",player,"WIN_MOTD_LINE4A",lvlWeapon[winner],loserColor,loserName);
		else len += formatex(motd[len],2047-len,"<font size=3>%L<font color=white>.<br>",player,"WIN_MOTD_LINE4B",lvlWeapon[winner],loserColor,loserName,winnerColor,winnerName);

		if(stats_mode == 1)
		{
			if(teamplay && timeratio)
			{
				// not enough for a win
				if(teamTimes[winner][winningTeam-1]/(teamTimes[winner][winningTeam-1]+teamTimes[winner][losingTeam-1]) < 0.5)
					len += formatex(motd[len],2047-len,"<p>");
				else
					len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE5A",winnerColor,winnerName,pointsExtraction[winner][0],winnerWinSuffix);
				
				len += formatex(motd[len],2047-len,"%L<br>",player,"WIN_MOTD_LINE6",floatround(teamTimes[player][winningTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1])*100.0));
			}
			else len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE5A",winnerColor,winnerName,pointsExtraction[winner][0],winnerWinSuffix);
			
			// we won somehow
			if( (!teamplay && winner == player) || (teamplay && !timeratio && winningTeam == _:cs_get_user_team(player)) ||
			(teamplay && timeratio && teamTimes[player][winningTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1]) >= 0.5) )
				len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE7A",pointsExtraction[player][0]);

			// we didn't get a win
			else len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE7B",pointsExtraction[player][0]);
				
		}
		else if(stats_mode == 2)
		{
			if(teamplay && timeratio)
			{
				// winner didn't play enough to get a win
				if(teamTimes[winner][winningTeam-1]/(teamTimes[winner][winningTeam-1]+teamTimes[winner][losingTeam-1]) < 0.5)
					len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE5B",winnerColor,winnerName,pointsExtraction[winner][2]);
				else
					len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE5C",winnerColor,winnerName,pointsExtraction[winner][0],winnerWinSuffix,pointsExtraction[winner][2]);
				
				len += formatex(motd[len],2047-len,"%L<br>",player,"WIN_MOTD_LINE6",floatround(teamTimes[player][winningTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1])*100.0));
			}
			else len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE5C",winnerColor,winnerName,pointsExtraction[winner][0],winnerWinSuffix,pointsExtraction[winner][2]);
			
			len += formatex(motd[len],2047-len,"%L<p>",player,"WIN_MOTD_LINE7C",pointsExtraction[player][1],pointsExtraction[player][2],pointsExtraction[player][0]);
		}
		else len += formatex(motd[len],2047-len,"<p>");
		
		if(iterations > 0)
		{
			if(roundsleft <= 0) len += formatex(motd[len],2047-len,"%L<font color=white>.",player,"WIN_MOTD_LINE8A",nextmap);
			else if(roundsleft == 1) len += formatex(motd[len],2047-len,"%L",player,"WIN_MOTD_LINE8B");
			else len += formatex(motd[len],2047-len,"%L",player,"WIN_MOTD_LINE8C",roundsleft);
		}

		len += formatex(motd[len],2047-len,"</center></body></html>");
	
		show_motd(player,motd,header);
	}
	
	return 1;
}

//**********************************************************************
// TEAMPLAY FUNCTIONS
//**********************************************************************

// change the score of a team
stock teamplay_update_score(team,newScore,exclude=0,direct=0)
{
	if(team != 1 && team != 2) return;

	teamScore[team] = newScore;
	
	new player, sdisplay = get_pcvar_num(gg_status_display);
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && player != exclude && _:cs_get_user_team(player) == team)
		{
			if(direct)
			{
				score[player] = newScore;
				if(sdisplay == STATUS_KILLSLEFT || sdisplay == STATUS_KILLSDONE)
					status_display(player);
			}
			else change_score(player,newScore-score[player],0); // don't refill
		}
	}
}

// change the level of a team
stock teamplay_update_level(team,newLevel,exclude=0,direct=1)
{
	if(team != 1 && team != 2) return;

	teamLevel[team] = newLevel;
	get_level_weapon(teamLevel[team],teamLvlWeapon[team],23);
	
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && player != exclude && _:cs_get_user_team(player) == team)
		{
			//if(direct) level[player] = newLevel;
			if(direct) set_level_noifandsorbuts(player,newLevel);
			else change_level(player,newLevel-level[player],_,_,1); // always score
		}
	}
}

// play the taken/tied/lost lead sounds
public teamplay_play_lead_sounds(id,oldLevel,Float:playDelay)
{
	// both teams not initialized yet
	if(!teamLevel[1] || !teamLevel[2]) return;

	// id: the player whose level changed
	// oldLevel: his level before it changed
	// playDelay: how long to wait until we play id's sounds
	
	// warmup or game over, no one cares
	if(warmup > 0 || won) return;

	// no level change
	if(level[id] == oldLevel) return;
	
	new team = _:cs_get_user_team(id), otherTeam = (team == 1) ? 2 : 1, thisTeam, player, params[2];
	if(team != 1 && team != 2) return;

	new leaderLevel, numLeaders, leader = teamplay_get_lead_team(leaderLevel,numLeaders);
	
	// this team is leading
	if(leader == team)
	{
		// the other team here?
		if(numLeaders > 1)
		{
			params[1] = gg_sound_tiedlead;
			
			// play to both teams
			for(player=1;player<=maxPlayers;player++)
			{
				if(!is_user_connected(player)) continue;

				thisTeam = _:cs_get_user_team(player);
				if(thisTeam == team || thisTeam == otherTeam)
				{
					params[0] = player;
					remove_task(TASK_PLAY_LEAD_SOUNDS+player);
					set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
				}
			}
		}
		
		// just us, we are the winners!
		else
		{
			// did we just pass the other team?
			if(level[id] > oldLevel && teamLevel[otherTeam] == oldLevel)
			{
				// play to both teams (conditional)
				for(player=1;player<=maxPlayers;player++)
				{
					if(!is_user_connected(player)) continue;
					
					thisTeam = _:cs_get_user_team(player);
					
					if(thisTeam == team) params[1] = gg_sound_takenlead;
					else if(thisTeam == otherTeam) params[1] = gg_sound_lostlead;
					else continue;
					
					params[0] = player;
					remove_task(TASK_PLAY_LEAD_SOUNDS+player);
					set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
				}
			}
		}
	}
	
	// WAS this team on the leader level?
	else if(oldLevel == leaderLevel)
	{
		// play to entire team
		for(player=1;player<=maxPlayers;player++)
		{
			if(!is_user_connected(player)) continue;
			
			thisTeam = _:cs_get_user_team(player);
			
			if(thisTeam == team) params[1] = gg_sound_lostlead;
			else if(thisTeam == otherTeam) params[1] = gg_sound_takenlead;
			else continue;
			
			params[0] = player;
			remove_task(TASK_PLAY_LEAD_SOUNDS+player);
			set_task((thisTeam == team) ? playDelay : 0.1,"play_sound_by_cvar_task",TASK_PLAY_LEAD_SOUNDS+player,params,2);
		}
	}
}

// find the highest level team and such
stock teamplay_get_lead_team(&retLevel=0,&retNumLeaders=0,&retRunnerUp=0)
{
	new leader, numLeaders, runnerUp;
	
	if(teamLevel[1] >= teamLevel[2]) leader = 1;
	else leader = 2;

	if(teamLevel[1] == teamLevel[2]) numLeaders = 2;
	else
	{
		numLeaders = 1;
		runnerUp = (leader == 1) ? 2 : 1;
	}

	retLevel = teamLevel[leader];
	retNumLeaders = numLeaders;
	retRunnerUp = runnerUp;

	return leader;
}

// gets the team's level goal without a player passed
teamplay_get_team_goal(team)
{
	if(team != 1 && team != 2) return 0;

	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && _:cs_get_user_team(player) == team)
			return get_level_goal(teamLevel[team],player);
	}
	
	return 0;
}

//**********************************************************************
// AUTOVOTE FUNCTIONS
//**********************************************************************

// start the autovote
public autovote_start()
{
	// vote in progress
	if(autovotes[0] || autovotes[1]) return;

	new Float:autovote_time = get_pcvar_float(gg_autovote_time);

	new i;
	for(i=1;i<=maxPlayers;i++)
	{
		if(is_user_connected(i))
		{
			format(menuText,511,"\y%L^n^n\w1. %L^n2. %L^n^n0. %L",i,"PLAY_GUNGAME",i,"YES",i,"NO",i,"CANCEL");
			show_menu(i,MENU_KEY_1|MENU_KEY_2|MENU_KEY_0,menuText,floatround(autovote_time),"autovote_menu");
		}
	}

	set_task(autovote_time,"autovote_result");
}

// take in votes
public autovote_menu_handler(id,key)
{
	switch(key)
	{
		case 0: autovotes[1]++;
		case 1: autovotes[0]++;
		//case 9: let menu close
	}

	return PLUGIN_HANDLED;
}

// calculate end of vote
public autovote_result()
{
	new enable, enabled = ggActive;

	if(autovotes[0] || autovotes[1])
	{
		if(float(autovotes[1]) / float(autovotes[0] + autovotes[1]) >= get_pcvar_float(gg_autovote_ratio))
			enable = 1;
	}

	gungame_print(0,0,1,"%L (%L: %i, %L: %i)",LANG_PLAYER_C,(enable) ? "VOTING_SUCCESS" : "VOTING_FAILED",LANG_PLAYER_C,"YES",autovotes[1],LANG_PLAYER_C,"NO",autovotes[0]);

	if(enable && !enabled)
	{
		restart_round(5);
		set_task(4.8,"toggle_gungame",TASK_TOGGLE_GUNGAME+TOGGLE_ENABLE);
	}
	else if(!enable && enabled)
	{
		restart_round(5);
		set_task(4.8,"toggle_gungame",TASK_TOGGLE_GUNGAME+TOGGLE_DISABLE);
		
		set_pcvar_num(gg_enabled,0);
		ggActive = 0;
	}

	// reset votes
	autovotes[0] = 0;
	autovotes[1] = 0;
}

//**********************************************************************
// STAT FUNCTIONS
//**********************************************************************

// we now have a super-duper function so that we only have to go through
// the stats file once, instead of rereading and rewriting it for every
// single player in a points match.
//
// also, timestamps are refreshed here, instead of every time you join.
stats_award_points(winner)
{	
	get_pcvar_string(gg_stats_file,sfFile,63);
	new stats_mode = get_pcvar_num(gg_stats_mode), ignore_bots = get_pcvar_num(gg_ignore_bots);
	
	if(!sfFile[0] || !stats_mode) return;
	
	new teamplay = get_pcvar_num(gg_teamplay), winningTeam =_:cs_get_user_team(winner),
	losingTeam = _:(!(winningTeam-1)) + 1, stats_ip = get_pcvar_num(gg_stats_ip),
	timeratio = get_pcvar_num(gg_teamplay_timeratio);

	new player, playerWins[32], playerPoints[32], playerAuthid[32][24], playerName[32][32],
	playerTotalPoints[32], players[32], set[32], setNum, playerNum, i, team, Float:time = get_gametime();

	get_players(players,playerNum);
	for(i=0;i<playerNum;i++)
	{
		player = players[i];
		
		// keep track of time
		team = _:cs_get_user_team(player);
		if(team == 1 || team == 2) teamTimes[player][team-1] += time - lastSwitch[player];
		lastSwitch[player] = time;

		if(stats_ip) get_user_ip(player,playerAuthid[i],23);
		else get_user_authid(player,playerAuthid[i],23);
		get_user_name(player,playerName[i],31);
		
		// solo wins only
		if(player == winner && stats_mode == 1 && !teamplay)
			playerWins[i] = 1;
	}
	
	//
	// COLLECT LIST OF PLAYERS AND THEIR INFORMATION
	//

	// points system
	if(stats_mode == 2)
	{
		new wins, Float:flPoints, iPoints, Float:winbonus = get_pcvar_float(gg_stats_winbonus), Float:percent;

		for(i=0;i<playerNum;i++)
		{
			player = players[i];
			if(!is_user_connected(player)) continue;
			
			// point ratio based on time played in teamplay
			if(teamplay && timeratio)
			{
				// give us points from losing team
				flPoints = (float(teamLevel[losingTeam]) - 1.0) * teamTimes[player][losingTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1]);

				// give us points from winning team
				percent = teamTimes[player][winningTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1]);
				flPoints += (float(teamLevel[winningTeam]) - 1.0) * percent;
				
				// we played over half on winning team, give us a bonus and win
				if(percent >= 0.5)
				{
					flPoints *= winbonus;
					wins = 1;
				}
			}
			else
			{
				// calculate points and add
				flPoints = float(level[player]) - 1.0;
				wins = 0;

				// winner gets bonus points plus a win
				if(player == winner || (teamplay && _:cs_get_user_team(player) == winningTeam))
				{
					flPoints *= winbonus;
					wins = 1;
				}
			}

			// unnecessary
			if(flPoints < 0.5 && !wins) continue;

			iPoints = floatround(flPoints);

			// it's okay to add to stats
			if(!ignore_bots || !is_user_bot(player))
			{
				playerWins[i] = wins;
				playerPoints[i] = iPoints;
			}
		}
	}

	// regular wins teamplay (solo regular wins is above)
	else if(teamplay)
	{
		for(i=0;i<playerNum;i++)
		{
			player = players[i];
			if(_:cs_get_user_team(player) == winningTeam && (!ignore_bots || !is_user_bot(player)))
			{
				// have to play at least half to get a win
				if(!timeratio || teamTimes[player][winningTeam-1]/(teamTimes[player][winningTeam-1]+teamTimes[player][losingTeam-1]) >= 0.5)
					playerWins[i] = 1;
			}
		}
	}
	
	//
	// NOW GO THROUGH THE FILE
	//
	
	new tempFileName[65], file;
	formatex(tempFileName,64,"%s2",sfFile); // our temp file, append 2

	// create stats file if it doesn't exist
	if(!file_exists(sfFile))
	{
		file = fopen(sfFile,"wt");
		fclose(file);
	}

	// copy over current stat file
	rename_file(sfFile,tempFileName,1); // relative

	// rename failed?
	if(!file_exists(tempFileName)) return;

	new tempFile = fopen(tempFileName,"rt"), lastSetNum;
	file = fopen(sfFile,"wt");

	// go through our old copy and rewrite entries
	while(tempFile && file && !feof(tempFile))
	{
		fgets(tempFile,sfLineData,80);
		if(!sfLineData[0]) continue;
		
		// still have scores to add to
		lastSetNum = setNum;
		if(setNum < playerNum)
		{
			strtok(sfLineData,sfAuthid,23,sfLineData,80,'^t'); // isolate authid
			
			// see if we need to change this one
			for(i=0;i<playerNum;i++)
			{
				if(!set[i] && equal(playerAuthid[i],sfAuthid))
				{
					set[i] = 1;
					setNum++;
					
					strtok(sfLineData,sfWins,5,sfLineData,80,'^t'); // get wins
					strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // get name
					strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // get timestamp
					strtok(sfLineData,sfPoints,7,dummy,1,'^t'); // get points
					playerTotalPoints[i] = playerPoints[i] + str_to_num(sfPoints);

					fprintf(file,"%s^t%i^t%s^t%i^t%i",sfAuthid,str_to_num(sfWins)+playerWins[i],playerName[i],get_systime(),playerTotalPoints[i]);
					fputc(file,'^n');
					
					// so we can reference this for the MOTD
					pointsExtraction[players[i]][0] = str_to_num(sfWins)+playerWins[i];
					pointsExtraction[players[i]][1] = playerPoints[i];
					pointsExtraction[players[i]][2] = playerTotalPoints[i];
					
					break;
				}
			}
			
			// nothing to replace, just copy it over (newline is already included)
			if(lastSetNum == setNum) fprintf(file,"%s^t%s",sfAuthid,sfLineData); // we cut authid earlier
		}
		else fprintf(file,"%s",sfLineData); // nothing to replace, just copy it over (newline is already included)
	}
	
	new teamName[10];
	for(i=0;i<playerNum;i++)
	{
		// never found an existing entry, make a new one
		if(!set[i])
		{
			playerTotalPoints[i] = playerPoints[i];
			fprintf(file,"%s^t%i^t%s^t%i^t%i",playerAuthid[i],playerWins[i],playerName[i],get_systime(),playerPoints[i]);
			fputc(file,'^n');
			
			// so we can reference this for the MOTD
			pointsExtraction[players[i]][0] = playerWins[i];
			pointsExtraction[players[i]][1] = playerPoints[i];
			pointsExtraction[players[i]][2] = playerTotalPoints[i];
		}
		
		get_user_team(players[i],teamName,9);
		
		if(players[i] == winner || (teamplay && _:cs_get_user_team(players[i]) == winningTeam))
			log_message("^"%s<%i><%s><%s>^" triggered ^"Won_GunGame^"",playerName[i],get_user_userid(players[i]),playerAuthid[i],teamName);

		if(stats_mode == 2 && playerPoints[i])
		{
			log_message("^"%s<%i><%s><%s>^" triggered ^"GunGame_Points^" amount ^"%i^"",playerName[i],get_user_userid(players[i]),playerAuthid[i],teamName,playerPoints[i]);
			gungame_print(players[i],0,1,"%L",players[i],"GAINED_POINTS",playerPoints[i],playerTotalPoints[i],pointsExtraction[players[i]][0]);
		}
	}

	if(tempFile) fclose(tempFile);
	if(file) fclose(file);

	// remove our copy
	delete_file(tempFileName);
}

// get a player's last used name and wins from save file
stock stats_get_data(authid[],&wins,&points,lastName[],nameLen,&timestamp,id=0)
{
	wins = 0;
	points = 0;
	timestamp = 0;

	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return 0;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return 0;

	// storage format:
	// AUTHID	WINS	LAST_USED_NAME	TIMESTAMP	POINTS
	
	// well this is convenient
	if(statsPosition[id]) ArrayGetString(statsArray,statsPosition[id]-1,sfLineData,80);
	else
	{
		// open 'er up, boys!
		new found, file = fopen(sfFile,"rt");
		if(!file) return 0;

		// go through it
		while(!feof(file))
		{
			fgets(file,sfLineData,80);

			// isolate authid
			strtok(sfLineData,sfAuthid,23,dummy,1,'^t');

			// this is it, stop now because our
			// data is already stored in sfLineData
			if(equal(authid,sfAuthid))
			{
				found = 1;
				break;
			}
		}

		// close 'er up, boys! (hmm....)
		fclose(file);

		// couldn't find
		if(!found) return 0;
	}

	// isolate authid
	strtok(sfLineData,sfAuthid,23,sfLineData,80,'^t');

	// isolate wins
	strtok(sfLineData,sfWins,5,sfLineData,80,'^t');
	wins = str_to_num(sfWins);

	// isolate name
	strtok(sfLineData,lastName,nameLen,sfLineData,80,'^t');

	// isolate timestamp
	strtok(sfLineData,sfTimestamp,11,sfPoints,7,'^t');
	timestamp = str_to_num(sfTimestamp);

	// isolate points (only thing left)
	points = str_to_num(sfPoints);

	return 1;
}

// gather up our players
stats_get_top_players()
{
	// stats disabled
	if(!get_pcvar_num(gg_stats_mode)) return 0;

	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return 0;
	
	// create our giant array
	statsArray = ArrayCreate(81,100);

	// storage format:
	// AUTHID	WINS	LAST_USED_NAME	TIMESTAMP	POINTS

	// open sesame
	new file = fopen(sfFile,"rt");
	if(!file) return 0;

	// reading, reading, reading...
	while(!feof(file))
	{
		fgets(file,sfLineData,80);

		// empty line
		if(!sfLineData[0]) continue;
		
		// store it
		ArrayPushString(statsArray,sfLineData);
	}
	
	// close
	fclose(file);

	// do the big sort
	glStatsMode = get_pcvar_num(gg_stats_mode);
	ArraySort(statsArray,"stats_custom_compare");
	
	statsSize =	ArraySize(statsArray);
	if(statsSize > 1000) statsSize = 1000; // arbitrarily limit because we have to look through this every time someone connects
	
	// assign stat position to players already in the game
	new i, authid[24], stats_ip = get_pcvar_num(gg_stats_ip);
	for(i=1;i<=maxPlayers;i++)
	{
		if(is_user_connected(i))
		{
			if(stats_ip) get_user_ip(i,authid,23); else get_user_authid(i,authid,23);
			statsPosition[i] = stats_get_position(authid);
		}
	}

	return 1;
}

// our custom sorting function
public stats_custom_compare(Array:array,item1,item2)
{
	new score[2];

	ArrayGetString(array,item1,sfLineData,80);
	strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // get rid of authid
	if(glStatsMode == 1) // sort by wins
	{
		strtok(sfLineData,sfWins,5,sfLineData,1,'^t');
		score[0] = str_to_num(sfWins);
	}
	else // sort by points
	{
		strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // break off wins
		strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // break off name
		strtok(sfLineData,dummy,1,sfPoints,7,'^t'); // break off timestamp and get points
		score[0] = str_to_num(sfPoints);
	}
	
	ArrayGetString(array,item2,sfLineData,80);
	strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // get rid of authid
	if(glStatsMode == 1) // sort by wins
	{
		strtok(sfLineData,sfWins,5,sfLineData,1,'^t');
		score[1] = str_to_num(sfWins);
	}
	else // sort by points
	{
		strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // break off wins
		strtok(sfLineData,dummy,1,sfLineData,80,'^t'); // break off name
		strtok(sfLineData,dummy,1,sfPoints,7,'^t'); // break off timestamp and get points
		score[1] = str_to_num(sfPoints);
	}

	return score[1] - score[0];
}

// get a player's overall position
stats_get_position(authid[])
{
	new i;
	for(i=0;i<statsSize;i++)
	{
		ArrayGetString(statsArray,i,sfLineData,23);
		strtok(sfLineData,sfAuthid,23,dummy,1,'^t'); // isolate authid
			
		if(equal(authid,sfAuthid)) return i+1;
	}
	
	return 0;
}

// prune old entries
stock stats_prune(max_time=-1)
{
	get_pcvar_string(gg_stats_file,sfFile,63);

	// stats disabled/file doesn't exist
	if(!sfFile[0] || !file_exists(sfFile)) return 0;

	// -1 = use value from cvar
	if(max_time == -1) max_time = get_pcvar_num(gg_stats_prune);

	// 0 = no pruning
	if(max_time == 0) return 0;

	new tempFileName[65];
	formatex(tempFileName,64,"%s2",sfFile); // our temp file, append 2

	// copy over current stat file
	rename_file(sfFile,tempFileName,1); // relative

	// rename failed?
	if(!file_exists(tempFileName)) return 0;

	new tempFile = fopen(tempFileName,"rt");
	new file = fopen(sfFile,"wt");

	// go through our old copy and rewrite valid entries into the new copy
	new current_time = get_systime(), original[81], removed;
	while(tempFile && file && !feof(tempFile))
	{
		fgets(tempFile,sfLineData,80);

		if(!sfLineData[0]) continue;

		// save original
		original = sfLineData;

		// break off authid
		strtok(sfLineData,sfAuthid,1,sfLineData,80,'^t');

		// break off wins
		strtok(sfLineData,sfWins,1,sfLineData,80,'^t');

		// break off name, and thus get timestamp
		strtok(sfLineData,sfName,1,sfTimestamp,11,'^t');
		copyc(sfTimestamp,11,sfTimestamp,'^t'); // cut off points

		// not too old, write it to our new file
		if(current_time - str_to_num(sfTimestamp) <= max_time)
			fprintf(file,"%s",original); // newline is already included
		else
			removed++;
	}

	if(tempFile) fclose(tempFile);
	if(file) fclose(file);

	// remove our copy
	delete_file(tempFileName);
	return removed;
}

//**********************************************************************
// WHATEV
//**********************************************************************

// task is set on a potential team change, and removed on an
// approved team change, so if we reach it, deduct level
public delayed_suicide(taskid)
{
	new id = taskid-TASK_DELAYED_SUICIDE;
	if(is_user_connected(id)) player_suicided(id);
}

// remove those annoying pesky pistols, if they haven't been already
public strip_starting_pistols(id)
{
	if(!is_user_alive(id)) return;

	switch(cs_get_user_team(id))
	{
		case CS_TEAM_T:
		{
			if(!equal(lvlWeapon[id],"glock18") && user_has_weapon(id,CSW_GLOCK18))
			{
				ham_strip_weapon(id,"weapon_glock18");
			}
		}
		case CS_TEAM_CT:
		{
			if(!equal(lvlWeapon[id],"usp") && user_has_weapon(id,CSW_USP))
			{
				ham_strip_weapon(id,"weapon_usp");
			}
		}
	}
}

// weapon display
stock status_display(id,status=1)
{
	new sdisplay = get_pcvar_num(gg_status_display);

	// display disabled
	if(!sdisplay) return;

	// dead
	if(id && !is_user_alive(id)) return;

	new dest;
	static sprite[32];

	if(!id) dest = MSG_BROADCAST;
	else dest = MSG_ONE_UNRELIABLE;
	
	// disable display if status is 0, or we are doing a warmup
	if(!status || warmup > 0)
	{
		// don't send to bots
		if(!id || !is_user_bot(id))
		{
			message_begin(dest,gmsgScenario,_,id);
			write_byte(0);
			message_end();
		}

		return;
	}

	// weapon display
	if(sdisplay == STATUS_LEADERWPN || sdisplay == STATUS_YOURWPN)
	{
		if(sdisplay == STATUS_LEADERWPN)
		{
			new ldrLevel;
			get_leader(ldrLevel);

			// get leader's weapon
			if(ldrLevel <= 0) return;
			formatex(sprite,31,"%s",weaponName[ldrLevel-1]);
		}
		else
		{
			// get your weapon
			if(level[id] <= 0) return;
			formatex(sprite,31,"%s",lvlWeapon[id]);
		}

		strtolower(sprite);

		// sprite is d_grenade, not d_hegrenade
		if(sprite[0] == 'h') sprite = "grenade";

		// get true sprite name
		format(sprite,31,"d_%s",sprite);
	}

	// kill display
	else if(sdisplay == STATUS_KILLSLEFT)
	{
		new goal = get_level_goal(level[id],id);
		formatex(sprite,31,"number_%i",goal-score[id]);
	}
	else if(sdisplay == STATUS_KILLSDONE)
	{
		formatex(sprite,31,"number_%i",score[id]);
	}

	// don't send to bots
	if(!id || !is_user_bot(id))
	{
		message_begin(dest,gmsgScenario,_,id);
		write_byte(1);
		write_string(sprite);
		write_byte(150);
		message_end();
	}
}

// hide someone's money display
public hide_money(id)
{
	// hide money
	message_begin(MSG_ONE,gmsgHideWeapon,_,id);
	write_byte(1<<5);
	message_end();

	// hide crosshair that appears from hiding money
	message_begin(MSG_ONE,gmsgCrosshair,_,id);
	write_byte(0);
	message_end();
}

//**********************************************************************
// SUPPORT FUNCTIONS
//**********************************************************************

// analyzes the weapon order and saves it into our variables
public setup_weapon_order()
{
	new weaponOrder[(MAX_WEAPONS*16)+1], temp[27];
	get_pcvar_string(gg_weapon_order,weaponOrder,MAX_WEAPONS*16);
	
	new Float:killsperlvl = get_pcvar_float(gg_kills_per_lvl), i, done, colon, goal[6];
	
	// cut them apart
	for(i=0;i<MAX_WEAPONS;i++)
	{
		// out of stuff
		if(strlen(weaponOrder) <= 1)
		{
			i--; // for our count
			break;
		}

		// we still have a comma, go up to it
		if(contain(weaponOrder,",") != -1)
		{
			strtok(weaponOrder,temp,26,weaponOrder,MAX_WEAPONS*16,',');
			trim(temp);
			strtolower(temp);
		}

		// otherwise, finish up
		else
		{
			formatex(temp,26,"%s",weaponOrder);
			trim(temp);
			strtolower(temp);
			done = 1; // flag for end of loop
		}
		
		colon = contain(temp,":");
		
		// no custom requirement, easy
		if(colon == -1)
		{
			formatex(weaponName[i],23,"%s",temp);
			if(equal(temp,"knife") || equal(temp,"hegrenade")) weaponGoal[i] = (killsperlvl > 1.0) ? 1.0 : killsperlvl;
			else weaponGoal[i] = killsperlvl;
		}
		else
		{
			copyc(weaponName[i],23,temp,':');
			formatex(goal,5,"%s",temp[colon+1]);
			weaponGoal[i] = floatstr(goal);
		}

		if(done) break;
	}
	
	// we break to end our loop, so "i" will be where we left it. but it's 0-based.
	weaponNum = i+1;
}

// gets the goal for a level, taking into account default and custom values
stock get_level_goal(level,id=0)
{
	if(level < 1) return 1;

	// no teamplay, return preset goal
	if(!is_user_connected(id) || !get_pcvar_num(gg_teamplay)) return floatround(weaponGoal[level-1],floatround_ceil);

	// one of this for every player on team
	new Float:result = weaponGoal[level-1] * float(team_player_count(cs_get_user_team(id)));
	
	// modifiers for nade and knife levels
	if(equal(weaponName[level-1],"hegrenade")) result *= get_pcvar_float(gg_teamplay_nade_mod);
	else if(equal(weaponName[level-1],"knife")) result *= get_pcvar_float(gg_teamplay_melee_mod);
	
	if(result <= 0.0) result = 1.0;
	return floatround(result,floatround_ceil);
}

// gets the level a player should use for his level
stock get_level_weapon(theLevel,var[],varLen)
{
	if(warmup > 0 && warmupWeapon[0]) formatex(var,varLen,"%s",warmupWeapon);
	else if(theLevel > 0) formatex(var,varLen,"%s",weaponName[theLevel-1]);
	else var[0] = 0;
}

// easy function to precache sound via cvar
stock precache_sound_by_cvar(pcvar)
{
	new value[64];
	get_pcvar_string(pcvar,value,63);
	precache_generic(value);
}

// figure out which gungame.cfg file to use
stock get_gg_config_file(filename[],len)
{
	formatex(filename,len,"%s/gungame.cfg",cfgDir);

	if(!file_exists(filename))
	{
		formatex(filename,len,"gungame.cfg");
		if(!file_exists(filename)) filename[0] = 0;
	}
}

// figure out which gungame_mapcycle file to use
stock get_gg_mapcycle_file(filename[],len)
{
	static testFile[64];

	// cstrike/addons/amxmodx/configs/gungame_mapcycle.cfg
	formatex(testFile,63,"%s/gungame_mapcycle.cfg",cfgDir);
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/addons/amxmodx/configs/gungame_mapcycle.txt
	formatex(testFile,63,"%s/gungame_mapcycle.txt",cfgDir);
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/gungame_mapcycle.cfg
	testFile = "gungame_mapcycle.cfg";
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	// cstrike/gungame_mapcycle.txt
	testFile = "gungame_mapcycle.txt";
	if(file_exists(testFile))
	{
		formatex(filename,len,"%s",testFile);
		return 1;
	}

	return 0;
}

// another easy function to play sound via cvar
stock play_sound_by_cvar(id,cvar)
{
	static value[64];
	get_pcvar_string(cvar,value,63);

	if(!value[0]) return;

	if(containi(value,".mp3") != -1) client_cmd(id,"mp3 play ^"%s^"",value);
	else client_cmd(id,"speak ^"%s^"",value);
}

// a taskable play_sound_by_cvar
public play_sound_by_cvar_task(params[2])
{
	play_sound_by_cvar(params[0],params[1]);
}

// this functions take a filepath, but manages speak/mp3 play
stock play_sound(id,value[])
{
	if(!value[0]) return;

	if(containi(value,".mp3") != -1) client_cmd(id,"mp3 play ^"%s^"",value);
	else
	{
		if(equali(value,"sound/",6)) client_cmd(id,"speak ^"%s^"",value[6]);
		else client_cmd(id,"speak ^"%s^"",value);
	}
}

// find the highest level player and his level
stock get_leader(&retLevel=0,&retNumLeaders=0,&retRunnerUp=0)
{
	new player, leader, numLeaders, runnerUp;

	// locate highest player
	for(player=1;player<=maxPlayers;player++)
	{
		if(!is_user_connected(player)) continue;
		
		if(leader == 0 || level[player] > level[leader])
		{
			// about to dethrown leader, monitor runnerup
			if(leader && (runnerUp == 0 || level[leader] > level[runnerUp]))
				runnerUp = leader;

			leader = player;
			numLeaders = 1; // reset tied count
		}
		else if(level[player] == level[leader])
			numLeaders++;
		else
		{
			// monitor runnerup
			if(runnerUp == 0 || level[player] > level[runnerUp])
				runnerUp = player;
		}
	}

	retLevel = level[leader];
	retNumLeaders = numLeaders;
	retRunnerUp = runnerUp;

	return leader;
}

// gets the number of players on a particular level
stock num_players_on_level(checkLvl)
{
	new player, result;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && level[player] == checkLvl)
			result++;
	}
	return result;
}

// a butchered version of teame06's CS Color Chat Function
public gungame_print(id,custom,tag,msg[],any:...)
{
	new changeCount, num, i, j, argnum = numargs(), player;
	static newMsg[191], message[191], changed[5], players[32];

	if(id)
	{
		players[0] = id;
		num = 1;
	}
	else get_players(players,num);

	new colored_messages = get_pcvar_num(gg_colored_messages);

	for(i=0;i<num;i++)
	{
		player = players[i];
		changeCount = 0;

		// we have to change LANG_PLAYER into
		// a player-specific argument, because
		// ML doesn't work well with SayText
		for(j=4;j<argnum;j++)
		{
			if(getarg(j) == LANG_PLAYER_C)
			{
				setarg(j,0,player);
				changed[changeCount++] = j;
			}
		}

		// do user formatting
		vformat(newMsg,190,msg,5);

		// and now we have to change what we changed
		// back into LANG_PLAYER, so that the next
		// player will be able to have it in his language
		for(j=0;j<changeCount;j++)
		{
			setarg(changed[j],0,LANG_PLAYER_C);
		}

		// optimized color swapping
		if(colored_messages)
		{
			replace_all(newMsg,190,"%n","^x03"); // %n = team color
			replace_all(newMsg,190,"%g","^x04"); // %g = green
			replace_all(newMsg,190,"%e","^x01"); // %e = regular
		}
		else
		{
			replace_all(newMsg,190,"%n","");
			replace_all(newMsg,190,"%g","");
			replace_all(newMsg,190,"%e","");
		}

		// now do our formatting (I used two variables because sharing one caused glitches)

		if(tag) formatex(message,190,"^x04[%L]^x01 %s",player,"GUNGAME",newMsg);
		else formatex(message,190,"^x01%s",newMsg);

		message_begin(MSG_ONE,gmsgSayText,_,player);
		write_byte((custom > 0) ? custom : player);
		write_string(message);
		message_end();
	}
	
	return 1;
}

// show a HUD message to a user
public gungame_hudmessage(id,Float:holdTime,msg[],{Float,Sql,Result,_}:...)
{
	// user formatting
	static newMsg[191];
	vformat(newMsg,190,msg,4);

	// show it
	set_hudmessage(255,255,255,-1.0,0.8,0,6.0,holdTime,0.1,0.5);
	return ShowSyncHudMsg(id,hudSyncReqKills,newMsg);
}

// start a map vote
stock start_mapvote()
{
	new dmmName[24];

	// AMXX Nextmap Chooser
	if(find_plugin_byfile("mapchooser.amxx") != INVALID_PLUGIN_ID)
	{
		log_amx("Starting a map vote from mapchooser.amxx");

		new oldWinLimit = get_cvar_num("mp_winlimit"), oldMaxRounds = get_cvar_num("mp_maxrounds");
		set_cvar_num("mp_winlimit",0); // skip winlimit check
		set_cvar_num("mp_maxrounds",-1); // trick plugin to think game is almost over

		// call the vote
		if(callfunc_begin("voteNextmap","mapchooser.amxx") == 1)
			callfunc_end();

		// set maxrounds back
		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_num("mp_maxrounds",oldMaxRounds);
	}

	// Deagles' Map Management 2.30b
	else if(find_plugin_byfile("deagsmapmanage230b.amxx") != INVALID_PLUGIN_ID)
	{
		dmmName = "deagsmapmanage230b.amxx";
	}

	// Deagles' Map Management 2.40
	else if(find_plugin_byfile("deagsmapmanager.amxx") != INVALID_PLUGIN_ID)
	{
		dmmName = "deagsmapmanager.amxx";
	}

	//  Mapchooser4
	else if(find_plugin_byfile("mapchooser4.amxx") != INVALID_PLUGIN_ID)
	{
		log_amx("Starting a map vote from mapchooser4.amxx");
	
		new oldWinLimit = get_cvar_num("mp_winlimit"), oldMaxRounds = get_cvar_num("mp_maxrounds");
		set_cvar_num("mp_winlimit",0); // skip winlimit check
		set_cvar_num("mp_maxrounds",1); // trick plugin to think game is almost over

		// deactivate g_buyingtime variable
		if(callfunc_begin("buyFinished","mapchooser4.amxx") == 1)
			callfunc_end();

		// call the vote
		if(callfunc_begin("voteNextmap","mapchooser4.amxx") == 1)
		{
			callfunc_push_str("",false);
			callfunc_end();
		}

		// set maxrounds back
		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_num("mp_maxrounds",oldMaxRounds);
	}

	// NOTHING?
	else log_amx("Using gg_vote_setting without mapchooser.amxx, mapchooser4.amxx, deagsmapmanage230b.amxx, or deagsmapmanager.amxx: could not start a vote!");

	// do DMM stuff
	if(dmmName[0])
	{
		log_amx("Starting a map vote from %s",dmmName);

		// allow voting
		/*if(callfunc_begin("dmapvotemode",dmmName) == 1)
					{
			callfunc_push_int(0); // server
			callfunc_end();
		}*/

		new oldWinLimit = get_cvar_num("mp_winlimit"), Float:oldTimeLimit = get_cvar_float("mp_timelimit");
		set_cvar_num("mp_winlimit",99999); // don't allow extending
		set_cvar_float("mp_timelimit",0.0); // don't wait for buying
		set_cvar_num("enforce_timelimit",1); // don't change map after vote

		// call the vote
		if(callfunc_begin("startthevote",dmmName) == 1)
			callfunc_end();

		set_cvar_num("mp_winlimit",oldWinLimit);
		set_cvar_float("mp_timelimit",oldTimeLimit);

		// disallow further voting
		/*if(callfunc_begin("dmapcyclemode",dmmName) == 1)
		{
			callfunc_push_int(0); // server
			callfunc_end();
		}*/
	}
}

// set amx_nextmap to the next map
stock set_nextmap()
{
	new mapCycleFile[64];
	get_gg_mapcycle_file(mapCycleFile,63);

	// no mapcycle, leave amx_nextmap alone
	if(!mapCycleFile[0] || !file_exists(mapCycleFile))
	{
		set_localinfo("gg_cycle_num","0");
		return;
	}

	new strVal[10];

	// have not gotten cycleNum yet (only get it once, because
	// set_nextmap is generally called at least twice per map, and we
	// don't want to change it twice)
	if(cycleNum == -1)
	{
		get_localinfo("gg_cycle_num",strVal,9);
		cycleNum = str_to_num(strVal);
	}

	new firstMap[32], currentMap[32], lineData[32], i, line, foundMap;
	get_mapname(currentMap,31);

	new file = fopen(mapCycleFile,"rt");
	while(file && !feof(file))
	{
		fgets(file,lineData,31);

		trim(lineData);
		replace(lineData,31,".bsp",""); // remove extension
		new len = strlen(lineData) - 2;

		// stop at a comment
		for(i=0;i<len;i++)
		{
			// supports config-style (;) and coding-style (//)
			if(lineData[i] == ';' || (lineData[i] == '/' && lineData[i+1] == '/'))
			{
				copy(lineData,i,lineData);
				break;
			}
		}

		trim(lineData);
		if(!lineData[0]) continue;

		// save first map
		if(!firstMap[0]) formatex(firstMap,31,"%s",lineData);

		// we reached the line after our current map's line
		if(line == cycleNum+1)
		{
			// remember so
			foundMap = 1;

			// get ready to change to it
			set_cvar_string("amx_nextmap",lineData);

			// remember this map's line for next time
			num_to_str(line,strVal,9);
			set_localinfo("gg_cycle_num",strVal);

			break;
		}

		line++;
	}
	if(file) fclose(file);

	// we didn't find next map
	if(!foundMap)
	{
		// reset line number to first (it's zero-based)
		set_localinfo("gg_cycle_num","0");

		// no maps listed, go to current
		if(!firstMap[0]) set_cvar_string("amx_nextmap",currentMap);

		// go to first map listed
		else set_cvar_string("amx_nextmap",firstMap);
	}
}

// go to amx_nextmap
public goto_nextmap()
{
	set_nextmap(); // for good measure

	new mapCycleFile[64];
	get_gg_mapcycle_file(mapCycleFile,63);

	// no gungame mapcycle
	if(!mapCycleFile[0] || !file_exists(mapCycleFile))
	{
		new custom[256];
		get_pcvar_string(gg_changelevel_custom,custom,255);

		// try custom changelevel command
		if(custom[0])
		{
			server_cmd(custom);
			return;
		}
	}

	// otherwise, go to amx_nextmap
	new nextMap[32];
	get_cvar_string("amx_nextmap",nextMap,31);

	server_cmd("changelevel %s",nextMap);
}

// find a player's weapon entity
stock get_weapon_ent(id,wpnid=0,wpnName[]="")
{
	// who knows what wpnName will be
	static newName[24];

	// need to find the name
	if(wpnid) get_weaponname(wpnid,newName,23);

	// go with what we were told
	else formatex(newName,23,"%s",wpnName);

	// prefix it if we need to
	if(!equal(newName,"weapon_",7))
		format(newName,23,"weapon_%s",newName);

	return fm_find_ent_by_owner(maxPlayers,newName,id);
}

// counts number of chars in a string, by (probably) Twilight Suzuka
stock str_count(str[],searchchar)
{
	new i = 0;
	new maxlen = strlen(str);
	new count = 0;
	
	for(i=0;i<=maxlen;i++)
	{
		if(str[i] == searchchar)
			count++;
	}
	return count;
}

// find the nth occurance of a character in a string, based on str_count
stock str_find_num(str[],searchchar,number)
{
	new i;
	new maxlen = strlen(str);
	new found = 0;

	for(i=0;i<=maxlen;i++)
	{
		if(str[i] == searchchar)
		{
			if(++found == number)
				return i;
		}
	}
	return -1;
}

// cuts a snippet out of a string
stock remove_snippet(string[],strLen,start,end)
{
	new i, newpos;
	for(i=start;i<strLen;i++)
	{
		if(!string[i]) break;
		newpos = i + end - start + 1;

		if(newpos >= strLen) string[i] = 0;
		else string[i] = string[newpos];
	}
	
	return 1;
}

// gets a player id that triggered certain logevents, by VEN
stock get_loguser_index()
{
	static loguser[80], name[32];
	read_logargv(0,loguser,79);
	parse_loguser(loguser,name,31);

	return get_user_index(name);
}

// checks if a space is vacant, by VEN
stock bool:is_hull_vacant(const Float:origin[3],hull)
{
	new tr = 0;
	engfunc(EngFunc_TraceHull,origin,origin,0,hull,0,tr);

	if(!get_tr2(tr,TR_StartSolid) && !get_tr2(tr,TR_AllSolid) && get_tr2(tr,TR_InOpen))
		return true;
	
	return false;
}

// gets a weapon's category, just a shortcut to the weaponSlots table basically
stock get_weapon_category(id=0,name[]="")
{
	if(name[0])
	{
		if(equal(name,"weapon_",7)) id = get_weaponid(name);
		else
		{
			static newName[24];
			formatex(newName,23,"weapon_%s",name);
			id = get_weaponid(newName);
		}
	}

	if(id < 1 || id > 30) return -1;
	return weaponSlots[id];
}

// if a player is allowed to score (at least 1 player on opposite team)
stock can_score(id)
{
	if(!is_user_connected(id)) return 0;

	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		// this player is in a position to play and is on the other team than me
		if(player != id && is_user_connected(player) && on_valid_team(player) && cs_get_user_team(id) != cs_get_user_team(player))
			return 1;
	}
	
	return 0;
}

// returns 1 if there are only bots in the server, 0 if not
stock only_bots()
{
	new player;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && !is_user_bot(player))
			return 0;
	}

	// didn't find any humans
	return 1;
}

// gives a player a weapon efficiently
stock ham_give_weapon(id,weapon[])
{	
	if(!equal(weapon,"weapon_",7)) return 0;
	
	new wEnt = engfunc(EngFunc_CreateNamedEntity,engfunc(EngFunc_AllocString,weapon));
	if(!pev_valid(wEnt)) return 0;
	
	set_pev(wEnt,pev_spawnflags,SF_NORESPAWN);
	dllfunc(DLLFunc_Spawn,wEnt);
	
	if(!ExecuteHamB(Ham_AddPlayerItem,id,wEnt) || !ExecuteHamB(Ham_Item_AttachToPlayer,wEnt,id))
	{
		if(pev_valid(wEnt)) set_pev(wEnt,pev_flags,pev(wEnt,pev_flags) & FL_KILLME);
		return 0;
	}

	return 1;
}

// takes a weapon from a player efficiently
stock ham_strip_weapon(id,weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;
	
	new wId = get_weaponid(weapon);
	if(!wId) return 0;

	new wEnt = fm_find_ent_by_owner(maxPlayers,weapon,id);
	if(!wEnt) return 0;
	
	new weapon = get_user_weapon(id);
	if(weapon == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);
	
	if(!ExecuteHamB(Ham_RemovePlayerItem,id,wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill,wEnt);

	set_pev(id,pev_weapons,pev(id,pev_weapons) & ~(1<<wId));

	if(wId == CSW_C4 || wId == CSW_SMOKEGRENADE || wId == CSW_FLASHBANG || wId == CSW_HEGRENADE)
		cs_set_user_bpammo(id,wId,0);

	return 1;
}

// gets the weapon that a killer used, just like CHalfLifeMultiplay::DeathNotice
stock get_killer_weapon(killer,inflictor,retVar[],retLen)
{
	static killer_weapon_name[32];
	killer_weapon_name = "world"; // by default, the player is killed by the world

	if(pev_valid(killer) && (pev(killer,pev_flags) & FL_CLIENT))
	{
		if(pev_valid(inflictor))
		{
			if(inflictor == killer)
			{
				// if the inflictor is the killer, then it must be their current weapon doing the damage
				new weapon = get_user_weapon(killer);
				get_weaponname(weapon,killer_weapon_name,31);
			}
			else pev(inflictor,pev_classname,killer_weapon_name,31); // it's just that easy
		}
	}
	else
	{
		if(pev_valid(killer)) pev(inflictor,pev_classname,killer_weapon_name,31);
		else if(killer == 0) killer_weapon_name = "worldspawn";
	}
	
	// strip the monster_* or weapon_* from the inflictor's classname
	if(equal(killer_weapon_name,"weapon_",7))
		format(killer_weapon_name,31,"%s",killer_weapon_name[7]);
	else if(equal(killer_weapon_name,"monster_",8))
		format(killer_weapon_name,31,"%s",killer_weapon_name[8]);
	else if(equal(killer_weapon_name,"func_",5))
		format(killer_weapon_name,31,"%s",killer_weapon_name[5]);
	
	// output
	formatex(retVar,retLen,"%s",killer_weapon_name);
}

// gets a team's color
stock get_team_color(CsTeams:team,ret[],retLen)
{
	switch(team)
	{
		case CS_TEAM_T: return formatex(ret,retLen,"#FF3F3F");
		case CS_TEAM_CT: return formatex(ret,retLen,"#99CCFF");
	}

	return formatex(ret,retLen,"#FFFFFF");
}

// gets the name of a team
stock get_team_name(CsTeams:team,ret[],retLen)
{
	switch(team)
	{
		case CS_TEAM_T: return formatex(ret,retLen,"TERRORIST");
		case CS_TEAM_CT: return formatex(ret,retLen,"CT");
		case CS_TEAM_SPECTATOR: return formatex(ret,retLen,"SPECTATOR");
	}
	
	return formatex(ret,retLen,"UNASSIGNED");
}

// gets the amount of players on a team
stock team_player_count(CsTeams:team)
{
	new player, count;
	for(player=1;player<=maxPlayers;player++)
	{
		if(is_user_connected(player) && cs_get_user_team(player) == team)
			count++;
	}
	
	return count;
}

// is this player on a valid team?
on_valid_team(id)
{
	new CsTeams:team = cs_get_user_team(id);
	return (team == CS_TEAM_T || team == CS_TEAM_CT);
}

// gets a number's suffix. sort of bad, has to convert to string.
stock get_number_suffix(number,ret[],retLen)
{
	static str[8];
	num_to_str(number,str,7);
	new len = strlen(str);

	if(number >= 10 && str[len-2] == '1') // second to last digit
		return formatex(ret,retLen,"th"); // 10-19 end in 'th

	switch(str[len-1]) // last digit
	{
		case '1': return formatex(ret,retLen,"st");
		case '2': return formatex(ret,retLen,"nd");
		case '3': return formatex(ret,retLen,"rd");
	}
	
	return formatex(ret,retLen,"th");
}