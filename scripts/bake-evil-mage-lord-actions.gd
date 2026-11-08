extends "res://../scripts/bake-occurrence-gestures.gd"

const LORD_CLIPS := {6: "RaisedCast", 11: "ReadyHand", 15: "WardRecoil", 18: "StafflessBend"}
var ready_hand := false

func run() -> void:
	var row := Registry.entry(125).duplicate(true)
	assert(row.kind.begins_with("mages_evil_mage_master"))
	var source_assets: Dictionary = row.get("classic_gesture_base_assets", {})
	var assets := {}
	for treatment: String in ["original", "rounded", "modern"]:
		assets[treatment] = source_assets.get(treatment, Registry.asset_path(row, treatment))
	row.assets = assets
	Registry.entries[125] = row
	# Graphics 20 and 21 have the same registered silhouettes in all five directions.
	current_body = 124
	bake_body(125, "evil-mage-lord", LORD_CLIPS,
		["bake-evil-mage-lord-actions.gd", "bake-occurrence-gestures.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	ready_hand = slot == 11
	# The source aliases use five frames, like the existing 18 timing template.
	return super.fit_troll(player, rig, skins, 18 if ready_hand else slot)

func pose_troll(rig: Skeleton3D, slot: int, phase: float) -> void:
	if not ready_hand:
		super.pose_troll(rig, slot, phase)
		return
	var weight := sin(PI * phase) * sin(PI * phase)
	turn_world(rig, "bip01 spine2", Vector3.UP, 0.06 * weight)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.08 * weight)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.11 * weight)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.06 * weight)
