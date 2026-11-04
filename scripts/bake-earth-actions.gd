extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	bake_body(14, "earth-elemental", {2: "Death2", 4: "StoneReach", 6: "OverheadSmash",
		15: "StoneHunch", 16: "StoneBrace", 18: "HeavyShift"}, ["bake-earth-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var wind := smoothstep(0.00, 0.28, phase) * (1.0 - smoothstep(0.30, 0.58, phase))
	var release := smoothstep(0.29, 0.62, phase) * (1.0 - smoothstep(0.70, 1.0, phase))
	if slot == 2:
		var bend := smoothstep(0.13, 0.60, phase)
		var settle := smoothstep(0.33, 0.96, phase)
		turn_world(rig, "bip01", Vector3.RIGHT, 1.28 * settle)
		turn_world(rig, "bip01 spine1", Vector3.FORWARD, -0.34 * settle)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.32 * settle)
		for side: String in ["l", "r"]:
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, -0.40 * bend)
			turn_world(rig, "bip01 " + side + " calf", Vector3.RIGHT, 0.75 * bend)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.42 * settle)
		return
	if slot == 18:
		turn_world(rig, "bip01 spine", Vector3.FORWARD, 0.16 * release)
		turn_world(rig, "bip01 neck", Vector3.UP, -0.20 * release)
		turn_world(rig, "bip01 l clavicle", Vector3.FORWARD, -0.31 * release)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.40 * release)
		return
	var hip := joint_world(rig, "bip01 pelvis")
	var hand := joint_world(rig, "bip01 r hand")
	if slot in [15, 16]:
		var guard := slot == 16
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.16 if guard else 0.48) * release)
		turn_world(rig, "bip01 spine1", Vector3.UP, (-0.31 if guard else 0.26) * release)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, (-1.05 if guard else -0.29) * release)
		fit_arm(rig, "r", hand.lerp(hip + (Vector3(-0.46, 1.26, 0.43) if guard else Vector3(-0.55, 0.50, 0.69)), release))
		return
	var smash := slot == 6
	var lift := Vector3(-0.67, 1.48, 0.32) if smash else Vector3(-0.80, 0.67, -0.24)
	var target := Vector3(-0.42, 0.44, 1.02) if smash else Vector3(-0.45, 0.64, 1.12)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.19 if smash else -0.07) * wind + 0.34 * release)
	turn_world(rig, "bip01 spine1", Vector3.UP, -0.31 * wind + 0.43 * release)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -1.08 * wind if smash else 0.22 * release)
	fit_arm(rig, "r", hand.lerp(hip + lift, wind).lerp(hip + target, release))
