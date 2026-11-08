extends "res://../scripts/test-goat-harpy-horde-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const ENTRY_GROUPS := {88: [9, 12], 87: [6, 3], 79: [13, 3], 149: [15, 3], 73: [6, 3], 776: [15, 3]}

class Arena extends Node3D:
	var avatars: Dictionary = {}

func run() -> void:
	install_packages()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in ENTRY_GROUPS:
			var groups: Array = ENTRY_GROUPS[body]
			witness(plane, body, groups[0], 0.0)
			for phase: float in [0.08, 0.45, 0.78]:
				witness(plane, body, groups[1], phase)
		witness(plane, 73, 19, 0.0)
		witness(plane, 73, 21, 0.45)
		plane.free()
		await physics_frame
	assert(checked == 3198)
	print("GOAT, MATRIARCH, LICH LORD, SUCCUBUS, STONE HARPY AND HORDE CORPSES: ",
		"78 decoded handoffs across ", checked, " poses")
	quit()

func witness(plane: StaticBody3D, body: int, group: int, phase: float) -> void:
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
	avatar.initial_body = body
	arena.add_child(avatar)
	avatar.set_physics_process(false)
	var serial := 0x10900 + body
	var corpse := 0x40010900 + body
	var entity := {"serial":serial, "body":body, "hue":0x8035, "direction":4}
	avatar.apply_server_appearance(entity, [])
	session.entities[serial] = entity
	arena.avatars[serial] = avatar
	var source: Node3D = avatar.horse_visual
	source.set_process(false)
	source.set_physics_process(false)
	source.contact.active = false
	source.contact.sample(plane.get_world_3d().direct_space_state, source.global_position)
	var previous: AnimationPlayer = source.animator
	previous.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(avatar.receive_native_action(decode(session, serial, group)))
	previous.advance(0.03 if phase > 0.0 and phase < 0.1 else 0.15)
	previous.seek(previous.current_animation_length * (phase if phase > 0.0 else 0.45), true)
	if body == 73 and phase == 0.0 and group != 19:
		source.clear_gesture_ground()
	var initial := world_joints(source.skeleton)
	var expected_time := previous.current_animation_position if phase > 0.0 else 0.0
	var expected_speed := absf(previous.get_playing_speed()) if phase > 0.0 else 1.0
	var clip := str(CLASSIC[body][group]) if phase > 0.0 else ("AirDeath" if group == 19 else "Death")
	var holder := Node3D.new()
	items.add_child(holder)
	items.nodes[corpse] = holder
	assert(items._equine_corpse(holder, {"id":0x2006, "amount":body, "hue":0x8035, "direction":4}, corpse))
	var death := PackedByteArray([0xaf])
	death.append_array(Wire.uint_be(serial, 4))
	death.append_array(Wire.uint_be(corpse, 4))
	death.append_array(Wire.uint_be(0, 4))
	session._handle(death)
	assert(deaths.active.has(serial) and not avatar.visible and not holder.visible)
	var visual: Node3D = deaths.active[serial].visual
	visual.set_process(false)
	var player: AnimationPlayer = visual.animator
	player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	var rig: Skeleton3D = visual.skeleton
	var collapsed: Dictionary = visual.collapse_plane if body in [73, 79] else visual.fall.plane
	var skin: Dictionary = visual.collapse_skin if body in [73, 79] else visual.fall.skin
	assert(collapsed.collider == plane and visual.global_transform.is_equal_approx(source.global_transform))
	assert(visual.current_clip == clip and is_equal_approx(player.current_animation_position, expected_time)
		and is_equal_approx(absf(player.get_playing_speed()), expected_speed))
	assert(is_equal_approx(visual.action_remaining, (player.current_animation_length - expected_time) / expected_speed))
	if phase > 0.0 or body != 79:
		var gap := joint_gap(initial, world_joints(rig))
		assert(gap < 0.005, "Body %d group %d phase %s entry gap %s" % [body, group, phase, gap])
	var normal := plane.global_basis.y.normalized()
	var floor := INF
	for frame in 41:
		player.seek(lerpf(expected_time, player.current_animation_length, frame / 40.0), true)
		floor = Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
		if body == 79:
			var staff_floor: float = visual.staff_gap(visual.staff.global_transform, normal)
			staff_floor += (visual.model.global_position - plane.global_position).dot(normal)
			assert(staff_floor >= 0.0015)
		assert(floor >= 0.0015, "Body %d group %d phase %s frame %s gap %s" % [body, group, phase, frame, floor])
		checked += 1
	var staff_names: Array[StringName] = []
	if body == 79:
		for mesh: MeshInstance3D in visual.staff_meshes():
			staff_names.append(mesh.name)
		assert(not staff_names.is_empty())
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(serial, 4))
	session._handle(removal)
	assert(not session.entities.has(serial))
	deaths._process(10.0)
	assert(not deaths.active.has(serial) and items.corpse_snapshots.has(corpse) and holder.visible)
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("death_clip") == clip
		and cadaver.get_meta("native_hue") == 0x8035 and cadaver.get_meta("static_cadaver")
		and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
	for name: StringName in staff_names:
		assert(cadaver.has_node(NodePath(name)))
	assert(absf(static_floor(cadaver, plane) - floor) < 0.001)
	arena.free()

func world_joints(rig: Skeleton3D) -> Array[Vector3]:
	rig.force_update_all_bone_transforms()
	var joints: Array[Vector3] = []
	for bone in rig.get_bone_count():
		joints.append(rig.to_global(rig.get_bone_global_pose(bone).origin))
	return joints

func joint_gap(before: Array[Vector3], after: Array[Vector3]) -> float:
	var distance := 0.0
	for index in before.size():
		distance = maxf(distance, before[index].distance_to(after[index]))
	return distance

func static_floor(cadaver: Node3D, plane: StaticBody3D) -> float:
	var lowest := INF
	var normal := plane.global_basis.y.normalized()
	for mesh: MeshInstance3D in cadaver.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				lowest = minf(lowest, normal.dot(mesh.to_global(point) - plane.global_position))
	return lowest
