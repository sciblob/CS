/* Plugin generated by AMXX-Studio */

#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fun>
#include <fakemeta>
#include <xs>
#include <hamsandwich>
#include <chr_engine>
#include <cstrike>

#define PLUGIN "Vehicle Mod"
#define VERSION "1.0"
#define AUTHOR "Leandro Urrere"

//The dimensions for car entity, are two dimensions, which is assigned depends on the angle of the vehicle parked
#define DIMENSION_MINIMA Float:{ -32.260000, -105.280001, -35.020000 }
#define DIMENSION_MAXIMA Float:{  32.340000,  105.629999,  35.020000 }

#define DIMENSION2_MINIMA Float:{ -105.260000, -32.280001, -35.020000 }
#define DIMENSION2_MAXIMA Float:{  105.340000,  32.629999,  35.020000 }

//The dimensions for jeep entity
#define DIMENSION_MINIMA_JEEP Float:{ -32.260000, -60.280001, -35.020000 }
#define DIMENSION_MAXIMA_JEEP Float:{  32.340000,  85.629999,  35.020000 }

#define DIMENSION2_MINIMA_JEEP Float:{ -60.260000, -32.280001, -35.020000 }
#define DIMENSION2_MAXIMA_JEEP Float:{  85.340000,  32.629999,  35.020000 }

new inRank[34]; //is the driver nearby from car? 
new goingUp[34] //is the driver getting into the car?
new goingDown[34] //is the driver getting out from the car?
new Float:normalspeed[34] //the normal speed of players
new inCar[34] // is the driver inside the car?

new car[34] //links the driver to this car
new playersInCar[500] //the numbers of player inside this car
new isInside[34] //is the companion inside the car?
new followTo[34] //the driver of the companion in the car

new goingDown2[34] //is the companion getting out from the car?
new inRank2[34]	//is the companion nearby from car? 
new goingUp2[34] //is the companion getting into the car?

new siren[34] //is the siren activated?
new hassiren[34] //does the driver's car have an siren?

new contador[34] //auxiliary meter
new contador2[34] //auxiliary meter
new Float:anguloactual[3] //the current angle of the player
new Float:anguloanterior[3] //the previous angle of the player

const m_flVelocityModifier = 108; //used to keep the driver's speed constant when receiving shots

public plugin_init() {
	
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_Touch, "FwdTouch", 0)
	
	register_clcmd("say buycar","BuyCar",ADMIN_RCON,"Comprar Auto");
	register_clcmd("say buyjeep","BuyJeep",ADMIN_RCON,"Comprar Jeep");
	register_forward(FM_CmdStart,"fwd_CmdStart")
	register_forward(FM_Think,"FM_Think_hook")
	register_logevent("Poczatek_Rundy", 2, "1=Round_Start")
	register_event("DeathMsg", "Event_DeathMsg", "a", "1>0")
	register_touch("player","player","crash")
	register_touch("player", "worldspawn", "choque")
	register_touch("player", "func_wall", "choque")
	register_touch("player", "func_breakable", "choque")
	RegisterHam(Ham_TakeDamage, "player", "OnCBasePlayer_TakeDamage_P", true);
			
	register_cvar("vm_carcost", "4000")
	register_clcmd("buycar","BuyCar",0,": Buy a Car")
	register_clcmd("buyjeep","BuyJeep",0,": Buy a Jeep")
}

public plugin_precache()
{
	   precache_model("models/vehicle_mod/policecar.mdl")  
	   precache_model("models/vehicle_mod/terroristcar.mdl")   
	   precache_model("models/vehicle_mod/jeep.mdl") 
	   precache_sound("vehicle_mod/choque.wav")
	   precache_sound("vehicle_mod/choque2.wav")
	   precache_sound("vehicle_mod/rapada.wav")
	   precache_sound("vehicle_mod/puerta.wav")
	   precache_sound("vehicle_mod/encendido.wav")
	   precache_sound("vehicle_mod/engine.wav")
	   precache_sound("vehicle_mod/siren.wav")
	   precache_sound("vehicle_mod/horn.wav")
}

