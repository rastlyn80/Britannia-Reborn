# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-field-enhanced.gd"

const Folder := "res://../work/creatures/native-form-audit/enhanced-source-gaps/troll-ratman/"
const UnarmedTroll := {4: "TrollOpenHandSlam", 23: "TrollBraceAndRise", 26: "TrollMeasure",
	27: "TrollOpenGuard", 28: "TrollBraceAlert"}
const Lengths := {4: .90, 23: 1.0, 26: 1.0, 27: .90, 28: .70}

func run() -> void:
	var row := Registry.entry(53)
	for treatment: String in row.assets:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate()
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		var skins: Array[Dictionary] = []
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			skins.append(Ground.skin_points(mesh, rig))
		for group: int in UnarmedTroll:
			var joints := Joints.filter(func(name: String): return rig.find_bone(name) >= 0)
			var clip := fit_grounded(player, rig, skins, Lengths[group], "bip01", joints, pose_unarmed.bind(group), .006)
			assert(library.add_animation(UnarmedTroll[group], clip) == OK)
		verify_base_clips(player, source)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, Folder + "53-%s.scn" % treatment, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TROLL 53 ENHANCED ", treatment, ": five unarmed fits")
	quit()

func pulse_window(phase: float, a: float, b: float, c: float, d: float) -> float:
	return smoothstep(a, b, phase) * (1.0 - smoothstep(c, d, phase))

func pose_unarmed(rig: Skeleton3D, phase: float, group: int) -> void:
	var depth := .17
	var bend := .17
	var yaw := 0.0
	var right := Vector3(-.55, -.39, .32)
	var left := Vector3(.55, -.39, .31)
	var pulse := sin(PI * phase)
	match group:
		4:
			var lift := pulse_window(phase, .02, .24, .30, .50)
			var slam := pulse_window(phase, .28, .55, .69, .97)
			depth += .62 * slam - .11 * lift
			bend += .78 * slam - .23 * lift
			yaw = -.38 * lift + .31 * slam
			right += Vector3(-.18, 1.24, -.22) * lift + Vector3(.19, -.40, .72) * slam
			left += Vector3(.24, .58, .22) * lift + Vector3(-.09, -.23, .52) * slam
		23:
			var kneel := 1.0 - smoothstep(.08, .82, phase)
			depth += .75 * kneel
			bend += .99 * kneel
			yaw = -.07 * kneel
			right += Vector3(.09, -.49, .79) * kneel
			left += Vector3(-.07, -.49, .77) * kneel
		26:
			depth += .09 * pulse
			bend += .12 * pulse
			yaw = .31 * pulse
			right += Vector3(.07, .25, .26) * pulse
		27:
			var guard := pulse_window(phase, .04, .31, .76, .98)
			depth += .27 * guard
			bend += .33 * guard
			yaw = -.14 * guard
			right += Vector3(-.30, .81, .40) * guard
			left += Vector3(.30, .73, .34) * guard
		28:
			var ready := smoothstep(.07, .89, phase)
			depth += .28 * ready
			bend += .36 * ready
			yaw = -.23 * ready
			right += Vector3(-.09, .65, .47) * ready
			left += Vector3(.10, .27, .52) * ready
	var hip := rig.find_bone("bip01")
	var placement := rig.get_bone_global_pose(hip)
	placement.origin += rig.global_basis.inverse() * Vector3(0.0, -depth, -.21 * depth)
	rig.set_bone_global_pose(hip, placement)
	rig.force_update_all_bone_transforms()
	turn_world(rig, "bip01 spine", Vector3.RIGHT, bend * .60)
	turn_world(rig, "bip01 spine1", Vector3.RIGHT, bend * .24)
	turn_world(rig, "bip01 spine2", Vector3.UP, yaw)
	turn_world(rig, "bip01 head", Vector3.RIGHT, -.19 * bend)
	for side: String in ["l", "r"]:
		var side_sign := 1.0 if side == "l" else -1.0
		var foot := rig.find_bone("bip01 %s foot" % side)
		var target := rig.get_bone_global_pose(foot)
		target.origin = rig.to_local(Vector3(side_sign * .47, .20, .24 if side == "l" else -.11))
		fit_foot(rig, side, target)
	var center := joint_world(rig, "bip01 pelvis")
	fit_arm(rig, "r", center + right)
	fit_arm(rig, "l", center + left)
