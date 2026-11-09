extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const GUARD_JOINTS := ["bip01 spine1", "bip01 neck", "bip01 head", "jawbone", "bip01 tail"]

func _initialize() -> void:
	create_timer(65.0).timeout.connect(func(): quit(2))
	super._initialize()

func run() -> void:
	var row := Registry.entry(248)
	if row.classic_gesture_batch == "post_solen_actions":
		push_error("Refusing to overwrite an active creature action package")
		quit(1)
		return
	assert(row.classic_gesture_batch == "gaman_gestures")
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
	bake_body(248, "post-solen-248", {10: "GamanLowGuard"},
		["bake-gaman-low-guard.gd",
		 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], _slot: int) -> Animation:
	return fit_grounded(player, rig, skins, 0.54, "bip01", GUARD_JOINTS, pose_guard)

func pose_guard(rig: Skeleton3D, phase: float) -> void:
	var dip := 1.0 - smoothstep(0.18, 0.77, phase)
	var jaw := smoothstep(0.06, 0.42, phase) * (1.0 - smoothstep(0.62, 0.98, phase))
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.09 * dip)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.28 * dip)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.08 * dip)
	turn_world(rig, "jawbone", Vector3.RIGHT, -0.19 * jaw)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.06 * dip)
