#define HEAT_CAPACITY_HUMAN 100 //249840 J/K, for a 72 kg person.

/obj/machinery/atmospherics/unary/cryo_cell
	name = "cryo cell"
	icon = 'icons/obj/machines/medical/cryogenics.dmi' // map only
	icon_state = "pod_preview"
	density = TRUE
	anchored = TRUE
	interact_offline = 1
	layer = ABOVE_HUMAN_LAYER
	atom_flags = ATOM_FLAG_NO_TEMP_CHANGE
	construct_state = /singleton/machine_construction/default/panel_closed
	uncreated_component_parts = null
	stat_immune = 0

	var/active = FALSE
	idle_power_usage = 20
	active_power_usage = 200
	clicksound = 'sound/machines/buttonbeep.ogg'
	clickvol = 30

	machine_name = "cryo cell"
	machine_desc = "Uses a supercooled chemical bath to hold living beings in something close to suspended animation. Often paired with specialized medicines to rapidly heal wounds of a patient inside."

	var/temperature_archived
	var/mob/living/carbon/human/occupant
	var/obj/item/reagent_containers/glass/beaker

	var/current_heat_capacity = 50

	var/temperature_warning_threshhold = 170
	var/temperature_danger_threshhold = T0C

	var/fast_stasis_mult = 0.8
	var/slow_stasis_mult = 1.25
	var/current_stasis_mult = 1

/obj/machinery/atmospherics/unary/cryo_cell/Initialize()
	. = ..()
	icon = 'icons/obj/machines/medical/cryogenics_split.dmi'
	update_icon()
	atmos_init()

/obj/machinery/atmospherics/unary/cryo_cell/Destroy()
	for(var/atom/movable/A in src)
		A.dropInto(loc)
	if(beaker)
		beaker.forceMove(get_step(loc, SOUTH)) //Beaker is carefully ejected from the wreckage of the cryotube
		beaker = null
	. = ..()

/obj/machinery/atmospherics/unary/cryo_cell/atmos_init()
	..()
	if(node) return
	var/node_connect = dir
	for(var/obj/machinery/atmospherics/target in get_step(src,node_connect))
		if(target.initialize_directions & get_dir(target,src))
			node = target
			break

/obj/machinery/atmospherics/unary/cryo_cell/examine(mob/user)
	. = ..()
	if (user.Adjacent(src))
		if (beaker)
			to_chat(user, "It is loaded with a beaker.")
		if (occupant)
			occupant.examine(arglist(args))

/obj/machinery/atmospherics/unary/cryo_cell/Process()
	..()
	if(!node)
		return

	var/has_air_contents = FALSE
	if(air_contents) //Check this even if it's unpowered
		ADJUST_ATOM_TEMPERATURE(src, air_contents.temperature)
		if(beaker)
			QUEUE_TEMPERATURE_ATOMS(beaker)
		has_air_contents = TRUE

	if(!active)
		return

	if(occupant)
		if(occupant.stat != 2)
			process_occupant()

	if(has_air_contents)
		temperature_archived = air_contents.temperature
		heat_gas_contents()
		expel_gas()
		queue_icon_update()

	if(abs(temperature_archived-air_contents.temperature) > 1)
		network.update = 1

	return 1

/obj/machinery/atmospherics/unary/cryo_cell/relaymove(mob/user as mob)
	// note that relaymove will also be called for mobs outside the cell with UI open
	if(src.occupant == user && !user.stat)
		go_out()

/obj/machinery/atmospherics/unary/cryo_cell/interface_interact(user)
	tgui_interact(user)
	return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/tgui_state(mob/user)
	return GLOB.default_state

/obj/machinery/atmospherics/unary/cryo_cell/tgui_interact(mob/user, datum/tgui/ui)
	ui = SStgui.try_update_ui(user, src, ui)
	if(!ui)
		ui = new(user, src, "CryoCell", name)
		ui.open()

/obj/machinery/atmospherics/unary/cryo_cell/tgui_data(mob/user)
	var/list/data = list()

	data["isOperating"] = active
	data["hasOccupant"] = occupant ? TRUE : FALSE

	var/list/occupantData = list()
	if(occupant)
		occupantData["name"] = occupant.name
		occupantData["stat"] = occupant.stat
		occupantData["health"] = occupant.health
		occupantData["maxHealth"] = occupant.maxHealth
		occupantData["minHealth"] = config.health_threshold_dead
		occupantData["bruteLoss"] = occupant.getBruteLoss()
		occupantData["oxyLoss"] = occupant.getOxyLoss()
		occupantData["toxLoss"] = occupant.getToxLoss()
		occupantData["fireLoss"] = occupant.getFireLoss()
		occupantData["bodyTemperature"] = occupant.bodytemperature
	data["occupant"] = occupantData

	data["cellTemp"] = round(air_contents.temperature)
	data["cellTempStats"] = "good"
	if(air_contents.temperature >= temperature_danger_threshhold) // if greater than 273.15 kelvin (0 celsius)
		data["cellTempStatus"] = "bad"
	else if(air_contents.temperature >= temperature_warning_threshhold)
		data["cellTempStatus"] = "average"

	data["beakerLoaded"] = beaker ? TRUE : FALSE
	data["beakerLabel"] = null
	data["beakerVolume"] = 0
	if(beaker)
		data["beakerLabel"] = beaker.name
		data["beakerVolume"] = beaker.reagents.total_volume

	data["fastStasis"] = fast_stasis_mult
	data["slowStasis"] = slow_stasis_mult
	data["currentStasis"] = current_stasis_mult

	return data

