# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-giant-spider-actions.gd"

const Clips := {
	"SpiderPounce": [4, .70], "SpiderFangSweep": [5, .75], "SpiderRecoil": [10, .62],
	"SpiderCrouch": [15, .74], "SpiderRaise": [23, 1.28], "SpiderSplay": [26, .94],
	"SpiderCephalicTurn": [27, .94], "SpiderBraceRise": [28, .88],
}


func run() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	var row := Registry.entry(28)
	for treatment: String in ["original", "rounded", "modern"]:
		var source := Registry.asset_path(row, treatment)
		assert(FileAccess.get_sha256(source) == row.asset_sha256[treatment])
		var model := (load(source) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		player.deterministic = true
		for clip: String in Clips:
			var data: Array = Clips[clip]
			assert(library.add_animation(clip, fit(player, rig, skin, data[0], data[1])) == OK)
		for group: int in [2, 3]:
			var name := "Death" if group == 2 else "Death2"
			library.remove_animation(name)
			assert(library.add_animation(name, fit(player, rig, skin, group, 1.08 if group == 2 else .94)) == OK)
		var walk := player.get_animation("Walk").duplicate(true) as Animation
		walk.length = player.get_animation("Walk").length
		assert(library.add_animation("SpiderPeaceWalk", walk) == OK)
		assert(library.add_animation("ReadyStance", fit(player, rig, skin, 25, 1.5)) == OK)
		player.stop()
		rig.reset_bone_poses()
		model.scale = Vector3(.83, .90, .93)
		var mesh_data := mesh.mesh.duplicate() as ArrayMesh
		for surface: int in mesh_data.get_surface_count():
			var material := mesh_data.surface_get_material(surface).duplicate() as StandardMaterial3D
			material.albedo_color = Color(.68, .45, .31)
			material.roughness = .81
			mesh_data.surface_set_material(surface, material)
		mesh.mesh = mesh_data
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK)
		assert(ResourceSaver.save(packed, folder.path_join("736-%s.scn" % treatment),
				ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("WOLF SPIDER FIT: ", treatment, ", ", Clips.size() + 2, " fitted motions plus donor walk")
	quit(0)


func pose(rig: Skeleton3D, slot: int, phase: float) -> void:
	var push := smoothstep(.12, .42, phase) * (1.0 - smoothstep(.52, .95, phase))
	var wind := smoothstep(.05, .24, phase) * (1.0 - smoothstep(.27, .49, phase))
	var curl := smoothstep(.15, .78, phase) if slot == 3 else 0.0
	var flatten := smoothstep(.23, .89, phase) if slot == 2 else 0.0
	var dip := push if slot in [4, 10, 15] else 0.0
	var fang := push if slot == 5 else 0.0
	var rise := (1.0 - smoothstep(.12, .80, phase)) if slot in [23, 28] else 0.0
	var quiet := .08 if slot == 25 else 0.0
	turn(rig, "bone01", Vector3.RIGHT, .31 * dip - .21 * wind - .34 * rise + .12 * curl + .08 * flatten)
	turn(rig, "bone01", Vector3.UP, .21 * fang)
	turn(rig, "bone02", Vector3.RIGHT, -.34 * dip + .20 * wind - .24 * curl - .23 * flatten + quiet)
	turn(rig, "bone02", Vector3.UP, -.32 * fang)
	for leg in LEGS.size():
		var pair: Array = LEGS[leg]
		var left := 1.0 if leg % 2 == 0 else -1.0
		var front := leg < 4
		var lunge := push - .63 * wind if front and slot == 4 else 0.0
		var swipe := fang if leg == 0 else .35 * fang if leg == 2 else 0.0
		var sway := push if slot in [26, 27] else 0.0
		turn(rig, pair[0], Vector3.UP, left * (.64 * curl + .40 * lunge - .2 * sway) - .49 * swipe)
		turn(rig, pair[0], Vector3.FORWARD, left * (1.0 * curl - .28 * flatten + .2 * dip + .30 * rise + .13 * sway))
		turn(rig, pair[1], Vector3.FORWARD, left * (-1.48 * curl + .68 * flatten - .35 * lunge - .15 * rise))
		turn(rig, pair[0], Vector3.RIGHT, -.48 * swipe)
