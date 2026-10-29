extends SceneTree
# Live protocol census (scripts/test-protocol-census.ps1): enters the local
# shard, plays a short scripted session (walk, backpack, status, war mode,
# context menus, a command) and lists every packet the server sent. It fails
# when a packet (or 0xBF subcommand) reached no handler and is not on the
# deliberately-ignored list. docs/PROTOCOL_BLUEPRINT.md tracks the result.
# --long (Phase 6): minutes of mixed play on top (bank and vendor speech,
# skills, spellbook, help, a decoded treasure map, idling with pings), then a
# proper logout (0xD1 acknowledged) and a reconnect into the same character.
# Deliberately ignored, with the reason.
const IGNORED := {}
const IGNORED_EXTENDED := {}
var session: Node

func _initialize() -> void: call_deferred("run")

func until(condition: Callable, seconds := 30.0) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true

func run() -> void:
	session = preload("res://Network/GameSession.gd").new()
	root.add_child(session)
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return session.phase == "characters"):
		push_error("Character list timeout")
		return quit(1)
	for character in session.characters:
		if not character.name.is_empty():
			session.select_character(character.slot,character.name)
			break
	if not await until(func(): return session.phase == "world"):
		push_error("World entry timeout")
		return quit(1)
	await create_timer(4.0).timeout
	session.open_backpack()
	session.request_character()
	for direction in [2,2,2,2,4,4,4,4,6,6,6,6,0,0,0,0]:
		session.walk(direction)
		await create_timer(0.5).timeout
	session.send_command("[PreviewWhere")
	session.set_war_mode(true)
	await create_timer(2.0).timeout
	session.set_war_mode(false)
	for serial in session.entities.keys().slice(0,6):
		session.request_context(serial)
		await create_timer(0.6).timeout
	# Requests the server must answer: paperdoll, profile, a name, a spell
	# (target cursor, then cancelled) and the tip window.
	var serial := int(session.player.serial)
	var answers := {0x88:"paperdoll",0xb8:"profile",0x98:"name",0xa6:"tip"}
	var before := {}
	for id in answers: before[id] = int(session.packet_counts.get(id,0))
	# A spell is answered by a target cursor or, without book or reagents, a message.
	var spell_answers := [0x6c,0xc1,0xcc,0x1c,0xae]
	var spell_before := 0
	for id in spell_answers: spell_before += int(session.packet_counts.get(id,0))
	session.send(preload("res://Network/Packets/Player.gd").open_paperdoll(serial))
	session.send(preload("res://Network/Packets/Player.gd").profile_request(serial))
	# The nearest other mobile: the server only names what is in range.
	var nearest := 0
	var nearest_distance := 999
	for other in session.entities:
		if int(other) == serial: continue
		var mobile: Dictionary = session.entities[other]
		var distance := maxi(absi(int(mobile.get("x",0))-int(session.player.x)),absi(int(mobile.get("y",0))-int(session.player.y)))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = int(other)
	if nearest: session.send(preload("res://Network/Packets/Mobiles.gd").name_request(nearest))
	session.send(preload("res://Network/Packets/Requests.gd").cast_spell(1))
	session.send(preload("res://Network/Packets/Dialogs.gd").tip_request(0))
	await create_timer(4.0).timeout
	if not session.target_request.is_empty(): session.target_item()
	await create_timer(16.0).timeout
	var long_problems := 0
	if "--long" in OS.get_cmdline_user_args(): long_problems = await long_session()
	var unanswered := long_problems
	var spell_after := 0
	for id in spell_answers: spell_after += int(session.packet_counts.get(id,0))
	print("REQUEST spell (0xBF 0x1C) -> %d answers (cursor or message)" % (spell_after-spell_before))
	if spell_after == spell_before: unanswered += 1
	for id in answers:
		var got := int(session.packet_counts.get(id,0))-int(before[id])
		print("REQUEST %s -> 0x%02X x%d" % [answers[id],id,got])
		if got == 0 and id != 0xa6: unanswered += 1
	var ids: Array = session.packet_counts.keys()
	ids.sort()
	for id in ids: print("RECEIVED 0x%02X x%d%s" % [id,session.packet_counts[id]," (unhandled)" if session.unhandled.has(id) else ""])
	var tooltips: RefCounted = session.module("tooltips")
	print("TOOLTIPS: %d revisions announced, %d lists received" % [tooltips.revisions.size(),tooltips.lists.size()])
	var problems := 0
	for id in session.unhandled:
		if not IGNORED.has(id):
			problems += 1
			print("UNHANDLED 0x%02X x%d" % [id,session.unhandled[id]])
	for sub in session.unhandled_extended:
		if not IGNORED_EXTENDED.has(sub):
			problems += 1
			print("UNHANDLED 0xBF 0x%02X x%d" % [sub,session.unhandled_extended[sub]])
	session.close()
	print("PROTOCOL CENSUS: %d packet types received, %d unhandled, %d requests unanswered" % [ids.size(),problems,unanswered])
	quit(1 if problems or unanswered else 0)

