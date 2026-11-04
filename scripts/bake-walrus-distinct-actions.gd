extends "res://../scripts/bake-zombie-actions.gd"

func run() -> void:
	var row := Registry.entry(221).duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = Registry.asset_path(Registry.entry(221), treatment)
	Registry.entries[221] = row
	bake_body(221, "walrus-distinct", {2:"Death2",4:"FlipperAlert",6:"TuskThrust",18:"HeadHitch"},
		["bake-walrus-distinct-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var pulse := smoothstep(0.04, 0.39, phase) * (1.0 - smoothstep(0.52, 1.0, phase))
	if slot == 2:
		var fall := smoothstep(0.12, 0.88, phase)
		turn_world(rig, "bip01", Vector3.FORWARD, -0.56 * fall)
		turn_world(rig, "bip01 spine", Vector3.RIGHT, 0.37 * fall)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.25 * fall)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.43 * fall)
		for side: String in ["l","r"]:
			var sign := 1.0 if side == "l" else -1.0
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -0.63 * fall)
			turn_world(rig, "bip01 " + side + " upperarm", Vector3.FORWARD, sign * -0.30 * fall)
			turn_world(rig, "bip01 " + side + " thigh", Vector3.RIGHT, 0.45 * fall)
		return
	if slot == 4:
		var start := 1.0 - smoothstep(0.0, 0.72, phase)
		turn_world(rig, "bip01 spine", Vector3.RIGHT, 0.30 * start)
		turn_world(rig, "bip01 head", Vector3.UP, 0.28 * start)
		turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, -0.46 * start)
		turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, 0.46 * start)
		return
	if slot == 6:
		turn_world(rig, "bip01 spine", Vector3.RIGHT, -0.35 * pulse)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, -0.28 * pulse)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -0.32 * pulse)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, 0.22 * pulse)
		return
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.14 * pulse)
	turn_world(rig, "bip01 head", Vector3.UP, -0.20 * pulse)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, 0.16 * pulse)
