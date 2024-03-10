GLOBAL_DATUM_INIT(is_http_protocol, /regex, regex("^https?://"))

/// Gets a dummy savefile for usage in icon generation.
/// Savefiles generated from this proc will be empty.
/proc/get_dummy_savefile(from_failure = FALSE)
	var/static/next_id = 0
	if(next_id++ > 9)
		next_id = 0
	var/savefile_path = "data/temp/dummy-save-[next_id].sav"
	try
		if(fexists(savefile_path))
			fdel(savefile_path)
		return new /savefile(savefile_path)
	catch(var/exception/error)
		// if we failed to create a dummy once, try again; maybe someone slept somewhere they shouldnt have
		if(from_failure) // this *is* the retry, something fucked up
			CRASH("get_dummy_savefile failed to create a dummy savefile: '[error]'")
		return get_dummy_savefile(from_failure = TRUE)

/**
 * Converts an icon to base64. Operates by putting the icon in the iconCache savefile,
 * exporting it as text, and then parsing the base64 from that.
 * (This relies on byond automatically storing icons in savefiles as base64)
 */
/proc/icon2base64(icon/icon)
	if (!isicon(icon))
		return FALSE
	var/savefile/dummySave = get_dummy_savefile()
	to_save(dummySave["dummy"], icon)
	var/iconData = dummySave.ExportText("dummy")
	var/list/partial = splittext(iconData, "{")
	return replacetext(copytext_char(partial[2], 3, -5), "\n", "") //if cleanup fails we want to still return the correct base64

/proc/register_icon_asset(icon/thing, icon_state, dir, frame = 1, moving = FALSE, realsize = FALSE, class = null)
	if (!thing)
		return null

	if (!isicon(thing))
		if (isfile(thing))
			var/name = "[generate_asset_name(thing)].png"
			SSassets.transport.register_asset(name, thing)
			return name

		if (ispath(thing))
			var/atom/A = thing
			if (isnull(dir))
				dir = SOUTH
			if (isnull(icon_state))
				icon_state = initial(A.icon_state)
			thing = initial(A.icon)

		else
			var/atom/A = thing
			if (isnull(dir))
				dir = A.dir
			if (isnull(icon_state))
				icon_state = A.icon_state
			thing = A.icon
			if (ishuman(thing)) // Shitty workaround for a BYOND issue.
				var/icon/temp = thing
				thing = icon()
				thing.Insert(temp, dir = SOUTH)
				dir = SOUTH
	else
		if (isnull(dir))
			dir = SOUTH
		if (isnull(icon_state))
			icon_state = ""

	thing = icon(thing, icon_state, dir, frame, moving)

	var/key = "[generate_asset_name(thing)].png"
	SSassets.transport.register_asset(key, thing)
	return key

/proc/icon2html(icon/thing, target, icon_state, dir, frame = 1, moving = FALSE, realsize = FALSE, class = null)
	if (!thing || !target)
		return

	var/list/targets
	if(target == world)
		targets = GLOB.clients

	else if (islist(target))
		targets = target

	else
		targets = list(target)

	if(!length(targets))
		return

	if (!isicon(thing))
		if (isfile(thing))
			var/name = "[generate_asset_name(thing)].png"
			SSassets.transport.register_asset(name, thing)
			for (var/thing2 in targets)
				SSassets.transport.send_assets(thing2, name)
			return "<img class='icon icon-misc [class]' src='[SSassets.transport.get_asset_url(name)]'>"

		if (ispath(thing))
			var/atom/A = thing
			if (isnull(dir))
				dir = SOUTH
			if (isnull(icon_state))
				icon_state = initial(A.icon_state)
			thing = initial(A.icon)

		else
			var/atom/A = thing
			if (isnull(dir))
				dir = A.dir
			if (isnull(icon_state))
				icon_state = A.icon_state
			thing = A.icon
			if (ishuman(thing)) // Shitty workaround for a BYOND issue.
				var/icon/temp = thing
				thing = icon()
				thing.Insert(temp, dir = SOUTH)
				dir = SOUTH
	else
		if (isnull(dir))
			dir = SOUTH
		if (isnull(icon_state))
			icon_state = ""

	thing = icon(thing, icon_state, dir, frame, moving)

	var/key = "[generate_asset_name(thing)].png"
	SSassets.transport.register_asset(key, thing)
	for (var/thing2 in targets)
		SSassets.transport.send_assets(thing2, key)

	if(realsize)
		return "<img class='icon icon-[icon_state] [class]' style='width:[thing.Width()]px;height:[thing.Height()]px;min-height:[thing.Height()]px' src='[SSassets.transport.get_asset_url(key)]'>"

	return "<img class='icon icon-[icon_state] [class]' src='[SSassets.transport.get_asset_url(key)]'>"

