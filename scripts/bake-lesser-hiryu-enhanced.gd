# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-hound-bear-enhanced.gd"

const Destination := "res://../work/creatures/native-form-audit/enhanced-source-gaps/lesser-hiryu-enhanced/"
const Body := 243
const Gestures := {11: "HiryuWingFeint", 12: "HiryuTailFlourish", 15: "HiryuMantle",
	25: "HiryuQuietWatch", 26: "HiryuLowInspection", 27: "HiryuCurl", 28: "HiryuHighAlert"}
const Durations := {11: .88, 12: 1.04, 15: .52, 25: 1.11, 26: .98, 27: .71, 28: .69}
const Gaits := {22: ["Walk", "HiryuPeaceWalk", .94], 31: ["Idle", "HiryuSeatedIdle", 1.10],
	29: ["Walk", "HiryuSeatedWalk", .89], 30: ["Run", "HiryuSeatedRun", .76]}
const PoseJoints := ["bip01 pelvis", "bip01 spine", "bip01 neck", "bip01 neck1", "bip01 head", "jaw_bone",
	"l_wing_bone", "l_wing_bone01", "r_wing_bone", "r_wing_bone01", "l_arm_bone", "r_arm_bone",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "bip01 l thigh", "bip01 r thigh",
	"bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]
const GaitJoints := ["bip01 spine", "bip01 neck", "bip01 neck1", "bip01 head",
	"bip01 tail", "bip01 tail1", "bip01 tail2", "l_wing_bone", "r_wing_bone"]


func run() -> void:
	var row := Registry.entry(Body)
	for treatment: String in row.assets:
		var path := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(path) == row.asset_sha256[treatment])
		var model := (load(path) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for group: int in Gestures:
			var clip := fit_grounded(player, rig, [skin], Durations[group], RootJoint, PoseJoints, pose_hiryu.bind(group), .004)
			if group == 25:
				clip.loop_mode = Animation.LOOP_LINEAR
			assert(library.add_animation(Gestures[group], clip) == OK)
		for group: int in Gaits:
			var gait: Array = Gaits[group]
			var clip := fit_gait(player, rig, gait[0], gait[2], group)
			assert(library.add_animation(gait[1], clip) == OK)
		verify_base_clips(player, path)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK)
		assert(ResourceSaver.save(scene, Destination + "%d-%s.scn" % [Body, treatment], ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("HIRYU FIT ", treatment, ": seven gestures and four locomotion loops")
	quit()


func pose_hiryu(rig: Skeleton3D, phase: float, group: int) -> void:
	var dip := 0.0
	var stretch := 0.0
	var fold := 0.0
	var rise := 0.0
	var curl := 0.0
	var sway := 0.0
	match group:
		11:
			var sweep := envelope(phase, .02, .35, .49, .93)
			dip = .34 * sweep
			stretch = .43 * sweep
			sway = .19 * sweep
		12:
			var flare := envelope(phase, .07, .41, .66, .98)
			rise = .29 * flare
			stretch = .40 * flare
			curl = .74 * flare
			sway = -.22 * flare
		15:
			fold = .78 * envelope(phase, .02, .33, .62, .94)
			dip = .38 * fold
			curl = -.14 * fold
		25:
			dip = .035 * sin(TAU * phase)
			stretch = .036 * (1.0 - cos(TAU * phase))
			sway = .06 * sin(TAU * phase)
		26:
			var inspection := envelope(phase, .07, .36, .63, .98)
			dip = .30 * inspection
			fold = .28 * inspection
			sway = .26 * sin(TAU * phase) * inspection
		27:
			var alert := envelope(phase, .10, .38, .57, .95)
			dip = .24 * alert
			stretch = .48 * alert
			curl = .52 * alert
			sway = .21 * alert
		28:
			var warning := smoothstep(.13, .81, phase)
			rise = .30 * warning
			stretch = .52 * warning
			curl = -.23 * warning
			sway = -.15 * warning
	var anchor := hind_midpoint(rig)
	turn_world(rig, RootJoint, Vector3.RIGHT, .13 * dip - .15 * rise)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, .24 * dip - .13 * rise)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .66 * dip - .65 * rise)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .35 * dip - .31 * rise)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.29 * dip)
	turn_world(rig, "bip01 head", Vector3.UP, sway * .68)
	turn_world(rig, "jaw_bone", Vector3.RIGHT, .33 * stretch)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.42 * curl - .14 * rise)
	turn_world(rig, "bip01 tail1", Vector3.RIGHT, -.64 * curl)
	turn_world(rig, "bip01 tail2", Vector3.UP, .52 * sway + .31 * curl)
	for side: String in ["l", "r"]:
		var sign_x := 1.0 if side == "l" else -1.0
		turn_world(rig, "%s_wing_bone" % side, Vector3.BACK, sign_x * (.69 * stretch - .42 * fold))
		turn_world(rig, "%s_wing_bone" % side, Vector3.UP, sign_x * (.45 * fold - .14 * stretch))
		turn_world(rig, "%s_wing_bone01" % side, Vector3.BACK, sign_x * (.36 * fold - .39 * stretch))
		turn_world(rig, "%s_arm_bone" % side, Vector3.RIGHT, -.38 * stretch + .17 * fold)
		turn_world(rig, "bip01 %s thigh" % side, Vector3.RIGHT, -.18 * dip)
		turn_world(rig, "bip01 %s calf" % side, Vector3.RIGHT, .24 * dip)
	anchor_hind_paws(rig, anchor)


