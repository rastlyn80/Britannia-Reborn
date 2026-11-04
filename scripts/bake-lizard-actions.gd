extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Arms := preload("res://Presentation/WaterElementalFidgets.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const LABELS := {4: "ClassicOverhead", 5: "Attack2", 6: "Attack3", 15: "RightGuard", 16: "LeftGuard", 18: "Fidget2"}
# The four phases follow the hilt and shaft in the front, side and back views.
const HILTS := {
	4: [Vector3(-0.68, 0.61, 0.48), Vector3(-0.65, 0.87, 0.40), Vector3(-0.55, 0.27, 1.04), Vector3(-0.60, 0.13, 0.88)],
	5: [Vector3(-1.04, 0.35, 0.12), Vector3(-0.88, 0.42, 0.23), Vector3(-0.50, 0.32, 1.16), Vector3(-0.61, 0.42, 0.81)],
	6: [Vector3(-0.61, 0.23, 0.60), Vector3(-0.63, 0.16, 0.67), Vector3(-0.51, 0.29, 0.98), Vector3(-0.60, 0.23, 0.75)],
	15: [Vector3(-0.53, 0.31, 0.23), Vector3(-0.50, 0.35, 0.20), Vector3(-0.50, 0.32, 0.25), Vector3(-0.52, 0.29, 0.24)],
	16: [Vector3(-0.53, 0.40, 0.40), Vector3(-0.45, 0.46, 0.25), Vector3(-0.41, 0.39, 0.19), Vector3(-0.49, 0.26, 0.24)],
	18: [Vector3(-0.58, 0.26, 0.39), Vector3(-0.54, 0.63, 0.29), Vector3(-0.54, 0.69, 0.10), Vector3(-0.54, 0.41, 0.26)]
}
const SHAFTS := {
	4: [Vector3(-0.03, 1.0, 0.13), Vector3(-0.25, 0.84, 0.46), Vector3(0.10, 0.03, 1.0), Vector3(-0.04, 0.07, 1.0)],
	5: [Vector3(-0.99, -0.14, 0.12), Vector3(-0.72, 0.49, 0.64), Vector3(0.13, 0.0, 1.0), Vector3(-0.28, 0.64, 0.71)],
	6: [Vector3(-0.12, -0.33, 0.94), Vector3(-0.14, -0.38, 0.92), Vector3(0.13, 0.0, 1.0), Vector3(-0.09, 0.07, 1.0)],
	15: [Vector3(-0.22, 0.92, 0.31), Vector3(-0.18, 0.96, 0.25), Vector3(-0.16, 0.91, 0.38), Vector3(-0.14, 0.85, 0.49)],
	16: [Vector3(-0.27, 0.57, 0.78), Vector3(-0.08, 0.26, 0.97), Vector3(0.06, 0.28, 0.96), Vector3(-0.10, 0.34, 0.94)],
	18: [Vector3(-0.16, 0.80, 0.58), Vector3(-0.07, 0.99, 0.09), Vector3(-0.06, 0.85, -0.52), Vector3(-0.08, 0.96, -0.24)]
}

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var scenes := {}
	for body: int in [35, 36]:
		var row := Registry.entry(body)
		assert(row.has("armed_native_receipt_sha256") and not row.has("classic_gesture_batch"))
		var source: String = row.assets.modern
		assert(FileAccess.get_sha256(source) == row.asset_sha256.modern)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		player.deterministic = true
		for group: int in LABELS:
			var motion := fit(player, rig, group)
			assert(library.add_animation(LABELS[group], motion) == OK)
		assert(library.add_animation("Death2", rear_collapse(model, player, rig)) == OK)
		player.stop()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		var target := "res://local-art/creatures/lizard-actions-%d.scn" % body
		assert(ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[str(body)] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
	var output := FileAccess.open("res://local-art/creatures/lizard-actions-bake.json", FileAccess.WRITE)
	assert(output != null)
	output.store_string(JSON.stringify({"recipe": FileAccess.get_sha256(get_script().resource_path),
		"arm_solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"),
		"skin_solver": FileAccess.get_sha256("res://Presentation/SourceGroundLookup.gd"), "scenes": scenes}))
	output.close()
	quit()

func fit(player: AnimationPlayer, rig: Skeleton3D, group: int) -> Animation:
	var donor := "Fidget" if group == 18 else ("Hit" if group >= 15 else "Attack")
	var motion := player.get_animation(donor).duplicate(true) as Animation
	var source_duration := motion.length
	motion.length = 0.8 if group == 18 else (0.48 if group >= 15 else 0.64)
	var joints := ["bip01 r upperarm", "bip01 r forearm", "bip01 r hand"]
	var rotations := {}
	var positions := {}
	for track in motion.get_track_count():
		var path := motion.track_get_path(track)
		var bone := rig.find_bone(str(path.get_concatenated_subnames()))
		var type := motion.track_get_type(track)
		if bone >= 0 and type == Animation.TYPE_ROTATION_3D:
			rotations[bone] = track
		elif bone >= 0 and type == Animation.TYPE_POSITION_3D:
			positions[bone] = track
		else:
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				var time := motion.track_get_key_time(track, key)
				motion.track_set_key_time(track, key, time * motion.length / source_duration)
			continue
		for key in range(motion.track_get_key_count(track) - 1, -1, -1):
			motion.track_remove_key(track, key)
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	var neutral_rotations := {}
	var neutral_positions := {}
	for bone: int in rotations:
		neutral_rotations[bone] = rig.get_bone_pose_rotation(bone)
	for bone: int in positions:
		neutral_positions[bone] = rig.get_bone_pose_position(bone)
	var hip := rig.find_bone("bip01 pelvis")
	var shoulder := rig.find_bone(joints[0])
	var elbow := rig.find_bone(joints[1])
	var hand := rig.find_bone(joints[2])
	var weapon := rig.find_bone("lizardman weapon")
	var maximum_error := 0.0
	player.play(donor, 0.0)
	player.advance(0.0)
	for sample in 61:
		var phase := float(sample) / 60.0
		rig.reset_bone_poses()
		player.seek(source_duration * phase, true)
		var blend: float = {4: 0.46, 5: 0.44, 6: 0.20, 15: 0.34, 16: 0.43, 18: 0.37}[group]
		for bone: int in rotations:
			var neutral: Quaternion = neutral_rotations[bone]
			rig.set_bone_pose_rotation(bone, neutral.slerp(rig.get_bone_pose_rotation(bone), blend))
		for bone: int in positions:
			var neutral: Vector3 = neutral_positions[bone]
			rig.set_bone_pose_position(bone, neutral.lerp(rig.get_bone_pose_position(bone), blend))
		rig.force_update_all_bone_transforms()
		var target := rig.get_bone_global_pose(hip).origin + rig.global_basis.inverse() * sample_path(HILTS[group], phase)
		maximum_error = maxf(maximum_error, move_hand(rig, shoulder, elbow, hand, target))
		var desired := (rig.global_basis.inverse() * sample_path(SHAFTS[group], phase)).normalized()
		var shaft := rig.get_bone_global_pose(weapon).basis.y.normalized()
		var grip := rig.get_bone_global_pose(hand)
		grip.basis = Basis(Quaternion(shaft, desired)) * grip.basis
		rig.set_bone_global_pose(hand, grip)
		rig.force_update_all_bone_transforms()
		assert(rig.get_bone_global_pose(weapon).basis.y.normalized().dot(desired) > 0.99)
		for bone: int in rotations:
			motion.rotation_track_insert_key(rotations[bone], motion.length * phase, rig.get_bone_pose_rotation(bone))
		for bone: int in positions:
			motion.position_track_insert_key(positions[bone], motion.length * phase, rig.get_bone_pose_position(bone))
	print(group, " greatest reach projection ", maximum_error)
	return motion

func rear_collapse(model: Node3D, player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.64
	clip.loop_mode = Animation.LOOP_NONE
	var joints := ["bip01 pelvis", "bip01 spine1", "bip01 spine2", "bip01 r upperarm",
		"bip01 r forearm", "bip01 r hand", "bip01 l upperarm", "bip01 l forearm",
		"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]
	var rotation_tracks := {}
	for track in clip.get_track_count():
		var name := str(clip.track_get_path(track).get_concatenated_subnames())
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if name in joints and clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotation_tracks[name] = track
	var pelvis := rig.find_bone("bip01 pelvis")
	var pelvis_path := clip.track_get_path(rotation_tracks["bip01 pelvis"])
	var position_track := clip.find_track(pelvis_path, Animation.TYPE_POSITION_3D)
	if position_track < 0:
		position_track = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(position_track, pelvis_path)
	var shoulder := rig.find_bone("bip01 r upperarm")
	var elbow := rig.find_bone("bip01 r forearm")
	var hand := rig.find_bone("bip01 r hand")
	var weapon := rig.find_bone("lizardman weapon")
	var meshes: Array[Dictionary] = []
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if mesh.skin != null:
			meshes.append(Ground.skin_points(mesh, rig))
	var furthest := 0.0
	player.play("Idle", 0.0)
	player.advance(0.0)
	for i in 65:
		var phase := float(i) / 64.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var fall := smoothstep(0.03, 0.89, phase)
		var flinch := sin(PI * smoothstep(0.02, 0.89, phase))
		rotate(rig, "bip01 pelvis", Vector3.RIGHT, -1.87 * fall)
		rotate(rig, "bip01 pelvis", Vector3.UP, 0.19 * fall)
		rotate(rig, "bip01 spine1", Vector3.RIGHT, 0.22 * flinch)
		rotate(rig, "bip01 spine2", Vector3.FORWARD, 0.19 * fall)
		rotate(rig, "bip01 l upperarm", Vector3.FORWARD, 0.50 * flinch + 0.20 * fall)
		rotate(rig, "bip01 l forearm", Vector3.RIGHT, -0.31 * flinch)
		var tail_settle := smoothstep(0.24, 0.87, phase)
		rotate(rig, "bip01 tail", Vector3.RIGHT, -1.36 * tail_settle)
		rotate(rig, "bip01 tail", Vector3.UP, 0.36 * tail_settle)
		for tail: String in ["bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 tail4"]:
			rotate(rig, tail, Vector3.UP, 0.12 * tail_settle)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			rotate(rig, "bip01 " + side + " thigh", Vector3.RIGHT, (0.34 + sign * 0.15) * fall)
			rotate(rig, "bip01 " + side + " calf", Vector3.RIGHT, (-0.42 + sign * 0.12) * flinch - 0.11 * fall)
		var hip := rig.get_bone_global_pose(pelvis)
		var goal := sample_path([Vector3(-0.58, 0.49, 0.30), Vector3(-0.59, 0.41, -0.24),
			Vector3(-0.58, 0.16, -0.48), Vector3(-0.58, -0.05, -0.45)], phase)
		move_hand(rig, shoulder, elbow, hand, hip.origin + rig.global_basis.inverse() * goal)
		var shaft_target := sample_path([Vector3(-0.07, 1.0, 0.10), Vector3(-0.15, 0.55, -0.86),
			Vector3(-0.16, 0.13, -1.0), Vector3(-0.24, 0.04, -1.0)], phase)
		var desired := (rig.global_basis.inverse() * shaft_target).normalized()
		var grip := rig.get_bone_global_pose(hand)
		grip.basis = Basis(Quaternion(rig.get_bone_global_pose(weapon).basis.y.normalized(), desired)) * grip.basis
		rig.set_bone_global_pose(hand, grip)
		rig.force_update_all_bone_transforms()
		var floor := INF
		for skin: Dictionary in meshes:
			floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		hip.origin += rig.global_basis.inverse() * Vector3(0.03 * fall, 0.004 - floor, -0.17 * fall)
		rig.set_bone_global_pose(pelvis, hip)
		rig.force_update_all_bone_transforms()
		var body_gap := Ground.minimum_plane_gap(meshes[0], rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		furthest = maxf(furthest, body_gap)
		var time := phase * clip.length
		clip.position_track_insert_key(position_track, time, rig.get_bone_pose_position(pelvis))
		for joint: String in rotation_tracks:
			clip.rotation_track_insert_key(rotation_tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	print("Rear collapse: greatest lift of skin above weapon clearance ", furthest)
	return clip

func rotate(rig: Skeleton3D, name: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(name)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()

func sample_path(points: Array, phase: float) -> Vector3:
	var segment := mini(2, int(phase * 3.0))
	var a: Vector3 = points[segment]
	return a.lerp(points[segment + 1], smoothstep(0.0, 1.0, phase * 3.0 - segment))

func move_hand(rig: Skeleton3D, shoulder: int, elbow: int, hand: int, target: Vector3) -> float:
	var a := rig.get_bone_global_pose(shoulder).origin
	var b := rig.get_bone_global_pose(elbow).origin
	var c := rig.get_bone_global_pose(hand).origin
	var direction := (target - a).normalized()
	var upper := a.distance_to(b)
	var lower := b.distance_to(c)
	var distance := clampf(a.distance_to(target), absf(upper - lower) + 0.001, upper + lower - 0.001)
	var along := (upper * upper - lower * lower + distance * distance) / (2.0 * distance)
	var pole := (b - a).slide(direction).normalized()
	if pole.is_zero_approx():
		pole = Vector3.UP.slide(direction).normalized()
	Arms.aim(rig, shoulder, elbow, a + direction * along + pole * sqrt(maxf(0.0, upper * upper - along * along)))
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, elbow, hand, a + direction * distance)
	rig.force_update_all_bone_transforms()
	return rig.get_bone_global_pose(hand).origin.distance_to(target)
