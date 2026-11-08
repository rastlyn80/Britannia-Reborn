extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(196)
	if row.get("classic_gesture_batch") == "copper_kaze_actions":
		Registry.entries[196] = row.merged({"assets": row.classic_gesture_base_assets}, true)
	bake_body(196, "kaze-kemono", {15:"KazeDoubleFlinch", 16:"KazeForearmGuard", 18:"KazeForwardSway"},
		["bake-kaze-kemono-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.03, 0.42, phase) * (1.0 - smoothstep(0.57, 0.98, phase))
	if slot == 15:
		turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.24 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.22 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, -0.50 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, 0.44 * pulse)
		return
	if slot == 16:
		turn_world(rig, "bip01 spine2", Vector3.UP, -0.35 * pulse)
		turn_world(rig, "bip01 head", Vector3.UP, 0.16 * pulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.57 * pulse)
		turn_world(rig, "bip01 l forearm", Vector3.UP, -0.43 * pulse)
		return
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.31 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.18 * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.28 * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.22 * pulse)
