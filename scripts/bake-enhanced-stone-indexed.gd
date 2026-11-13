# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-fitted-spell-forms.gd"

const Exact := preload("res://../scripts/test-quadruped-actions.gd")
const Fits := ["EnhancedStoneFallback", "EnhancedStoneFallForward", "EnhancedStoneBackhand", "EnhancedStoneOverhead"]


func run() -> void:
	var destination := OS.get_environment("BR_INDEXED_BAKE_DIRECTORY")
	assert(not destination.is_empty(), "Set BR_INDEXED_BAKE_DIRECTORY to the local build folder.")
	var folder := destination.path_join("stone-form-enhanced")
	assert(DirAccess.make_dir_recursive_absolute(folder) == OK)
	var row := Registry.entry(705)
	for treatment: String in TREATMENTS:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		bake_pose(player, rig, mesh, Fits[0], "Idle", .72, stone_fall.bind(rig, false), true)
		bake_pose(player, rig, mesh, Fits[1], "Idle", .81, stone_fall.bind(rig, true), true)
		bake_pose(player, rig, mesh, Fits[2], "Idle", 1.08, stone_strike.bind(rig, false))
		bake_pose(player, rig, mesh, Fits[3], "Idle", 1.17, stone_strike.bind(rig, true))
		Grounding.fit_source_floor(model, PackedStringArray([Fits[2], Fits[3]]))
		Exact.check_earlier_keys(player, source)
		player.stop()
		rig.reset_bone_poses()
		var result := PackedScene.new()
		assert(result.pack(model) == OK)
		assert(ResourceSaver.save(result, folder.path_join("705-%s.scn" % treatment), ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("ENHANCED STONE FIT: ", treatment, ", two strikes and two falls")
	quit(0)


func stone_fall(phase: float, rig: Skeleton3D, forward: bool) -> void:
	var fall := smoothstep(.33, .76, phase)
	var stagger := action_peak(phase, .31)
	var splay := smoothstep(.38, .68, phase)
	var pitch := (1.58 if forward else -1.49) * fall - .23 * stagger
	rotate_world(rig, "bip01 pelvis", Vector3.RIGHT, pitch)
	rotate_world(rig, "bip01 pelvis", Vector3.UP, (-.16 if forward else .22) * fall)
	rotate_world(rig, "bip01 spine1", Vector3.RIGHT, .14 * stagger + .09 * fall)
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side
		var sign := 1.0 if side == "l" else -1.0
		rotate_world(rig, prefix + " thigh", Vector3.RIGHT, -.38 * stagger + sign * .16 * fall)
		rotate_world(rig, prefix + " calf", Vector3.RIGHT, .42 * stagger + sign * .15 * fall)
		rotate_world(rig, prefix + " upperarm", Vector3.BACK, -sign * (.33 * stagger + .91 * splay))
		rotate_world(rig, prefix + " upperarm", Vector3.RIGHT, -.7 * stagger + (.46 if forward else -.48) * fall)
		rotate_world(rig, prefix + " forearm", Vector3.RIGHT, -.34 * stagger + sign * .21 * fall)
	var hip := rig.find_bone("bip01 pelvis")
	var pose := rig.get_bone_global_pose(hip)
	pose.origin += rig.global_basis.inverse() * Vector3(.10 * fall, 0, (.23 if forward else -.26) * fall)
	rig.set_bone_global_pose(hip, pose)


func stone_strike(phase: float, rig: Skeleton3D, overhead: bool) -> void:
	var wind := smoothstep(.02, .25, phase) * (1.0 - smoothstep(.30, .48, phase))
	var blow := smoothstep(.30, .56, phase) * (1.0 - smoothstep(.68, .97, phase))
	rotate_world(rig, "bip01 spine1", Vector3.RIGHT, -.25 * wind + (.78 if overhead else .55) * blow)
	rotate_world(rig, "bip01 spine1", Vector3.UP, (.13 if overhead else .71) * wind - (.18 if overhead else .63) * blow)
	for side: String in ["l", "r"]:
		var prefix := "bip01 " + side
		var sign := 1.0 if side == "l" else -1.0
		var strength := 1.0 if overhead or side == "r" else .65
		rotate_world(rig, prefix + " upperarm", Vector3.RIGHT, strength * ((-1.95 if overhead else -.91) * wind + .65 * blow))
		rotate_world(rig, prefix + " upperarm", Vector3.BACK, -sign * strength * ((.26 if overhead else .86) * wind + .18 * blow))
		rotate_world(rig, prefix + " forearm", Vector3.RIGHT, -.67 * wind + .22 * blow)
