extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(309)
	if row.get("classic_gesture_batch") == "ophidian_patchwork_actions":
		Registry.entries[309] = row.merged({"assets": row.classic_gesture_base_assets}, true)
	bake_body(309, "patchwork-skeleton", {15:"WideArmRecoil", 18:"ReachAndHitch"},
		["bake-patchwork-skeleton-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var recoil := slot == 15
	var pulse := smoothstep(0.03, 0.39 if recoil else 0.55, phase) * (1.0 - smoothstep(0.57, 0.98, phase))
	turn_world(rig, "bip01 spine1", Vector3.UP, (0.36 if recoil else -0.24) * pulse)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, (-0.18 if recoil else 0.21) * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, (-0.18 if recoil else 0.28) * pulse)
	turn_world(rig, "bip01 r clavicle", Vector3.FORWARD, -0.30 * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, (-0.73 if recoil else -0.42) * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.UP, (0.43 if recoil else -0.46) * pulse)
	turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, (0.63 if recoil else 0.23) * pulse)
