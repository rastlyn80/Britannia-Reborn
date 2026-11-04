extends "res://../scripts/bake-quadruped-actions.gd"

func run() -> void:
	var scenes := {}
	for body: int in [217, 211]:
		var row := Registry.entry(body)
		assert(not row.has("classic_gesture_batch"))
		var treatments := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var source := Registry.asset_path(row, treatment)
			var output := "res://local-art/creatures/dog-bear-actions-%d-%s.scn" % [body, treatment]
			assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
			bake(body, source, output)
			treatments[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
		scenes[str(body)] = treatments
	var receipt := FileAccess.open("res://local-art/creatures/dog-bear-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in [get_script().resource_path, "res://../scripts/bake-quadruped-actions.gd",
			"res://Presentation/WaterElementalFidgets.gd", "res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake(body: int, path: String, output: String) -> void:
	var dog := body == 217
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var library := player.get_animation_library("")
	library.rename_animation("Death", "RecoveredDeath")
	player.deterministic = true
	library.rename_animation("Attack", "RecoveredAttack")
	assert(library.add_animation("Attack", calibrated_attack(player, rig, skin)) == OK)
	for slot: int in ([6, 8, 10, 12] if dog else [4, 6, 8, 10, 12]):
		var label: String = "BearRearStrike" if not dog and slot == 6 else ROUTES[slot]
		assert(library.add_animation(label, build(225 if dog else body, slot, player, rig, skin)) == OK)
	player.stop()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func calibrated_attack(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var motion := player.get_animation("RecoveredAttack").duplicate(true) as Animation
	var pelvis := rig.find_bone("bip01 pelvis")
	var root := player.get_node(player.root_node)
	var path := NodePath(str(root.get_path_to(rig)) + ":bip01 pelvis")
	var position := motion.find_track(path, Animation.TYPE_POSITION_3D)
	if position < 0:
		position = motion.add_track(Animation.TYPE_POSITION_3D)
		motion.track_set_path(position, path)
	for key in range(motion.track_get_key_count(position) - 1, -1, -1):
		motion.track_remove_key(position, key)
	player.play("RecoveredAttack", 0.0)
	player.advance(0.0)
	motion.track_set_interpolation_type(position, Animation.INTERPOLATION_LINEAR)
	for frame in 241:
		var time := motion.length * float(frame) / 240.0
		rig.reset_bone_poses()
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		var pose := rig.get_bone_global_pose(pelvis)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * maxf(0.0, 0.004 - gap)
		rig.set_bone_global_pose(pelvis, pose)
		motion.position_track_insert_key(position, time, rig.get_bone_pose_position(pelvis))
	return motion

func pose(rig: Skeleton3D, wolf: bool, slot: int, phase: float) -> float:
	if wolf:
		return super.pose(rig, true, slot, phase)
	var pulse := smoothstep(0.03, 0.48, phase) * (1.0 - smoothstep(0.52, 0.99, phase))
	if slot == 6:
		turn(rig, "pelvis", Vector3.RIGHT, -1.07 * pulse)
		turn(rig, "spine1", Vector3.RIGHT, 0.11 * pulse)
		turn(rig, "neck", Vector3.RIGHT, 0.19 * pulse)
		turn(rig, "head", Vector3.RIGHT, 0.20 * pulse)
		for leg: String in ["l", "r"]:
			var sign := 1.0 if leg == "l" else -1.0
			turn(rig, leg + " thigh", Vector3.RIGHT, 0.89 * pulse)
			turn(rig, leg + " calf", Vector3.RIGHT, 0.16 * pulse)
			turn(rig, leg + " upperarm", Vector3.RIGHT, 0.39 * pulse)
			turn(rig, leg + " forearm", Vector3.RIGHT, -0.73 * pulse)
			turn(rig, leg + " upperarm", Vector3.FORWARD, sign * -0.24 * pulse)
		return 0.0
	if slot in [4, 10]:
		var amount := 1.0 - smoothstep(0.0, 0.70, phase) if slot == 4 else pulse
		turn(rig, "spine1", Vector3.RIGHT, 0.12 * amount)
		turn(rig, "neck", Vector3.RIGHT, 0.34 * amount)
		turn(rig, "head", Vector3.UP, -0.20 * amount if slot == 4 else 0.16 * amount)
		if slot == 10:
			turn(rig, "l upperarm", Vector3.RIGHT, 0.26 * pulse)
			turn(rig, "l forearm", Vector3.RIGHT, -0.47 * pulse)
		return 0.0
	var fall := smoothstep(0.05, 0.80, phase)
	var settle := smoothstep(0.42, 0.97, phase)
	var roll := -1.22 * fall if slot == 12 else 0.15 * fall
	turn(rig, "pelvis", Vector3.RIGHT, (0.29 if slot == 8 else 0.13) * fall)
	turn(rig, "pelvis", Vector3.FORWARD, roll)
	turn(rig, "spine1", Vector3.RIGHT, 0.16 * fall)
	turn(rig, "neck", Vector3.RIGHT, 0.34 * fall)
	turn(rig, "head", Vector3.RIGHT, -0.19 * fall)
	for leg: String in ["l", "r"]:
		var sign := 1.0 if leg == "l" else -1.0
		var lateral := sign * 0.08 + (-0.20 if slot == 12 else 0.0)
		settle_chain(rig, leg + " upperarm", leg + " forearm", leg + " hand",
			Vector3(lateral, -0.19, 0.34 if slot == 8 else 0.27), settle)
		settle_chain(rig, leg + " thigh", leg + " calf", leg + " horselink",
			Vector3(lateral, -0.22, 0.09 + sign * 0.12), settle)
		turn(rig, leg + " horselink", Vector3.RIGHT, -0.30 * settle)
	translate_hip(rig, Vector3(-0.13 * fall if slot == 12 else 0.0, 0.0, 0.10 * fall))
	return 0.0
