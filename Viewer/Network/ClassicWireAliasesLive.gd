extends "res://Network/CreatureLive.gd"

const FAMILY := "classic_wire_aliases"
const Dispatcher := preload("res://Presentation/CreatureWireActions.gd")
const ROUTES := "res://Presentation/creature-wire-routes.json"
const CANDIDATES := "res://../work/creatures/live-candidates.json"
const INDEX := "res://local-art/creatures/accepted-index.json"
const Avatar := preload("res://Presentation/HumanAvatar.gd")
var witnesses: Array[Dictionary] = []

func _initialize() -> void:
	family = FAMILY
	assert("--family=" + FAMILY in OS.get_cmdline_user_args())
	create_timer(175.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(CANDIDATES))
	var mapping: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROUTES))
	var index_hash := FileAccess.get_sha256(INDEX)
	var candidate_hash := FileAccess.get_sha256(CANDIDATES)
	var routes_hash := FileAccess.get_sha256(ROUTES)
	assert(mapping.size() == candidates.size())
	for sex: int in [0, 1]:
		var session := Game.new()
		root.add_child(session)
		sessions.append(session)
		session.failed.connect(func(reason: String): errors.append(reason))
		session.message_received.connect(func(message: String):
			if message.begins_with("UCCREATURE|"): replies[sex].append(message))
		session.connect_account(accounts[sex].username, accounts[sex].password, 2594)
		if not check(await until(func(): return session.phase == "characters"), "Disposable native login"): return
		var slot := -1
		var city := -1
		for character: Dictionary in session.characters:
			if character.name.is_empty():
				slot = int(character.slot)
				break
		for place: Dictionary in session.cities:
			if place.name == "Britain":
				city = int(place.index)
				break
		if not check(slot >= 0 and city >= 0, "Native character creation is available"): return
		session.create_character("Wire Woman" if sex else "Wire Man", slot, city, sex == 1)
		if not check(await until(func(): return session.phase == "world"), "Actual ModernUO world entry"): return
	for candidate: Dictionary in candidates:
		for sex: int in [0, 1]:
			if not await witness(sex, candidate, mapping): return
	for session: Node in sessions: session.close()
	if not check(index_hash == FileAccess.get_sha256(INDEX) and candidate_hash == FileAccess.get_sha256(CANDIDATES)
			and routes_hash == FileAccess.get_sha256(ROUTES), "Registry, native list and route table remained unchanged"): return
	var folder := "res://../outputs/creatures/" + FAMILY
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	var output := FileAccess.open(folder + "/live.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"test_sha256": FileAccess.get_sha256(get_script().resource_path),
		"dispatcher_sha256": FileAccess.get_sha256("res://Presentation/CreatureWireActions.gd"), "routes_sha256": routes_hash,
		"accepted_index_sha256": index_hash, "candidate_sha256": candidate_hash, "checks": checks, "failures": 0,
		"prepared_trial": true, "records": records, "classic_wire_witnesses": witnesses,
		"scope": "Two actual clients, native constructors and controlled server-emitted 0xE2 packets for both parity modes."}, "\t"))
	output.close()
	print("CLASSIC WIRE NATIVE: ", checks, " checks, ", witnesses.size(), " two-client packet observations")
	quit()

func witness(sex: int, candidate: Dictionary, mapping: Dictionary) -> bool:
	var body := int(candidate.body)
	var native_class: String = candidate.native_class
	var response := await reply(sex, "prepare %d %s" % [body, native_class], "UCCREATURE|prepared|")
	if response.is_empty(): return false
	var fields := response.split("|")
	var serial := int(fields[2])
	if not check(int(fields[3]) == body and fields[4] == native_class, "Native constructor keeps the declared class and body"): return false
	var actors: Array[Node3D] = []
	for client: int in [0, 1]:
		if not check(await until(func(): return sessions[client].entities.has(serial)), "Native creature reaches the client"): return false
		var actor := Avatar.new()
		actor.initial_body = body
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.apply_server_appearance(sessions[client].entities[serial], [])
		if not check(actor.horse_visual != null and actor.horse_visual.native_body == body, "Decoded body creates the actual avatar"): return false
		actors.append(actor)
	for kind: String in mapping[str(body)]:
		var rule: Array = mapping[str(body)][kind]
		for mode: int in [0, 1]:
			if not await observe(sex, serial, body, int(kind), mode, int(rule[mode]), actors): return false
	for actor: Node3D in actors: actor.queue_free()
	await process_frame
	records.append({"body": body, "native_class": native_class, "female": sex == 1})
	return not (await reply(sex, "cleanup", "UCCREATURE|cleaned")).is_empty()

func observe(sex: int, serial: int, body: int, kind: int, mode: int, classic_group: int, actors: Array[Node3D]) -> bool:
	var received := {}
	var collect := func(packet: Dictionary, client: int) -> void:
		if (int(packet.get("serial", -1)) == serial and packet.get("protocol") == "new"
				and int(packet.get("type", -1)) == kind and int(packet.get("subaction", -1)) == 0
				and int(packet.get("variation", -1)) == mode):
			received[client] = packet
	var listeners := [collect.bind(0), collect.bind(1)]
	for client: int in [0, 1]:
		sessions[client].mobile_action_received.connect(listeners[client])
	var marker := "UCCREATURE|classic-wire|%d|%d|%d" % [serial, kind, mode]
	replies[sex].clear()
	sessions[sex].send_command("[ClassicWireFixture %d %d %d" % [serial, kind, mode])
	var answered := await until(func():
		return (replies[sex].has(marker) and received.size() == 2
			or replies[sex].any(func(message: String): return message.begins_with("UCCREATURE|blocked|"))))
	for client: int in [0, 1]:
		sessions[client].mobile_action_received.disconnect(listeners[client])
	if not check(answered and replies[sex].has(marker) and received.size() == 2,
			"Both clients decode body %d type %d mode %d, received %s (%s)" % [body, kind, mode, received.keys(), replies[sex]]):
		return false
	var packets: Array[Dictionary] = []
	var expected := ""
	for client: int in [0, 1]:
		var actor := actors[client]
		var packet: Dictionary = received[client]
		var baseline: Dictionary = actor.horse_visual.entry.duplicate(true)
		if not check(actor.receive_native_action({"protocol": "classic", "action": classic_group}),
				"Classic group %d still plays on the retained renderer" % classic_group): return false
		var earlier: String = actor.horse_visual.current_clip
		if expected.is_empty():
			expected = earlier
		if not check(earlier == expected, "Both native avatars retain the same Classic replacement"): return false
		if not check(Dispatcher.dispatch(actor, packet) and actor.horse_visual.current_clip == expected
				and actor.horse_visual.get_meta("native_action") == packet and actor.horse_visual.entry == baseline,
				"The unmodified wire packet selects %s on the actual renderer" % expected): return false
		packets.append(packet)
	witnesses.append({"body": body, "serial": serial, "female": sex == 1, "type": kind,
		"mode": mode, "clip": expected, "packets": packets})
	return true
