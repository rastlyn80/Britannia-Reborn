extends "res://Network/FluidElementalBehaviourLive.gd"

const Avatar := preload("res://Presentation/HumanAvatar.gd")
const Appearance := preload("res://Presentation/NativeCreatureAppearance.gd")
const Registry := preload("res://Presentation/CreatureRegistry.gd")
const OUT := "res://../outputs/creatures/golem_raptor_juka_solen_actions/stance.json"
const INPUTS := ["Network/CreatureCombatFlagsLive.gd", "Presentation/NativeCreatureAppearance.gd",
	"Presentation/UopMonsterGait.gd", "Presentation/RaptorActionsVisual.gd", "Presentation/SlithUopGaitVisual.gd"]

func _initialize() -> void:
	create_timer(105.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func reply(client: int, command: String) -> String:
	replies[client].clear()
	sessions[client].send_command("[CreatureCombatFlagFixture " + command)
	assert(await until(func(): return not replies[client].is_empty()), command)
	return replies[client][-1]

func run() -> void:
	var scenes := {}
	for body: int in [730, 734]:
		var row := Registry.entry(body).duplicate(true)
		var prefix := "raptor-uop" if body == 730 else "slith-uop-gait"
		var renderer := "RaptorActionsVisual" if body == 730 else "SlithUopGaitVisual"
		row.presentation_script = "res://Presentation/%s.gd" % renderer
		var paths := {}
		for treatment: String in row.assets:
			var path := "res://local-art/creatures/%s-actions-%s.scn" % [prefix, treatment]
			row.assets[treatment] = path
			paths[treatment] = FileAccess.get_sha256(path)
			assert(not paths[treatment].is_empty())
		scenes[str(body)] = paths
		Registry.entries[body] = row
	var accounts: Array = JSON.parse_string(FileAccess.get_file_as_string("res://../work/horse-session/accounts.local.json"))
	for client in 2:
		var session := Game.new()
		root.add_child(session)
		sessions.append(session)
		session.failed.connect(func(reason: String): errors.append(reason))
		session.message_received.connect(func(message: String):
			if message.begins_with("UCGFLAG|"):
				replies[client].append(message))
		session.connect_account(accounts[client].username, accounts[client].password, 2594)
		assert(await until(func(): return session.phase == "characters"))
		var slot := -1
		var city := -1
		for place: Dictionary in session.cities:
			if place.name == "Britain":
				city = int(place.index)
		for character: Dictionary in session.characters:
			if str(character.name).is_empty():
				slot = int(character.slot)
				break
		assert(slot >= 0 and city >= 0)
		session.create_character("Motion Witness %s" % ("Two" if client else "One"), slot, city, client == 1)
		assert(await until(func(): return session.phase == "world"))
		assert(await reply(client, "arena") == "UCGFLAG|arena")
	var records := []
	for body in [730, 734]:
		var prepared := (await reply(0, "prepare %d" % body)).split("|")
		assert(prepared.size() == 4 and prepared[1] == "prepared" and int(prepared[3]) == body)
		var serial := int(prepared[2])
		assert(await until(func(): return sessions.all(func(session: Node): return session.entities.has(serial))))
		var actors: Array[Node3D] = []
		for client in 2:
			var avatar := Avatar.new()
			avatar.initial_body = body
			root.add_child(avatar)
			avatar.set_physics_process(false)
			actors.append(avatar)
		var modes := [false, true, false]
		for phase in modes.size():
			var combat: bool = modes[phase]
			assert(await reply(0, "mode %d" % int(combat)) == "UCGFLAG|mode|%d" % int(combat))
			assert(await until(func(): return sessions.all(func(session: Node):
				return ((int(session.entities[serial].flags) & 0x40) != 0) == combat)))
			var idle := "Idle" if combat else "ReadyStance"
			var walk := "Walk" if combat else ("RaptorPeaceWalk" if body == 730 else "SlithPeaceWalk")
			var starts := []
			for client in 2:
				apply_entity(actors[client], sessions[client], serial)
				var visual: Node3D = actors[client].horse_visual
				assert(visual.native_body == body)
				visual.play_gait(false, 0.0)
				assert(visual.current_clip == idle)
				starts.append(location(sessions[client], serial))
			var step := (await reply(0, "step")).split("|")
			assert(step.size() == 5 and step[1] == "step")
			var target := Vector3i(int(step[2]), int(step[3]), int(step[4]))
			assert(await until(func(): return sessions.all(func(session: Node): return location(session, serial) == target)))
			for client in 2:
				assert(starts[client] != target)
				var entity: Dictionary = sessions[client].entities[serial]
				assert(not entity.running and ((int(entity.flags) & 0x40) != 0) == combat)
				apply_entity(actors[client], sessions[client], serial)
				var visual: Node3D = actors[client].horse_visual
				visual.play_gait(true, 2.0)
				assert(visual.current_clip == walk)
				var start: Vector3i = starts[client]
				records.append({"body": body, "serial": serial, "client": client, "phase": phase,
					"combat": combat, "flags": int(entity.flags), "idle": idle, "walk": walk,
					"from": [start.x, start.y, start.z], "to": [target.x, target.y, target.z]})
		assert(await reply(0, "cleanup") == "UCGFLAG|clean")
		for actor in actors:
			actor.free()
	assert(records.size() == 12)
	for session in sessions:
		session.close()
	var scripts := {}
	for path: String in INPUTS:
		scripts[path] = FileAccess.get_sha256("res://" + path)
		assert(not scripts[path].is_empty())
	var file := FileAccess.open(OUT, FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({"records": records, "scenes": scenes, "scripts": scripts, "failures": 0,
		"scope": "Actual native Warmode and Move on two disposable clients; controlled setup, not autonomous combat."}, "\t"))
	file.close()
	print("CREATURE COMBAT FLAGS NATIVE: 12 two-client pose and motion records for Raptor and Slith, including return to peaceful gait")
	quit()

func apply_entity(actor: Node3D, session: Node, serial: int) -> void:
	Appearance.apply(actor, session.entities[serial], session.mobile_equipment.get(serial, {}).values(), session.appearance_for(serial))

func location(session: Node, serial: int) -> Vector3i:
	var entity: Dictionary = session.entities[serial]
	return Vector3i(int(entity.x), int(entity.y), int(entity.z))
