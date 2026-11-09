# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-banshee-through-queens-actions.gd"

const RARE_FITS := {
	101: {15: "CentaurShoulderBrace"},
	146: {15: "ShadowlordRecoil", 18: "ShadowlordCloakTurn"},
	255: {15: "ElderBrace", 18: "ElderStaffCheck"},
	262: {18: "TormentedWeaponCheck"},
	273: {15: "EssenceCompactRecoil", 16: "EssenceTallRecoil", 18: "EssenceBillow"},
}
const ESSENCE_SCALES := {
	15: [Vector2(0.6047, 0.6087), Vector2(0.6947, 0.69), Vector2(0.9158, 0.913)],
	16: [Vector2(0.6211, 0.587), Vector2(0.6947, 0.69), Vector2(0.9158, 0.913)],
	18: [Vector2(0.7907, 0.7895), Vector2(0.7093, 0.6304), Vector2(0.7326, 0.72), Vector2(0.7684, 0.7609), Vector2(0.9158, 0.913)],
}

func run() -> void:
	Registry.load_index()
	for body: int in RARE_FITS:
		var row := Registry.entry(body).duplicate(true)
		if row.get("classic_gesture_batch") == "centaur_through_essence_actions":
			row = preload("res://Presentation/SealedCreatureActionBase.gd").retained(row, body)
		var sources := {}
		for treatment: String in ["original", "rounded", "modern"]:
			var path := Registry.asset_path(row, treatment)
			assert(ResourceLoader.exists(path), path)
			assert(FileAccess.get_sha256(path) == row.asset_sha256[treatment])
			sources[treatment] = path
		row.assets = sources
		Registry.entries[body] = row
		fitting_body = body
		bake_body(body, "centaur-essence-%d" % body, RARE_FITS[body],
			["bake-centaur-through-essence-actions.gd", "centaur-through-essence-action-pins.json",
				"bake-banshee-through-queens-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	if fitting_body == 273:
		return fit_essence(player, rig, slot)
	var joints := (BIPED + FORM_JOINTS).filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	assert(joints.size() >= 7, str([fitting_body, joints]))
	var duration := 0.47 if slot == 15 else 0.83
	var root_bone := "bip01" if rig.find_bone("bip01") >= 0 else "bip 01"
	return fit_grounded(player, rig, skins, duration, root_bone, joints, pose_rare_form.bind(slot), 0.009)

func pose_rare_form(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	var sway := effort * sin(phase * TAU)
	if fitting_body == 101:
		rotate(rig, "spine1", Vector3.FORWARD, -0.28 * effort)
		rotate(rig, "spine2", Vector3.UP, 0.45 * effort)
		rotate(rig, "head", Vector3.UP, 0.28 * effort)
		rotate(rig, "r upperarm", Vector3.RIGHT, -0.74 * effort)
		rotate(rig, "l upperarm", Vector3.FORWARD, -0.24 * effort)
		return
	if fitting_body == 146:
		rotate(rig, "spine1", Vector3.UP, 0.25 * effort if slot == 15 else 0.37 * effort)
		rotate(rig, "spine2", Vector3.RIGHT, 0.23 * effort if slot == 15 else 0.13 * effort)
		rotate(rig, "head", Vector3.RIGHT, 0.17 * effort if slot == 15 else 0.25 * effort)
		rotate(rig, "head", Vector3.UP, 0.23 * sway)
		rotate(rig, "r upperarm", Vector3.RIGHT, -0.42 * effort if slot == 15 else -0.19 * effort)
		return
	if fitting_body == 255:
		rotate(rig, "spine1", Vector3.RIGHT, -0.17 * effort if slot == 15 else 0.14 * effort)
		rotate(rig, "head", Vector3.UP, 0.18 * sway)
		rotate(rig, "r upperarm", Vector3.RIGHT, -0.33 * effort if slot == 15 else -0.61 * effort)
		rotate(rig, "r forearm", Vector3.UP, 0.22 * effort if slot == 15 else -0.42 * sway)
		rotate(rig, "l upperarm", Vector3.FORWARD, 0.16 * effort)
		return
	assert(fitting_body == 262)
	rotate(rig, "spine1", Vector3.UP, -0.19 * effort)
	rotate(rig, "head", Vector3.RIGHT, 0.20 * effort)
	rotate(rig, "head", Vector3.UP, 0.32 * sway)
	rotate(rig, "r upperarm", Vector3.RIGHT, -0.91 * effort)
	rotate(rig, "r forearm", Vector3.RIGHT, -0.45 * effort)
	rotate(rig, "l upperarm", Vector3.FORWARD, 0.23 * effort)

func fit_essence(player: AnimationPlayer, rig: Skeleton3D, slot: int) -> Animation:
	var clip := player.get_animation("Idle").duplicate(true) as Animation
	clip.length = 0.46 if slot != 18 else 0.81
	clip.loop_mode = Animation.LOOP_NONE
	for track: int in clip.get_track_count():
		for key: int in range(clip.track_get_key_count(track)-1, 0, -1):
			clip.track_remove_key(track, key)
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var track := clip.find_track(NodePath("%s:EnergyRoot" % rig_path), Animation.TYPE_SCALE_3D)
	assert(track >= 0 and clip.track_get_key_count(track) == 1)
	var base: Vector3 = clip.track_get_key_value(track, 0)
	var scales: Array = ESSENCE_SCALES[slot]
	for frame in scales.size():
		var phase := float(frame + 1) / float(scales.size() + 1)
		var amount: Vector2 = scales[frame]
		clip.scale_track_insert_key(track, phase * clip.length, base * Vector3(amount.x, amount.y, amount.x))
	clip.scale_track_insert_key(track, clip.length, base)
	return clip
