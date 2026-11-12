# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Hip := "bip01"
const Fits := {
	1: ["SkeletalCombatIdle", 1.0], 2: ["SkeletalSideFall", .98], 3: ["Death2", 1.14],
	4: ["SkeletalRearStrike", .90], 12: ["SkeletalRearCast", 1.30], 15: ["SkeletalForelegGuard", .85],
	26: ["SkeletalQuietNod", .95], 27: ["SkeletalHighFidget", .94], 28: ["SkeletalAlert", .78],
}
const MotionJoints := [Hip, "bip01 spine", "bip01 spine1", "bip01 neck", "bip01 neck1", "bip01 neck2",
	"bip01 head", "bip01 tail", "bip01 tail1", "bip01 l upperarm", "bip01 r upperarm",
	"bip01 l forearm", "bip01 r forearm", "bip01 l hand", "bip01 r hand", "bip01 l thigh",
	"bip01 r thigh", "bip01 l calf", "bip01 r calf", "bip01 l foot", "bip01 r foot"]


func run() -> void:
	var folder: String = get_script().resource_path.get_base_dir()
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--study="):
			folder = argument.trim_prefix("--study=")
	var source := folder.path_join("skeletal-mount-breath.scn")
	var actor := (load(source) as PackedScene).instantiate()
	root.add_child(actor)
	var rig := actor.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	var player := actor.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
	var mesh := actor.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	var space := actor.find_child("SourceSpace", true, false) as Node3D
	var original_space := space.transform
	var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
	player.remove_animation_library("")
	player.add_animation_library("", library)
	var skins: Array[Dictionary] = [Ground.skin_points(mesh, rig)]
	for group: int in Fits:
		var fitted := fit_grounded(player, rig, skins, Fits[group][1], Hip, MotionJoints,
			pose_group.bind(group), .004)
		if group == 1:
			fitted.loop_mode = Animation.LOOP_LINEAR
		assert(library.add_animation(Fits[group][0], fitted) == OK)
	verify_base_clips(player, source)
	player.stop()
	rig.reset_bone_poses()
	space.transform = original_space
	var result := PackedScene.new()
	assert(result.pack(actor) == OK and ResourceSaver.save(result,
		folder.path_join("skeletal-mount-enhanced.scn"), ResourceSaver.FLAG_COMPRESS) == OK)
	actor.free()
	print("SKELETAL ENHANCED BAKE: nine fitted clips on the original rig, retaining ten original clips and Chaos Breath")
	quit()


func pose_group(rig: Skeleton3D, phase: float, group: int) -> void:
	match group:
		2, 3:
			collapse(rig, phase, group)
		4, 12, 27:
			rear(rig, phase, group)
		15:
			guard(rig, phase)
		_:
			head_gesture(rig, phase, group)


func collapse(rig: Skeleton3D, phase: float, group: int) -> void:
	var side := 1. if group == 2 else -1.
	var raise := envelope(phase, .03, .23, .32, .59)
	var down := smoothstep(.29, .81, phase)
	var fold := envelope(phase, .13, .36, .60, .86)
	turn_world(rig, Hip, Vector3.RIGHT, -.86 * raise + (.16 if group == 2 else -.33) * down)
	turn_world(rig, Hip, Vector3.BACK, side * (1.66 if group == 2 else 2.66) * down)
	turn_world(rig, Hip, Vector3.UP, side * .18 * down)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .21 * raise + .39 * down)
	turn_world(rig, "bip01 head", Vector3.UP, side * .33 * down)
	turn_world(rig, "bip01 tail", Vector3.BACK, -.30 * side * down)
	for leg: String in ["l", "r"]:
		var closer := (leg == "l") == (side > 0.)
		turn_world(rig, "bip01 " + leg + " upperarm", Vector3.RIGHT, -.27 * raise + (.26 if closer else .12) * down)
		turn_world(rig, "bip01 " + leg + " forearm", Vector3.RIGHT, .71 * fold + .30 * down)
		turn_world(rig, "bip01 " + leg + " thigh", Vector3.RIGHT, .48 * raise + .47 * down)
		turn_world(rig, "bip01 " + leg + " calf", Vector3.RIGHT, -.42 * down)
	shift_hip(rig, Vector3(side * .22 * down, 0., -.18 * down))


