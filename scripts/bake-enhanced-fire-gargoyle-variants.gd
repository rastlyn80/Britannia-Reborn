# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-fire-gargoyle-enhanced.gd"

const VariantDestination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/fire-gargoyle-variants/"
const Falls := ["FireGargoyleTwistingFall", "FireGargoyleBackFall"]
const Reaction := "FireGargoyleRaisedRecoil"


func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(VariantDestination)) == OK)
	for treatment: String in ["original", "rounded", "modern"]:
		fit(treatment)
	print("FIRE GARGOYLE FIT: recoil and two falls across three treatments")
	quit()


func fit(treatment: String) -> void:
	var file := "130-%s.scn" % treatment
	var path := Destination + file
	var model := (load(path) as PackedScene).instantiate()
	root.add_child(model)
	var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var skin: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	assert(library.add_animation(Reaction, fit_grounded(player, rig, skin, .64, RootJoint, FireJoints, recoil, .004)) == OK)
	for i in 2:
		var seed := "Death" if i == 0 else "Death2"
		assert(library.add_animation(Falls[i], adjust_fall(player, rig, seed, i)) == OK)
	verify_base_clips(player, path)
	player.stop()
	rig.reset_bone_poses()
	var packed := PackedScene.new()
	assert(packed.pack(model) == OK and ResourceSaver.save(packed, VariantDestination + file, ResourceSaver.FLAG_COMPRESS) == OK)
	model.free()


func recoil(rig: Skeleton3D, phase: float) -> void:
	var weight := envelope(phase, .0, .24, .53, .98)
	var brace := envelope(phase, .07, .39, .59, .95)
	var support := hind_midpoint(rig)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.22 * weight)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.36 * weight)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .35 * weight)
	turn_world(rig, "bip01 spine2", Vector3.UP, .34 * weight)
	turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -1.60 * weight)
	turn_world(rig, "bip01 l upperarm", Vector3.BACK, .33 * weight)
	turn_world(rig, "bip01 l forearm", Vector3.RIGHT, -.55 * weight)
	turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.51 * brace)
	turn_world(rig, "gargoyle l mainwing1", Vector3.BACK, -.31 * brace)
	turn_world(rig, "gargoyle r mainwing1", Vector3.BACK, .40 * brace)
	anchor_hind_paws(rig, support)


func adjust_fall(player: AnimationPlayer, rig: Skeleton3D, seed: String, index: int) -> Animation:
	var source := player.get_animation(seed)
	var motion := source.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var joints := [RootJoint, "bip01 spine2", "bip01 l upperarm", "bip01 r upperarm",
		"gargoyle l mainwing1", "gargoyle r mainwing1"]
	var tracks := {}
	for joint: String in joints:
		var path := NodePath("%s:%s" % [rig_path, joint])
		var track := motion.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = motion.add_track(Animation.TYPE_ROTATION_3D)
			motion.track_set_path(track, path)
		else:
			for key in range(motion.track_get_key_count(track) - 1, -1, -1):
				motion.track_remove_key(track, key)
		tracks[joint] = track
	player.stop()
	player.play(seed, 0.0)
	player.advance(0.0)
	for i in 81:
		var phase := i / 80.0
		var time := phase * source.length
		player.seek(time, true)
		var flail := envelope(phase, .04, .34, .49, .86)
		var direction := 1.0 if index == 0 else -1.0
		var turn := flail * direction
		turn_world(rig, RootJoint, Vector3.UP, .36 * turn)
		turn_world(rig, "bip01 spine2", Vector3.RIGHT, -.30 * flail)
		turn_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.61 * flail)
		turn_world(rig, "bip01 r upperarm", Vector3.RIGHT, .40 * turn)
		turn_world(rig, "gargoyle l mainwing1", Vector3.BACK, -.38 * flail)
		turn_world(rig, "gargoyle r mainwing1", Vector3.BACK, .54 * flail)
		for joint: String in joints:
			motion.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return motion