/proc/icon2base64html(thing)
	if (!thing)
		return

	var/static/list/bicon_cache = list()
	if (isicon(thing))
		var/icon/I = thing
		var/icon_base64 = icon2base64(I)

		if (I.Height() > world.icon_size || I.Width() > world.icon_size)
			var/icon_md5 = md5(icon_base64)
			icon_base64 = bicon_cache[icon_md5]
			if (!icon_base64) // Doesn't exist yet, make it.
				bicon_cache[icon_md5] = icon_base64 = icon2base64(I)

		return "<img class='icon icon-misc' src='data:image/png;base64,[icon_base64]'>"

	// Either an atom or somebody fucked up and is gonna get a runtime, which I'm fine with.
	var/atom/A = thing
	var/key = "[istype(A.icon, /icon) ? "\ref[A.icon]" : A.icon]:[A.icon_state]"


	if (!bicon_cache[key]) // Doesn't exist, make it.
		var/icon/I = icon(A.icon, A.icon_state, SOUTH, 1)
		if (ishuman(thing)) // Shitty workaround for a BYOND issue.
			var/icon/temp = I
			I = icon()
			I.Insert(temp, dir = SOUTH)

		bicon_cache[key] = icon2base64(I, key)

	return "<img class='icon icon-[A.icon_state]' src='data:image/png;base64,[bicon_cache[key]]'>"

// Costlier version of icon2html() that uses getFlatIcon() to account for overlays, underlays, etc. Use with extreme moderation, ESPECIALLY on mobs.
/proc/costly_icon2html(thing, target)
	if (!thing)
		return

	if (isicon(thing))
		return icon2html(thing, target)

	var/icon/I = getFlatIcon(thing)
	return icon2html(I, target)

/// Generates a filename for a given asset.
/// Like generate_asset_name(), except returns the rsc reference and the rsc file hash as well as the asset name (sans extension)
/// Used so that certain asset files dont have to be hashed twice
/proc/generate_and_hash_rsc_file(file, dmi_file_path)
	var/rsc_ref = fcopy_rsc(file)
	var/hash
	// If we have a valid dmi file path we can trust md5'ing the rsc file because we know it doesnt have the bug described in http://www.byond.com/forum/post/2611357
	if(dmi_file_path)
		hash = md5(rsc_ref)
	else // Otherwise, we need to do the expensive fcopy() workaround
		hash = md5asfile(rsc_ref)

	return list(rsc_ref, hash, "asset.[hash]")

///given a text string, returns whether it is a valid dmi icons folder path
/proc/is_valid_dmi_file(icon_path)
	if(!istext(icon_path) || !length(icon_path))
		return FALSE

	var/is_in_icon_folder = findtextEx(icon_path, "icons/")
	var/is_dmi_file = findtextEx(icon_path, ".dmi")

	if(is_in_icon_folder && is_dmi_file)
		return TRUE
	return FALSE

/// Given an icon object, dmi file path, or atom/image/mutable_appearance, attempts to find and return an associated dmi file path.
/// A weird quirk about dm is that /icon objects represent both compile-time or dynamic icons in the rsc,
/// But stringifying rsc references returns a dmi file path
/// ONLY if that icon represents a completely unchanged dmi file from when the game was compiled.
/// So if the given object is associated with an icon that was in the rsc when the game was compiled, this returns a path. otherwise it returns ""
/proc/get_icon_dmi_path(icon/icon)
	/// The dmi file path we attempt to return if the given object argument is associated with a stringifiable icon
	/// If successful, this looks like "icons/path/to/dmi_file.dmi"
	var/icon_path = ""

	if(isatom(icon) || istype(icon, /image) || istype(icon, /mutable_appearance))
		var/atom/atom_icon = icon
		icon = atom_icon.icon
		// Atom icons compiled in from 'icons/path/to/dmi_file.dmi' are weird and not really icon objects that you generate with icon().
		// If theyre unchanged dmi's then they're stringifiable to "icons/path/to/dmi_file.dmi"

	if(isicon(icon) && isfile(icon))
		// Icons compiled in from 'icons/path/to/dmi_file.dmi' at compile time are weird and arent really /icon objects,
		// But they pass both isicon() and isfile() checks. theyre the easiest case since stringifying them gives us the path we want
		var/icon_ref = "\ref[icon]"
		var/locate_icon_string = "[locate(icon_ref)]"

		icon_path = locate_icon_string

	else if(isicon(icon) && "[icon]" == "/icon")
		// Icon objects generated from icon() at runtime are icons, but they ARENT files themselves, they represent icon files.
		// If the files they represent are compile time dmi files in the rsc, then
		// The rsc reference returned by fcopy_rsc() will be stringifiable to "icons/path/to/dmi_file.dmi"
		var/rsc_ref = fcopy_rsc(icon)

		var/icon_ref = "\ref[rsc_ref]"

		var/icon_path_string = "[locate(icon_ref)]"

		icon_path = icon_path_string

	else if(istext(icon))
		var/rsc_ref = fcopy_rsc(icon)
		// If its the text path of an existing dmi file, the rsc reference returned by fcopy_rsc() will be stringifiable to a dmi path

		var/rsc_ref_ref = "\ref[rsc_ref]"
		var/rsc_ref_string = "[locate(rsc_ref_ref)]"

		icon_path = rsc_ref_string

	if(is_valid_dmi_file(icon_path))
		return icon_path

	return FALSE
