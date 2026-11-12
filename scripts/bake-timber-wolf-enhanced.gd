# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-wolf-grizzly-enhanced.gd"

const Body := 225
const Reference := 25
const TimberJoints := ["bip01 neck1", "bip01 jaw", "bip01 tail1", "bip01 tail2"]


func run() -> void:
	var folder := ProjectSettings.globalize_path("res://../work/creatures/timber-wolf-enhanced-bake")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	var timber := Registry.entry(Body)
	var grey := Registry.entry(Reference)
	assert(timber.kind == "canines_wolf_timber" and str(grey.kind).begins_with("canines_wolf_grey"))
	var clips := {}
	for group: int in WolfClips:
		clips[group] = str(WolfClips[group]).replace("GreyWolf", "TimberWolf")
	for treatment: String in timber.assets:
		compare_rigs(Registry.asset_path(timber, treatment), Registry.asset_path(grey, treatment))
	prepare_body(Body, clips, WolfLengths, CommonJoints + TimberJoints, pose_wolf, folder + "/")
	var result := {}
	for treatment: String in timber.assets:
		var scene := folder.path_join("%d-%s.scn" % [Body, treatment])
		var model := (load(scene) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var skin := Ground.skin_points(mesh, rig)
		player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		var gaps := {}
		for label: String in clips.values():
			player.play(label, 0.0)
			player.advance(0.0)
			var minimum := INF
			for frame in 61:
				player.seek(player.current_animation_length * frame / 60.0, true)
				rig.force_update_all_bone_transforms()
				minimum = minf(minimum, Ground.minimum_plane_gap(skin, rig, rig.global_transform, Vector3.ZERO, Vector3.UP))
			assert(minimum > .003, "%s skinned floor gap %.6f" % [label, minimum])
			gaps[label] = minimum
		result[treatment] = {"scene_sha256": FileAccess.get_sha256(scene),
			"base_sha256": FileAccess.get_sha256(Registry.asset_path(timber, treatment)),
			"grey_base_sha256": FileAccess.get_sha256(Registry.asset_path(grey, treatment)), "gaps": gaps}
		model.free()
	var file := FileAccess.open(folder.path_join("timber-wolf-first-fit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"body": Body, "motion_reference": Reference, "clips": clips,
		"sample_count": clips.size() * result.size() * 61, "variants": result}, "  "))
	file.close()
	print("TIMBER WOLF FIT: ", clips.size(), " authored reference motions on three retained Timber Wolf rigs")
	quit()


func compare_rigs(timber_path: String, grey_path: String) -> void:
	var timber := (load(timber_path) as PackedScene).instantiate()
	var grey := (load(grey_path) as PackedScene).instantiate()
	var rig := timber.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var reference := grey.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	assert(rig.get_bone_count() == 32 and reference.get_bone_count() == 32)
	for index in rig.get_bone_count():
		assert(rig.get_bone_name(index) == reference.get_bone_name(index))
		assert(rig.get_bone_parent(index) == reference.get_bone_parent(index))
		assert(rig.get_bone_rest(index).is_equal_approx(reference.get_bone_rest(index)))
	timber.free()
	grey.free()
