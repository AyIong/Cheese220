// Construction frames

/singleton/machine_construction/frame/unwrenched/state_is_valid(obj/machinery/machine)
	return !machine.anchored

/singleton/machine_construction/frame/unwrenched/validate_state(obj/machinery/constructable_frame/machine)
	. = ..()
	if(!.)
		if(machine.circuit)
			try_change_state(machine, /singleton/machine_construction/frame/awaiting_parts)
		else
			try_change_state(machine, /singleton/machine_construction/frame/wrenched)

/singleton/machine_construction/frame/unwrenched/attackby(obj/item/I, mob/user, obj/machinery/machine)
	if(I.tool_behaviour == TOOL_WRENCH)
		if(!I.use_as_tool(machine, user, 2 SECONDS, volume = 50, skill_path = SKILL_CONSTRUCTION, do_flags = DO_REPAIR_CONSTRUCT))
			return
		TRANSFER_STATE(/singleton/machine_construction/frame/wrenched)
		to_chat(user, SPAN_NOTICE("You wrench [machine] into place."))
		machine.anchored = TRUE
	if(I.tool_behaviour == TOOL_WELDER)
		if(!I.tool_start_check(user, 3))
			return TRUE
		if(!I.use_as_tool(machine, user, 2 SECONDS, 3, 50, SKILL_CONSTRUCTION, do_flags = DO_REPAIR_CONSTRUCT))
			return TRUE
		TRANSFER_STATE(/singleton/machine_construction/default/deconstructed)
		to_chat(user, SPAN_NOTICE("You deconstruct [machine]."))
		machine.dismantle()


/singleton/machine_construction/frame/unwrenched/mechanics_info()
	. = list()
	. += "Use a welder to break apart the frame."
	. += "Use a wrench to secure the frame in place."

/singleton/machine_construction/frame/wrenched/state_is_valid(obj/machinery/constructable_frame/machine)
	return machine.anchored && !machine.circuit

/singleton/machine_construction/frame/wrenched/validate_state(obj/machinery/constructable_frame/machine)
	. = ..()
	if(!.)
		if(machine.circuit)
			try_change_state(machine, /singleton/machine_construction/frame/awaiting_parts)
		else
			try_change_state(machine, /singleton/machine_construction/frame/unwrenched)

/singleton/machine_construction/frame/wrenched/attackby(obj/item/I, mob/user, obj/machinery/machine)
	if(I.tool_behaviour == TOOL_WRENCH)
		if(!I.use_as_tool(machine, user, 2 SECONDS, volume = 50, skill_path = SKILL_CONSTRUCTION, do_flags = DO_REPAIR_CONSTRUCT))
			return
		TRANSFER_STATE(/singleton/machine_construction/frame/unwrenched)
		to_chat(user, SPAN_NOTICE("You unfasten [machine]."))
		machine.anchored = FALSE
		return
	if(isCoil(I))
		var/obj/item/stack/cable_coil/C = I
		if(C.get_amount() < 5)
			to_chat(user, SPAN_WARNING("You need five lengths of cable to add them to [machine]."))
			return TRUE
		playsound(machine.loc, 'sound/items/Deconstruct.ogg', 50, 1)
		to_chat(user, SPAN_NOTICE("You start to add cables to the frame."))
		if(do_after(user, 2 SECONDS, machine, DO_REPAIR_CONSTRUCT) && C.use(5))
			TRANSFER_STATE(/singleton/machine_construction/frame/awaiting_circuit)
			to_chat(user, SPAN_NOTICE("You add cables to the frame."))
		return TRUE


/singleton/machine_construction/frame/wrenched/mechanics_info()
	. = list()
	. += "Use a wrench to unfasten the frame from the floor and prepare it for deconstruction."
	. += "Add cables to make it ready for a circuit."

/singleton/machine_construction/frame/awaiting_circuit/state_is_valid(obj/machinery/constructable_frame/machine)
	return machine.anchored && !machine.circuit

