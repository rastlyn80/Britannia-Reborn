extends "res://../scripts/test-gargoyle-kitsune-larva-corpses.gd"

const BOG := 780
const GESTURES := {11: "BogFloorFidget", 15: "BogFloorBrace", 16: "BogFloorBrace",
	17: "BogFloorFidget", 18: "BogFloorReach"}
const BOG_TREATMENTS := ["original", "modern"]

func run() -> void:
	Registry.load_index()
	if "--candidate" in OS.get_cmdline_user_args():
		var row := Registry.entry(BOG).duplicate(true)
		row.assets = {}
		for treatment: String in BOG_TREATMENTS:
			row.assets[treatment] = "res://local-art/creatures/bog-thing-actions.scn"
		for slot: int in GESTURES:
			row.classic_action_categories[str(slot)] = GESTURES[slot]
		row.classic_action_categories["3"] = "Death"
		row.presentation_script = "res://Presentation/BogThingActionsVisual.gd"
		Registry.entries[BOG] = row
	var session := Game.new()
	root.add_child(session)
	session.set_process(false)
	for slope: Vector3 in SLOPES:
		var plane := await support(slope)
		for treatment: String in BOG_TREATMENTS:
			sample_gestures(session, plane, treatment)
		for group: int in [2, 3]:
			for phase: float in [0.08, 0.45, 0.78]:
				witness_fall(plane, group, phase)
		plane.free()
		await physics_frame
	assert(checked == 2910 and handoffs == 18)
	print("BOG THING: ", checked, " decoded gesture poses, ", handoffs, " decoded fall-to-corpse handoffs")
	quit()

func sample_gestures(session: Node, plane: StaticBody3D, treatment: String) -> void:
	var actor := Registry.create(BOG)
	actor.treatment = treatment
	root.add_child(actor)
	actor.apply_identity(BOG, 0x8035)
	actor.set_process(false)
	actor.set_physics_process(false)
	actor.contact.active = false
	var anchor := actor.global_transform
	var rig: Skeleton3D = actor.skeleton
	assert(rig.get_bone_count() == 116 and actor.footprint.size() == 103)
	var mesh: MeshInstance3D = actor.base_mesh
	var skin := Ground.skin_points(mesh, rig)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var normal := plane.global_basis.y.normalized()
	var player: AnimationPlayer = actor.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for slot: int in GESTURES:
		player.stop()
		assert(actor.receive_action(decode(session, BOG, slot)) and actor.current_clip == GESTURES[slot])
		player.advance(0.15)
		for frame in 97:
			player.seek(player.current_animation_length * frame / 96.0, true)
			rig.force_update_all_bone_transforms()
			actor._physics_process(1.0 / 60.0)
			var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
			assert(gap >= -0.001, "Bog Thing group %d frame %d branch gap %s" % [slot, frame, gap])
			assert(actor.global_transform == anchor and actor.native_hue == 0x8035)
			var matrices: Array[Transform3D] = actor.skin_transforms(mesh, rig.global_transform)
			var contact_gap := INF
			for vertex: int in actor.footprint:
				var point: Vector3 = actor.weighted_point(arrays, matrices, vertex)
				contact_gap = minf(contact_gap, normal.dot(point - plane.global_position))
			assert(absf(contact_gap) < 0.001)
			checked += 1
	actor.free()

func witness_fall(plane: StaticBody3D, group: int, phase: float) -> void:
	var arena := Arena.new()
	root.add_child(arena)
	var session := Game.new()
	arena.add_child(session)
	session.set_process(false)
	var items := Items.new()
	arena.add_child(items)
	items.add_child(items.hint)
	items.session = session
	var deaths := Deaths.new()
	arena.add_child(deaths)
	deaths.configure(arena, session, items)
	deaths.set_process(false)
	var avatar := Avatar.new()
	avatar.initial_body = BOG
	arena.add_child(avatar)
	avatar.set_physics_process(false)
	var serial := 0x10a00 + BOG
	var corpse := 0x40010a00 + BOG
	var entity := {"serial": serial, "body": BOG, "hue": 0x8035, "direction": 4}
	avatar.apply_server_appearance(entity, [])
	session.entities[serial] = entity
	arena.avatars[serial] = avatar
	var source: Node3D = avatar.horse_visual
	source.set_process(false)
	source.set_physics_process(false)
	source.contact.active = false
	source._physics_process(1.0 / 60.0)
	assert(source.ground_hit(source.global_position).collider == plane)
	var previous: AnimationPlayer = source.animator
	previous.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(avatar.receive_native_action(decode(session, serial, group)) and source.current_clip == "Death")
	previous.advance(0.03 if phase < 0.1 else 0.15)
	var time := previous.current_animation_length * phase
	previous.seek(time, true)
	var speed := previous.get_playing_speed()
	var before := full_points(source)
	var packet := PackedByteArray([0xaf])
	packet.append_array(Wire.uint_be(serial, 4))
	packet.append_array(Wire.uint_be(corpse, 4))
	packet.append_array(Wire.uint_be(0, 4))
	session._handle(packet)
	assert(deaths.active.has(serial) and not avatar.visible)
	var visual: Node3D = deaths.active[serial].visual
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(visual.current_clip == "Death" and visual.model.transform == source.model.transform)
	assert(is_equal_approx(player.current_animation_position, time) and is_equal_approx(player.get_playing_speed(), speed))
	assert(is_equal_approx(visual.action_remaining, (player.current_animation_length - time) / speed))
	var error := largest_difference(before, full_points(visual))
	assert(error < 0.001, "Bog Thing fall %d phase %s moved a corner by %s m" % [group, phase, error])
	player.advance(0.081)
	assert(visual.entry_positions.is_empty())
	player.seek(player.current_animation_length, true)
	var endpoint := full_points(visual)
	deaths._process(10.0)
	assert(items.corpse_snapshots.has(corpse))
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[corpse] = holder
	assert(items._equine_corpse(holder, {"id": 0x2006, "amount": BOG, "hue": 0x8035, "direction": 4}, corpse))
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("static_cadaver") and cadaver.get_meta("corpse_body") == BOG
		and cadaver.get_meta("native_hue") == 0x8035 and int(cadaver.get_meta("vertices")) == 4710)
	var mesh := cadaver.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var points: PackedVector3Array = mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for index in points.size():
		points[index] = mesh.to_global(points[index])
	assert(largest_difference(endpoint, points) < 0.001)
	handoffs += 1
	arena.free()

func full_points(actor: Node3D) -> PackedVector3Array:
	var mesh: MeshInstance3D = actor.base_mesh
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	var matrices: Array[Transform3D] = actor.skin_transforms(mesh, rig.global_transform)
	var arrays := mesh.mesh.surface_get_arrays(0)
	var points := PackedVector3Array()
	for vertex in mesh.mesh.surface_get_array_len(0):
		points.append(actor.weighted_point(arrays, matrices, vertex))
	assert(points.size() == 4710)
	return points
