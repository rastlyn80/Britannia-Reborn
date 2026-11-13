# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-troll-actions.gd"

const Study := "res://../work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/"
const Fits := {
	267: ["troglodyte-variants", "TroglodyteTwistingFall", "TroglodyteForwardFall"],
	753: ["enslaved-gargoyle-variants", "EnslavedGargoyleTwistingFall", "EnslavedGargoyleBackFall"],
}
const Joints := ["bip01 pelvis", "bip01 spine1", "bip01 head", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l thigh", "bip01 r thigh"]


func run() -> void:
	for body: int in Fits:
		var row: Array = Fits[body]
		var directory := Study.path_join(row[0])
		for treatment: String in ["original", "rounded", "modern"]:
			var filename := "%d-%s.scn" % [body, treatment]
			var source := directory.path_join(filename)
			var model := (load(source) as PackedScene).instantiate()
			root.add_child(model)
			var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
			var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
			var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
			player.remove_animation_library("")
			player.add_animation_library("", library)
			for i in 2:
				var seed := "Death2" if i == 1 and player.has_animation("Death2") else "Death"
				var result := fit_fall(player, rig, seed, body, i)
				assert(library.add_animation(row[i + 1], result) == OK)
			player.stop()
			rig.reset_bone_poses()
			var scene := PackedScene.new()
			assert(scene.pack(model) == OK and ResourceSaver.save(scene, directory.path_join("falls-" + filename),
				ResourceSaver.FLAG_COMPRESS) == OK)
			model.free()
		print("HUMANOID FITTED FALLS ", body, " ", row.slice(1))
	quit()


func fit_fall(player: AnimationPlayer, rig: Skeleton3D, seed: String, body: int, index: int) -> Animation:
	var source := player.get_animation(seed)
	var motion := source.duplicate(true) as Animation
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	var tracks := {}
	for joint: String in Joints:
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
	for frame in 81:
		var phase := frame / 80.0
		var time := phase * source.length
		rig.reset_bone_poses()
		player.seek(time, true)
		var brace := smoothstep(.06, .35, phase) * (1.0 - smoothstep(.49, .84, phase))
		var reach := smoothstep(.15, .46, phase) * (1.0 - smoothstep(.59, .80, phase))
		var turn := -.36 if index == 0 else .29
		var pitch := .49 if body == 267 and index == 1 else -.29
		turn_world(rig, Joints[0], Vector3.UP, turn * brace)
		if body == 753 and index == 1:
			turn_world(rig, Joints[0], Vector3.FORWARD, .62 * smoothstep(.26, .90, phase))
		turn_world(rig, Joints[1], Vector3.RIGHT, pitch * brace)
		turn_world(rig, Joints[2], Vector3.RIGHT, -.29 * pitch * brace)
		turn_world(rig, Joints[3], Vector3.RIGHT, -.54 * reach)
		turn_world(rig, Joints[4], Vector3.BACK, -.42 * reach)
		turn_world(rig, Joints[5], Vector3.RIGHT, .34 * brace)
		turn_world(rig, Joints[6], Vector3.RIGHT, -.29 * brace)
		for joint: String in Joints:
			motion.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return motion
