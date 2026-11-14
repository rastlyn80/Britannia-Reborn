# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-giant-spider-actions.gd"

const Clips := {2: ["Death", .83], 3: ["Death2", 1.06], 4: ["TrapdoorSnap", .59],
	5: ["TrapdoorPounce", .78], 10: ["TrapdoorRecoil", .45], 11: ["TrapdoorClawWatch", .94],
	15: ["TrapdoorWithdraw", .54], 23: ["TrapdoorAbdomenLift", 1.22],
	25: ["ReadyStance", 1.35], 26: ["TrapdoorSignal", .85],
	27: ["TrapdoorSway", 1.02], 28: ["TrapdoorRise", .79]}


func run() -> void:
	var row := Registry.entry(157)
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, style)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[style])
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		model.scale *= Vector3(.89, .63, .84)
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for group: int in Clips:
			var data: Array = Clips[group]
			if library.has_animation(data[0]):
				library.remove_animation(data[0])
			assert(library.add_animation(data[0], fit(player, rig, skin, group, data[1])) == OK)
		assert(library.add_animation("TrapdoorPeaceWalk", player.get_animation("Walk").duplicate(true)) == OK)
		player.stop()
		rig.reset_bone_poses()
		var packed := PackedScene.new()
		var target := folder.path_join("737-%s.scn" % style)
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("TRAPDOOR SPIDER FIT: ", style, " donor ", FileAccess.get_sha256(source), ", output ", FileAccess.get_sha256(target))
	quit(0)


func pose(rig: Skeleton3D, group: int, phase: float) -> void:
	var pulse := smoothstep(.07, .37, phase) * (1.0 - smoothstep(.57, .96, phase))
	var wind := smoothstep(.07, .20, phase) * (1.0 - smoothstep(.26, .47, phase))
	var collapse := smoothstep(.12, .92, phase) if group in [2, 3] else 0.0
	var sweep := pulse if group in [4, 5, 11, 26] else 0.0
	var tuck := pulse if group in [10, 15] else 0.0
	var rise := pulse if group in [23, 27, 28] else 0.0
	turn(rig, "bone01", Vector3.RIGHT, .24 * sweep - .30 * wind + .35 * tuck - .37 * rise)
	turn(rig, "bone01", Vector3.FORWARD, (.08 if group == 2 else -.41) * collapse)
	turn(rig, "bone02", Vector3.RIGHT, -.33 * sweep + .46 * rise + .26 * collapse)
	for index in LEGS.size():
		var pair: Array = LEGS[index]
		var side := 1.0 if index % 2 == 0 else -1.0
		var forward := sweep if index < (4 if group == 5 else 2) else .14 * sweep
		var fold := (-.42 if group == 2 else .84) * collapse
		turn(rig, pair[0], Vector3.UP, side * (fold + .38 * forward - .20 * rise))
		turn(rig, pair[0], Vector3.RIGHT, -.54 * forward + .24 * tuck)
		turn(rig, pair[1], Vector3.FORWARD, side * (fold + .43 * forward + .29 * tuck))
