# SPDX-License-Identifier: GPL-3.0-or-later
extends "bake-raptor-slith-enhanced.gd"

const Review := "res://../work/creatures/native-form-audit/enhanced-source-gaps/common-forms-enhanced/raptor-slith-index-recovery/"
const RaptorNew := {5: "RaptorRearingKick", 10: "RaptorHeadRecoil"}
const SlithNew := {5: "SlithLowTailStrike", 10: "SlithRaisedRecoil"}
const Length := {5: .92, 10: .70}
const RaptorExtra := ["BackUpLeg.L", "BackLowLeg.L", "BackUpLeg.R", "BackLowLeg.R"]
const Deaths := {730: ["RaptorForwardFall", "RaptorRearFall"], 734: ["SlithDippingFall", "SlithRearingFall"]}


func run() -> void:
	assert(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(Review)) == OK)
	fit_pair(730, RaptorNew, "Body", RaptorJoints + RaptorExtra, raptor_motion)
	fit_pair(734, SlithNew, RootJoint, SlithJoints + ["bip01 ponytail1"], slith_motion)
	print("REPTILE FIT: eight recovered motions across six scenes")
	quit()


func fit_pair(body: int, names: Dictionary, hips: String, joints: Array, motion: Callable) -> void:
	for treatment: String in ["original", "rounded", "modern"]:
		var filename := "%d-%s.scn" % [body, treatment]
		var source := Destination + filename
		var scene := load(source) as PackedScene
		assert(scene != null)
		var model := scene.instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var mesh := model.find_child("Velociraptor" if body == 730 else "Body", true, false) as MeshInstance3D
		var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
		for group: int in names:
			var fitted := fit_grounded(player, rig, skins, Length[group], hips, joints, motion.bind(group), .004)
			assert(library.add_animation(names[group], fitted) == OK)
		for index in 2:
			var seed := "Death" if index == 0 or body == 730 else "Death2"
			var source_fall := player.get_animation(seed)
			var original := source_fall.duplicate(true) as Animation
			var influence: Array = [
				[.24, -.26, .34], [-.44, -.43, .08],
			][index] if body == 730 else [
				[.31, .13, -.18], [-.21, .25, -.33],
			][index]
			var fitted_fall := fit_fall(player, rig, original, seed, body, hips, influence, index)
			assert(library.add_animation(Deaths[body][index], fitted_fall) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, Review + filename, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("REPTILE FIT ", body, " ", treatment, " ", names.values() + Deaths[body])


func fit_fall(player: AnimationPlayer, rig: Skeleton3D, clip: Animation, seed: String, body: int,
		hips: String, influence: Array, index: int) -> Animation:
	var joints: Array = [hips, "Neck", "Tail2"] if body == 730 else [hips, "bip01 neck", "bip01 tail1"]
	var tracks := {}
	var rig_path := player.get_node(player.root_node).get_path_to(rig)
	for joint: String in joints:
		var path := NodePath("%s:%s" % [rig_path, joint])
		var track := clip.find_track(path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = clip.add_track(Animation.TYPE_ROTATION_3D)
			clip.track_set_path(track, path)
		else:
			for key in range(clip.track_get_key_count(track) - 1, -1, -1):
				clip.track_remove_key(track, key)
		tracks[joint] = track
	player.stop()
	player.play(seed, 0.0)
	player.advance(0.0)
	for frame in 81:
		var phase := frame / 80.0
		var time := phase * clip.length
		rig.reset_bone_poses()
		player.seek(time, true)
		var settle := smoothstep(.09, .60 if index == 0 else .77, phase)
		var brace := envelope(phase, .04, .33, .51, .83)
		turn_world(rig, joints[0], Vector3.RIGHT, float(influence[0]) * brace)
		if body == 730 and index == 1:
			turn_world(rig, hips, Vector3.UP, -.36 * smoothstep(.36, .88, phase))
		turn_world(rig, joints[1], Vector3.RIGHT, float(influence[1]) * brace)
		turn_world(rig, joints[2], Vector3.UP, float(influence[2]) * settle)
		for joint: String in joints:
			clip.rotation_track_insert_key(tracks[joint], time, rig.get_bone_pose_rotation(rig.find_bone(joint)))
	return clip


func raptor_motion(rig: Skeleton3D, phase: float, group: int) -> void:
	var gather := .23 * (1.0 - smoothstep(.17, .45, phase))
	var rear := 1.0 - smoothstep(.22, .90, phase)
	var thrust := 0.0
	var kick := 0.0
	if group == 5:
		gather = envelope(phase, .02, .16, .22, .34)
		rear = envelope(phase, .17, .41, .53, .85)
		kick = envelope(phase, .27, .47, .57, .84)
	else:
		thrust = envelope(phase, .09, .30, .38, .61)
	turn_world(rig, "Body", Vector3.RIGHT, .18 * gather - .35 * rear)
	turn_world(rig, "Torso", Vector3.RIGHT, .13 * gather - .27 * rear)
	turn_world(rig, "Shoulders", Vector3.RIGHT, -.21 * rear)
	turn_world(rig, "Neck", Vector3.RIGHT, .36 * gather - .28 * rear - .34 * thrust)
	turn_world(rig, "Head", Vector3.RIGHT, .25 * rear - .20 * thrust)
	turn_world(rig, "Tail1", Vector3.RIGHT, -.12 + .33 * rear)
	turn_world(rig, "Tail2", Vector3.RIGHT, -.12 + .18 * rear)
	turn_world(rig, "Tail4", Vector3.RIGHT, -.22 * kick)
	for side: String in ["L", "R"]:
		var asymmetry := 1.0 if side == "L" else .56
		turn_world(rig, "FrontUpLeg." + side, Vector3.RIGHT, -.49 * rear)
		turn_world(rig, "FrontLowLeg." + side, Vector3.RIGHT, .32 * rear)
		turn_world(rig, "BackUpLeg." + side, Vector3.RIGHT, -.42 * kick * asymmetry)
		turn_world(rig, "BackLowLeg." + side, Vector3.RIGHT, -.33 * kick * asymmetry)


func slith_motion(rig: Skeleton3D, phase: float, group: int) -> void:
	var peak := envelope(phase, .02, .21, .44, .86)
	var coil := .54 * peak
	var bend := -.43 * peak
	var push := 0.0
	if group == 5:
		peak = envelope(phase, .10, .38, .53, .94)
		bend = .37 * envelope(phase, .41, .62, .72, .95) - .25 * peak
		coil = .73 * peak
		push = envelope(phase, .21, .46, .58, .91)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.15 * peak + .12 * bend)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, bend - .23 * peak)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, bend * .52)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .20 * peak + .45 * bend)
	turn_world(rig, "bip01 ponytail1", Vector3.RIGHT, .22 * peak)
	turn_world(rig, "bip01 tail", Vector3.UP, .22 * coil)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, .19 * coil)
	turn_world(rig, "bip01 tail2", Vector3.RIGHT, .36 * coil)
	for side: String in ["l", "r"]:
		var asymmetry := 1.0 if side == "l" else .45
		turn_world(rig, "bip01 %s upperarm" % side, Vector3.RIGHT, -.19 * peak - .27 * push * asymmetry)
		turn_world(rig, "bip01 %s forearm" % side, Vector3.RIGHT, .26 * peak + .15 * push * asymmetry)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, .24 * push * asymmetry)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, -.26 * push * asymmetry)
