extends "res://Network/CreatureLive.gd"

const INPUT := "res://../work/creatures/live-candidates.json"
const INDEX := "res://local-art/creatures/accepted-index.json"
const CORPSES := preload("res://Presentation/CorpseModels.gd")
const SPECTRAL_ARMOUR := 637
const RESTLESS_SOUL := 970
const SPECTRAL_ITEMS := [0x13BB, 0x1414, 0x1B73]

func _initialize() -> void:
	family = "khaldun_doom"
	prepared = true
	create_timer(150.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	var candidates: Array = JSON.parse_string(FileAccess.get_file_as_string(INPUT))
	accepted_pin = FileAccess.get_sha256(INDEX)
	candidate_pin = FileAccess.get_sha256(INPUT)
	Registry.load_index()
	if not check(candidates.size() == 2, "Two exact private candidates"): return
	for candidate: Dictionary in candidates:
		var row: Dictionary = candidate.presentation
		var body := int(candidate.body)
		if not check(body in [SPECTRAL_ARMOUR, RESTLESS_SOUL] and row.status == "prepared"
				and row.family == family and int(row.bodies[0].body) == body, "Prepared source package matches its body"): return
		for treatment: String in row.assets:
			if not check(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment],
					"Private scene matches its pinned input"): return
		Registry.entries[body] = row

	for sex in 2:
		var session := Game.new()
		root.add_child(session)
		sessions.append(session)
		session.failed.connect(func(reason: String): errors.append(reason))
		session.message_received.connect(func(message: String):
			if message.begins_with("UCCREATURE|"): replies[sex].append(message))
		session.connect_account(accounts[sex].username, accounts[sex].password, 2594)
		if not check(await until(func(): return session.phase == "characters"), "Disposable ModernUO login"): return
		var free_slots := session.characters.filter(func(item: Dictionary): return item.name.is_empty())
		var britain := session.cities.filter(func(item: Dictionary): return item.name == "Britain")
		if not check(not free_slots.is_empty() and britain.size() == 1, "New character slot and Britain start"): return
		session.create_character("Khaldun Test Woman" if sex else "Khaldun Test Man",
			free_slots[0].slot, britain[0].index, sex == 1)
		if not check(await until(func(): return session.phase == "world"), "Native world entry"): return

	for sex in 2:
		for candidate: Dictionary in candidates:
			if not await check_creature(sex, candidate):
				return
	for session in sessions:
		session.close()
	if not check(FileAccess.get_sha256(INDEX) == accepted_pin and FileAccess.get_sha256(INPUT) == candidate_pin,
			"Trial preserves its input and active registry"): return
	var path := "res://../outputs/creatures/%s" % family
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
	var output := FileAccess.open(path + "/live.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"records": records, "checks": checks, "failures": 0,
		"prepared_trial": true, "candidate_sha256": candidate_pin, "accepted_sha256": accepted_pin,
		"test_sha256": FileAccess.get_sha256(get_script().resource_path),
		"fixture_sha256": FileAccess.get_sha256("res://../Server/HorseIntegrationFixtures/CreatureFixtures.cs")}, "\t"))
	output.close()
	print("KHALDUN AND DOOM NATIVE: ", checks, " checks / 0 failures")
	quit()

