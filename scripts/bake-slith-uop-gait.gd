extends "res://../scripts/bake-raptor-uop-actions.gd"

func run() -> void:
	var row := Registry.entry(734)
	if row.get("classic_gesture_batch") == "golem_raptor_juka_solen_actions":
		push_error("Refusing to overwrite an active creature action package")
		quit(1)
		return
	assert(row.classic_gesture_batch == "slith_actions")
	for treatment: String in row.assets:
		assert(FileAccess.get_sha256(row.assets[treatment]) == row.asset_sha256[treatment])
	bake_body(734, "slith-uop-gait", {22: "SlithPeaceWalk"}, [
		"bake-slith-uop-gait.gd",
		"bake-raptor-uop-actions.gd",
		"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func peaceful_walk(player: AnimationPlayer, rig: Skeleton3D) -> Animation:
	return reframe_walk(player, rig, ["bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 head",
		"bip01 tail", "bip01 tail1", "bip01 tail2"], shape_slith_walk)

func shape_slith_walk(rig: Skeleton3D, phase: float) -> void:
	var sway := sin(TAU * phase)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.04)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.12)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, -0.08 + 0.03 * sway)
	turn_world(rig, "bip01 head", Vector3.UP, 0.06 * sway)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -0.04)
	turn_world(rig, "bip01 tail1", Vector3.UP, -0.15 * sway)
	turn_world(rig, "bip01 tail2", Vector3.UP, -0.09 * sway)
