extends "res://Network/OstardLive.gd"
## Actual disposable native Desert Ostard, with explicit action fixture requests.

const Actions := preload("res://Presentation/DesertOstardActions.gd")
const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Transition := preload("res://Network/DesertOstardLiveTransition.gd")
const OUTPUT := "res://../outputs/creatures/desert_ostard_actions/"
const BAKE := "res://local-art/ostards/desert-actions-bake.json"
const INPUTS := ["Presentation/DesertOstardActions.gd", "Presentation/OstardMount.gd",
	"Presentation/CreatureFallPlayback.gd", "Presentation/CreatureDeathsWithOstard.gd",
	"Network/DesertOstardLive.gd", "Network/DesertOstardLiveTransition.gd",
	"../Server/HorseIntegrationFixtures/DesertOstardActionFixtures.cs", "../Server/HorseIntegrationFixtures/EquineFixtures.cs"]

func run() -> void:
	Actions.trial = "--candidate" in OS.get_cmdline_user_args()
	if not check(Actions.available(), "Exact Desert Ostard action library is installed"): return
	var bake_pin := FileAccess.get_sha256(BAKE)
	var input_pins := {}
	for path: String in INPUTS:
		input_pins[path] = FileAccess.get_sha256("res://" + path)
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for index in 2:
		if not await connect_rider(index, accounts[index]): return
	for index in 2:
		if not await exercise(index): return
	if not check(FileAccess.get_sha256(BAKE) == bake_pin, "Action libraries stayed fixed through the native trial"): return
	if not check(INPUTS.all(func(path: String) -> bool: return input_pins[path] == FileAccess.get_sha256("res://" + path)),
		"Native test and renderer sources stayed fixed through the trial"): return
	for session: Node in sessions:
		session.close()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var evidence := FileAccess.open(OUTPUT + ("candidate-live.json" if Actions.trial else "live.json"), FileAccess.WRITE)
	evidence.store_string(JSON.stringify({"checks":checks, "failures":0, "records":records, "bake_sha256":bake_pin,
		"candidate":Actions.trial, "inputs":input_pins, "scope":"Two disposable loopback clients. Native owned Desert Ostard, mounting, worn hue, movement, dismount, explicit classic packets, and ordinary and alternate animated corpse handoffs."}, "\t"))
	evidence.close()
	print("DESERT OSTARD LIVE: ", checks, " checks across two riders")
	quit()

func connect_rider(index: int, account: Dictionary) -> bool:
	var session := Game.new()
	root.add_child(session)
	sessions.append(session)
	replies.append([])
	session.failed.connect(func(reason: String): errors.append(reason))
	session.message_received.connect(func(message: String):
		if message.begins_with("UCEQUINE|"): replies[index].append(message))
	session.connect_account(account.username, account.password, 2594)
	if not check(await until(func(): return session.phase == "characters"), "Actual disposable native login"): return false
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
	if not check(slot >= 0 and city >= 0, "Disposable character slot and Britain start are available"): return false
	session.create_character("Ostard Woman" if index else "Ostard Man", slot, city, index == 1)
	return check(await until(func(): return session.phase == "world"), "Actual isolated ModernUO world entry")

