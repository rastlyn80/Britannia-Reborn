# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _initialize() -> void:
	var source := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not source.is_empty() and DirAccess.dir_exists_absolute(source))
	for style: String in ["original", "rounded", "modern"]:
		var importer := GLTFDocument.new()
		var state := GLTFState.new()
		assert(importer.append_from_file(source.path_join("parrot-%s.gltf" % style), state) == OK)
		var model := importer.generate_scene(state)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		assert(rig.get_bone_count() == 42)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		for clip in ["Idle", "Walk", "Fidget", "Fidget2"]:
			assert(player.has_animation(clip))
			var tracks := player.get_animation(clip).get_track_count()
			assert(tracks > 0)
			print("PERCH PARROT CLIP: ", style, " ", clip, " ", tracks)
		var scene := PackedScene.new()
		var path := source.path_join("282-%s.scn" % style)
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, path, ResourceSaver.FLAG_COMPRESS) == OK)
		print("PERCH PARROT BAKE: ", style, " 42 joints ", FileAccess.get_sha256(path))
		model.free()
	quit(0)

