# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-banshee-through-queens-actions.gd"

const VENDOR := 758
const RELATED_HOLDS := {
	VENDOR: {15: "VendorWingGuard", 18: "VendorHandCheck", 21: "AirDeath"},
	10: {13: "DaemonWingCanopy", 15: "DaemonBriefGuard", 18: "DaemonWingFlare", 21: "AirDeath"},
	38: {13: "DaemonWingCanopy", 15: "DaemonBriefGuard", 18: "DaemonWingFlare", 21: "AirDeath"},
}

func run() -> void:
	Registry.load_index()
	for body: int in RELATED_HOLDS:
		var row := Registry.entry(body).duplicate(true)
		var sources := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Registry.asset_path(row, treatment)
			assert(ResourceLoader.exists(path), path)
			var digest := FileAccess.get_sha256(path)
			if row.has("asset_sha256"):
				assert(digest == row.asset_sha256[treatment])
			else:
				assert(digest == row.saved_scenes[treatment].scene_sha256)
			sources[treatment] = path
		row.assets = sources
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "vendor-daemon-wing-%d" % body, RELATED_HOLDS[body],
			["bake-related-wing-actions.gd", "bake-banshee-through-queens-actions.gd", "bake-gargoyle-flight-minotaur-actions.gd",
			"bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var wing_joints := WINGS if fitting_body == VENDOR else WING_JOINTS
	var joints := (BIPED + FORM_JOINTS + wing_joints).filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	assert(wing_joints.all(func(name: String) -> bool: return joints.has(name)))
	var duration := 0.49 if slot == 15 else 0.83 if slot == 18 else 1.10
	return fit_grounded(player, rig, skins, duration, "bip01", joints, pose_related_wings.bind(slot), 0.009)

func pose_related_wings(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	if fitting_body == VENDOR:
		if slot == 21:
			var drift := sin(phase * TAU) * 0.035
			turn_world(rig, WINGS[0], Vector3.UP, -0.19 - drift)
			turn_world(rig, WINGS[1], Vector3.UP, 0.19 + drift)
			turn_world(rig, WINGS[2], Vector3.RIGHT, -0.07)
			turn_world(rig, WINGS[3], Vector3.RIGHT, -0.07)
			rotate(rig, "head", Vector3.RIGHT, 0.10 + drift)
		elif slot == 15:
			turn_world(rig, WINGS[0], Vector3.UP, -0.74 * effort)
			turn_world(rig, WINGS[1], Vector3.UP, 0.74 * effort)
			rotate(rig, "head", Vector3.RIGHT, -0.21 * effort)
		else:
			rotate(rig, "head", Vector3.RIGHT, 0.20 * effort)
			rotate(rig, "r upperarm", Vector3.RIGHT, -0.60 * effort)
			rotate(rig, "r forearm", Vector3.RIGHT, -0.52 * effort)
			turn_world(rig, WINGS[0], Vector3.UP, -0.12 * effort)
			turn_world(rig, WINGS[1], Vector3.UP, 0.12 * effort)
		return
	if slot == 15:
		for index in 2:
			var sign := 1.0 if index == 0 else -1.0
			turn_world(rig, WING_JOINTS[index], Vector3.UP, -sign * 0.34 * effort)
			turn_world(rig, WING_JOINTS[index + 2], Vector3.FORWARD, sign * 0.18 * effort)
		rotate(rig, "spine2", Vector3.RIGHT, -0.14 * effort)
		rotate(rig, "l upperarm", Vector3.RIGHT, -0.30 * effort)
		rotate(rig, "r upperarm", Vector3.RIGHT, -0.30 * effort)
		return
	pose_wings(rig, phase, slot)