func exercise(index: int) -> bool:
	var session: Node = sessions[index]
	var observer: Node = sessions[1 - index]
	var rider := int(session.player.serial)
	var response := await fixture_reply(session, index, "prepare 13", "UCEQUINE|prepared|")
	var fields := response.split("|")
	if not check(fields.size() == 6 and fields[3] == "210" and int(fields[4]) == 0x3ea3
		and fields[5] == "DesertOstard", "Pinned native constructor body 210 and mount item 0x3EA3"): return false
	var serial := int(fields[2])
	if not check(await until(func(): return session.entities.has(serial) and observer.entities.has(serial)),
		"Both clients receive the loose Desert Ostard"): return false
	if not check(await object_ready(session) and session.use_mobile(serial), "Normal mount double click"): return false
	if not check(await until(func(): return (int(session.equipment.get(25, {}).get("id", 0)) == 0x3ea3
		and int(observer.mobile_equipment.get(rider, {}).get(25, {}).get("id", 0)) == 0x3ea3)),
		"Native layer 25 and observer match the exact worn item"): return false
	var mounted := Avatar.new()
	mounted.initial_body = 400 + index
	root.add_child(mounted)
	mounted.set_physics_process(false)
	for hue: int in [53, 0x8035]:
		await fixture_reply(session, index, "colour %d" % hue, "UCEQUINE|colour|")
		if not check(await until(func(): return (int(session.equipment[25].hue) == hue
			and int(observer.mobile_equipment[rider][25].hue) == hue)), "Mounted full and partial hue reaches both clients"): return false
		mounted.apply_server_appearance(session.player, session.equipment.values())
		if not check(mounted.horse_visual.desert_actions != null and mounted.horse_visual.native_hue == hue,
			"Mounted renderer keeps the exact library and raw hue"): return false
	mounted.animate(false, 0.0, 0.1, 0.0)
	if not check(await until(func(): return mounted.rider_contact.seated_weight >= 1.0)
		and mounted.rider_contact.seat_error < 0.003, "Native mounted appearance seats the actual rider"): return false
	for running: bool in [false, true]:
		var origin := Vector2i(session.player.x, session.player.y)
		var direction := await native_step(session, running)
		if not check(direction >= 0, "Native mounted movement changes coordinates"): return false
		mounted.animate(true, 0.0, 0.1, 6.8 if running else 1.8)
		if not check(mounted.horse_visual.current_clip == ("Run" if running else "Walk"), "Mounted movement keeps the recovered gait"): return false
		await native_step(session, running, (direction + 4) % 8)
		if not check(Vector2i(session.player.x, session.player.y) == origin, "Native return keeps observer in range"): return false
	if not check(await object_ready(session) and session.use_mobile(rider), "Normal dismount double click"): return false
	if not check(await until(func(): return (not session.equipment.has(25) and not observer.mobile_equipment.get(rider, {}).has(25)
		and session.entities.has(serial) and observer.entities.has(serial))), "Both clients see the mount restored as a loose creature"): return false
	mounted.free()
	var probes: Array[Node3D] = []
	var loose: Array[Node3D] = []
	for connection: Node in [session, observer]:
		var actor := Avatar.new()
		actor.initial_body = 210
		root.add_child(actor)
		actor.set_physics_process(false)
		actor.apply_server_appearance(connection.entities[serial], [])
		var probe := Transition.new()
		root.add_child(probe)
		probe.configure(connection, serial, actor)
		actor.reparent(probe)
		loose.append(actor)
		probes.append(probe)
	var groups := [4, 6, 9, 10, 11]
	if index == 1:
		groups.append(12)
	for group: int in groups:
		session.last_mobile_actions.erase(serial)
		observer.last_mobile_actions.erase(serial)
		if group == 11:
			await fixture_reply(session, index, "action 11", "UCEQUINE|action|")
		else:
			replies[index].clear()
			session.send_command("[DesertOstardActionFixture %d %d" % [serial, group])
			if not check(await until(func(): return replies[index].has("UCEQUINE|ostard-action|%d|%d" % [serial, group])),
				"Native fixture accepts Desert Ostard group %d" % group): return false
		if not check(await until(func(): return session.last_mobile_actions.has(serial) and observer.last_mobile_actions.has(serial)),
			"Native classic group %d reaches both clients" % group): return false
		for client in 2:
			var connection: Node = [session, observer][client]
			var packet: Dictionary = connection.last_mobile_actions[serial]
			if not check(packet.protocol == "classic" and packet.action == group and loose[client].receive_native_action(packet)
				and loose[client].horse_visual.current_clip == Actions.CLIPS[group], "Both decoded routes select %s" % Actions.CLIPS[group]): return false
	if index == 1:
		for frame in 4: await process_frame
	var corpse_reply := await fixture_reply(session, index, "kill", "UCEQUINE|corpse|")
	if corpse_reply.is_empty(): return false
	var corpse := int(corpse_reply.split("|")[2])
	var clip := "Death2" if index else "Death"
	if not check(await until(func(): return session.world_items.has(corpse) and observer.world_items.has(corpse)),
		"Native corpse item reaches both clients"): return false
	for client in 2:
		var connection: Node = [session, observer][client]
		var item: Dictionary = connection.world_items[corpse]
		var event: Dictionary = probes[client].events.get(serial, {})
		if not check(item.amount == 210 and item.id == 0x2006 and event.get("corpse") == corpse
			and event.get("clip") == clip and probes[client].place_corpse(corpse, item), "Decoded death starts %s and holds the corpse" % clip): return false
	for client in 2:
		var connection: Node = [session, observer][client]
		var probe: Node3D = probes[client]
		if not check(await until(func(): return probe.settled(corpse) and not connection.entities.has(serial))
			and probe.verify_corpse(corpse, 210, int(connection.world_items[corpse].hue), clip),
			"Both clients retain the matching static native corpse"): return false
		probe.free()
	records.append({"female":index == 1, "body":210, "native_class":"DesertOstard", "mount_item":0x3ea3,
		"groups":groups, "corpse_clip":clip, "death":true})
	return (await fixture_reply(session, index, "cleanup", "UCEQUINE|cleaned")) == "UCEQUINE|cleaned"
