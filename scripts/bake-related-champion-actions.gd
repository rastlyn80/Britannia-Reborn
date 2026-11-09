# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-banshee-through-queens-actions.gd"

const VARIANTS := {
	172: {"bake": {15: "RikktorShortRecoil", 18: "RikktorWingLift"}},
	173: {"donor": 157, "clips": ["LowBrace", "AbdomenSignal"]},
	174: {"donor": 149, "clips": ["SuccubusWingRecoil", "SuccubusWingLift"]},
	175: {"donor": 123, "clips": ["LatticeWingDisplay"]},
	176: {"donor": 128, "clips": ["PixieFlinch", "PixieSpiral"]},
}
const PINS := "res://../scripts/related-champion-action-pins.json"
var donor_pins: Dictionary
const RETRO_WING_ROOTS := ["dummy-l_wing", "dummy-r_wing"]

func run() -> void:
	Registry.load_index()
	donor_pins = JSON.parse_string(FileAccess.get_file_as_string(PINS)).donors
	for body: int in VARIANTS:
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
		bake_body(body, "related-champion-%d" % body, VARIANTS[body].get("bake", {}),
			["bake-related-champion-actions.gd", "related-champion-action-pins.json", "bake-banshee-through-queens-actions.gd", "bake-swamp-widow-juka-actions.gd", "bake-zombie-actions.gd"])
	quit()

func fit_troll(player: AnimationPlayer, rig: Skeleton3D, skins: Array[Dictionary], slot: int) -> Animation:
	assert(fitting_body == 172)
	var joints := (BIPED + FORM_JOINTS + RETRO_WING_ROOTS).filter(func(name: String) -> bool: return rig.find_bone(name) >= 0)
	assert(RETRO_WING_ROOTS.all(func(name: String) -> bool: return joints.has(name)))
	return fit_grounded(player, rig, skins, 0.47 if slot == 15 else 0.83, "bip01", joints, pose_retro.bind(slot), 0.008)

func pose_retro(rig: Skeleton3D, phase: float, slot: int) -> void:
	var effort := pulse(phase)
	if slot == 15:
		rotate(rig, "spine2", Vector3.RIGHT, -0.25 * effort)
		rotate(rig, "neck", Vector3.RIGHT, -0.33 * effort)
		rotate(rig, "head", Vector3.RIGHT, 0.18 * effort)
	else:
		rotate(rig, "spine2", Vector3.RIGHT, 0.12 * effort)
		rotate(rig, "head", Vector3.UP, 0.13 * sin(phase * TAU) * effort)
	for index in 2:
		var sign := 1.0 if index == 0 else -1.0
		turn_world(rig, RETRO_WING_ROOTS[index], Vector3.UP, sign * (0.14 if slot == 15 else -0.35) * effort)
		turn_world(rig, RETRO_WING_ROOTS[index], Vector3.FORWARD, sign * (0.28 if slot == 15 else -0.48) * effort)

func add_retained_actions(player: AnimationPlayer, rig: Skeleton3D, row: Dictionary, treatment: String) -> void:
	var body := int(row.bodies[0].body)
	if body == 172:
		return
	var recipe: Dictionary = VARIANTS[body]
	var checked: Dictionary = donor_pins[str(body)]
	assert(int(checked.body) == int(recipe.donor))
	var donor_path: String = checked.assets[treatment]
	assert(FileAccess.get_sha256(donor_path) == checked.sha256[treatment])
	var donor := (load(donor_path) as PackedScene).instantiate()
	var donor_rig := donor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var donor_player := donor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var target_root := player.get_node(player.root_node)
	var donor_root := donor_player.get_node(donor_player.root_node)
	var target_path := target_root.get_path_to(rig)
	assert(donor_rig.get_bone_count() == rig.get_bone_count())
	var library := player.get_animation_library("")
	for label: String in recipe.clips:
		var motion := donor_player.get_animation(label).duplicate(true) as Animation
		for track: int in motion.get_track_count():
			var path := motion.track_get_path(track)
			var track_node := donor_root.get_node_or_null(NodePath(path.get_concatenated_names()))
			if track_node != donor_rig:
				var target_node := target_root.get_node_or_null(NodePath(path.get_concatenated_names())) as Node3D
				assert(track_node is Node3D and target_node != null and path.get_subname_count() == 0)
				assert(motion.track_get_key_count(track) == 1, str([body, label, path]))
				var value: Variant = {Animation.TYPE_POSITION_3D: target_node.position,
					Animation.TYPE_ROTATION_3D: target_node.quaternion,
					Animation.TYPE_SCALE_3D: target_node.scale}.get(motion.track_get_type(track))
				assert(value != null)
				motion.track_set_key_value(track, 0, value)
				continue
			assert(path.get_subname_count() == 1)
			var bone := str(path.get_subname(0))
			var source_joint := donor_rig.find_bone(bone)
			var target_joint := rig.find_bone(bone)
			assert(source_joint >= 0)
			if target_joint < 0:
				assert(body == 173 and donor_rig.get_bone_parent(source_joint) == rig.get_bone_parent(source_joint))
				target_joint = source_joint
				bone = rig.get_bone_name(target_joint)
			assert(rig.get_bone_rest(target_joint).is_equal_approx(donor_rig.get_bone_rest(source_joint)))
			var a := donor_rig.get_bone_parent(source_joint)
			var b := rig.get_bone_parent(target_joint)
			assert(a == b or a >= 0 and b >= 0 and donor_rig.get_bone_name(a) == rig.get_bone_name(b))
			motion.track_set_path(track, NodePath("%s:%s" % [target_path, bone]))
		assert(library.add_animation(label, motion) == OK)
	donor.free()
	if body == 175:
		var recoil := player.get_animation("Hit").duplicate(true) as Animation
		for track: int in recoil.get_track_count():
			for key: int in recoil.track_get_key_count(track):
				recoil.track_set_key_time(track, key, recoil.track_get_key_time(track, key) * 0.75)
		recoil.length *= 0.75
		recoil.loop_mode = Animation.LOOP_NONE
		assert(library.add_animation("OaksShortRecoil", recoil) == OK)
