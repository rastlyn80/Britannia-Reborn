extends "res://../scripts/bake-zombie-actions.gd"
## Body 242 groups 11 and 18 are an exact archive alias.
func run() -> void:
	bake_body(242, "deathwatch", {15: "LeftRecoil", 16: "RightRecoil", 18: "RearingFidget"},
		["bake-deathwatch-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.36, phase) * (1.0 - smoothstep(0.54, 1.0, phase))
	if slot == 18:
		var yaw := (smoothstep(0.0, 0.29, phase) - smoothstep(0.31, 0.63, phase)) * 0.71
		var return_yaw := (smoothstep(0.29, 0.59, phase) - smoothstep(0.71, 1.0, phase)) * 0.38
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.34 * pulse)
		turn_world(rig, "bip01 neck", Vector3.UP, yaw - return_yaw)
		turn_world(rig, "bip01 head", Vector3.UP, 0.35 * pulse - 0.24 * return_yaw)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, 0.31 * pulse)
		return
	var side := -1.0 if slot == 15 else 1.0
	turn_world(rig, "bip01 spine", Vector3.RIGHT, 0.30 * pulse)
	turn_world(rig, "bip01 spine1", Vector3.FORWARD, 0.14 * side * pulse)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.37 * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, 0.19 * side * pulse)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.22 * pulse)
	turn_world(rig, "bip01 tail1", Vector3.FORWARD, -0.18 * side * pulse)
