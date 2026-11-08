extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(110).duplicate(true)
	if row.get("classic_gesture_batch") == "copper_kaze_actions":
		row.assets = row.classic_gesture_base_assets
	else:
		row.assets = {}
		for treatment: String in ["original", "rounded", "modern"]:
			row.assets[treatment] = Registry.asset_path(row, treatment)
	Registry.entries[110] = row
	bake_body(110, "dull-copper", {15:"CopperRecoil", 16:"CopperBrace", 18:"CopperShift"},
		["bake-dull-copper-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var library := player.get_animation_library("")
	var original := library.get_animation("Idle")
	var seed := original.duplicate(true) as Animation
	var path := player.get_node(player.root_node).get_path_to(rig)
	# The source Idle leaves these three shared parents at their bind rotation.
	# The fitted pose rotates them, so each parent needs a track in the new clip.
	for name: String in ["bip01 spine", "bip01 neck", "bip01 head"]:
		var track_path := NodePath("%s:%s" % [path, name])
		if seed.find_track(track_path, Animation.TYPE_ROTATION_3D) < 0:
			var track := seed.add_track(Animation.TYPE_ROTATION_3D)
			seed.track_set_path(track, track_path)
			seed.rotation_track_insert_key(track, 0.0, rig.get_bone_rest(rig.find_bone(name)).basis.get_rotation_quaternion())
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", seed) == OK)
	var fitted := super.fit_troll(player, rig, skins, slot)
	player.stop()
	library.remove_animation("Idle")
	assert(library.add_animation("Idle", original) == OK)
	return fitted

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.02, 0.37, phase) * (1.0 - smoothstep(0.57, 0.99, phase))
	var recoil := slot == 15
	var brace := slot == 16
	turn_world(rig, "bip01 spine", Vector3.RIGHT, (-0.28 if recoil else 0.22) * pulse)
	turn_world(rig, "bip01 neck", Vector3.UP, (0.30 if brace else -0.14) * pulse)
	turn_world(rig, "bip01 head", Vector3.FORWARD, (-0.16 if brace else 0.11) * pulse)
	turn_world(rig, "box07", Vector3.RIGHT, (0.30 if recoil else -0.26) * pulse)
	turn_world(rig, "box08", Vector3.RIGHT, (-0.44 if brace else 0.29) * pulse)
	turn_world(rig, "box02", Vector3.UP, 0.19 * pulse)
	turn_world(rig, "box04", Vector3.UP, -0.15 * pulse)
