extends "res://../scripts/bake-troll-actions.gd"

const ACTIONS := {2: "Death2", 4: "WingBackhand", 6: "WingJab", 15: "WingOpenRecoil", 16: "WingFoldRecoil"}
const DONOR := "res://local-art/creatures/mongbat-air-death-donor.gltf"

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(DONOR, state) == OK)
	var donor := document.generate_scene(state)
	root.add_child(donor)
	var row := Registry.entry(39)
	assert(row.classic_gesture_batch == "mongbat_fidgets")
	var scenes := {}
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var output := "res://local-art/creatures/mongbat-actions-%s.scn" % treatment
		bake_mongbat(source, output, donor)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(output)}
	donor.free()
	var receipt := FileAccess.open("res://local-art/creatures/mongbat-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	var inputs := {}
	for path: String in [get_script().resource_path, DONOR, "res://../scripts/bake-troll-actions.gd",
			"res://../scripts/bake-skeleton-actions.gd", "res://Presentation/WaterElementalFidgets.gd",
			"res://Presentation/SourceGroundLookup.gd"]:
		inputs[path.get_file()] = FileAccess.get_sha256(path)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func bake_mongbat(source: String, output: String, donor: Node) -> void:
	var model := (load(source) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin := Ground.skin_points(mesh, rig)
	var skins: Array[Dictionary] = [skin]
	var library := player.get_animation_library("")
	player.deterministic = true
	add_air_death(player, rig, skin, donor)
	for slot: int in ACTIONS:
		var motion := grounded_fall(player, rig, skin) if slot == 2 else fit_troll(player, rig, skins, slot)
		assert(library.add_animation(ACTIONS[slot], motion) == OK)
	player.stop()
	var result := PackedScene.new()
	assert(result.pack(model) == OK and ResourceSaver.save(result, output, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()

func grounded_fall(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var source := player.get_animation("AirDeath")
	var clip := source.duplicate(true) as Animation
	clip.length = 0.80
	var space := rig.get_parent() as Node3D
	var labels := {}
	var initial := {}
	player.play("Idle", 0.0)
	player.advance(0.0)
	player.seek(0.0, true)
	rig.force_update_all_bone_transforms()
	for track in clip.get_track_count():
		var joint := rig.find_bone(str(clip.track_get_path(track).get_concatenated_subnames()))
		var type := clip.track_get_type(track)
		assert(type in [Animation.TYPE_POSITION_3D, Animation.TYPE_ROTATION_3D])
		labels[track] = joint
		if type == Animation.TYPE_POSITION_3D:
			initial[track] = space.position if joint < 0 else rig.get_bone_pose_position(joint)
		else:
			assert(joint >= 0)
			initial[track] = rig.get_bone_pose_rotation(joint)
		for key in range(clip.track_get_key_count(track) - 1, -1, -1):
			clip.track_remove_key(track, key)
	var hip := rig.find_bone("bip01")
	player.play("AirDeath", 0.0)
	player.advance(0.0)
	for frame in 161:
		var phase := float(frame) / 160.0
		var time := phase * clip.length
		var blend := smoothstep(0.01, 0.56, phase)
		player.seek(source.length * lerpf(0.36, 1.0, phase), true)
		for track in clip.get_track_count():
			var joint: int = labels[track]
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var rest: Vector3 = initial[track]
				if joint < 0:
					space.position = rest.lerp(space.position, blend)
				else:
					rig.set_bone_pose_position(joint, rest.lerp(rig.get_bone_pose_position(joint), blend))
			else:
				var rest: Quaternion = initial[track]
				rig.set_bone_pose_rotation(joint, rest.slerp(rig.get_bone_pose_rotation(joint), blend))
		rig.force_update_all_bone_transforms()
		var pose := rig.get_bone_global_pose(hip)
		var gap := Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (0.004 - gap)
		rig.set_bone_global_pose(hip, pose)
		for track in clip.get_track_count():
			var joint: int = labels[track]
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D:
				var value := space.position if joint < 0 else rig.get_bone_pose_position(joint)
				clip.position_track_insert_key(track, time, value)
			else:
				clip.rotation_track_insert_key(track, time, rig.get_bone_pose_rotation(joint))
	return clip

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var hip := joint_world(rig, "bip01 pelvis")
	var left := joint_world(rig, "bip01 l hand")
	var right := joint_world(rig, "bip01 r hand")
	var pulse := smoothstep(0.04, 0.38, phase) * (1.0 - smoothstep(0.57, 1.0, phase))
	if slot in [4, 6]:
		var sweep := smoothstep(0.18, 0.63, phase) * (1.0 - smoothstep(0.67, 1.0, phase))
		var sign := 1.0 if slot == 4 else -1.0
		turn_world(rig, "bip01 spine1", Vector3.UP, 0.39 * pulse * sign)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, (0.11 if slot == 4 else 0.31) * pulse)
		wing(rig, "l", -0.27 * pulse, 0.23 * pulse)
		wing(rig, "r", 0.33 * pulse, -0.23 * pulse)
		if slot == 4:
			fit_arm(rig, "l", left.lerp(hip + Vector3(0.45, 0.45, 0.63), pulse).lerp(hip + Vector3(0.57, 0.20, 0.43), sweep))
		else:
			fit_arm(rig, "r", right.lerp(hip + Vector3(-0.26, 0.55, 0.73), pulse))
			fit_arm(rig, "l", left.lerp(hip + Vector3(0.36, 0.12, 0.38), sweep))
		return
	var sign := 1.0 if slot == 15 else -1.0
	turn_world(rig, "bip01 spine2", Vector3.UP, sign * 0.27 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, sign * -0.25 * pulse)
	wing(rig, "l", -0.66 * sign * pulse, 0.40 * pulse)
	wing(rig, "r", 0.35 * sign * pulse, -0.27 * pulse)
	fit_arm(rig, "r", right.lerp(hip + Vector3(-0.26, 0.43, 0.27), pulse))

func wing(rig: Skeleton3D, side: String, fold: float, tilt: float) -> void:
	turn_world(rig, "mongbat " + side + " wingmain1", Vector3.FORWARD, fold)
	turn_world(rig, "mongbat " + side + " wingmain2", Vector3.UP, tilt)

func add_air_death(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, donor: Node) -> void:
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var base := player.get_node(player.root_node).get_path_to(rig)
	var donor_path := donor_player.get_node(donor_player.root_node).get_path_to(donor_rig)
	var motion := donor_player.get_animation("AirDeath").duplicate(true) as Animation
	for track in motion.get_track_count():
		var path := motion.track_get_path(track)
		if str(path) == "VisualRoot/SourceSpace":
			assert(motion.track_get_type(track) == Animation.TYPE_POSITION_3D and
				player.get_node(player.root_node).has_node(path))
			continue
		assert(str(path.get_concatenated_names()) == str(donor_path) and path.get_subname_count() == 1)
		var name := str(path.get_concatenated_subnames())
		var index := rig.find_bone(name)
		assert(index >= 0 and index == donor_rig.find_bone(name))
		assert(rig.get_bone_rest(index).is_equal_approx(donor_rig.get_bone_rest(index)))
		motion.track_set_path(track, NodePath(str(base) + ":" + name))
	var library := player.get_animation_library("")
	assert(library.add_animation("AirDeath", motion) == OK)
	player.play("AirDeath", 0.0)
	player.advance(0.0)
	player.seek(motion.length, true)
	var baseline := 0.004 - clearance(skin, rig)
	var joint := rig.find_bone("bip01")
	var joint_path := NodePath(str(base) + ":bip01")
	var track := motion.find_track(joint_path, Animation.TYPE_POSITION_3D)
	assert(track >= 0)
	var floor := PackedVector3Array()
	for frame in 241:
		player.seek(motion.length * float(frame) / 240.0, true)
		var gap := clearance(skin, rig)
		var local := rig.get_bone_pose_position(joint)
		var original := rig.get_bone_global_pose(joint)
		var lift := maxf(baseline, 0.004 - gap)
		original.origin += rig.global_basis.inverse() * Vector3.UP * lift
		rig.set_bone_global_pose(joint, original)
		floor.append(rig.get_bone_pose_position(joint))
		rig.set_bone_pose_position(joint, local)
	for key in range(motion.track_get_key_count(track) - 1, -1, -1):
		motion.track_remove_key(track, key)
	motion.track_set_interpolation_type(track, Animation.INTERPOLATION_LINEAR)
	for frame in floor.size():
		motion.position_track_insert_key(track, motion.length * float(frame) / 240.0, floor[frame])
	player.stop()

func clearance(skin: Dictionary, rig: Skeleton3D) -> float:
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
