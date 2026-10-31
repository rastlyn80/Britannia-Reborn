extends SceneTree
# Live developer travel: the server's Trammel location list arrives, and a
# move to Covetous level 1 puts the character there (PreviewTravel).
var session: Node
var error := ""
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, seconds := 30.0) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec()-start > seconds*1000: return false
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
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return session.phase == "characters"): return fail("Character list timeout")
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			break
	if not await until(func(): return session.phase == "world"): return fail("Character entry failed")
	var home := Vector3i(int(session.player.x),int(session.player.y),int(session.player.z))
	session.request_travel_locations()
	if not await until(func(): return not session.travel_loading): return fail("No location list")
	var groups := {}
	for entry in session.travel_locations: groups[entry.category] = int(groups.get(entry.category,0))+1
	print("TRAVEL LOCATIONS: %d %s" % [session.travel_locations.size(),groups])
	var target: Dictionary = {}
	for entry in session.travel_locations:
		if entry.group == "Covetous" and entry.place == "Level 1": target = entry
	if target.is_empty(): return fail("Covetous level 1 not listed")
	session.travel_to(target.x,target.y,target.z)
	if not await until(func(): return absi(int(session.player.x)-int(target.x)) <= 2 and absi(int(session.player.y)-int(target.y)) <= 2,20.0): return fail("Did not arrive (at %d,%d)" % [session.player.x,session.player.y])
	print("TRAVEL ARRIVED: Covetous level 1 at %d,%d,%d" % [session.player.x,session.player.y,session.player.z])
	session.travel_to(home.x,home.y,home.z)
	await create_timer(2.0).timeout
	session.close()
	print("TRAVEL LIVE PASS")
	quit(0)
