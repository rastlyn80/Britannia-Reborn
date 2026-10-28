extends SceneTree
# Live bounded spawner population (PreviewSpawn on the local server): the
# upstream Trammel spawners inside the prepared Britain bounds are built, a
# second run must create none, and the audit counts what now lives there.
var session: Node
var error := ""
var replies := []
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, seconds := 30.0) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if not error.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
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
func command(text: String, prefix: String) -> PackedStringArray:
	replies.clear()
	session.send_command(text)
	if not await until(func(): return not reply(prefix).is_empty(),120.0): return PackedStringArray()
	return reply(prefix)
func run() -> void:
	session = preload("res://Network/GameSession.gd").new()
	root.add_child(session)
	session.failed.connect(func(reason: String): error = reason)
	session.message_received.connect(func(text: String):
		replies.append(text)
		if text.begins_with("UC") or text.begins_with("Skipped"): print("SERVER: ",text))
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return session.phase == "characters"): return fail("Character list timeout")
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			break
	if not await until(func(): return session.phase == "world"): return fail("Character entry failed")
	var first := await command("[PreviewSpawn","UCSPAWN1|")
	if first.is_empty(): return fail("PreviewSpawn did not answer (is the extension installed and the server restarted?)")
	print("SPAWN RUN 1: files %s, created %s, kept %s, failed %s, stand-in vendors retired %s" % [first[1],first[2],first[3],first[4],first[5]])
	var second := await command("[PreviewSpawn","UCSPAWN1|")
	if second.is_empty() or int(second[2]) != 0: return fail("A repeated run created spawners: %s" % str(second))
	print("SPAWN RUN 2: created 0, kept %s (idempotent)" % second[3])
	await create_timer(3.0).timeout
	var audit := await command("[PreviewSpawnAudit","UCSPAWNAUDIT1|")
	if audit.is_empty(): return fail("Audit did not answer")
	print("SPAWN AUDIT: %s spawners, %s creatures and NPCs, %s vendors in the region" % [audit[1],audit[2],audit[3]])
	session.send_command("[PreviewHome")
	await create_timer(1.0).timeout
	session.close()
	print("SPAWN LIVE PASS")
	quit(0)
