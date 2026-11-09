extends "res://../scripts/bake-terathan-distinct-actions.gd"

func run() -> void:
	var row := Registry.entry(152).duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = "res://local-art/creatures/%s-%s.gltf" % [row.kind, treatment]
	Registry.entries[152] = row
	bake_body(152, "terathan-avenger", {15: "AvengerPincerRecoil", 18: "AvengerThreat"},
		["bake-terathan-avenger-actions.gd", "bake-terathan-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, _slot: int, phase: float) -> void:
	var impulse := smoothstep(0.05, 0.43, phase) * (1.0 - smoothstep(0.59, 0.97, phase))
	if classic_group == 15:
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.24 * impulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, -0.22 * impulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.90 * impulse)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.46 * impulse)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.27 * impulse)
		turn_world(rig, "bip01 l forearm", Vector3.UP, 0.26 * impulse)
		return
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.31 * impulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.22 * impulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -1.50 * impulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.37 * impulse)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.53 * impulse)
	turn_world(rig, "bone_r", Vector3.RIGHT, -0.30 * impulse)
	turn_world(rig, "bone_r05", Vector3.RIGHT, -0.28 * impulse)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.25 * impulse)
