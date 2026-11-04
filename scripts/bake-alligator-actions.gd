extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(202).duplicate(true)
	var assets := {}
	for treatment: String in ["original", "rounded", "modern"]:
		assets[treatment] = Registry.asset_path(row, treatment)
	row.assets = assets
	Registry.entries[202] = row
	bake_body(202, "alligator", {2: "Death", 4: "Alert", 6: "JawLunge", 18: "SlowLook"}, ["bake-alligator-actions.gd", "bake-zombie-actions.gd"])
	quit()

func add_retained_actions(player: AnimationPlayer, _rig: Skeleton3D, _row: Dictionary, _treatment: String) -> void:
	var library := player.get_animation_library("")
	library.rename_animation("Death", "RecoveredDeath")
	assert(library.add_animation("Death2", library.get_animation("RecoveredDeath").duplicate(true)) == OK)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.03, 0.29, phase) * (1.0 - smoothstep(0.33, 0.67, phase))
	var pulse := smoothstep(0.22, 0.54, phase) * (1.0 - smoothstep(0.63, 1.0, phase))
	if slot == 2:
		var relax := smoothstep(0.28, 0.96, phase)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, -1.26 * relax)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.29 * lift + 0.31 * relax)
		turn_world(rig, "bip01 tail", Vector3.UP, 0.35 * relax)
		turn_world(rig, "bip01 tail1", Vector3.UP, 0.39 * relax)
		turn_world(rig, "bip01 tail2", Vector3.RIGHT, -0.49 * relax)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 " + side + " thigh", Vector3.FORWARD, sign * 0.27 * relax)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * 0.19 * relax)
		return
	if slot == 6:
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.41 * lift + 0.17 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.34 * lift - 0.10 * pulse)
		turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, 0.62 * lift - 0.18 * pulse)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.40 * pulse)
		turn_world(rig, "bip01 tail2", Vector3.UP, -0.27 * pulse)
		return
	if slot == 4:
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, -0.28 * pulse)
		turn_world(rig, "bip01 tail", Vector3.UP, -0.58 * lift)
		turn_world(rig, "bip01 tail1", Vector3.UP, -0.47 * lift + 0.21 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.29 * pulse)
		return
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.18 * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, -0.29 * pulse)
	turn_world(rig, "bip01 tail2", Vector3.UP, 0.17 * lift)
