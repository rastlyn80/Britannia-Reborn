# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-fitted-spell-forms.gd"

const Foot := preload("res://Presentation/FootContact.gd")
const MODE_DIR := "res://local-art/creatures/stone-mode-trial"
const PREDECESSOR := "res://local-art/creatures/next-spell-forms/"

func run() -> void:
	if Registry.entry(705).has("stone_mode_predecessor"):
		push_error("Bake Stone Form modes in a staging viewer with the base Stone Form registered")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MODE_DIR))
	for treatment: String in TREATMENTS:
		var packed := load(PREDECESSOR + "705-" + treatment + ".scn") as PackedScene
		assert(packed != null)
		var model := packed.instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		stone_mode_poses(player, rig, mesh)
		var names := PackedStringArray(["StonePeaceWalk", "StoneKneelRise", "Run", "ReadyStance",
			"StonePeaceGesture", "StoneWarGesture", "StoneStanceRise"])
		Grounding.fit_source_floor(model, names)
		var result := PackedScene.new()
		assert(result.pack(model) == OK)
		assert(ResourceSaver.save(result, MODE_DIR.path_join("705-" + treatment + ".scn"), ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("STONE MODES ", treatment, " / ", names.size(), " fitted archive clips")
	quit()

func stone_mode_poses(player: AnimationPlayer, rig: Skeleton3D, mesh: MeshInstance3D) -> void:
	bake_pose(player, rig, mesh, "StonePeaceWalk", "Walk", 1.30,
		func(phase: float) -> void:
			relax(rig, .86)
			var swing := sin(TAU * phase)
			rotate_world(rig, "bip01 l upperarm", Vector3.RIGHT, .07 * swing)
			rotate_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.07 * swing))
	bake_pose(player, rig, mesh, "StoneKneelRise", "Idle", 1.90,
		func(phase: float) -> void:
			var crouch := 1.0 - smoothstep(.24, .81, phase)
			var push := action_peak(phase, .57)
			kneel(rig, crouch)
			rotate_world(rig, "bip01 spine1", Vector3.RIGHT, .27 * crouch - .19 * push)
			rotate_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.68 * crouch - .31 * push)
			rotate_world(rig, "bip01 r upperarm", Vector3.RIGHT, -.44 * crouch - .42 * push))
	bake_pose(player, rig, mesh, "StoneRunArchive", "Run", .90,
		func(phase: float) -> void:
			rotate_world(rig, "bip01 spine1", Vector3.RIGHT, .16 + .075 * sin(TAU * phase))
			var pulse := sin(TAU * phase)
			rotate_world(rig, "bip01 l forearm", Vector3.RIGHT, -.11 - .12 * pulse)
			rotate_world(rig, "bip01 r forearm", Vector3.RIGHT, -.11 + .12 * pulse))
	bake_pose(player, rig, mesh, "ReadyStance", "Idle", 2.10,
		func(phase: float) -> void: relax(rig, 1.0 + .042 * sin(TAU * phase)))
	bake_pose(player, rig, mesh, "StonePeaceGesture", "Idle", 3.0,
		func(phase: float) -> void:
			relax(rig, 1.0)
			var turn := action_peak(phase, .62)
			rotate_world(rig, "bip01 spine1", Vector3.UP, .31 * turn)
			rotate_world(rig, "bip01 neck", Vector3.UP, .30 * turn)
			rotate_world(rig, "bip01 l forearm", Vector3.RIGHT, -.37 * turn)
			rotate_world(rig, "bip01 r upperarm", Vector3.BACK, -.18 * turn), false, ["bip01 neck"])
	bake_pose(player, rig, mesh, "StoneWarGesture", "Idle", 1.80,
		func(phase: float) -> void:
			var raise := action_peak(phase, .49)
			rotate_world(rig, "bip01 spine1", Vector3.UP, -.24 * raise)
			rotate_world(rig, "bip01 l upperarm", Vector3.RIGHT, -.92 * raise)
			rotate_world(rig, "bip01 l forearm", Vector3.RIGHT, .41 * raise)
			rotate_world(rig, "bip01 r upperarm", Vector3.RIGHT, .27 * raise))
	bake_pose(player, rig, mesh, "StoneStanceRise", "Idle", 1.10,
		func(phase: float) -> void:
			var entry := smoothstep(.0, .93, phase)
			relax(rig, 1.0 - entry)
			rotate_world(rig, "bip01 spine1", Vector3.RIGHT, -.17 * action_peak(phase, .57)))
	var library := player.get_animation_library("")
	library.remove_animation("Run")
	library.rename_animation("StoneRunArchive", "Run")
	for clip: String in ["Run", "ReadyStance", "StonePeaceWalk"]:
		library.get_animation(clip).loop_mode = Animation.LOOP_LINEAR

func relax(rig: Skeleton3D, amount: float) -> void:
	rotate_world(rig, "bip01 spine1", Vector3.RIGHT, -.19 * amount)
	rotate_world(rig, "bip01 l upperarm", Vector3.RIGHT, .27 * amount)
	rotate_world(rig, "bip01 r upperarm", Vector3.RIGHT, .38 * amount)
	rotate_world(rig, "bip01 l forearm", Vector3.RIGHT, .28 * amount)
	rotate_world(rig, "bip01 r forearm", Vector3.RIGHT, .34 * amount)

func kneel(rig: Skeleton3D, amount: float) -> void:
	var planted := {}
	for side: String in ["l", "r"]:
		var foot := rig.find_bone("bip01 " + side + " foot")
		planted[side] = rig.get_bone_global_pose(foot)
	var hip := rig.find_bone("bip01 pelvis")
	var pose := rig.get_bone_global_pose(hip)
	var inverse := rig.global_basis.inverse()
	pose.origin += inverse * Vector3(.09, -.41, .10) * amount
	rig.set_bone_global_pose(hip, pose)
	rig.force_update_all_bone_transforms()
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side + " "
		var thigh := rig.find_bone(prefix + "thigh")
		var calf := rig.find_bone(prefix + "calf")
		var foot := rig.find_bone(prefix + "foot")
		var anchor: Transform3D = planted[side]
		var target := anchor.origin + inverse * Vector3(0., 0., (.24 if side == "l" else -.27) * amount)
		var a := rig.get_bone_global_pose(thigh).origin
		var b := rig.get_bone_global_pose(calf).origin
		var c := rig.get_bone_global_pose(foot).origin
		aim_joint(rig, thigh, calf, Foot.knee_target(a, b, c, target))
		aim_joint(rig, calf, foot, target)
		anchor.origin = rig.get_bone_global_pose(foot).origin
		rig.set_bone_global_pose(foot, anchor)
		rig.force_update_all_bone_transforms()

func aim_joint(rig: Skeleton3D, bone: int, child: int, goal: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var axis := (rig.get_bone_global_pose(child).origin - pose.origin).normalized()
	pose.basis = Basis(Quaternion(axis, (goal - pose.origin).normalized())) * pose.basis
	rig.set_bone_global_pose(bone, pose)
	rig.force_update_all_bone_transforms()
