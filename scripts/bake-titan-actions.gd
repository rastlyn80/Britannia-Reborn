extends "res://../scripts/bake-zombie-actions.gd"

const TITAN := {15: "TitanBrace", 18: "TitanOath"}

func run() -> void:
	var source := Registry.entry(76)
	var row := source.duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = Registry.asset_path(source, treatment)
	Registry.entries[76] = row
	bake_body(76, "titan", TITAN, ["bake-titan-actions.gd", "bake-zombie-actions.gd"])
	quit()

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	var rise := smoothstep(0.08, 0.44, phase) * (1.0 - smoothstep(0.56, 0.96, phase))
	var bow := slot == 18
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, (0.29 if bow else -0.22) * rise)
	turn_world(rig, "bip01 spine2", Vector3.UP, 0.17 * rise if not bow else 0.0)
	turn_world(rig, "bip01 head", Vector3.RIGHT, (0.19 if bow else -0.16) * rise)
	for side: String in ["l", "r"]:
		var side_sign := 1.0 if side == "l" else -1.0
		var lift := -1.90 if bow else -1.10 if side == "r" else -0.76
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, lift * rise)
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.FORWARD, -0.10 * rise * side_sign)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, (-0.28 if bow else -0.72) * rise)