public BuyJeep(id)
{	
	new cost = get_cvar_num("vm_carcost") //get car cost
	
	if(cs_get_user_money(id) < cost) //does the player have enough money to buy a car?
	{
		return PLUGIN_HANDLED;
	}	
				
	cs_set_user_money(id, cs_get_user_money(id) - cost) //subtract the money to the player
	emit_sound(id, CHAN_ITEM, "vehicle_mod/encendido.wav", 1.0, ATTN_NORM, 0, PITCH_NORM) //sound when the car appears 
	new car = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target")); //create new entity 
	
	set_pev(car,pev_classname,"item_car"); //set classname to car entity
	
	entity_set_string(car,EV_SZ_targetname,"jeep") //set name to car entity
	
	engfunc(EngFunc_SetModel,car,"models/vehicle_mod/jeep.mdl"); //set model to entity	
	
	setJeepDimension(id,car) //set entity dimension 
	setCarAngle(id,car)	//set entity angle
	setCarOrigin(id,car)	//set entity origin
	
	set_pev(car,pev_solid,SOLID_SLIDEBOX ); //set propiertis. Make solid the entity
	set_pev(car,pev_movetype,MOVETYPE_FLY); //set movetype: no gravity, but still collides with stuff
	setCarAnim(car,0) 
	set_pev(car,pev_nextthink,1.0) //refresh entity
			
	playersInCar[car]=0 //this car has nobody inside
	return PLUGIN_HANDLED;
}

public BuyCar(id)
{	
	new cost = get_cvar_num("vm_carcost")
	
	if(cs_get_user_money(id) < cost)
	{
		return PLUGIN_HANDLED;
	}	
				
	cs_set_user_money(id, cs_get_user_money(id) - cost)
	emit_sound(id, CHAN_ITEM, "vehicle_mod/encendido.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)
	new car = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));  
	
	set_pev(car,pev_classname,"item_car"); 
	
	if(get_user_team(id) == 2) //if player is police, give them a police car, if not give them a terrorist car
	{
		entity_set_string(car,EV_SZ_targetname,"policecar") 
		engfunc(EngFunc_SetModel,car,"models/vehicle_mod/policecar.mdl"); 	
	}
	else
	{
		entity_set_string(car,EV_SZ_targetname,"terroristcar") 
		engfunc(EngFunc_SetModel,car,"models/vehicle_mod/terroristcar.mdl");
	}
	
	setCarDimension(id,car)
	setCarAngle(id,car)	
	setCarOrigin(id,car)
	
	set_pev(car,pev_solid,SOLID_SLIDEBOX ); 	
	set_pev(car,pev_movetype,MOVETYPE_FLY); 
	setCarAnim(car,0)
	set_pev(car,pev_nextthink,1.0)
			
	playersInCar[car]=0
	return PLUGIN_HANDLED;
}

public FwdTouch(ent, id)
{
	    if (!is_valid_ent(ent) || !is_valid_ent(id)) //are valids the entitys?
		return;
	    
	    
	    static ClassName[32]
	    pev(ent, pev_classname, ClassName, 31)	//get classname
	    
	    if (!equali(ClassName, "item_car")) //is the touched entity a car?
		return
	    
	    inRank[id]=1  //if player touch the car, he is in rank to goinp up to car  
		
	    if (goingUp[id]==1) //is the driver getting into the car?
	    {
		car[id]=ent //links the car with the driver 	
		inCar[id] = 0 //the driver is out of car
		isInside[id] = 0 
		getInCar(ent,id) //the driver get in car
		setCarAnim(ent,2) //change car anim
		set_pev(ent,pev_solid,SOLID_NOT) //change the solid properties of entity
		set_pev(ent,pev_nextthink,1.0) //refresh entity
	    }
    
    
} 

public client_PreThink(id)
{
	   
	if(inCar[id] != 0) //is player driving a car?
	{
		new bufferstop = entity_get_int(id,EV_INT_button)
		
		if(bufferstop != 0) {
			//driver can only shoot with secondary guns
			if (get_user_weapon(id) != CSW_USP && get_user_weapon(id) != CSW_GLOCK18 && get_user_weapon(id) != CSW_P228 && get_user_weapon(id) != CSW_ELITE && get_user_weapon(id) != CSW_FIVESEVEN && get_user_weapon(id) != CSW_DEAGLE)
			{		
				entity_set_int(id,EV_INT_button,bufferstop & ~IN_ATTACK & ~IN_ATTACK2 & ~IN_ALT1 & ~IN_USE)
			}	 	 
		}
		
		if((bufferstop & IN_JUMP) && (entity_get_int(id,EV_INT_flags) & ~FL_ONGROUND & ~FL_DUCKING)) {
			entity_set_int(id,EV_INT_button,entity_get_int(id,EV_INT_button) & ~IN_JUMP)
		}
		
		return PLUGIN_CONTINUE
	}
	return PLUGIN_CONTINUE
}