func fit_gait(player: AnimationPlayer, rig: Skeleton3D, seed: String, length: float, group: int) -> Animation:
	var source := player.get_animation(seed)
	var result := source.duplicate(true) as Animation
	var ratio := length / source.length
	result.length = length
	result.loop_mode = Animation.LOOP_LINEAR
	var path := player.get_node(player.root_node).get_path_to(rig)
	var editable := {}
	for joint: String in GaitJoints:
		var track_path := NodePath("%s:%s" % [path, joint])
		var track := result.find_track(track_path, Animation.TYPE_ROTATION_3D)
		if track < 0:
			track = result.add_track(Animation.TYPE_ROTATION_3D)
			result.track_set_path(track, track_path)
		editable[track] = rig.find_bone(joint)
	for track in result.get_track_count():
		var count := result.track_get_key_count(track)
		if editable.has(track):
			for index in range(count - 1, -1, -1):
				result.track_remove_key(track, index)
		else:
			var indices := range(count - 1, -1, -1) if ratio > 1.0 else range(count)
			for index in indices:
				result.track_set_key_time(track, index, result.track_get_key_time(track, index) * ratio)
	player.play(seed, 0.0)
	player.advance(0.0)
	var source_loop := source.loop_mode
	source.loop_mode = Animation.LOOP_NONE
	for frame in 81:
		var phase := float(frame) / 80.0
		rig.reset_bone_poses()
		player.seek(source.length * phase, true)
		rig.force_update_all_bone_transforms()
		var stride := sin(TAU * phase)
		var mounted := group in [29, 30, 31]
		var reach := (.10 if group == 30 else .045) if mounted else -.033
		turn_world(rig, "bip01 spine", Vector3.RIGHT, .24 * reach + .012 * stride)
		turn_world(rig, "bip01 neck", Vector3.RIGHT, reach + .034 * stride)
		turn_world(rig, "bip01 neck1", Vector3.RIGHT, .52 * reach - .015 * stride)
		turn_world(rig, "bip01 head", Vector3.RIGHT, -.29 * reach)
		turn_world(rig, "bip01 tail", Vector3.RIGHT, -.20 * reach + .038 * stride)
		turn_world(rig, "bip01 tail1", Vector3.UP, (.073 if mounted else .043) * stride)
		turn_world(rig, "bip01 tail2", Vector3.UP, .051 * sin(TAU * phase - .45))
		for side: String in ["l", "r"]:
			var sign_x := 1.0 if side == "l" else -1.0
			turn_world(rig, "%s_wing_bone" % side, Vector3.BACK, sign_x * (.052 * stride - .13 * float(mounted)))
		for track: int in editable:
			result.rotation_track_insert_key(track, length * phase, rig.get_bone_pose_rotation(editable[track]))
	source.loop_mode = source_loop
	return result
