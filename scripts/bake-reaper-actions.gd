extends "res://../scripts/bake-troll-actions.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const FITS := {2: "Death2", 4: "BranchRake", 6: "OppositeSweep", 15: "LeftBarkRecoil",
	16: "RightBarkRecoil", 18: "CrownShake"}

func run() -> void:
	var scenes := {}
	var row := Registry.entry(47)
	for treatment: String in row.assets:
		var path := Registry.asset_path(row, treatment)
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		library.rename_animation("Attack", "RecoveredAttack")
		assert(library.add_animation("Attack", settle_attack_leaf(player, rig, skins[0])) == OK)
		for slot: int in FITS:
			assert(library.add_animation(FITS[slot], fit_troll(player, rig, skins, slot)) == OK)
		Exact.check_earlier_keys(player, path)
		player.stop()
		var output := PackedScene.new()
		var target := "res://local-art/creatures/reaper-actions-%s.scn" % treatment
		assert(output.pack(model) == OK and ResourceSaver.save(output, target, ResourceSaver.FLAG_COMPRESS) == OK)
		scenes[treatment] = {"source": FileAccess.get_sha256(path), "scene": FileAccess.get_sha256(target)}
		model.free()
		print("Prepared ", target)
	var inputs := {}
	for file: String in [get_script().resource_path, "res://../scripts/bake-troll-actions.gd",
		"res://../scripts/bake-skeleton-actions.gd",
		"res://Presentation/WaterElementalFidgets.gd",
		"res://Presentation/SourceGroundLookup.gd"]:
		inputs[file.get_file()] = FileAccess.get_sha256(file)
	var receipt := FileAccess.open("res://local-art/creatures/reaper-actions-bake.json", FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_string(JSON.stringify({"inputs": inputs, "scenes": scenes}))
	receipt.close()
	quit()

func settle_attack_leaf(player: AnimationPlayer, rig: Skeleton3D, skin: Dictionary) -> Animation:
	var clip := player.get_animation("RecoveredAttack").duplicate(true) as Animation
	var leaf := rig.find_bone("leaf_7")
	var relative := player.get_node(player.root_node).get_path_to(rig)
	var path := NodePath(str(relative) + ":leaf_7")
	var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
	if track < 0:
		track = clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(track, path)
	for key in range(clip.track_get_key_count(track) - 1, -1, -1):
		clip.track_remove_key(track, key)
	player.play("RecoveredAttack", 0.0)
	player.advance(0.0)
	for frame in 161:
		var time := clip.length * frame / 160.0
		player.seek(time, true)
		rig.force_update_all_bone_transforms()
		var original := rig.get_bone_pose_rotation(leaf)
		var best := original
		var gap := floor_gap(skin, rig)
		if gap < -0.002:
			for amount: float in [0.08, -0.08, 0.16, -0.16, 0.26, -0.26, 0.42, -0.42]:
				for axis: Vector3 in [Vector3.RIGHT, Vector3.FORWARD]:
					rig.set_bone_pose_rotation(leaf, original)
					rig.force_update_all_bone_transforms()
					turn_world(rig, "leaf_7", axis, amount)
					var trial := floor_gap(skin, rig)
					if trial > gap:
						gap = trial
						best = rig.get_bone_pose_rotation(leaf)
				if gap >= -0.001:
					break
		clip.rotation_track_insert_key(track, time, best)
		rig.set_bone_pose_rotation(leaf, original)
	return clip

func floor_gap(skin: Dictionary, rig: Skeleton3D) -> float:
	return Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if slot == 2:
		var falling := smoothstep(0.05, 0.88, phase)
		var snap := smoothstep(0.18, 0.4, phase) * (1.0 - smoothstep(0.45, 0.81, phase))
		turn_world(rig, "bip01", Vector3.FORWARD, 1.30 * falling)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.20 * falling - 0.18 * snap)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, -0.13 * falling)
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, -0.21 * falling)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.42 * falling)
		return
	var pulse := smoothstep(0.05, 0.44, phase) * (1.0 - smoothstep(0.54, 0.98, phase))
	if slot == 18:
		var sway := sin(TAU * phase) * pulse
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.18 * sway)
		turn_world(rig, "bip01 spine2", Vector3.UP, -0.22 * sway)
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, -0.26 * sway)
		turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, -0.29 * sway)
		return
	if slot == 15 or slot == 16:
		var side := "l" if slot == 15 else "r"
		var sign := 1.0 if slot == 15 else -1.0
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, -sign * 0.17 * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, sign * 0.30 * pulse)
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, 0.34 * pulse)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.UP, sign * 0.29 * pulse)
		return
	var side := "l" if slot == 4 else "r"
	var sign := 1.0 if slot == 4 else -1.0
	turn_world(rig, "bip01 spine1", Vector3.UP, sign * 0.40 * pulse)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.36 * pulse)
	turn_world(rig, "bip01 " + side + " upperarm", Vector3.UP, sign * 0.76 * pulse)
	turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -0.45 * pulse)