public fwd_CmdStart(id, uc_handle, seed) {
		if(!is_user_alive(id) ){
			return FMRES_IGNORED;
		}
		
		new buttons = get_uc(uc_handle,UC_Buttons)
		new oldbuttons = get_user_oldbutton(id);
		
		if(is_user_bot(id)&&inCar[id]==0&& inRank[id]==1) //if player is a bot, and is out of car, and is in rank, GO UP like driver 
		{				
			goingUp[id]=1
			goingDown[id]=0						
		}
		
		if(buttons & IN_USE && !(oldbuttons & IN_USE)) // if player press ACCION KEY
		{ 
			
			if(inCar[id] == 0 && inRank[id]==1) //if player is out of car and is in rank, GO UP like driver 
			{				
				goingUp[id]=1
				goingDown[id]=0
			}
			if(inCar[id] == 1) //if player is driving the car, GO OUT from car
			{
				
				inRank[id]=0
				goingUp[id]=0
				goingDown[id]=1
							
			}
			if (inRank2[id]==1) //if the companion is in rank, GO UP like companion 
			{				
				goingUp2[id]=1
				goingDown2[id]=0							
			}
			if (isInside[id]==1) //if the companion is inside the car, GO OUT from car
			{		
				inRank2[id]=0
				goingUp2[id]=0
				goingDown2[id]=1											
			}
		}
		
		
		if( buttons & IN_JUMP ) //if player press JUMP KEY
		{	
			
			
			if (inCar[id]==1 || isInside[id]==1) //if player is inside the car, like driver or companion
			{
				//the player can not jump in car
				new Float:fVel[ 3 ];
				pev( id, pev_velocity, fVel );
				fVel[ 2 ] = float( -abs( floatround( fVel[ 2 ] ) ) ) 
				set_pev( id, pev_velocity, fVel )			
				
				
			}
			
			if(inCar[id]==1) //if player is driving
			{				
				//set horn sound
				emit_sound(id, CHAN_ITEM, "vehicle_mod/horn.wav", 1.0, ATTN_NORM, 0, PITCH_NORM)			
									
			}
			
			if(is_user_bot(id)) //if player is a bot
			{				
				//get out from car (only bots)
				goingDown[id]=1
				goingDown2[id]=1				
									
			}
		} 
		
		if( buttons & IN_DUCK ) //if player press CROUNCH KEY
		{					
			if (inCar[id] == 1) //if player is driving the car
			{
				
				//set_pev( id, pev_velocity, 0 )
				
				if(siren[id]!=1) //activate o desactivate the siren
				{
					siren[id]=1
				}
				else
				{
					siren[id]=0
				}
				
			}
		}		
		
		return FMRES_HANDLED
	}
	
public client_connect(id) {

	      inCar[id] = 0 //the player is not in any car	      
	      normalspeed[id] = get_user_maxspeed(id) //save the normal speed of player	         	
	      
	      return PLUGIN_CONTINUE
}

public client_disconnect( id ) 
{	
	client_cmd(id,"cl_sidespeed %2.3f",normalspeed[id]) //set normal speed to player
         client_cmd(id,"cl_forwardspeed %2.3f",normalspeed[id])
	client_cmd(id,"cl_backspeed %2.3f",normalspeed[id])  
	set_user_footsteps(id, 0) //set ON walk sound
	goingDown[id]=1 //get out from any car
	goingDown2[id]=1 
	
	return PLUGIN_CONTINUE
}

public Engine(id) {
	if(inCar[id] != 1) return PLUGIN_HANDLED //is user driving a car?
   
	emit_sound(id, CHAN_ITEM, "vehicle_mod/engine.wav", 1.0, ATTN_NORM, 0, PITCH_NORM) //set the engine sound
	
	if(siren[id]==1 && hassiren[id] == 1) //is siren activated and has siren the car?
	{
		emit_sound(id, CHAN_ITEM, "vehicle_mod/siren.wav", 1.0, ATTN_NORM, 0, PITCH_NORM) //set the siren sound
	}
	
	set_task(0.9,"Engine",id) //call this function again in 0.9 units of time
   
	return PLUGIN_HANDLED
}

