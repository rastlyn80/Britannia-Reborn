extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	bake_body(74, "imp", {15: "ShoulderRecoil"}, ["bake-imp-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var amount := smoothstep(0.12, 0.43, phase) * (1.0 - smoothstep(0.58, 1.0, phase))
	turn_world(rig, "bip01 spine1", Vector3.UP, -0.24 * amount)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.19 * amount)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.37 * amount)
	turn_world(rig, "imp_r_wing 01", Vector3.UP, 0.31 * amount)
	turn_world(rig, "imp_l_wing 01", Vector3.UP, 0.13 * amount)
	turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.14 * amount)
