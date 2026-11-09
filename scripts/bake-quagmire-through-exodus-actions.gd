# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-lattice-through-meer-actions.gd"

const QUAGMIRE := 789
const WYRM := 46
const OVERSEER := 756
const FITS := {
	QUAGMIRE: {15: "QuagmireDrawIn", 18: "QuagmireFan"},
	784: {15: "ArcaneDaemonBrace"},
	266: {},
	772: {15: "MeerEternalGuard", 18: "MeerEternalReach"},
	267: {18: "TroglodyteSway"},
	304: {15: "FleshGolemHighGuard", 18: "FleshGolemCheck"},
	WYRM: {15: "AncientWyrmWingBrace", 18: "AncientWyrmHeadSweep"},
	757: {15: "MinionSpringGuard", 18: "MinionLeverTest"},
	OVERSEER: {15: "OverseerRetract", 18: "OverseerTailCurl"},
	252: {18: "SnowLadyGather"},
	199: {18: "RaiJuCheck"},
	271: {18: "SatyrLean"},
}
const BIPED := ["bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck", "bip01 head",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l thigh", "bip01 r thigh", "bip01 l calf", "bip01 r calf"]
const QUAGMIRE_JOINTS := ["spine 01", "spine 02", "arm 01", "arm 02", "arm 03", "arm 04",
	"tentacle 01", "tentacle 04", "tentacle 07", "tentacle 10", "tentacle 13", "tentacle 16"]
const WYRM_JOINTS := ["bip01 spine2", "bip01 neck", "bip01 neck2", "bip01 head", "box01", "box02", "box06", "box07"]

func run() -> void:
	Registry.load_index()
	for body: int in FITS:
		var row := Registry.entry(body).duplicate(true)
		assert(row.get("classic_gesture_batch") != "quagmire_through_exodus_actions", "Use the retained base when rebaking")
		var assets := {}
		var treatments: Array = row.assets.keys() if row.has("assets") else ["original", "rounded", "modern"]
		for treatment: String in treatments:
			var path := Registry.asset_path(row, treatment)
			var digest := FileAccess.get_sha256(path)
			assert(not digest.is_empty(), str([body, treatment, path]))
			if row.has("asset_sha256"):
				assert(row.asset_sha256[treatment] == digest, str([body, treatment]))
			elif row.has("saved_scenes"):
				assert(row.saved_scenes[treatment].scene_sha256 == digest, str([body, treatment]))
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "quagmire-through-exodus-%d" % body, FITS[body],
			["bake-quagmire-through-exodus-actions.gd",
			 "bake-lattice-through-meer-actions.gd", "bake-frost-through-gargoyle-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var length := 0.52 if slot == 15 else 0.86
	if fitting_body == QUAGMIRE:
		return fit_grounded(player, rig, skins, length, "bip 01", QUAGMIRE_JOINTS, pose_quagmire.bind(slot))
	if fitting_body == WYRM:
		return fit_grounded(player, rig, skins, length, "bip01", WYRM_JOINTS, pose_wyrm.bind(slot))
	var joints := BIPED.filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	if fitting_body == OVERSEER:
		joints += ["bip01 tail", "bip01 tail1", "bip01 tail2"]
		# The original overseer keeps a gap below its shell.
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var rest_gap := INF
		for skin: Dictionary in skins:
			rest_gap = minf(rest_gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(is_finite(rest_gap))
		return fit_grounded(player, rig, skins, length, "bip01", joints, pose_ranked_biped.bind(slot), maxf(0.005, rest_gap))
	return fit_grounded(player, rig, skins, length, "bip01", joints, pose_ranked_biped.bind(slot), 0.007)

func pulse(phase: float) -> float:
	return smoothstep(0.03, 0.37, phase) * (1.0 - smoothstep(0.55, 0.99, phase))

func pose_quagmire(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	var fan := slot == 18
	for index in 6:
		var joint: String = QUAGMIRE_JOINTS[6 + index]
		var wave := (sin(TAU * phase + index * 0.55) if fan else 0.6) * effort
		turn_world(rig, joint, Vector3.RIGHT, (0.48 if fan else -0.42) * wave)
		turn_world(rig, joint, Vector3.UP, (0.18 if index % 2 == 0 else -0.18) * effort)
	turn_world(rig, "spine 01", Vector3.RIGHT, (0.21 if fan else -0.20) * effort)
	turn_world(rig, "spine 02", Vector3.FORWARD, 0.18 * effort)
	for index in 4:
		turn_world(rig, QUAGMIRE_JOINTS[2 + index], Vector3.UP, (1.0 if index % 2 == 0 else -1.0) * 0.34 * effort)

func pose_wyrm(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	if slot == 15:
		turn_world(rig, "box01", Vector3.UP, -0.46 * effort)
		turn_world(rig, "box06", Vector3.UP, 0.46 * effort)
		turn_world(rig, "box02", Vector3.FORWARD, 0.26 * effort)
		turn_world(rig, "box07", Vector3.FORWARD, -0.26 * effort)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, 0.19 * effort)
		return
	var glance := effort * sin(TAU * phase)
	turn_world(rig, "bip01 neck2", Vector3.UP, 0.31 * glance)
	turn_world(rig, "bip01 head", Vector3.UP, 0.42 * glance)
	turn_world(rig, "bip01 head", Vector3.RIGHT, 0.17 * effort)

func pose_ranked_biped(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	var glance := effort * sin(TAU * phase)
	var upper := "bip01 spine2" if rig.find_bone("bip01 spine2") >= 0 else "bip01 spine"
	if fitting_body == OVERSEER:
		turn_world(rig, "bip01 tail", Vector3.RIGHT, (-0.51 if slot == 15 else -0.79) * effort)
		turn_world(rig, "bip01 tail1", Vector3.RIGHT, 0.46 * effort)
		turn_world(rig, "bip01 tail2", Vector3.UP, 0.29 * glance)
		turn_world(rig, "bip01 head", Vector3.RIGHT, 0.18 * effort)
		return
	if slot == 15:
		var high := fitting_body == 304
		turn_world(rig, upper, Vector3.RIGHT, (0.29 if high else -0.23) * effort)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, (-0.98 if high else -0.42) * effort)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.27 * effort)
		turn_world(rig, "bip01 r upperarm", Vector3.UP, -0.28 * effort)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.19 * effort)
		return
	if fitting_body == 757:
		turn_world(rig, upper, Vector3.FORWARD, -0.29 * effort)
		turn_world(rig, "bip01 r upperarm", Vector3.UP, -0.93 * effort)
		turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.55 * effort)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, 0.20 * effort)
		return
	var sweep := 0.62 if fitting_body in [267, 772, 304] else 0.39
	turn_world(rig, "bip01 head", Vector3.UP, 0.43 * glance)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -0.17 * effort)
	turn_world(rig, upper, Vector3.UP, 0.28 * glance)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -sweep * effort)
	turn_world(rig, "bip01 r forearm", Vector3.RIGHT, -0.42 * effort)
	if fitting_body in [267, 252, 271]:
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -0.33 * effort)
		turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -0.22 * effort)
