# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-quagmire-through-exodus-actions.gd"

const BANSHEE := 310
const CAPTAIN := 280
const COHORT := 767
const ICE_FIEND := 43
const FERRET := 279
const JUGGERNAUT := 768
const GIBBERLING := 307
const YAMANDON := 249
const RANKED_FITS := {
	BANSHEE: {15: "BansheeShortRecoil", 18: "BansheeHandCheck"},
	CAPTAIN: {18: "CaptainWatch"},
	COHORT: {15: "CohortShortRecoil", 18: "CohortPoint"},
	ICE_FIEND: {13: "FiendWingCanopy", 15: "FiendShortRecoil", 18: "FiendWingFlare", 21: "AirDeath"},
	FERRET: {10: "FerretSniff"},
	JUGGERNAUT: {15: "JuggernautShortRecoil", 18: "JuggernautArmSweep"},
	GIBBERLING: {15: "GibberlingDuck", 18: "GibberlingReach"},
	807: {15: "QueenShortRecoil"},
	783: {15: "QueenShortRecoil"},
	YAMANDON: {11: "YamandonCoil", 15: "YamandonDuck"},
}
const WING_JOINTS := ["daemon l mainwing01", "daemon r mainwing01", "daemon l mainwing02", "daemon r mainwing02",
	"daemon l wing01", "daemon r wing01", "daemon l wing02", "daemon r wing02"]
const FORM_JOINTS := ["bip01 spine3", "bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 tail3", "bip01 jaw",
	"bip01 neck1", "bip01 l hand", "bip01 r hand"]

func run() -> void:
	Registry.load_index()
	for body: int in RANKED_FITS:
		var row := Registry.entry(body).duplicate(true)
		assert(row.get("classic_gesture_batch") != "banshee_through_queens_actions", "Use the retained base when rebaking")
		var assets := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Registry.asset_path(row, treatment)
			var digest := FileAccess.get_sha256(path)
			assert(not digest.is_empty(), str([body, treatment, path]))
			if row.has("asset_sha256"):
				assert(row.asset_sha256[treatment] == digest)
			elif row.has("saved_scenes"):
				assert(row.saved_scenes[treatment].scene_sha256 == digest)
			assets[treatment] = path
		row.assets = assets
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "banshee-through-queens-%d" % body, RANKED_FITS[body],
			["bake-banshee-through-queens-actions.gd",
			 "bake-quagmire-through-exodus-actions.gd", "bake-lattice-through-meer-actions.gd",
			 "bake-frost-through-gargoyle-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var duration := 0.46 if slot in [10, 15] else 1.10 if slot in [13, 21] else 0.81
	var joints := (BIPED + FORM_JOINTS).filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	if fitting_body == ICE_FIEND:
		joints += WING_JOINTS
	var clearance := 0.007
	if fitting_body in [BANSHEE, JUGGERNAUT] or slot == 21:
		player.play("Idle", 0.0)
		player.advance(0.0)
		rig.force_update_all_bone_transforms()
		var gap := INF
		for skin: Dictionary in skins:
			gap = minf(gap, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
		assert(is_finite(gap))
		clearance = maxf(clearance, gap)
	return fit_grounded(player, rig, skins, duration, "bip01", joints, pose_form.bind(slot), clearance)

func rotate(rig: Skeleton3D, name: String, axis: Vector3, angle: float) -> void:
	var label := "bip01 " + name
	if rig.find_bone(label) >= 0:
		turn_world(rig, label, axis, angle)

func pose_form(rig: Skeleton3D, phase: float, slot: int) -> void:
	var strength := pulse(phase)
	if fitting_body == ICE_FIEND:
		pose_wings(rig, phase, slot)
		return
	if fitting_body == FERRET:
		rotate(rig, "spine2", Vector3.RIGHT, 0.28 * strength)
		rotate(rig, "neck1", Vector3.RIGHT, 0.27 * strength)
		rotate(rig, "head", Vector3.UP, 0.48 * sin(TAU * phase) * strength)
		rotate(rig, "tail", Vector3.RIGHT, -0.28 * strength)
		return
	if fitting_body == YAMANDON and slot == 11:
		rotate(rig, "spine2", Vector3.UP, -0.44 * strength)
		rotate(rig, "tail", Vector3.UP, 0.49 * strength)
		rotate(rig, "tail1", Vector3.UP, 0.66 * strength)
		rotate(rig, "tail2", Vector3.UP, 0.69 * strength)
		rotate(rig, "tail3", Vector3.UP, 0.38 * strength)
		rotate(rig, "head", Vector3.RIGHT, 0.25 * strength)
		return
	if slot == 15:
		var dip := -0.30 if fitting_body in [GIBBERLING, 807, 783, YAMANDON] else 0.22
		rotate(rig, "spine", Vector3.RIGHT, 0.64 * dip * strength)
		rotate(rig, "spine2", Vector3.RIGHT, dip * strength)
		rotate(rig, "head", Vector3.RIGHT, dip * strength)
		rotate(rig, "l upperarm", Vector3.RIGHT, -0.36 * strength)
		rotate(rig, "r upperarm", Vector3.RIGHT, -0.31 * strength)
		rotate(rig, "tail1", Vector3.RIGHT, 0.14 * strength)
		return
	var sweep := 0.88 if fitting_body in [COHORT, JUGGERNAUT, GIBBERLING] else 0.45
	var turn := sin(TAU * phase) * strength
	rotate(rig, "spine", Vector3.UP, 0.28 * strength)
	rotate(rig, "head", Vector3.UP, 0.32 * turn)
	rotate(rig, "r upperarm", Vector3.RIGHT, -sweep * strength)
	rotate(rig, "r forearm", Vector3.RIGHT, -0.36 * strength)
	rotate(rig, "r hand", Vector3.UP, 0.22 * turn)
	if fitting_body == CAPTAIN:
		rotate(rig, "tail", Vector3.UP, 0.30 * turn)
		rotate(rig, "l thigh", Vector3.RIGHT, 0.19 * strength)
		rotate(rig, "l calf", Vector3.RIGHT, -0.31 * strength)

func pose_wings(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := (smoothstep(0.05, 0.26, phase) * (1.0 - smoothstep(0.79, 0.99, phase))
		if slot == 13 else pulse(phase))
	var lift := 0.91 if slot == 13 else 0.58 if slot == 18 else 0.11 if slot == 21 else -0.23
	var fan := 0.63 if slot == 13 else 0.35 if slot == 18 else 0.04 if slot == 21 else 0.14
	for index in 2:
		var side := 1.0 if index == 0 else -1.0
		turn_world(rig, WING_JOINTS[index], Vector3.UP, -side * fan * effort)
		turn_world(rig, WING_JOINTS[2 + index], Vector3.FORWARD, side * lift * effort)
		turn_world(rig, WING_JOINTS[4 + index], Vector3.RIGHT, lift * 0.52 * effort)
		turn_world(rig, WING_JOINTS[6 + index], Vector3.FORWARD, side * lift * 0.28 * effort)
	rotate(rig, "spine2", Vector3.RIGHT, (-0.22 if slot == 15 else 0.045 if slot == 21 else 0.17) * effort)
	rotate(rig, "neck", Vector3.RIGHT, (-0.04 if slot == 21 else -0.21) * effort)
