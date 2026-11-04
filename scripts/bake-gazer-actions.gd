extends "res://../scripts/bake-zombie-actions.gd"

const EYES := ["gazers_gazer_eyebone1", "gazers_gazer_eyebone2", "gazers_gazer_eyebone3", "gazers_gazer_eyebone4"]

func run() -> void:
	var row := Registry.entry(22)
	var scenes := {}
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		assert(library.add_animation("Death2", fit_hover(player, rig, skin, "Death2")) == OK)
		assert(library.add_animation("EyeSpread", fit_hover(player, rig, skin, "EyeSpread")) == OK)
		assert(library.add_animation("EyeVolley", fit_hover(player, rig, skin, "EyeVolley")) == OK)
		Exact.check_earlier_keys(player, source)
		player.stop()
		var packed := PackedScene.new()
		var target := "res://local-art/creatures/gazer-actions-%s.scn" % treatment
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(source), "scene": FileAccess.get_sha256(target)}
		model.free()
		print("GAZER PREVIEW: ", treatment, " retained tracks and distinct eye spread and rolling collapse")
	write_receipt("gazer-actions", 22, scenes, ["bake-gazer-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_hover(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary, motion: String) -> Animation:
	var death := motion == "Death2"
	var volley := motion == "EyeVolley"
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.98 if death else (0.58 if volley else 0.82)
	clip.loop_mode = Animation.LOOP_NONE
	var path := str(player.get_node(player.root_node).get_path_to(rig))
	var placement_path := NodePath(path + ":bip01")
	var placement := clip.find_track(placement_path, Animation.TYPE_POSITION_3D)
	if placement < 0:
		placement = clip.add_track(Animation.TYPE_POSITION_3D)
		clip.track_set_path(placement, placement_path)
	var rotations := {}
	for track in clip.get_track_count():
		for key in range(clip.track_get_key_count(track) - 1, 0, -1):
			clip.track_remove_key(track, key)
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D:
			rotations[str(clip.track_get_path(track).get_concatenated_subnames())] = track
	for name: String in ["bip01", "bip01 head", "bip01 ponytail1", "bip01 ponytail2"] + EYES:
		if not rotations.has(name):
			var track := clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, NodePath(path + ":" + name))
			rotations[name] = track
	player.play("Idle", 0.0)
	player.advance(0.0)
	var hover := clearance(rig, skin)
	var pelvis := rig.find_bone("bip01")
	for frame in 161:
		var phase := float(frame) / 160.0
		rig.reset_bone_poses()
		player.seek(0.0, true)
		rig.force_update_all_bone_transforms()
		var amount := smoothstep(0.08, 0.95, phase) if death else smoothstep(0.04, 0.43, phase) * (1.0 - smoothstep(0.55, 1.0, phase))
		turn_world(rig, "bip01", Vector3.FORWARD, (1.43 if death else (-0.17 if volley else -0.09)) * amount)
		turn_world(rig, "bip01 head", Vector3.RIGHT, (0.28 if death else (0.27 if volley else -0.09)) * amount)
		turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, (0.35 if death else -0.24) * amount)
		turn_world(rig, "bip01 ponytail2", Vector3.UP, (0.23 if death else 0.32) * amount)
		for index in EYES.size():
			var eye: String = EYES[index]
			var sign := 1.0 if index % 2 == 0 else -1.0
			turn_world(rig, eye, Vector3.RIGHT, sign * (0.25 + index * 0.06) * amount)
			turn_world(rig, eye, Vector3.UP, sign * (0.32 if death else (0.58 if volley else 0.23)) * amount)
		var pose := rig.get_bone_global_pose(pelvis)
		var target := lerpf(hover, 0.004, smoothstep(0.12, 0.94, phase)) if death else hover + 0.035 * amount
		pose.origin += rig.global_basis.inverse() * Vector3.UP * (target - clearance(rig, skin))
		rig.set_bone_global_pose(pelvis, pose)
		var time := phase * clip.length
		clip.position_track_insert_key(placement, time, rig.get_bone_pose_position(pelvis))
		for label: String in rotations:
			clip.rotation_track_insert_key(rotations[label], time, rig.get_bone_pose_rotation(rig.find_bone(label)))
	return clip

func clearance(rig: Skeleton3D, skin: Dictionary) -> float:
	rig.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)
