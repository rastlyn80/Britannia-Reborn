extends "res://Network/SwampWidowJukaActionsLive.gd"

const Appearance := preload("res://Presentation/NativeCreatureAppearance.gd")
const BODY := 130
var fire_stances := []

func run() -> void:
	await super.run()
	if not check(fire_stances.size() == 12, "Both clients witness each Fire Gargoyle gait transition"):
		quit(1)
		return
	var path := "res://../outputs/creatures/%s/live.json" % family
	var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	report.fire_stances = fire_stances
	var out := FileAccess.open(path, FileAccess.WRITE)
	assert(out != null)
	out.store_string(JSON.stringify(report, "\t"))
	out.close()
	print("FIRE GARGOYLE NATIVE: 12 replicated stance and step records")

func clear_fall(actor: Node3D) -> bool:
	if actor.native_body in [20, BODY]:
		if not check(actor.dead and not actor.fall.skin.is_empty(), "Fitted fall arms its skinned terrain support"):
			return false
		actor.model.position -= actor.fall.shift
		actor.fall.shift = Vector3.ZERO
		actor.fall.plane = {}
	return super.clear_fall(actor)

func sample_additional_actions(sex: int) -> bool:
	if not await super.sample_additional_actions(sex):
		return false
	var owned: Dictionary = death_arenas[sex].avatars
	var serial: int = owned.keys()[0]
	if owned[serial].horse_visual.native_body != BODY:
		return true
	var clients := [sex, 1 - sex]
	for client: int in clients:
		sessions[client].last_mobile_actions.erase(serial)
	var response := await super.reply(sex, "action -2", "UCCREATURE|action|")
	var received := not response.is_empty() and await until(func():
		return clients.all(func(client: int):
			var packet: Dictionary = sessions[client].last_mobile_actions.get(serial, {})
			return packet.get("protocol") == "new" and int(packet.get("type", -1)) == 11))
	if not check(received, "Both clients receive Fire Gargoyle's newer strike"):
		return false
	var witness := {"requested": -2}
	for client: int in clients:
		var side := "owner" if client == sex else "observer"
		var packet: Dictionary = sessions[client].last_mobile_actions[serial]
		var avatar: Node3D = death_arenas[client].avatars[serial]
		if not check(avatar.receive_native_action(packet) and avatar.horse_visual.current_clip == "Attack",
				"Fire Gargoyle's newer strike keeps the original attack route"):
			return false
		witness[side + "_packet"] = packet
		witness[side + "_clip"] = avatar.horse_visual.current_clip
	additional_actions[records.size()].actions.append(witness)
	return await witness_stances(sex, clients, serial)

func witness_stances(sex: int, clients: Array, serial: int) -> bool:
	for phase in 3:
		var combat := phase == 1
		replies[sex].clear()
		sessions[sex].send_command("[FireGargoyleStanceFixture %d %d" % [serial, int(combat)])
		var replied := await until(func(): return not replies[sex].is_empty())
		if not check(replied and replies[sex][-1] == "UCCREATURE|fire-stance|%d" % int(combat),
				"Fixture sets the actual Fire Gargoyle warmode"):
			return false
		if not check(await until(func():
			return clients.all(func(client: int):
				return ((int(sessions[client].entities[serial].flags) & 0x40) != 0) == combat)),
				"Both clients receive the native Fire Gargoyle flag"):
			return false
		var start := native_location(sex, serial)
		var idle := "Idle" if combat else "ReadyStance"
		var walk := "Walk" if combat else "FireGargoylePeaceWalk"
		for client: int in clients:
			var actor := apply_gait_entity(client, serial)
			actor.action_remaining = 0.0
			actor.play_gait(false, 0.0)
			if not check(actor.current_clip == idle and native_location(client, serial) == start,
					"Both views stand in the correct replicated stance"):
				return false
		await create_timer(0.85).timeout
		var step := (await super.reply(sex, "step 0", "UCCREATURE|step|")).split("|")
		if not check(step.size() >= 5, "Fixture performs a genuine Fire Gargoyle step"):
			return false
		var target := Vector3i(int(step[2]), int(step[3]), int(step[4]))
		if not check(target != start and await until(func():
			return clients.all(func(client: int): return native_location(client, serial) == target)),
				"Both clients receive the real step"):
			return false
		for client: int in clients:
			var actor := apply_gait_entity(client, serial)
			actor.play_gait(true, 2.0)
			if not check(actor.current_clip == walk and not sessions[client].entities[serial].running,
					"Both clients select the intended walk"):
				return false
			fire_stances.append({"owner": sex, "client": client, "phase": phase, "body": BODY, "serial": serial,
				"flags": int(sessions[client].entities[serial].flags), "idle": idle, "walk": walk,
				"from": [start.x, start.y, start.z], "to": [target.x, target.y, target.z]})
	return true

func apply_gait_entity(client: int, serial: int) -> Node3D:
	var session: Node = sessions[client]
	var avatar: Node3D = death_arenas[client].avatars[serial]
	Appearance.apply(avatar, session.entities[serial], session.mobile_equipment.get(serial, {}).values(),
		session.appearance_for(serial))
	return avatar.horse_visual

func native_location(client: int, serial: int) -> Vector3i:
	var entity: Dictionary = sessions[client].entities[serial]
	return Vector3i(int(entity.x), int(entity.y), int(entity.z))
