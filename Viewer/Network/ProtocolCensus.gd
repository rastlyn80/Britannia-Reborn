extends SceneTree
# Live protocol census (scripts/test-protocol-census.ps1): enters the local
# shard, plays a short scripted session (walk, backpack, status, war mode,
# context menus, a command) and lists every packet the server sent. It fails
# when a packet (or 0xBF subcommand) reached no handler and is not on the
# deliberately-ignored list. docs/PROTOCOL_BLUEPRINT.md tracks the result.
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
	for other in session.entities.keys():
		if other != serial:
			session.send(preload("res://Network/Packets/Mobiles.gd").name_request(other))
			break
	session.send(preload("res://Network/Packets/Requests.gd").cast_spell(1))
	session.send(preload("res://Network/Packets/Dialogs.gd").tip_request(0))
	await create_timer(4.0).timeout
	if not session.target_request.is_empty(): session.target_item()
	await create_timer(16.0).timeout
	var unanswered := 0
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
