extends "res://../scripts/test-ophidian-terathan-actions.gd"

const Deaths := preload("res://Presentation/CreatureDeaths.gd")
const Items := preload("res://Presentation/WorldItems.gd")

class Arena extends Node3D:
	var avatars: Dictionary = {}

func run() -> void:
	install_packages()
	for tilt: Vector3 in SLOPES:
		var plane := await support(tilt)
		for body: int in FORMS:
			for phase: float in [0.0, 0.08, 0.45, 0.78]:
				witness(plane, body, phase)
		plane.free()
		await physics_frame
	assert(checked == 1476)
	print("OPHIDIAN AND TERATHAN CORPSES: 36 decoded handoffs across ", checked, " poses")
	quit()

func witness(plane: StaticBody3D, body: int, phase: float) -> void:
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
	var clip := "Death2" if phase > 0.0 else "Death"
	var group := 3 if phase > 0.0 else 5
	assert(avatar.receive_native_action(decode(session, serial, group)))
	previous.advance(0.03 if phase > 0.0 and phase < 0.1 else 0.15)
	previous.seek(previous.current_animation_length * (phase if phase > 0.0 else 0.45), true)
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
	var floor := 0.0
	for frame in 41:
		player.seek(lerpf(time, player.current_animation_length, frame / 40.0), true)
		var normal := plane.global_basis.y.normalized()
		var skin: Dictionary = visual.fall.skin if body == 85 else visual.skin
		floor = Ground.minimum_plane_gap(skin, rig, rig.global_transform, plane.global_position, normal)
		if body == 85:
			floor = minf(floor, Ground.minimum_plane_gap(visual.staff_skin, rig, rig.global_transform, plane.global_position, normal))
		assert(floor >= 0.0015, "Body %d floor gap %s m at phase %s, frame %d, slope %s" % [body, floor, phase, frame, plane.rotation])
		checked += 1
	var prop := visual.model.find_child("OphidianMageStaff", true, false) as MeshInstance3D
	var pose := Transform3D.IDENTITY
	if body == 85:
		assert(prop != null)
		var joint := rig.find_bone("ophidian mage staff")
		pose = rig.global_transform * rig.get_bone_global_pose(joint) * prop.skin.get_bind_pose(0)
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
	if body == 85:
		check_frozen_staff(cadaver, prop, pose)
	assert(not holder.get_node("PickBody/PickShape").shape.size.is_zero_approx())
	print(body, " ", clip, " ", phase, " ", plane.rotation, " entry gap ", jump, " m")
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

func check_frozen_staff(cadaver: Node3D, prop: MeshInstance3D, pose: Transform3D) -> void:
	var frozen := cadaver.find_child("OphidianMageStaff", true, false) as MeshInstance3D
	assert(frozen != null and frozen.mesh.get_surface_count() == prop.mesh.get_surface_count())
	for surface in prop.mesh.get_surface_count():
		var before: PackedVector3Array = prop.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		var after: PackedVector3Array = frozen.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		assert(before.size() == after.size())
		for index in before.size():
			assert(frozen.to_global(after[index]).distance_to(pose * before[index]) < 0.0003)
