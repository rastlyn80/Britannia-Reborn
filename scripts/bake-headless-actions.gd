extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(31).duplicate(true)
	var assets := {}
	for treatment: String in ["original", "rounded", "modern"]:
		assets[treatment] = Registry.asset_path(row, treatment)
	row.assets = assets
	Registry.entries[31] = row
	bake_body(31, "headless", {2: "Death2", 15: "BackGuard", 16: "ShoulderHunch", 18: "LowSwing"}, ["bake-headless-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.06, 0.48, phase) * (1.0 - smoothstep(0.63, 1.0, phase))
	if slot == 2:
		var fall := smoothstep(0.12, 0.90, phase)
		var reach := smoothstep(0.0, 0.34, phase) * (1.0 - smoothstep(0.49, 0.88, phase))
		turn_world(rig, "bip01", Vector3.RIGHT, -1.46 * fall)
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, 0.26 * fall)
		for side: String in ["l", "r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.24 * fall)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, -0.22 * fall)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.93 * reach)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * 0.26 * fall)
		return
	var hip := joint_world(rig, "bip01 pelvis")
	var side := "l" if slot == 16 else "r"
	var hand := joint_world(rig, "bip01 " + side + " hand")
	var target: Vector3 = {15: Vector3(-0.51, 0.73, 0.38), 16: Vector3(0.37, 0.52, -0.25),
		18: Vector3(-0.48, 0.09, 0.55)}[slot]
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.46 if slot == 16 else -0.11) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, (-0.35 if slot == 16 else 0.26) * pulse)
	fit_arm(rig, side, hand.lerp(hip + target, pulse))
