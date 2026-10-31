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
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return session.phase == "characters"): return fail("Character list timeout")
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			break
	if not await until(func(): return session.phase == "world"): return fail("Character entry failed")
	var done := await command("[PreviewTrammel","UCTRAM1|",3600.0)
	if done.is_empty(): return fail("PreviewTrammel did not answer (is the extension installed and the server restarted?)")
	print("TRAMMEL: decorations %s, doors %s, signs %s, teleporters %s, moongates %s; spawn files %s, spawners created %s, kept %s, failed %s, stand-ins retired %s" % [done[1],done[2],done[3],done[4],done[5],done[6],done[7],done[8],done[9],done[10]])
	error = ""
	var saved := await command("[PreviewSave","UCSAVE1|")
	if saved.is_empty(): return fail("Save did not answer")
	await create_timer(5.0).timeout
	session.close()
	print("TRAMMEL LIVE PASS")
	quit(0)
