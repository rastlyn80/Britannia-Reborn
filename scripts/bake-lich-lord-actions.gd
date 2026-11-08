extends "res://../scripts/bake-lich-actions.gd"

const LORD := {3:"Death2", 13:"LordCastingReach", 15:"LordFreeHandGuard",
	16:"LordStaffRaise", 18:"LordShoulderTurn"}
var group := 0

func run() -> void:
	var row := Registry.entry(79).duplicate(true)
	row.assets = {}
	for treatment: String in ["original", "rounded", "modern"]:
		row.assets[treatment] = Registry.asset_path(Registry.entry(79), treatment)
	Registry.entries[79] = row
	bake_body(79, "lich-lord", LORD, ["bake-lich-lord-actions.gd", "bake-lich-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	group = slot
	var base_slot := 2 if slot == 3 else (4 if slot == 13 else slot)
	return super.fit_troll(player, rig, skins, base_slot)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if group != 3:
		super.pose_troll(rig, slot, phase)
		if group == 13:
			var pulse := smoothstep(0.05, 0.42, phase) * (1.0 - smoothstep(0.69, 1.0, phase))
			turn_world(rig, "bip01 l forearm", Vector3.UP, 0.21 * pulse)
		return
	var fall := smoothstep(0.14, 0.96, phase)
	var reach := smoothstep(0.12, 0.58, phase)
	turn_world(rig, "bip01", Vector3.RIGHT, 1.44 * fall)
	turn_world(rig, "bip01 spine1", Vector3.FORWARD, -0.16 * fall)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.24 * fall)
	for side: String in ["l", "r"]:
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -0.40 * fall)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, 0.58 * fall)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.91 * reach)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.31 * reach)
	turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, -0.25 * reach)
