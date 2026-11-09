extends "res://../scripts/bake-zombie-actions.gd"

const ROT_MOTIONS := {2: "Death2", 4: "BackhandReach", 6: "OverheadClaw", 11: "ArmsRaise",
	15: "DoubleOver", 16: "StaggerBack", 18: "LookUp"}
var group := 0

func run() -> void:
	var row := Registry.entry(155).duplicate(true)
	row.assets = row.get("classic_gesture_base_assets", row.assets)
	Registry.entries[155] = row
	bake_body(155, "rotting-corpse", ROT_MOTIONS, ["bake-rotting-corpse-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	assert(rig.get_bone_count() == 34)
	group = slot
	return super.fit_troll(player, rig, skins, 18 if slot == 11 else slot)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if group != 11:
		super.pose_troll(rig, slot, phase)
		return
	var raise := smoothstep(0.0, 0.28, phase) * (1.0 - smoothstep(0.36, 0.69, phase))
	var stoop := smoothstep(0.30, 0.78, phase) * (1.0 - smoothstep(0.81, 1.0, phase))
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.39 * stoop)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, 0.26 * stoop)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.26 * raise - 0.16 * stoop)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -2.21 * raise)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -1.83 * raise)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.28 * raise)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.35 * raise)
