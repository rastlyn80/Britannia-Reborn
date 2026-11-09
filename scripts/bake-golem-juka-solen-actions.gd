extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const NEXT := {752: {15: "IronBrace", 18: "IronReset"}, 766: {6: "BackhandStep", 15: "ArmoredBrace", 18: "ArmorGlance"},
	806: {15: "SolenRecoil"}, 782: {15: "SolenRecoil"}}
const UPPER := ["bip01 spine1", "bip01 neck", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm"]
const JUKA_BONES := UPPER + ["bip01 spine2", "bip01 head", "bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]
const SOLEN_BONES := UPPER + ["bip01 spine2", "bip01 head", "antenna l", "antenna r"]

func run() -> void:
	for identity: int in NEXT:
		var row := Registry.entry(identity).duplicate(true)
		if row.get("classic_gesture_batch") == "golem_raptor_juka_solen_actions":
			push_error("Refusing to overwrite an active creature action package")
			quit(1)
			return
		var assets := {}
		for treatment: String in row.asset_sha256:
			var path := Registry.asset_path(row, treatment)
			assert(FileAccess.get_sha256(path) == row.asset_sha256[treatment])
			assets[treatment] = path
		row.assets = assets
		Registry.entries[identity] = row
		fitting_body = identity
		bake_body(identity, "golem-juka-solen-%d" % identity, NEXT[identity],
			["bake-golem-juka-solen-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var joints := UPPER + ["bone_head", "bone_stem", "bip01 l thigh", "bip01 r thigh", "bip01 r calf"]
	if fitting_body == 766:
		joints = JUKA_BONES
	elif fitting_body != 752:
		joints = SOLEN_BONES
	var length := 0.48 if slot == 15 else 0.72 if slot == 6 else 0.90
	return fit_grounded(player, rig, skins, length, "bip01", joints, fit_next.bind(slot))

func fit_next(rig: Skeleton3D, phase: float, slot: int) -> void:
	var pulse := smoothstep(0.04, 0.41, phase) * (1.0 - smoothstep(0.59, 1.0, phase))
	if fitting_body == 752:
		if slot == 15:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.25 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.30 * pulse)
			turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.15 * pulse)
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.38 * pulse)
			turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -0.17 * pulse)
			turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.21 * pulse)
			turn_world(rig, "bone_stem", Vector3.RIGHT, 0.17 * pulse)
			return
		var turn := sin(TAU * phase) * pulse
		turn_world(rig, "bip01 spine1", Vector3.UP, 0.37 * turn)
		turn_world(rig, "bone_head", Vector3.UP, -0.27 * turn)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.49 * maxf(0.0, turn))
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.55 * minf(0.0, turn))
		return
	if fitting_body == 766:
		if slot == 6:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.21 * pulse)
			turn_world(rig, "bip01 spine2", Vector3.UP, -0.22 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.61 * pulse)
			turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.28 * pulse)
			turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -0.23 * pulse)
			turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.29 * pulse)
			return
		if slot == 15:
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, 0.28 * pulse)
			turn_world(rig, "bip01 spine2", Vector3.UP, 0.28 * pulse)
			turn_world(rig, "bip01 l upperarm", Vector3.FORWARD, -0.17 * pulse)
			turn_world(rig, "bip01 r upperarm", Vector3.FORWARD, 0.32 * pulse)
			turn_world(rig, "bip01 r thigh", Vector3.RIGHT, -0.26 * pulse)
			turn_world(rig, "bip01 r calf", Vector3.RIGHT, 0.31 * pulse)
			return
		turn_world(rig, "bip01 head", Vector3.UP, 0.39 * pulse * sin(phase * TAU))
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.24 * pulse)
		turn_world(rig, "bip01 spine2", Vector3.UP, 0.11 * pulse)
		return
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -0.34 * pulse)
	turn_world(rig, "bip01 spine2", Vector3.UP, -0.19 * pulse)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -0.52 * pulse)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.30 * pulse)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.16 * pulse)
	turn_world(rig, "antenna l", Vector3.RIGHT, -0.27 * pulse)
	turn_world(rig, "antenna r", Vector3.RIGHT, -0.22 * pulse)
