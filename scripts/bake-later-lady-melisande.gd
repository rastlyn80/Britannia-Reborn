# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _initialize() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for treatment: String in ["original", "rounded", "modern"]:
		var importer := GLTFDocument.new()
		var state := GLTFState.new()
		var path := folder.path_join("ladymelisande-%s.gltf" % treatment)
		assert(importer.append_from_file(path, state) == OK)
		var model := importer.generate_scene(state)
		assert(model != null)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert(rig.get_bone_count() == 46)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var library := player.get_animation_library("")
		var ready := library.get_animation("Idle").duplicate() as Animation
		ready.loop_mode = Animation.LOOP_LINEAR
		assert(library.add_animation("ReadyStance", ready) == OK)
		var scene := PackedScene.new()
		var target := folder.path_join("258-%s.scn" % treatment)
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("LADY MELISANDE BAKE: ", treatment, " ", FileAccess.get_sha256(target))
	quit(0)
