extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	bake_body(48, "scorpion", {2: "Death2", 6: "ClawSnap", 15: "LowRecoil", 16: "RaisedClawRecoil", 18: "TailCheck"}, ["bake-scorpion-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var lift := smoothstep(0.06, 0.31, phase) * (1.0 - smoothstep(0.37, 0.66, phase))
	var release := smoothstep(0.31, 0.58, phase) * (1.0 - smoothstep(0.69, 1.0, phase))
	if slot == 2:
		var drop := smoothstep(0.34, 0.96, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, 0.38 * drop)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, 0.34 * lift - 0.36 * drop)
		turn_world(rig, "bip01 tail2", Vector3.RIGHT, -0.68 * drop)
		turn_world(rig, "bip01 tail3", Vector3.UP, -0.66 * drop)
		turn_world(rig, "bip01 tail4", Vector3.FORWARD, 0.42 * drop)
		turn_world(rig, "bip01 l upperarm", Vector3.UP, -0.41 * drop)
		turn_world(rig, "bip01 r upperarm", Vector3.UP, 0.40 * drop)
		return
	if slot == 18:
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.46 * release)
		turn_world(rig, "bip01 tail3", Vector3.UP, -0.30 * release)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.41 * release)
		return
	var pincher := slot == 6
	var raised := slot == 16
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.UP,
			sign * ((0.31 * lift - 0.56 * release) if pincher else 0.19 * release))
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT,
			(-0.48 if raised else 0.13) * release * (1.0 if side == "l" else 0.7))
		turn_world(rig, "bip01 " + side + " finger0", Vector3.UP, sign * 0.29 * release)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, (0.15 if raised else -0.32) * release)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (-0.14 if pincher else 0.08) * release)