public getInCar(car,id) //if driver get in to car
{
	if(inCar[id] != 0) return PLUGIN_HANDLED  //is driver out of car?
	
	normalspeed[id] = get_user_maxspeed(id) //save the normal speed from driver
	
	static Float:origin[3];
	pev(car,pev_origin,origin) //get car position
	
	//origin[0]=origin[0]+22; 
	origin[2]=origin[2]+10; 
	
	set_pev(id,pev_origin,origin) //set driver position inside the car	
	
	engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/puerta.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM) //get sounds of doors and starting engine
	engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/encendido.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	set_user_footsteps(id, 1) //set OFF the walk sound
	playersInCar[car]=playersInCar[car]+1 //add one player to account of players in car
	inCar[id] = 1 //the player is driving the car
	goingUp[id]=0 //reset value
	
	set_task(3.0,"Engine",id) //call this function in 3.0 units of time
	
	static carname[32]
	pev(car, pev_targetname, carname, 31)	//get the name of car
			    
	if(equali(carname, "policecar")) //if driver's car is a police car this have an siren, if not the driver's car have not a siren
	{
		hassiren[id]=1				
	}
	else
	{
		hassiren[id]=0
	}
	
	return PLUGIN_HANDLED
}

public getOutCar(id) //if driver get out from car
{	
	set_user_footsteps(id, 0) //set ON the walk sound
	
	setPilotOrigin(id) //set the driver origin
	set_user_maxspeed(id,normalspeed[id]) //set normal speed to player
	client_cmd(id,"cl_sidespeed %2.3f",normalspeed[id]) 
		
	for(new id2=0;id2<=33;id2++) //if driver go out from car, he deslinks the companion
	{
		if(followTo[id2]==id)
		{
			followTo[id2]=0
			
		}
	}
		
	inCar[id] = 0 //the player is out of car
	isInside[id] = 0 
	car[id] = 0 //deslinks the car and driver
	hassiren[id]=0 
	client_cmd(id,"cl_forwardspeed %2.3f",normalspeed[id]) //set normal speed 
	client_cmd(id,"cl_backspeed %2.3f",normalspeed[id]) 	
	
	return PLUGIN_HANDLED
}

public getOutCar2(id) //if companion get out from car
{
	setCoPilotOrigin(id) //set the companion origin
		  
	inCar[id] = 0 //the player is out from car
	isInside[id] = 0
	followTo[id]=0 //the player does not accompany any driver
		
	return PLUGIN_HANDLED
}

public Sounds(id) //get drifting sound
{
	contador[id]=contador[id]+1 //auxiliary meter, to change the frecuency of drifting sound
	if (contador[id]==10)
	{
		new diferencia,dif[33];
		pev(id,pev_angles,anguloactual)	 //get current angle of player
		
		diferencia = anguloactual[1]-anguloanterior[1] // calculate the difference between the current angle and the previous angle
		num_to_str(diferencia,dif,33)
		static Float:origin[3];
		pev(id,pev_origin,origin)
		new rango = 9665000000 //range constant to determine the maximum change of angle  
		if(diferencia>=rango || diferencia<=-rango) //if the difference is above the range constant
		{			
			
			engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/rapada.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM) //get drifting sound
			
		}	
		
		anguloanterior = anguloactual //set value of current angle to previous angle
		contador[id]=0
	}
	
	
}


