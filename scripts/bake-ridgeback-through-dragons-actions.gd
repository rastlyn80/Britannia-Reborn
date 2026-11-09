# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-banshee-through-queens-actions.gd"

const RIDGEBACK := 187
const SAVAGE_RIDGEBACK := 188
const REPTALON := 276
const FIRE_BEETLE := 169
const BONE_DEMON := 308
const SERPENTINE := 103
const SKELETAL := 104
const MOUNT_AND_DRAGON_FITS := {
	RIDGEBACK: {4: "RidgebackNoseDip", 10: "RidgebackBriefFidget", 11: "FittedRest"},
	REPTALON: {},
	BONE_DEMON: {15: "BoneDemonShortRecoil", 18: "BoneDemonHandCheck"},
	FIRE_BEETLE: {4: "FireBeetleLowerHead", 11: "FittedRest"},
	SAVAGE_RIDGEBACK: {4: "RidgebackNoseDip", 10: "RidgebackBriefFidget", 11: "FittedRest"},
	SERPENTINE: {15: "SerpentineShortRecoil", 18: "SerpentineNeckSweep"},
	SKELETAL: {15: "SkeletalShortRecoil", 18: "SkeletalWingAdjust", 21: "AirDeath"},
}
const SKELETAL_WINGS := ["box06", "box07", "box01", "box02"]
const SPINE_CHAIN := ["bip01 spine4", "bip01 neck2", "bip01 neck3", "bip01 ponytail1", "bip01 ponytail2"]

func run() -> void:
	Registry.load_index()
	for body: int in MOUNT_AND_DRAGON_FITS:
		var row := Registry.entry(body).duplicate(true)
		assert(row.get("classic_gesture_batch") != "ridgeback_through_dragons_actions" and not row.has("fire_beetle_rest_native_sha256"))
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
		bake_body(body, "ridgeback-through-dragons-%d" % body, MOUNT_AND_DRAGON_FITS[body],
			["bake-ridgeback-through-dragons-actions.gd",
			 "bake-banshee-through-queens-actions.gd", "bake-quagmire-through-exodus-actions.gd",
			 "bake-lattice-through-meer-actions.gd", "bake-frost-through-gargoyle-actions.gd",
			 "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	var duration := 0.46 if slot in [4, 10, 15] else 0.98 if slot == 11 else 1.10 if slot == 21 else 0.84
	if fitting_body == FIRE_BEETLE:
		return fit_grounded(player, rig, skins, duration, "bip 01", BEETLE_JOINTS, pose_beetle.bind(slot), 0.008)
	var joints := (BIPED + FORM_JOINTS + SPINE_CHAIN).filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	if fitting_body == SKELETAL:
		joints += SKELETAL_WINGS
	return fit_grounded(player, rig, skins, duration, "bip01", joints, pose_mount_or_dragon.bind(slot), 0.008)

func pose_mount_or_dragon(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase) * (0.10 if slot == 21 else 1.0)
	var settle := smoothstep(0.05, 0.80, phase)
	if fitting_body in [RIDGEBACK, SAVAGE_RIDGEBACK]:
		if slot == 4:
			rotate(rig, "spine", Vector3.RIGHT, 0.18 * effort)
			rotate(rig, "neck", Vector3.RIGHT, 0.28 * effort)
			rotate(rig, "head", Vector3.RIGHT, 0.25 * effort)
		elif slot == 10:
			rotate(rig, "neck", Vector3.UP, 0.31 * effort)
			rotate(rig, "head", Vector3.RIGHT, -0.14 * effort)
			rotate(rig, "ponytail1", Vector3.FORWARD, 0.29 * effort)
		else:
			rotate(rig, "spine", Vector3.RIGHT, 0.06 * settle)
			rotate(rig, "neck", Vector3.RIGHT, 0.17 * settle)
			rotate(rig, "head", Vector3.RIGHT, 0.15 * settle)
			for side: String in ["l", "r"]:
				rotate(rig, side + " thigh", Vector3.RIGHT, -0.13 * settle)
				rotate(rig, side + " calf", Vector3.RIGHT, 0.19 * settle)
		return
	if fitting_body == BONE_DEMON:
		if slot == 15:
			rotate(rig, "spine1", Vector3.RIGHT, 0.35 * effort)
			rotate(rig, "l upperarm", Vector3.FORWARD, 0.43 * effort)
			rotate(rig, "r upperarm", Vector3.FORWARD, -0.43 * effort)
		else:
			rotate(rig, "r upperarm", Vector3.RIGHT, -0.68 * effort)
			rotate(rig, "r forearm", Vector3.RIGHT, -0.52 * effort)
			rotate(rig, "head", Vector3.RIGHT, 0.28 * effort)
		return
	var flick := sin(phase * TAU) * effort
	rotate(rig, "spine2", Vector3.RIGHT, (-0.18 if slot == 15 else 0.20) * effort)
	rotate(rig, "neck", Vector3.RIGHT, (-0.32 if slot == 15 else 0.18) * effort)
	rotate(rig, "head", Vector3.UP, (0.24 if slot == 15 else 0.46) * flick)
	rotate(rig, "tail1", Vector3.UP, 0.31 * flick)
	if fitting_body == SKELETAL:
		for index in 2:
			var sign := 1.0 if index == 0 else -1.0
			turn_world(rig, SKELETAL_WINGS[index * 2], Vector3.UP, sign * (0.14 if slot == 15 else -0.51) * effort)
			turn_world(rig, SKELETAL_WINGS[index * 2 + 1], Vector3.FORWARD, sign * 0.25 * effort)

func add_retained_actions(player: AnimationPlayer, rig: Skeleton3D, row: Dictionary, treatment: String) -> void:
	if int(row.bodies[0].body) != REPTALON:
		return
	var folder := "res://../work/creatures/reptalon-source-clips"
	var model_path := folder + "/raptalon-%s.gltf" % treatment
	var receipt: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(folder + "/extra-motion-receipt.json"))
	assert(FileAccess.get_sha256(model_path) == receipt.scenes_sha256[treatment] and int(receipt.rig_joint_count) == 45)
	var path := ProjectSettings.globalize_path(model_path)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file(path, state) == OK)
	var donor := document.generate_scene(state)
	var source_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(source_rig.get_bone_count() == rig.get_bone_count() and rig.get_bone_count() == 45)
	for index: int in rig.get_bone_count():
		assert(source_rig.get_bone_name(index) == rig.get_bone_name(index))
		assert(source_rig.get_bone_parent(index) == rig.get_bone_parent(index))
		assert(source_rig.get_bone_rest(index).is_equal_approx(rig.get_bone_rest(index)))
	var source := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var clips := player.get_animation_library("")
	for label: String in ["FittedRest", "ReptalonGrazing", "ReptalonSourceFidget2"]:
		var motion := source.get_animation(label).duplicate(true) as Animation
		var scene_root := player.get_node(player.root_node)
		for track: int in motion.get_track_count():
			var track_path := motion.track_get_path(track)
			assert(scene_root.has_node(NodePath(track_path.get_concatenated_names())))
			if track_path.get_subname_count() > 0:
				assert(rig.find_bone(track_path.get_subname(0)) >= 0)
		assert(clips.add_animation(label, motion) == OK)
	donor.free()