func speak(text: String) -> void:
	session.send(preload("res://Network/ActionProtocol.gd").speech(text))

func count(ids: Array) -> int:
	var total := 0
	for id in ids: total += int(session.packet_counts.get(id,0))
	return total

# Mixed play; returns how many expected answers never came.
func long_session() -> int:
	var missing := 0
	session.send_command("[PreviewHome")
	await create_timer(4.0).timeout
	var before := count([0x24,0x3c])
	speak("bank")
	await create_timer(2.0).timeout
	# Informational: only a banker within earshot answers.
	print("LONG bank -> %s" % ("opened" if count([0x24,0x3c]) > before else "no banker in range"))
	before = count([0x74,0x24,0x1c,0xae,0xc1])
	speak("vendor buy")
	await create_timer(2.5).timeout
	print("LONG vendor buy -> %d answers" % (count([0x74,0x24,0x1c,0xae,0xc1])-before))
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for step in 40:
		session.walk(rng.randi_range(0,7),step%5 == 0)
		await create_timer(0.45).timeout
	session.use_skill(21)
	await create_timer(1.5).timeout
	session.send(preload("res://Network/ActionProtocol.gd").open_spellbook(1))
	session.request_help()
	await create_timer(2.0).timeout
	session.send_command("[PreviewKit map")
	await create_timer(2.0).timeout
	session.open_backpack()
	await create_timer(2.0).timeout
	var chart := 0
	for item in session.contents_of(int(session.backpack)):
		if int(item.id) in [0x14eb,0x14ec]: chart = int(item.serial)
	var maps: RefCounted = session.module("world")
	if chart:
		for attempt in 30:
			session.use_item(chart)
			if await until(func(): return not maps.maps.is_empty(),2.5): break
	print("LONG treasure map -> %s" % ("read" if not maps.maps.is_empty() else "not read"))
	if maps.maps.is_empty(): missing += 1
	# Idle a while: pings keep the connection, and the server's own timers run.
	var pings := int(session.packet_counts.get(0x73,0))
	await create_timer(45.0).timeout
	print("LONG idle 45 s -> %d ping replies" % (int(session.packet_counts.get(0x73,0))-pings))
	# A proper logout: the server acknowledges 0xD1 before the client closes.
	var acknowledged := [false]
	session.module("player").logged_out.connect(func(): acknowledged[0] = true)
	session.send(preload("res://Network/Packets/Player.gd").logout_request())
	await until(func(): return acknowledged[0],5)
	print("LONG logout -> %s" % ("acknowledged" if acknowledged[0] else "no acknowledgement"))
	if not acknowledged[0]: missing += 1
	# Keep this session's counts for the report; reconnect on a fresh session.
	var counts: Dictionary = session.packet_counts.duplicate()
	var unhandled: Dictionary = session.unhandled.duplicate()
	var unhandled_extended: Dictionary = session.unhandled_extended.duplicate()
	var name := ""
	for character in session.characters:
		if not character.name.is_empty():
			name = str(character.name)
			break
	session.close()
	await create_timer(2.0).timeout
	session.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	var back := await until(func(): return session.phase == "characters",30)
	if back:
		for character in session.characters:
			if str(character.name) == name:
				session.select_character(character.slot,character.name)
				break
		back = await until(func(): return session.phase == "world",30)
	print("LONG reconnect as %s -> %s" % [name,"in the world" if back else "failed"])
	if not back: missing += 1
	await create_timer(3.0).timeout
	for id in counts: session.packet_counts[id] = int(session.packet_counts.get(id,0))+int(counts[id])
	for id in unhandled: session.unhandled[id] = int(session.unhandled.get(id,0))+int(unhandled[id])
	for sub in unhandled_extended: session.unhandled_extended[sub] = int(session.unhandled_extended.get(sub,0))+int(unhandled_extended[sub])
	return missing