public FM_Think_hook(ent)
{
		
	for(new id=0;id<=33;id++) //for each player in game
	{
				
		if(ent==car[id]) //is player links to this car?
		{					
		   
		    if(inCar[id] == 1) //is player driving the car?
		    {
			static Float:rvec[3]; 
			pev(id,pev_angles,rvec); //get player angle	
			set_pev(ent,pev_angles,rvec); //set to car the user angle
			
			static Float:origin[3]			
						
			origin = getOriginByAngle(id) //get the new origin of car acording the user angle	 		
			
			static Float:origin2[3]
			static Float:velocity[3]
			pev(ent,pev_origin,origin2) //get current car origin
					             
			if(get_distance_f(origin,origin2)>40) //if difference between the two origins is above 40
			{
				set_pev(ent,pev_origin,origin) //set new origin to car
			}
			
			else if(get_distance_f(origin,origin2)>4) //if the difference between the two origins is above 4 and below 40
			{
				setCarAnim(ent,2) //set car running anim
			         
				get_speed_vector(origin2,origin,600.0,velocity) //create velocity vector 
				set_pev(ent,pev_velocity,velocity)		//set velocity vector to car from current origin to new origin		
			} 
			else //if not
			{
				setCarAnim(ent,0) //set car stoping anim 
				set_pev(ent,pev_velocity,Float:{0.0,0.0,0.0}) //set null velocity vector 
				set_pev(ent,pev_origin,origin) //set new origin to car
			} 
			
			set_pev(ent,pev_nextthink,1.0) //refresh car entity
			
			set_user_maxspeed(id, 600.0) //change driver velocity
			client_cmd(id,"cl_forwardspeed 600.0")
			client_cmd(id,"cl_sidespeed 0.0")
			client_cmd(id,"cl_backspeed 500.0")  
			
			Sounds(id) //get drifting sounds
			
			if (is_user_alive(id)) //if driver is alive
			{
				setUserAnim(id) //set player driving anim
				//set_pev(id,pev_nextthink,1.0)
			}
			
			if (goingDown[id]==1 || !is_user_alive(id)) //if driver is geting out from car or if driver is dead
			{				
				set_pev(ent,pev_solid,SOLID_SLIDEBOX ) //change solid properties to car 
				static Float:rvec[3];
				static Float:p_mins1[3], Float:p_maxs1[3];
				
				setCarAngle(id,ent) //set car angle
				
				new name[32]
				pev(ent, pev_targetname, name, 31)
				if(equali(name, "car") ) //set dimension of car, according to it is a car or is a jeep
				{
					setCarDimension(id,ent)
				}
				else 
				{
					setJeepDimension(id,ent)
				}
								
				inCar[id] = 0 //player is not driving 
				car[id]=0 //deslinks the car from the player
				set_pev(ent,pev_velocity,Float:{0.0,0.0,0.0}) //set velocity to car
				setCarAnim(ent,0) //set stoping anim to car
				set_pev(ent,pev_nextthink,1.0) //refresh car
				goingDown[id]=0	 //reset variable
				playersInCar[ent]=playersInCar[ent]-1 //subtract one player to account of players in car
				getOutCar(id) //driver get out player from car	
				
				if(is_user_alive(id)) //if player die inside the car, dont get door sound
				{
					static Float:origin2[3]
					pev(id,pev_origin,origin2)
					engfunc(EngFunc_EmitAmbientSound, 0,origin2, "vehicle_mod/puerta.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				}
			}
		      }
		      for(new id2=0;id2<=33;id2++) //for each player in game that can be companion
		      {
		      	
				if(inCar[id2] == 0 && playersInCar[ent]>=1 && playersInCar[ent]<2) //if companion is out of car, and the account of players in car is lower that 2 players 
				{
					static Float:origin[3],origin2[3]			
					pev(ent,pev_origin,origin) //get car origin
					pev(id2,pev_origin,origin2) //get companion origin
					if(get_distance_f(origin,origin2)<60  ) //if distance between the companion and the car is lower that 60
					{
						inRank2[id2]=1 //the companion is in rank to get in to car
						
						if (goingUp2[id2]==1) //if companion is going up to car
						{						
							followTo[id2]=id //links companion (id2) to driver (id)
							playersInCar[ent]=playersInCar[ent]+1 //add one player to account of players in car
							normalspeed[id2] = get_user_maxspeed(id2) //save the normal speed of companion
							inRank2[id2]=0 //reset variables
							goingUp2[id2]=0
							isInside[id2]=1	//the companion is inside the car
							engfunc(EngFunc_EmitAmbientSound, 0,origin2, "vehicle_mod/puerta.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM) //get door sound
						}
					}
					else //if not
					{
						inRank2[id2]=0 //the companion is not in rank to get in to car
					}
				}
			
				if(followTo[id2]==id && ent==car[id]) //if companion (id2) follow to driver (id) and driver (id) is linked to car (ent)
				{
					if (goingDown2[id2]==1 || !is_user_alive(id2)) //if companion is going down from car or he is dead
					{
						goingDown2[id2]=0 //reset variable	
						playersInCar[ent]=playersInCar[ent]-1  //subtract one player to account of players in car
						isInside[id2]=0 //he is not inside the car
						getOutCar2(id2)	//companion get out from car
						
						if(is_user_alive(id2)) //if player die inside the car, dont get door sound
						{
							static Float:origin2[3]
							pev(id2,pev_origin,origin2)
							engfunc(EngFunc_EmitAmbientSound, 0,origin2, "vehicle_mod/puerta.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						}
					}
					
					if (isInside[id2]==1 && is_user_alive(id2)) //if companion is inside the car and he is alive
					{
						static Float:originx[3]			
						originx = getOriginByAngle(ent) //get the new origin acording the car angle
						
						set_pev(id2,pev_origin,originx) //set new origin to companion
						
						setUserAnim(id2) //set companion anim to player
						//set_pev(id2,pev_nextthink,1.0)						
					}
				}
			
		     }
			
		}
		
		
		
	}
	
}

public Poczatek_Rundy(ent)
{
	
	while((ent = find_ent_by_class(ent,"item_car")) != 0) //for each entity car
	{
		new solid, name[32]
		pev(ent,pev_solid,solid )
	
		pev(ent, pev_classname, name, 31)
		
		//remove all alone car at round start		
		if(equali(name, "item_car") && solid != SOLID_NOT) //if the car is parked and alone
		{
			remove_entity(ent)
		}
		else //if the car is not linked to any driver
		{
			new b = true
			for(new id=0;id<=33;id++)
			{
				if(car[id]==ent)
				{
					b = false
				}
			}
			if(b)
			{
				remove_entity(ent)
			}
		}
	}
	
}


public setUserAnim(id) //set anim driver to player
{		
	entity_set_int(id, EV_INT_sequence, 6)
                     entity_set_int(id, EV_INT_gaitsequence, 6)
                     entity_set_float(id, EV_FL_frame, 2.0)
                     entity_set_float(id, EV_FL_framerate, 0.0)
}
public setCarAnim(ent,anim) //set a certain anim to car
{
	set_pev(ent, pev_sequence, anim)
	set_pev(ent, pev_gaitsequence, anim)
	set_pev(ent, pev_frame, 1.0)
	set_pev(ent, pev_animtime, 5.0)
	set_pev(ent, pev_framerate, 10.0)	
}

public getOriginByAngle(id) //get origin acording the angle
{
	static Float:originx[3]			
	pev(id,pev_origin,originx)
	static Float:rvecx[3]; 
	pev(id,pev_angles,rvecx)
	
	if( rvecx[1] > 0 && rvecx[1] <= 45 ) 
	{
		originx[0] = (((2*rvecx[1])-15)/5)+originx[0]
		originx[1] = (((7*rvecx[1])-990)/45)+originx[1]			     
	}
		
	else if( rvecx[1] > 45 && rvecx[1] <= 90 ) 
	{
		originx[0] = (((7*rvecx[1])+360)/45)+originx[0]
		originx[1] = (((4*rvecx[1])-405)/15)+originx[1]			     
	}
			
	else if( rvecx[1] > 90 && rvecx[1] <= 135 ) 
	{
		originx[0] = (((-7*rvecx[1])+1620)/45)+originx[0]
		originx[1] = (((2*rvecx[1])-195)/5)+originx[1]			     
	}
			
	else if( rvecx[1] > 135 && rvecx[1] <= 180 ) 
	{
		originx[0] = (((-4*rvecx[1])+765)/15)+originx[0]
		originx[1] = (((7*rvecx[1])-270)/45)+originx[1]			     
	}
		
	else if( rvecx[1] <= 0 && rvecx[1] > -45 ) 
	{
		originx[0] = (((4*rvecx[1])-45)/15)+originx[0]
		originx[1] = (((-7*rvecx[1])-990)/45)+originx[1]			     
	}
			
	else if( rvecx[1] <= -45 && rvecx[1] > -90 ) 
	{
		originx[0] = (((7*rvecx[1])-360)/45)+originx[0]
		originx[1] = (((-2*rvecx[1])-165)/5)+originx[1]			     
	}
			
	else if( rvecx[1] <= -90 && rvecx[1] > -135 ) 
	{
		originx[0] = (((-7*rvecx[1])-1620)/45)+originx[0]
		originx[1] = (((-4*rvecx[1])-315)/15)+originx[1]			     
	}
			
	else if( rvecx[1] <= -135 && rvecx[1] > -180 ) 
	{
		originx[0] = (((-2*rvecx[1])-345)/5)+originx[0]
		originx[1] = (((-7*rvecx[1])-270)/45)+originx[1]			     
	}
	
	return originx
}

public setCarAngle(id,ent) //set angle to car
{
	static Float:rvec[3]; 
	pev(id,pev_angles,rvec); 
	
	rvec[0] = 0.0;
	if(rvec[1]<45 && rvec[1]>=-45)
	{
		rvec[1] = 0.0;		
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{
		rvec[1] = 90.0;		
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{
		rvec[1] = 180.0;		
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{
		rvec[1] = -90.0;		
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{
		rvec[1] = -180.0;		
	}
	
	set_pev(ent,pev_angles,rvec)
}

public setCarOrigin(id,ent) //set origin to car
{
	static Float:rvec[3]; 
	pev(id,pev_angles,rvec); 
	
	static Float:origin[3];		
	pev(id, pev_origin, origin) 	
	
	if(rvec[1]<45 && rvec[1]>=-45)
	{		
		origin[0]=origin[0]+10;
		origin[1]=origin[1]-55;
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{		
		origin[0]=origin[0]+55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{		
		origin[0]=origin[0]+10;
		origin[1]=origin[1]+55;
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{		
		origin[0]=origin[0]-55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{		
		origin[0]=origin[0]+10;
		origin[1]=origin[1]+55;
	}
	
	entity_set_origin(ent, origin) 
}

public setCarDimension(id,ent) //set dimension to car
{
	static Float:rvec[3];
	static Float:p_mins1[3], Float:p_maxs1[3];
				
	pev(id,pev_angles,rvec); 
	
	if(rvec[1]<45 && rvec[1]>=-45)
	{		
		p_mins1 = DIMENSION2_MINIMA;
		p_maxs1 = DIMENSION2_MAXIMA;
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{		
		p_mins1 = DIMENSION_MINIMA;
		p_maxs1 = DIMENSION_MAXIMA;
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{		
		p_mins1 = DIMENSION2_MINIMA;
		p_maxs1 = DIMENSION2_MAXIMA;
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{		
		p_mins1 = DIMENSION_MINIMA;
		p_maxs1 = DIMENSION_MAXIMA;
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{		
		p_mins1 = DIMENSION2_MINIMA;
		p_maxs1 = DIMENSION2_MAXIMA;
	}
					
	engfunc(EngFunc_SetSize, ent, p_mins1, p_maxs1);	
	
}

public setJeepDimension(id,ent) //set dimension to jeep
{
	static Float:rvec[3];
	static Float:p_mins1[3], Float:p_maxs1[3];
				
	pev(id,pev_angles,rvec); 
	
	if(rvec[1]<45 && rvec[1]>=-45)
	{		
		p_mins1 = DIMENSION2_MINIMA_JEEP;
		p_maxs1 = DIMENSION2_MAXIMA_JEEP;
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{		
		p_mins1 = DIMENSION_MINIMA_JEEP;
		p_maxs1 = DIMENSION_MAXIMA_JEEP;
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{		
		p_mins1 = DIMENSION2_MINIMA_JEEP;
		p_maxs1 = DIMENSION2_MAXIMA_JEEP;
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{		
		p_mins1 = DIMENSION_MINIMA_JEEP;
		p_maxs1 = DIMENSION_MAXIMA_JEEP;
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{		
		p_mins1 = DIMENSION2_MINIMA_JEEP;
		p_maxs1 = DIMENSION2_MAXIMA_JEEP;
	}
					
	engfunc(EngFunc_SetSize, ent, p_mins1, p_maxs1);	
	
}

public setPilotOrigin(id) //set driver origin
{
	static Float:origin[3];
	pev(id, pev_origin, origin)
	
	static Float:rvec[3];
         pev(id,pev_angles,rvec);	
	
	if(rvec[1]<45 && rvec[1]>=-45)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]+55;
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{
		origin[0]=origin[0]-55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]-55;
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{
		origin[0]=origin[0]+55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]-55;
	}	
	origin[2]=origin[2]+10;
	
	if(is_user_bot(id))
	{
		origin[2]=origin[2]+30;
	}
	
	set_pev(id, pev_origin, origin)
}

public setCoPilotOrigin(id) //set companion origin
{
	static Float:origin[3];
	pev(id, pev_origin, origin)
	
	static Float:rvec[3];
         pev(id,pev_angles,rvec);
	rvec[0] = 0.0;
	
	if(rvec[1]<45 && rvec[1]>=-45)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]-55;
	}
	else if(rvec[1]<135 && rvec[1]>=45)
	{
		origin[0]=origin[0]+55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]<=180 && rvec[1]>=135)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]+55;
	}
	else if(rvec[1]>=-135 && rvec[1]<-45)
	{
		origin[0]=origin[0]-55;
		origin[1]=origin[1]+10;
	}
	else if(rvec[1]>=-180 && rvec[1]<-135)
	{
		origin[0]=origin[0]+10;
		origin[1]=origin[1]+55;
	}	
	origin[2]=origin[2]+10;
	
	if(is_user_bot(id))
	{
		origin[2]=origin[2]+30;
	}
	
	set_pev(id, pev_origin, origin)
}

public Event_DeathMsg() {
	
	new id = read_data(2)  
	
	//if player die
	set_user_footsteps(id, 0) //set ON walk sound
	goingDown[id]=1 //get out from car
	goingDown2[id]=1
	
   }

public OnCBasePlayer_TakeDamage_P(id)
{
	if(inCar[id] == 1) //if player is driving car
	{
		set_pdata_float(id, m_flVelocityModifier, 1.0); //keep the driver's speed constant when receiving shots
	}
}

   
 public crash(entid, id) {
	
	if(fm_get_ent_speed(entid) >= 400) //if driver speed is more that 400 units
	{
		static Float:origin[3];
		pev(id,pev_origin,origin)
		if(fm_get_ent_speed(entid) >= 550) //set a crash sound acording the speed
		{
			engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/choque2.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		else
		{
			engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/choque.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}		
	      
		if(inCar[entid] == 1 && inCar[id] == 0 && isInside[id] == 0) //if attacker is driving and victim is out from any car
		{
			
			new hp = get_user_health(id) //get hp from victim
			
			new iFfire  = get_cvar_num("mp_friendlyfire") //is activated frienlyfire?
			
			if(!iFfire && get_user_team(entid) == get_user_team(id)) //if friendlyfire is not activated and attacker and victim have belong the same team
			{
				
			}
			else //if not
			{
				if(fm_get_ent_speed(entid) <= 500) //if driver speed is less that 500 units
				{				
					if(hp<=75) //if victim hp is less that 75 units
					{
						user_silentkill(id) //kill victim
						make_deathmsg(entid,id,0,"car") //show death message						
						set_user_frags(entid,get_user_frags(entid)+1) //add score to driver
											
					}
					else 
					{
						set_user_health(id,(hp - 75)) //set damage to victim
					}
				}
				else if(fm_get_ent_speed(entid) > 500) //else driver speed is more that 500 units
				{
					user_silentkill(id) //kill victim
					make_deathmsg(entid,id,0,"car") //show death message					
					set_user_frags(entid,get_user_frags(entid)+1) //add score to driver
					
				}
			}
			
			
			
		}
	}
	
	if(inCar[entid] == 1 && inCar[id] == 0 && isInside[id] == 0 && is_user_bot(id) && is_user_alive(id)) //if attacker is driving and victim is out from any car, and victim is a bot and victim is alive
	{
		goingUp2[id]=1 //victim GO UP to the car 
	}
   
	return PLUGIN_HANDLED
}

public choque(id, entid) 
{
   
	   contador2[id]=contador2[id]+1 //auxiliary meter, to change the frecuency of crash sound
	   
	   if(inCar[id] && contador2[id]>10) //if player is driving
	   {
		
			static Float:origin[3];
			pev(id,pev_origin,origin)
			if(fm_get_ent_speed(entid) >= 550) //set a crash sound acording the speed
			{
				engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/choque2.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
			else
			{
				engfunc(EngFunc_EmitAmbientSound, 0,origin, "vehicle_mod/choque.wav",VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			}
			contador2[id]=0
	   }
	   
	   
	   return PLUGIN_HANDLED
}

stock Float:fm_get_ent_speed(id) //auxiliary function to get ent velocity
{
	 if(!pev_valid(id))
	  return 0.0;
	 
	 static Float:vVelocity[3];
	 pev(id, pev_velocity, vVelocity);
	 
	 vVelocity[2] = 0.0;
	 
	 return vector_length(vVelocity);
} 
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