func check_creature(sex: int, candidate: Dictionary) -> bool:
	var body := int(candidate.body)
	var native_class := str(candidate.native_class)
	var response := await reply(sex, "prepare %d %s" % [body, native_class], "UCCREATURE|prepared|")
	if response.is_empty(): return false
	var fields := response.split("|")
	var serial := int(fields[2])
	if not check(int(fields[3]) == body and fields[4] == native_class, "Native constructor retains body and class"): return false
	var hue := int(candidate.constructor_hues[native_class])
	if not check(await until(func(): return sessions.all(func(client): return int(client.entities.get(serial, {}).get("hue", -1)) == hue)),
			"Both clients receive the constructor hue"): return false
	if body == SPECTRAL_ARMOUR:
		if not check(await until(func(): return sessions.all(func(client): return spectral_items(client, serial))),
				"Both clients receive the buckler, coif and gloves with native equipment hues"): return false
	var avatars: Array[Node3D] = []
	for session in sessions:
		var avatar := preload("res://Presentation/HumanAvatar.gd").new()
		avatar.initial_body = body
		root.add_child(avatar)
		avatar.set_physics_process(false)
		avatar.apply_server_appearance(session.entities[serial], session.mobile_equipment.get(serial, {}).values())
		avatars.append(avatar)
		if not check(avatar.human_visual == null and avatar.horse_visual.native_hue == hue,
				"Actual creature renderer consumes the replicated identity"): return false
	var observed: Array = [[], []]
	var listeners: Array[Callable] = []
	for i in 2:
		var collect := func(packet: Dictionary, index: int):
			if int(packet.serial) == serial: observed[index].append(packet)
		listeners.append(collect.bind(i))
		sessions[i].mobile_action_received.connect(listeners[i])
	if (await reply(sex, "hurt", "UCCREATURE|hurt|")).is_empty(): return false
	var attack_group := 9 if body == SPECTRAL_ARMOUR else 10
	if (await reply(sex, "action %d" % attack_group, "UCCREATURE|action|")).is_empty(): return false
	if not check(await until(func(): return observed.all(func(actions: Array): return not actions.is_empty())),
			"Explicit native attack packet reaches both clients"): return false
	for i in 2:
		sessions[i].mobile_action_received.disconnect(listeners[i])
		if not check(observed[i].size() == 1 and int(observed[i][0].action) == attack_group,
				"Equipment and Empty bodies send no native weapon hurt animation"): return false
		if not check(avatars[i].receive_native_action(observed[i][0]) and avatars[i].horse_visual.current_clip == "Attack",
				"Explicit packet plays the prepared attack on both clients"): return false
	for running in [false, true]:
		var origin := Vector2i(sessions[sex].entities[serial].x, sessions[sex].entities[serial].y)
		response = await reply(sex, "step %d" % int(running), "UCCREATURE|step|")
		if response.is_empty(): return false
		fields = response.split("|")
		var target := Vector2i(int(fields[2]), int(fields[3]))
		if not check(target != origin and await until(func(): return sessions.all(func(client):
				var entity: Dictionary = client.entities[serial]
				return Vector2i(entity.x, entity.y) == target and bool(entity.running) == running)),
				"Native movement and its run flag reach both clients"): return false
	response = await reply(sex, "kill", "UCCREATURE|corpse|")
	if response.is_empty(): return false
	var corpse := int(response.split("|")[2])
	if body == SPECTRAL_ARMOUR:
		if not check(corpse == 0 and response.ends_with("|suppressed"), "Spectral Armour leaves no persistent corpse"): return false
	else:
		if not check(corpse != 0 and await until(func(): return sessions.all(func(client):
				return int(client.world_items.get(corpse, {}).get("amount", 0)) == body)),
				"Restless Soul corpse uses its actual body on both clients"): return false
	var snapshot := CORPSES.build(body, hue)
	if not check(snapshot != null and snapshot.get_meta("static_cadaver")
			and int(snapshot.get_meta("corpse_body")) == body and int(snapshot.get_meta("native_hue")) == hue
			and snapshot.find_children("*", "Skeleton3D", true, false).is_empty(),
			"The body has a frozen, correctly hued corpse graphic"): return false
	snapshot.free()
	for avatar in avatars:
		avatar.free()
	records.append({"body": body, "native_class": native_class, "constructor_hue": hue,
		"female": sex == 1, "corpse_suppressed": corpse == 0, "explicit_attack": true})
	return not (await reply(sex, "cleanup", "UCCREATURE|cleaned")).is_empty()

func spectral_items(client: Node, serial: int) -> bool:
	var items: Array = client.mobile_equipment.get(serial, {}).values()
	var ids: Array = []
	for item: Dictionary in items:
		if int(item.get("id", 0)) in SPECTRAL_ITEMS and int(item.get("hue", 0)) == 0x835:
			ids.append(int(item.id))
	ids.sort()
	return ids == SPECTRAL_ITEMS
