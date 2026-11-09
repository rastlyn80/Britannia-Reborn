extends "res://../scripts/test-gargoyle-kitsune-larva-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")
const HEIGHTS := [0.94, 1.36, 0.69]
var handoffs := 0

class Arena extends Node3D:
	var avatars: Dictionary = {}

func run() -> void:
	install_packages()
	for index in SLOPES.size():
		var plane := await support(SLOPES[index])
		for group: int in [21, 19, 20]:
			witness(plane, 67, group, 0.0)
		witness(plane, 246, 10, 0.0)
		for phase: float in [0.08, 0.45, 0.78]:
			for group: int in [2, 3]:
				witness(plane, 67, group, phase)
				witness(plane, 778, group, phase, HEIGHTS[index])
			for group: int in [8, 12]:
				witness(plane, 246, group, phase)
		plane.free()
		await physics_frame
	assert(handoffs == 66 and checked == 2706)
	print("GARGOYLE, KITSUNE AND LARVA: ", handoffs, " decoded corpse handoffs across ", checked, " poses")
	quit()

func witness(plane: StaticBody3D, body: int, group: int, phase: float, height := 0.0) -> void:
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
	avatar.position.y = height
	var serial := 0x10a00 + body
	var corpse := 0x40010a00 + body
	var entity := {"serial":serial, "body":body, "hue":0x8035, "direction":4}
	avatar.apply_server_appearance(entity, [])
	session.entities[serial] = entity
	arena.avatars[serial] = avatar
	var source: Node3D = avatar.horse_visual
	source.set_process(false)
	source.set_physics_process(false)
	source.contact.active = false
	var previous: AnimationPlayer = source.animator
	previous.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	assert(avatar.receive_native_action(decode(session, serial, group)))
	previous.advance(0.03 if phase > 0.0 and phase < 0.1 else 0.15)
	previous.seek(previous.current_animation_length * (phase if phase > 0.0 else 0.45), true)
	var start := skinned_points(source)
	var expected_time := previous.current_animation_position if phase > 0.0 else 0.0
	var speed := absf(previous.get_playing_speed()) if phase > 0.0 else 1.0
	var clip := expected_fall(body, group)
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
	assert(visual.current_clip == clip and visual.global_transform.is_equal_approx(source.global_transform))
	assert(is_equal_approx(player.current_animation_position, expected_time)
		and is_equal_approx(absf(player.get_playing_speed()), speed))
	assert(is_equal_approx(visual.action_remaining, (player.current_animation_length - expected_time) / speed))
	var entry_gap := largest_difference(start, skinned_points(visual))
	assert(entry_gap < 0.005, "Body %d group %d phase %s entry gap %s" % [body, group, phase, entry_gap])
	var anchor: Transform3D = visual.global_transform
	var floor := INF
	for frame in 41:
		player.seek(lerpf(expected_time, player.current_animation_length, frame / 40.0), true)
		assert(visual.global_transform.is_equal_approx(anchor))
		if body == 778:
			assert(is_equal_approx(visual.global_position.y, height))
		else:
			assert(visual.fall.plane.collider == plane)
			floor = Ground.minimum_plane_gap(visual.fall.skin, visual.skeleton, visual.skeleton.global_transform,
				plane.global_position, plane.global_basis.y.normalized())
			assert(floor >= 0.0015, "Body %d group %d phase %s frame %d floor %s" % [body, group, phase, frame, floor])
		checked += 1
	var removal := PackedByteArray([0x1d])
	removal.append_array(Wire.uint_be(serial, 4))
	session._handle(removal)
	assert(not session.entities.has(serial))
	deaths._process(10.0)
	assert(not deaths.active.has(serial) and holder.visible)
	var cadaver := holder.get_node("CorpseVisual") as Node3D
	assert(cadaver.get_meta("corpse_body") == body and cadaver.get_meta("native_hue") == 0x8035
		and cadaver.get_meta("static_cadaver") and cadaver.find_children("*", "Skeleton3D", true, false).is_empty())
	if body == 778:
		assert(cadaver.find_child("OriginalCards", true, false) != null)
		var source_corners := 0
		for mesh: MeshInstance3D in source.model.find_children("*", "MeshInstance3D", true, false):
			source_corners += int(Ground.skin_points(mesh, source.skeleton).source_vertices)
		assert(int(cadaver.get_meta("vertices")) == source_corners)
	else:
		assert(items.corpse_snapshots.has(corpse) and cadaver.get_meta("death_clip") == clip)
		assert(absf(static_floor(cadaver, plane) - floor) < 0.001)
	handoffs += 1
	arena.free()

func expected_fall(_body: int, group: int) -> String:
	return "Death2" if group == 12 else ("AirDeath" if group in [19, 20] else "Death")

func skinned_points(actor: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	var rig: Skeleton3D = actor.skeleton
	rig.force_update_all_bone_transforms()
	for mesh: MeshInstance3D in actor.model.find_children("*", "MeshInstance3D", true, false):
		var skin := Ground.skin_points(mesh, rig)
		for surface: Dictionary in skin.surfaces:
			var matrices: Array[Transform3D] = []
			for bind in skin.bones.size():
				matrices.append(rig.global_transform * rig.get_bone_global_pose(skin.bones[bind]) * skin.bind_poses[bind])
			for vertex in surface.points.size():
				var point := Vector3.ZERO
				for slot in surface.stride:
					var at: int = vertex * surface.stride + slot
					var weight: float = surface.weights[at]
					if weight > 0.0:
						point += (matrices[surface.bindings[at]] * surface.points[vertex]) * weight
				points.append(point)
	return points

func largest_difference(before: PackedVector3Array, after: PackedVector3Array) -> float:
	assert(before.size() == after.size())
	var largest := 0.0
	for index in before.size():
		largest = maxf(largest, before[index].distance_to(after[index]))
	return largest

func static_floor(cadaver: Node3D, plane: StaticBody3D) -> float:
	var lowest := INF
	var normal := plane.global_basis.y.normalized()
	for mesh: MeshInstance3D in cadaver.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			for point: Vector3 in mesh.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				lowest = minf(lowest, normal.dot(mesh.to_global(point) - plane.global_position))
	return lowest
