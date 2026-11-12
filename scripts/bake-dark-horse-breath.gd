# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Duration := 1.67
const BreathJoints := ["bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 neck2",
	"bip01 head", "bip01 l upperarm", "bip01 r upperarm", "bip01 tail"]


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	var forms := PackedStringArray(["nightmare", "firesteed"])
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
		elif argument == "--skeletal":
			forms = PackedStringArray(["skeletal-mount"])
		elif argument == "--silver":
			forms = PackedStringArray(["silver-steed"])
	for name: String in forms:
		var input := folder.path_join(name + "-source.scn")
		var actor := (load(input) as PackedScene).instantiate()
		root.add_child(actor)
		var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		var retained := library.get_animation_list().size()
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var source_space := actor.find_child("SourceSpace", true, false) as Node3D
		var source_transform := Transform3D.IDENTITY if source_space == null else source_space.transform
		var breath := fit_grounded(player, rig, [Ground.skin_points(mesh, rig)], Duration,
			"bip01", BreathJoints, pose_breath, .004)
		assert(library.add_animation("FireBreath", breath) == OK)
		verify_base_clips(player, input)
		player.stop()
		rig.reset_bone_poses()
		if source_space != null:
			source_space.transform = source_transform
		var scene := PackedScene.new()
		assert(scene.pack(actor) == OK)
		assert(ResourceSaver.save(scene, folder.path_join(name + "-breath.scn"), ResourceSaver.FLAG_COMPRESS) == OK)
		actor.free()
		print("HORSE BREATH BAKE: ", name, ", ", retained, " original clips retained")
	quit()


func pose_breath(rig: Skeleton3D, phase: float) -> void:
	var inhale := smoothstep(.04, .39, phase) * (1.0 - smoothstep(.51, .68, phase))
	var forward := smoothstep(.50, .72, phase) * (1.0 - smoothstep(.86, 1.0, phase))
	var tremor := .028 * sin(phase * TAU * 12.) * forward
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -.06 * inhale + .035 * forward)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.07 * inhale + .06 * forward)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.17 * inhale + .18 * forward)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.17 * inhale + .24 * forward)
	turn_world(rig, "bip01 neck2", Vector3.RIGHT, -.09 * inhale + .09 * forward + tremor)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .22 * inhale - .25 * forward + tremor)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, .035 * inhale)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, .035 * inhale)
	turn_world(rig, "bip01 tail", Vector3.UP, .10 * inhale - .14 * forward)