/singleton/machine_construction/frame/awaiting_circuit/validate_state(obj/machinery/constructable_frame/machine)
	. = ..()
	if(!.)
		if(machine.circuit)
			try_change_state(machine, /singleton/machine_construction/frame/awaiting_parts)
		else
			try_change_state(machine, /singleton/machine_construction/frame/unwrenched)

/singleton/machine_construction/frame/awaiting_circuit/attackby(obj/item/I, mob/user, obj/machinery/constructable_frame/machine)
	if(istype(I, /obj/item/stock_parts/circuitboard))
		var/obj/item/stock_parts/circuitboard/circuit = I
		if(circuit.board_type == machine.expected_machine_type)
			if(!user.canUnEquip(I))
				return FALSE
			TRANSFER_STATE(/singleton/machine_construction/frame/awaiting_parts)
			user.unEquip(I, machine)
			playsound(machine.loc, 'sound/items/Deconstruct.ogg', 50, 1)
			to_chat(user, SPAN_NOTICE("You add the circuit board to [machine]."))
			machine.circuit = I
			return
		else
			to_chat(user, SPAN_WARNING("This frame does not accept circuit boards of this type!"))
			return TRUE
	if(I.tool_behaviour == TOOL_WIRECUTTER)
		if(!I.use_as_tool(machine, user, volume = 50, do_flags = DO_REPAIR_CONSTRUCT))
			return
		TRANSFER_STATE(/singleton/machine_construction/frame/wrenched)
		to_chat(user, SPAN_NOTICE("You remove the cables."))
		new /obj/item/stack/cable_coil(machine.loc, 5)

/singleton/machine_construction/frame/awaiting_circuit/mechanics_info()
	. = list()
	. += "Insert a circuit board to progress with constructing the machine."
	. += "Use a wirecutter to remove the cables."

/singleton/machine_construction/frame/awaiting_parts/state_is_valid(obj/machinery/constructable_frame/machine)
	return machine.anchored && machine.circuit

/singleton/machine_construction/frame/awaiting_parts/validate_state(obj/machinery/constructable_frame/machine)
	. = ..()
	if(!.)
		if(machine.anchored)
			try_change_state(machine, /singleton/machine_construction/frame/wrenched)
		else
			try_change_state(machine, /singleton/machine_construction/frame/unwrenched)

/singleton/machine_construction/frame/awaiting_parts/attackby(obj/item/I, mob/user, obj/machinery/constructable_frame/machine)
	if(I.tool_behaviour == TOOL_CROWBAR)
		if(!I.use_as_tool(machine, user, volume = 50, do_flags = DO_REPAIR_CONSTRUCT))
			return
		TRANSFER_STATE(/singleton/machine_construction/frame/awaiting_circuit)
		machine.circuit.dropInto(machine.loc)
		machine.circuit = null
		to_chat(user, SPAN_NOTICE("You remove the circuit board."))
		return
	if(I.tool_behaviour == TOOL_SCREWDRIVER)
		if(!I.use_as_tool(machine, user, volume = 50, do_flags = DO_REPAIR_CONSTRUCT))
			return
		var/obj/machinery/new_machine = new machine.circuit.build_path(machine.loc, machine.dir, FALSE)
		machine.circuit.construct(new_machine)
		new_machine.install_component(machine.circuit, refresh_parts = FALSE)
		new_machine.apply_component_presets()
		new_machine.RefreshParts()
		if(new_machine.construct_state)
			new_machine.construct_state.post_construct(new_machine)
		else
			crash_with("Machine of type [new_machine.type] was built from a circuit and frame, but had no construct state set.")
		qdel(machine)
		return TRUE

/singleton/machine_construction/frame/awaiting_parts/mechanics_info()
	. = list()
	. += "Use a crowbar to remove the circuitboard and any parts installed."
	. += "Use a screwdriver to build the machine."