/obj/machinery/atmospherics/unary/cryo_cell/tgui_act(action, params)
	if(..())
		return
	. = TRUE

	switch(action)
		if("toggleActive")
			active = !active
			update_icon()
			return TRUE
		if("ejectBeaker")
			if(beaker)
				beaker.forceMove(get_step(loc, SOUTH))
				beaker = null
			return TRUE
		if("ejectOccupant")
			if(!occupant || isslime(usr) || ispAI(usr))
				return
			go_out()
			return TRUE
		if("goFast")
			current_stasis_mult = fast_stasis_mult
			update_icon()
			return TRUE
		if("goRegular")
			current_stasis_mult = 1
			update_icon()
			return TRUE
		if("goSlow")
			current_stasis_mult = slow_stasis_mult
			update_icon()
			return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/state_transition(singleton/machine_construction/default/new_state)
	. = ..()
	if(istype(new_state))
		updateUsrDialog()

/obj/machinery/atmospherics/unary/cryo_cell/use_tool(obj/item/G, mob/living/user, list/click_params)
	if (!istype(G, /obj/item/reagent_containers/glass))
		return ..()

	if (beaker)
		to_chat(user, SPAN_WARNING("A beaker is already loaded into the machine."))
		return TRUE
	if (!user.unEquip(G, src))
		return TRUE

	beaker =  G
	user.visible_message("\The [user] adds \a [G] to \the [src]!", "You add \a [G] to \the [src]!")
	return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/on_update_icon()
	ClearOverlays()
	icon_state = "pod[active]"
	var/image/I

	if(panel_open)
		AddOverlays("pod_panel")

	I = image(icon, "pod[active]_top")
	I.pixel_z = 32
	AddOverlays(I)

	if(occupant)
		var/image/pickle = image(occupant.icon, occupant.icon_state)
		pickle.CopyOverlays(occupant)
		pickle.pixel_z = 11
		AddOverlays(pickle)

	I = image(icon, "lid[active]")
	AddOverlays(I)

	I = image(icon, "lid[active]_top")
	I.pixel_z = 32
	AddOverlays(I)

	if(!powered())
		return
	var/warn_state = "off"
	if(active)
		warn_state = "safe"
		if(air_contents.temperature >= temperature_danger_threshhold)
			warn_state = "danger"
		else if(air_contents.temperature >= temperature_warning_threshhold)
			warn_state = "warn"
	I = overlay_image(icon, "lights_[warn_state]")
	AddOverlays(I)
	I = overlay_image(icon, "lights_[warn_state]_top")
	I.pixel_z = 32
	AddOverlays(I)
	AddOverlays(emissive_appearance(icon, "lights_mask"))
	I = emissive_appearance(icon, "lights_mask_top")
	I.pixel_z = 32
	AddOverlays(I)

/obj/machinery/atmospherics/unary/cryo_cell/proc/process_occupant()
	if(air_contents.total_moles < 10)
		return
	if(occupant)
		if(occupant.stat == DEAD)
			return
		occupant.set_stat(UNCONSCIOUS)
		var/has_cryo_medicine = occupant.reagents.has_any_reagent(list(/datum/reagent/cryoxadone, /datum/reagent/clonexadone, /datum/reagent/nanitefluid)) >= REM
		if(beaker && !has_cryo_medicine)
			beaker.reagents.trans_to_mob(occupant, REM, CHEM_BLOOD)
		if (prob(2))
			to_chat(occupant, SPAN_NOTICE(SPAN_BOLD("... [pick("floating", "cold")] ...")))

/obj/machinery/atmospherics/unary/cryo_cell/proc/heat_gas_contents()
	if(air_contents.total_moles < 1)
		return
	var/air_heat_capacity = air_contents.heat_capacity()
	var/combined_heat_capacity = current_heat_capacity + air_heat_capacity
	if(combined_heat_capacity > 0)
		var/combined_energy = T20C*current_heat_capacity + air_heat_capacity*air_contents.temperature
		air_contents.temperature = combined_energy/combined_heat_capacity

/obj/machinery/atmospherics/unary/cryo_cell/proc/expel_gas()
	if(air_contents.total_moles < 1)
		return

