/// The name of the controller
/datum/controller
	var/name
	/// The next time we should do work updating statLine
	var/statNext = 0

/datum/controller/Destroy()
	SHOULD_CALL_PARENT(FALSE)
	return QDEL_HINT_LETMELIVE

/datum/controller/proc/Initialize()
	return

/datum/controller/proc/Shutdown()
	return

/datum/controller/proc/Recover()
	return

/// when we enter dmm_suite.load_map
/datum/controller/proc/StartLoadingMap()
	return

/// when we exit dmm_suite.load_map
/datum/controller/proc/StopLoadingMap()
	return

/datum/controller/proc/stat_entry(msg)
	SHOULD_CALL_PARENT(TRUE)
	SHOULD_NOT_SLEEP(TRUE)
	return msg
