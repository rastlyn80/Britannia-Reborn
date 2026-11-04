extends SceneTree

const Registry := preload("res://Presentation/CreatureRegistry.gd")
const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const Arms := preload("res://Presentation/WaterElementalFidgets.gd")

func _initialize() -> void:
	create_timer(20.0).timeout.connect(func(): quit(2))
	call_deferred("run")

func run() -> void:
	var receipt := {"recipe": FileAccess.get_sha256(get_script().resource_path),
		"solver": FileAccess.get_sha256("res://Presentation/WaterElementalFidgets.gd"), "bodies": {}}
	for body: int in [237, 238]:
		var row := Registry.entry(body)
		assert(not row.classic_action_categories.has("12"))
		var scenes := {}
		for treatment: String in row.assets:
			var source: String = row.assets[treatment]
			var expected := "ae58cfc3162b428e452aa56466d7973470ab692db962ab55fcea13d3162a108a" if body == 238 else str(row.asset_sha256[treatment])
			assert(FileAccess.get_sha256(source) == expected)
			var output := "res://local-art/creatures/field-death-%d-%s.scn" % [body, treatment]
			bake(body, treatment, source, output)
			scenes[treatment] = {"source": expected, "scene": FileAccess.get_sha256(output)}
		receipt.bodies[str(body)] = scenes
	var report := FileAccess.open("res://local-art/creatures/field-death-bake.json", FileAccess.WRITE)
	assert(report != null)
	report.store_string(JSON.stringify(receipt, "\t") + "\n")
	report.close()
	quit()

func bake(body: int, treatment: String, path: String, output: String) -> void:
	var rat := body == 238
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var donor := "Idle" if rat else "Death"
	var motion := player.get_animation(donor).duplicate(true) as Animation
	var duration := motion.length
	motion.length = 0.96
	motion.loop_mode = Animation.LOOP_NONE
	var placement := "base" if rat else "bip01 pelvis"
	var root_bone := rig.find_bone(placement)
	var rotations := {}
	var positions := {}
	for track in motion.get_track_count():
		var joint := str(motion.track_get_path(track).get_concatenated_subnames())
		if rig.find_bone(joint) < 0:
			continue
		for key in range(motion.track_get_key_count(track) - 1, 0, -1):
			motion.track_remove_key(track, key)
		match motion.track_get_type(track):
			Animation.TYPE_ROTATION_3D: rotations[joint] = track
			Animation.TYPE_POSITION_3D: positions[joint] = track
	if not positions.has(placement):
		var placement_track := motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(placement_track, motion.track_get_path(rotations[placement]))
		positions[placement] = placement_track
	var floor := INF
	player.deterministic = true
	player.play(donor, 0.0)
	player.advance(0.0)
	for sample in 65:
		var phase := float(sample) / 64.0
		rig.reset_bone_poses()
		player.seek(0.0 if rat else duration * smoothstep(0.27, 0.87, phase), true)
		rig.force_update_all_bone_transforms()
		if rat:
			pose_rat(rig, phase)
		else:
			pose_hind(rig, phase)
		var pose := rig.get_bone_global_pose(root_bone)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.003 - gap)
		rig.set_bone_global_pose(root_bone, pose)
		rig.force_update_all_bone_transforms()
		floor = minf(floor, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		for joint: String in rotations:
			motion.rotation_track_insert_key(rotations[joint], motion.length * phase, rig.get_bone_pose_rotation(rig.find_bone(joint)))
		for joint: String in positions:
			motion.position_track_insert_key(positions[joint], motion.length * phase, rig.get_bone_pose_position(rig.find_bone(joint)))
	assert(player.get_animation_library("").add_animation("Death2", motion) == OK)
	player.stop()
	var out := PackedScene.new()
	assert(out.pack(model) == OK)
	assert(ResourceSaver.save(out, output, ResourceSaver.FLAG_COMPRESS) == OK)
	print(body, " ", treatment, " nominal floor ", floor)
	model.free()

func pose_hind(rig: Skeleton3D, phase: float) -> void:
	var rear := smoothstep(0.04, 0.36, phase) * (1.0 - smoothstep(0.40, 0.73, phase))
	var roll := smoothstep(0.44, 0.87, phase)
	turn(rig, "bip01 pelvis", Vector3.RIGHT, -0.80 * rear + 0.16 * roll)
	turn(rig, "bip01 pelvis", Vector3.FORWARD, 1.18 * roll)
	turn(rig, "bip01 neck", Vector3.RIGHT, -0.24 * rear + 0.30 * roll)
	turn(rig, "bip01 neck1", Vector3.UP, 0.39 * roll)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, 0.21 * rear + sign * 0.09 * roll)
		turn(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.78 * rear)
		turn(rig, "bip01 " + side + " thigh", Vector3.RIGHT, sign * 0.15 * roll)
		var settle := smoothstep(0.54, 0.97, phase)
		var prefix := "bip01 " + side
		settle_chain(rig, prefix + " thigh", prefix + " calf", prefix + " foot",
			Vector3(0.25 + sign * 0.05, -0.24, 0.06 + sign * 0.13), settle)
		settle_chain(rig, prefix + " upperarm", prefix + " forearm", prefix + " hand",
			Vector3(0.26 + sign * 0.04, -0.23, 0.09 + sign * 0.07), settle)

