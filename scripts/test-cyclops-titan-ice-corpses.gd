extends "res://../scripts/test-cyclops-titan-ice-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

func run() -> void:
	load_batch()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for phase: float in [0.0, 0.08, 0.45, 0.78]:
			witness(plane, 75, phase)
		for body: int in [76, 161]:
			for phase: float in [0.0, 0.12, 0.62]:
				witness(plane, body, phase)
		plane.free()
		await physics_frame
	for edge: float in [0.35, -0.35]:
		var plane := await support(Vector3.ZERO)
		var riser := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.0, 0.22, 8.0)
		riser.shape = box
		riser.position = Vector3(edge + 1.0, 0.11, 0.0)
		plane.add_child(riser)
		await physics_frame
		await physics_frame
		for phase: float in [0.0, 0.45]:
			witness(plane, 75, phase, edge)
		plane.free()
		await physics_frame
	assert(checked == 1394)
	print("CYCLOPS, TITAN AND ICE ELEMENTAL CORPSES: 34 decoded handoffs across ", checked, " terrain poses")
	quit()

func witness(plane: StaticBody3D, body: int, phase: float, edge := INF) -> void:
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
	if edge < 0.0:
		avatar.position.y = 0.22
	avatar.set_physics_process(false)
	var serial := 0x10100 + body
	var corpse := 0x40010100 + body
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
	var clip := "Death2" if phase > 0.0 and body != 76 else "Death"
	var group := 3 if phase > 0.0 else (15 if body == 75 else 18)
	assert(avatar.receive_native_action(decode(session, serial, group)))
	previous.advance(0.03 if phase > 0.0 and phase < 0.1 else 0.15)
	previous.seek(previous.current_animation_length * (phase if phase > 0.0 else 0.45), true)
	if body != 75 and phase == 0.0:
		source.contact.sample(plane.get_world_3d().direct_space_state, source.global_position)
		source.contact._process_modification_with_delta(0.0)
		if body == 76:
			source.clear_gesture_ground()
	var initial := world_joints(source.skeleton)
	var time := previous.current_animation_position if phase > 0.0 else 0.0
	var speed := previous.get_playing_speed() if phase > 0.0 else 1.0
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
	assert(visual.current_clip == clip and visual.global_transform.is_equal_approx(source.global_transform))
	assert(is_equal_approx(player.current_animation_position, time) and is_equal_approx(player.get_playing_speed(), speed))
	assert(is_equal_approx(visual.action_remaining, (player.current_animation_length - time) / speed))
	var jump := joint_gap(initial, world_joints(rig))
	assert(jump < 0.005, "Body %d pose entry %s m at phase %s, slope %s" % [body, jump, phase, plane.rotation])
	var grip := rig.find_bone("cp_grasp_rhand") if body == 75 else -1
	var mallet := rig.find_bone("cyclopsmallet") if body == 75 else -1
	var floor := 0.0
	var over_step := 0
	for frame in 41:
		player.seek(lerpf(time, player.current_animation_length, frame / 40.0), true)
		var normal := plane.global_basis.y.normalized()
		var skin: Dictionary = visual.body_skin if body == 75 else (visual.support_skin if body == 161 else visual.fall.skin)
		floor = Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
		if body == 75:
			floor = minf(floor, Ground.minimum_plane_gap(visual.mallet_skin, rig, rig.global_transform, plane.global_position, normal))
		if body == 75 and phase > 0.0:
			assert(rig.get_bone_global_pose(grip).origin.distance_to(rig.get_bone_global_pose(mallet).origin) < 0.000001)
		assert(floor >= (0.0015 if body != 161 else -0.002),
			"Body %d floor gap %s m at phase %s, frame %d, slope %s" % [body, floor, phase, frame, plane.rotation])
		if is_finite(edge):
			over_step += check_ledge(visual, edge)
		checked += 1
	assert(not is_finite(edge) or over_step > 0)
	var prop := visual.find_child("CyclopsMallet", true, false) as MeshInstance3D
	var prop_world := rig.global_transform * rig.get_bone_global_pose(mallet) * prop.skin.get_bind_pose(0) if body == 75 else Transform3D.IDENTITY
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
	assert(absf(static_floor(cadaver, plane) - floor) < 0.0003)
	if body == 75:
		var frozen := cadaver.find_child("CyclopsMallet", true, false) as MeshInstance3D
		assert(frozen != null and frozen.mesh.get_surface_count() == prop.mesh.get_surface_count())
		for surface in prop.mesh.get_surface_count():
			var original: PackedVector3Array = prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			var vertices: PackedVector3Array = frozen.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
			assert(vertices.size() == original.size())
			for index in vertices.size():
				assert(frozen.to_global(vertices[index]).distance_to(prop_world * original[index]) < 0.0003)
	assert(not holder.get_node("PickBody/PickShape").shape.size.is_zero_approx())
	print(body, " ", clip, " ", phase, " ", plane.rotation, " entry gap ", jump, " m")
	arena.free()

func check_ledge(visual: Node3D, edge: float) -> int:
	var rig: Skeleton3D = visual.skeleton
	var above := 0
	for data: Dictionary in [visual.body_skin, visual.mallet_skin]:
		var matrices: Array[Transform3D] = []
		for index in data.bones.size():
			matrices.append(rig.global_transform * rig.get_bone_global_pose(data.bones[index]) * data.bind_poses[index])
		for surface: Dictionary in data.surfaces:
			var stride: int = surface.stride
			for vertex: int in surface.points.size():
				var point := Vector3.ZERO
				for slot in stride:
					var index := vertex * stride + slot
					point += (matrices[surface.bindings[index]] * surface.points[vertex]) * float(surface.weights[index])
				if point.x > edge + 0.0001 and point.x < edge + 1.9999:
					assert(point.y >= 0.2215, "Mallet or body crosses ledge by %s m" % (0.22 - point.y))
					above += 1
	return above

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
