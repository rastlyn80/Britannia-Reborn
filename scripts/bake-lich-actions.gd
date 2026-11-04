extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(24).duplicate(true)
	var assets := {}
	for treatment: String in ["original", "rounded", "modern"]:
		assets[treatment] = Registry.asset_path(row, treatment)
	row.assets = assets
	Registry.entries[24] = row
	bake_body(24, "lich", {2: "Death2", 4: "StaffStagger", 15: "HandGuard", 16: "StaffBrace", 18: "StaffShift"}, ["bake-lich-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.06, 0.44, phase) * (1.0 - smoothstep(0.61, 1.0, phase))
	if slot == 2:
		var fall := smoothstep(0.14, 0.93, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 1.42 * fall)
		turn_world(rig, "bip01 spine2", Vector3.FORWARD, -0.24 * fall)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -0.39 * fall)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, 0.65 * fall)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.51 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.49 * pulse)
		return
	var crouch := 0.34 if slot == 4 else 0.04
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -crouch * pulse)
		turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, crouch * 1.6 * pulse)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.37 if slot == 4 else -0.09) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, (0.39 if slot in [4, 15] else -0.20) * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, (-0.26 if slot == 18 else 0.16) * pulse)
	var side := "l" if slot in [4, 15] else "r"
	var hip := joint_world(rig, "bip01 pelvis")
	var hand := joint_world(rig, "bip01 " + side + " hand")
	var target: Vector3 = {4: Vector3(0.42, 0.55, 0.75), 15: Vector3(0.37, 0.88, 0.55),
		16: Vector3(-0.53, 0.72, 0.22), 18: Vector3(-0.47, 0.27, 0.32)}[slot]
	fit_arm(rig, side, hand.lerp(hip + target, pulse))