/obj/machinery/atmospherics/unary/cryo_cell/proc/go_out()
	if(!( occupant ))
		return
	//for(var/obj/O in src)
	//	O.loc = loc
	if (occupant.client)
		occupant.client.eye = occupant.client.mob
		occupant.client.perspective = MOB_PERSPECTIVE
	occupant.forceMove(get_step(loc, SOUTH))
	if (occupant.bodytemperature < 261 && occupant.bodytemperature >= 70)
		occupant.bodytemperature = 261
	occupant = null
	current_heat_capacity = initial(current_heat_capacity)
	update_use_power(POWER_USE_IDLE)
	update_icon()
	SetName(initial(name))
	return

/obj/machinery/atmospherics/unary/cryo_cell/AltClick(mob/user)
	if(CanDefaultInteract(user))
		go_out()
		return TRUE
	return ..()

/obj/machinery/atmospherics/unary/cryo_cell/CtrlClick(mob/user)
	if(CanDefaultInteract(user))
		active = !active
		update_icon()
		return TRUE
	return FALSE

/obj/machinery/atmospherics/unary/cryo_cell/proc/put_mob(mob/living/carbon/target, mob/user)
	add_fingerprint(user) //Add fingerprints for trying to go in.
	if (!do_after(user, 3 SECONDS, src, DO_PUBLIC_UNIQUE))
		return FALSE
	if (!user_can_move_target_inside(target, user))
		return FALSE
	if (target.client)
		target.client.perspective = EYE_PERSPECTIVE
		target.client.eye = src
	target.stop_pulling()
	target.forceMove(src)
	target.ExtinguishMob()
	if (target.health > -100 && (target.health < 0 || target.sleeping))
		to_chat(target, SPAN_NOTICE("<b>You feel a cold liquid surround you. Your skin starts to freeze up.</b>"))
	occupant = target
	current_heat_capacity = HEAT_CAPACITY_HUMAN
	update_use_power(POWER_USE_ACTIVE)
	if (user != target)
		add_fingerprint(target) //Add fingerprints of the person stuffed in.
	update_icon()
	SetName("[name] ([occupant])")
	target.remove_grabs_and_pulls()
	return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/user_can_move_target_inside(mob/target, mob/user)
	if (occupant)
		to_chat(user, SPAN_WARNING("\The [src] is already occupied!"))
		return FALSE
	if (!node)
		to_chat(usr, SPAN_WARNING("The cell is not correctly connected to its pipe network!"))
		return FALSE
	return ..()

/obj/machinery/atmospherics/unary/cryo_cell/MouseDrop_T(mob/target, mob/user)
	if (!CanMouseDrop(target, user) || !ismob(target))
		return
	if (!user_can_move_target_inside(target, user))
		return

	user.visible_message(SPAN_NOTICE("\The [user] begins placing \the [target] into \the [src]."), SPAN_NOTICE("You start placing \the [target] into \the [src]."))
	put_mob(target, user)

/obj/machinery/atmospherics/unary/cryo_cell/use_grab(obj/item/grab/grab, list/click_params) //Grab is deleted at the level of put_mob if all checks are passed.
	MouseDrop_T(grab.affecting, grab.assailant)
	return TRUE

/obj/machinery/atmospherics/unary/cryo_cell/verb/move_eject()
	set name = "Eject occupant"
	set category = "Object"
	set src in oview(1)
	if(usr == occupant)//If the user is inside the tube...
		if (usr.stat == 2)//and he's not dead....
			return
		to_chat(usr, SPAN_NOTICE("Release sequence activated. This will take two minutes."))
		sleep(1200)
		if(!src || !usr || !occupant || (occupant != usr)) //Check if someone's released/replaced/bombed him already
			return
		go_out()//and release him from the eternal prison.
	else
		if (usr.stat != 0)
			return
		go_out()
	add_fingerprint(usr)
	return

/obj/machinery/atmospherics/unary/cryo_cell/verb/move_inside()
	set name = "Move Inside"
	set category = "Object"
	set src in oview(1)
	if (usr.stat != 0)
		return
	put_mob(usr, usr)
	return

/obj/machinery/atmospherics/unary/cryo_cell/return_air()
	return air_contents

/**
 * Alternative to `return_air()` used for internal organ and lung checks.
 *
 * Returns instance of `/datum/gas_mixture`.
 */
/atom/proc/return_air_for_internal_lifeform()
	return return_air()

/obj/machinery/atmospherics/unary/cryo_cell/return_air_for_internal_lifeform()
	//assume that the cryo cell has some kind of breath mask or something that
	//draws from the cryo tube's environment, instead of the cold internal air.
	if(loc)
		return loc.return_air()
	else
		return null

/obj/machinery/atmospherics/unary/cryo_cell/RefreshParts()
	..()
	var/stasis_coeff = total_component_rating_of_type(/obj/item/stock_parts/manipulator)
	fast_stasis_mult = max(1 - (stasis_coeff * 0.06), 0.66)
	slow_stasis_mult = min(1 + (stasis_coeff * 0.08), 1.5)

/datum/data/function/proc/reset()
	return

/datum/data/function/proc/r_input(href, href_list, mob/user as mob)
	return

/datum/data/function/proc/display()
	return