func pose_rat(rig: Skeleton3D, phase: float) -> void:
	var collapse := smoothstep(0.10, 0.68, phase)
	var flinch := smoothstep(0.0, 0.31, phase) * (1.0 - smoothstep(0.31, 0.59, phase))
	turn(rig, "base", Vector3.FORWARD, 0.10 * collapse)
	turn(rig, "spine", Vector3.RIGHT, 0.48 * flinch + 0.09 * collapse)
	turn(rig, "neck", Vector3.RIGHT, 0.26 * collapse)
	turn(rig, "head", Vector3.RIGHT, 0.20 * flinch)
	turn(rig, "tailbone", Vector3.UP, -0.32 * collapse)
	turn(rig, "tail", Vector3.UP, -0.29 * collapse)
	for side: String in ["L", "R"]:
		var sign := 1.0 if side == "L" else -1.0
		turn(rig, "base_" + side, Vector3.FORWARD, sign * -0.70 * collapse)
		turn(rig, "base.001_" + side, Vector3.FORWARD, sign * -0.62 * collapse)

func settle_chain(rig: Skeleton3D, proximal: String, middle: String, distal: String, target: Vector3, amount: float) -> void:
	if amount <= 0.0:
		return
	var upper := rig.find_bone(proximal)
	var joint := rig.find_bone(middle)
	var end := rig.find_bone(distal)
	var a := rig.get_bone_global_pose(upper).origin
	var b := rig.get_bone_global_pose(joint).origin
	var c := rig.get_bone_global_pose(end).origin
	var goal := c.lerp(a + rig.global_basis.inverse() * target, amount)
	var direction := (goal - a).normalized()
	var first := a.distance_to(b)
	var second := b.distance_to(c)
	var distance := clampf(a.distance_to(goal), absf(first - second) + 0.001, first + second - 0.001)
	var along := (first * first - second * second + distance * distance) / (2.0 * distance)
	var pole := (b - a).slide(direction).normalized()
	if pole.is_zero_approx():
		pole = Vector3.UP.slide(direction).normalized()
	Arms.aim(rig, upper, joint, a + direction * along + pole * sqrt(maxf(0.0, first * first - along * along)))
	rig.force_update_all_bone_transforms()
	Arms.aim(rig, joint, end, a + direction * distance)
	rig.force_update_all_bone_transforms()

func turn(rig: Skeleton3D, name: String, axis: Vector3, amount: float) -> void:
	var bone := rig.find_bone(name)
	assert(bone >= 0)
	var pose := rig.get_bone_global_pose(bone)
	pose.basis = Basis(Quaternion((rig.global_basis.inverse() * axis).normalized(), amount)) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
