extends SceneTree
# Live whole-Trammel population (PreviewTrammel on the local server): the
# native decorations, doors, signs, teleporters, public moongates and
# spawners for all of Trammel, then a world save. Existing items are kept,
# so it can be run again; it blocks the server for several minutes.
var session: Node
var error := ""
var replies := []
func _initialize() -> void: call_deferred("run")
# patient: the server is busy for minutes (no movement replies), so session
# warnings such as a movement timeout do not end the wait.
func until(condition: Callable, seconds := 30.0, patient := false) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if (not patient and not error.is_empty()) or Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true
func fail(reason: String) -> void:
	push_error(reason+" "+error)
	if session: session.close()
	quit(1)
func reply(prefix: String) -> PackedStringArray:
	for text in replies:
		if str(text).begins_with(prefix): return str(text).split("|")
	return PackedStringArray()
func command(text: String, prefix: String, seconds := 120.0) -> PackedStringArray:
	replies.clear()
	session.send_command(text)
	if not await until(func(): return not reply(prefix).is_empty(),seconds,seconds > 120.0): return PackedStringArray()
	return reply(prefix)
func run() -> void:
	session = preload("res://Network/GameSession.gd").new()
	root.add_child(session)
	session.failed.connect(func(reason: String): error = reason)
	session.message_received.connect(func(text: String):
		replies.append(text)
		if text.begins_with("UC") or "Trammel" in text or text.begins_with("Skipped"): print("SERVER: ",text))
	# UO_DEV_PORT: another local server (the friends' package is prepared on 2594).
	var port := int(OS.get_environment("UO_DEV_PORT")) if OS.get_environment("UO_DEV_PORT").is_valid_int() else 2593
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"),port)
	if not await until(func(): return session.phase == "characters"): return fail("Character list timeout")
	var chosen := false
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			chosen = true
			break
	# A fresh account (the friends' package): its first character, in Britain.
	if not chosen:
		var name := OS.get_environment("UO_DEV_CHARACTER") if OS.get_environment("UO_DEV_CHARACTER") != "" else "Tester"
		for city in session.cities:
			if city.name == "Britain":
				session.create_character(name,0,city.index)
				break
	if not await until(func(): return session.phase == "world"): return fail("Character entry failed")
	replies.clear()
	session.send_command("[PreviewTrammel")
	# The server is busy for minutes; the connection may drop meanwhile. Either
	# its answer arrives, or the session ends and we sign in again, which only
	# succeeds once the population (and the server) is done.
	await until(func(): return not reply("UCTRAM1|").is_empty() or session.phase != "world",3600.0,true)
	var done := reply("UCTRAM1|")
	if not done.is_empty():
		print("TRAMMEL: decorations %s, doors %s, signs %s, teleporters %s, moongates %s; spawn files %s, spawners created %s, kept %s, failed %s, stand-ins retired %s" % [done[1],done[2],done[3],done[4],done[5],done[6],done[7],done[8],done[9],done[10]])
	else:
		print("TRAMMEL: the connection dropped while the server populated; signing in again")
		error = ""
		var signed_in := false
		for attempt in 120:
			session.close()
			error = ""
			session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"),port)
			if await until(func(): return session.phase == "characters" or not error.is_empty(),60.0,true) and session.phase == "characters":
				signed_in = true
				break
			await create_timer(10.0).timeout
		if not signed_in: return fail("Could not sign in again after the population")
		for character in session.characters:
			if not character.name.is_empty():
				session.select_character(character.slot,character.name)
				break
		if not await until(func(): return session.phase == "world",120.0,true): return fail("Character entry failed after the population")
	error = ""
	var saved := await command("[PreviewSave","UCSAVE1|")
	if saved.is_empty(): return fail("Save did not answer")
	await create_timer(5.0).timeout
	session.close()
	print("TRAMMEL LIVE PASS")
	quit(0)