func rear(rig: Skeleton3D, phase: float, group: int) -> void:
	var anchor := hind_midpoint(rig)
	var cast := group == 12
	var strike := group == 4
	var lift := envelope(phase, .06, .31, .61 if cast else .49, .87)
	var reach := envelope(phase, .36, .59, .63, .83) if strike else 0.
	var settle := envelope(phase, .67, .81, .84, 1.)
	turn_world(rig, Hip, Vector3.RIGHT, (-.94 if cast else -.76 if strike else -.67) * lift + .12 * settle)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, -.11 * lift + .18 * reach)
	turn_world(rig, "bip01 neck1", Vector3.RIGHT, .24 * lift + .22 * reach)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.17 * lift + .21 * reach)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.36 * lift - .17 * settle)
	turn_world(rig, "bip01 tail1", Vector3.UP, .18 * lift)
	for leg: String in ["l", "r"]:
		var lead := 1. if leg == "l" else .56
		turn_world(rig, "bip01 " + leg + " upperarm", Vector3.RIGHT, -.28 * lift - .56 * reach * lead)
		turn_world(rig, "bip01 " + leg + " forearm", Vector3.RIGHT, .73 * lift - .67 * reach * lead)
		turn_world(rig, "bip01 " + leg + " thigh", Vector3.RIGHT, .53 * lift)
		turn_world(rig, "bip01 " + leg + " calf", Vector3.RIGHT, -.26 * lift)
	shift_hip(rig, (anchor - hind_midpoint(rig)).slide(Vector3.UP))


func guard(rig: Skeleton3D, phase: float) -> void:
	var tuck := envelope(phase, .06, .29, .51, .83)
	var release := envelope(phase, .48, .67, .73, .93)
	turn_world(rig, Hip, Vector3.RIGHT, -.25 * tuck + .10 * release)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, -.24 * tuck)
	turn_world(rig, "bip01 head", Vector3.RIGHT, .38 * tuck - .22 * release)
	for side: String in ["l", "r"]:
		var lead := 1. if side == "l" else .85
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.RIGHT, -.55 * tuck + .25 * release)
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, .90 * tuck * lead)
		turn_world(rig, "bip01 " + side + " hand", Vector3.RIGHT, -.22 * tuck)
	turn_world(rig, "bip01 tail", Vector3.RIGHT, -.30 * tuck)


func head_gesture(rig: Skeleton3D, phase: float, group: int) -> void:
	var pulse := envelope(phase, .06, .35, .50, .94)
	match group:
		1:
			var breath := sin(TAU * phase)
			turn_world(rig, "bip01 spine1", Vector3.RIGHT, .028 * breath)
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.045 - .025 * breath)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .027 * breath)
		26:
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, .32 * pulse)
			turn_world(rig, "bip01 head", Vector3.RIGHT, .22 * pulse)
			turn_world(rig, "bip01 tail", Vector3.UP, -.13 * pulse)
		28:
			turn_world(rig, "bip01 neck1", Vector3.RIGHT, -.17 * pulse)
			turn_world(rig, "bip01 head", Vector3.UP, .13 * pulse)
			turn_world(rig, "bip01 tail", Vector3.RIGHT, -.24 * pulse)
			turn_world(rig, "bip01 tail1", Vector3.UP, .37 * pulse)


func envelope(t: float, rise: float, peak: float, hold: float, end: float) -> float:
	return smoothstep(rise, peak, t) * (1. - smoothstep(hold, end, t))


func shift_hip(rig: Skeleton3D, offset: Vector3) -> void:
	var index := rig.find_bone(Hip)
	var placement := rig.get_bone_global_pose(index)
	placement.origin += rig.global_basis.inverse() * offset
	rig.set_bone_global_pose(index, placement)
	rig.force_update_all_bone_transforms()
