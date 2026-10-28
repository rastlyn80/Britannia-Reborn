extends SceneTree
# Live quickbar checks against the local ModernUO server: real slots run
# through ActionRunner and the server's answers are observed. War/Peace
# round trip (the server echoes the mode), a skill that asks for a target
# answered on yourself by a self-aimed slot, a spell request the server
# processes (cast or refused with its reason), speech, a bow, Select Nearest
# and a missing-item slot that explains itself instead of sending anything.
var session: Node
var runner: Node
var error := ""
var messages := []
var feedback := []
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, seconds: float = 10.0) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if not error.is_empty() or Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true
func fail(reason: String) -> void:
	push_error(reason+" "+error)
	if session: session.close()
	quit(1)
func run() -> void:
	session = preload("res://Network/GameSession.gd").new()
	root.add_child(session)
	session.failed.connect(func(reason: String): error = reason)
	session.message_received.connect(func(text: String):
		messages.append(text)
		print("SERVER: ",text))
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return session.phase == "characters"): return fail("Character list timeout")
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			break
	if not await until(func(): return session.phase == "world"): return fail("Character entry failed")
	runner = preload("res://Network/ActionRunner.gd").new()
	root.add_child(runner)
	runner.configure(session)
	runner.feedback.connect(func(text: String):
		feedback.append(text)
		print("QUICKBAR: ",text))
	session.request_character()
	await until(func(): return session.player_status.has("mana"),5.0)
	session.open_backpack()
	await create_timer(1.5).timeout
	# War/Peace: the server answers with the new mode; toggle back.
	var war := func() -> bool: return (int(session.player.get("flags",0)) & 0x40) != 0
	var was: bool = war.call()
	await runner.run([{"action":"War/Peace"}])
	if not await until(func(): return war.call() != was,5.0): return fail("War/Peace slot was not confirmed by the server")
	await runner.run([{"action":"War/Peace"}])
	if not await until(func(): return war.call() == was,5.0): return fail("War/Peace did not return")
	print("LIVE QUICKBAR: War/Peace toggled and restored, confirmed by the server")
	# A self-aimed skill slot: Anatomy opens a cursor that the slot answers.
	var cursor := {"opened":false,"closed":false}
	session.target_changed.connect(func(active: bool):
		if active: cursor.opened = true
		else: cursor.closed = true)
	await runner.run([{"action":"Use Skill","option":"Anatomy"}],"self")
	if not await until(func(): return cursor.opened and cursor.closed and session.target_request.is_empty(),6.0): return fail("Self-aimed Anatomy slot did not answer the target cursor")
	print("LIVE QUICKBAR: Anatomy slot aimed at yourself answered the server's target cursor")
	await create_timer(1.0).timeout
	# A spell request: the server either casts or refuses with a reason.
	var before := messages.size()
	var opened_before: bool = cursor.opened
	cursor.opened = false
	var ready: Dictionary = runner.availability([{"action":"Cast Spell","option":"Night Sight"}])
	if ready.ok:
		await runner.run([{"action":"Cast Spell","option":"Night Sight"}],"self")
		if not await until(func(): return messages.size() > before or cursor.opened,8.0): return fail("The server did not respond to the spell request")
		print("LIVE QUICKBAR: Night Sight request processed by the server (%s)" % ("target cursor" if cursor.opened else str(messages.back())))
	else:
		await runner.run([{"action":"Cast Spell","option":"Night Sight"}],"self")
		if feedback.is_empty() or not "Cannot cast" in str(feedback.back()): return fail("A spell without reagents should explain itself")
		print("LIVE QUICKBAR: Night Sight held back on the client: %s" % ready.reason)
	cursor.opened = opened_before
	# Speech and a bow reach the server without errors.
	before = messages.size()
	await runner.run([{"action":"Say","text":"Quickbar check"},{"action":"Delay","text":"300"},{"action":"Bow"}])
	await create_timer(1.0).timeout
	if session.phase != "world": return fail("Speech or bow broke the connection")
	print("LIVE QUICKBAR: speech and bow sent; still in the world")
	# Select Nearest: any creature around becomes the last target.
	await runner.run([{"action":"Select Nearest","option":"Mobile"}])
	print("LIVE QUICKBAR: Select Nearest -> %s" % str(feedback.back() if not feedback.is_empty() else "nothing"))
	# An item slot with nothing to use explains itself and sends nothing.
	await runner.run([{"action":"Use Item Type","graphic":0x1F4C,"hue":-1,"name":"Recall scroll"}])
	if feedback.is_empty() or not "No recall scroll" in str(feedback.back()): return fail("Missing item slot should explain itself")
	print("LIVE QUICKBAR: missing item explained: %s" % feedback.back())
	session.close()
	print("LIVE QUICKBAR: all checks passed")
	quit(0)
