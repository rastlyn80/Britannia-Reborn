# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree


func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style in ["original", "rounded", "modern"]:
		var document := GLTFDocument.new()
		var state := GLTFState.new()
		var input := folder.path_join("orcs_orc_scout-%s.gltf" % style)
		assert(document.append_from_file(input, state) == OK)
		var model := document.generate_scene(state)
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var meshes := model.find_children("*", "MeshInstance3D", true, false)
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		assert(rig.get_bone_count() in [35, 36] and meshes.size() == 1,
			str([rig.get_bone_count(), meshes.size(), player.get_animation_list()]))
		for clip in ["Idle", "Walk", "Run", "Attack", "AttackBow", "Hit", "Death", "Fidget", "Stomp"]:
			assert(player.has_animation(clip))
		if style == "modern":
			var surface := meshes[0] as MeshInstance3D
			for index in surface.mesh.get_surface_count():
				var material := (surface.get_active_material(index) as StandardMaterial3D).duplicate() as StandardMaterial3D
				material.roughness = .84
				material.metallic = 0.0
				surface.set_surface_override_material(index, material)
		var output := folder.path_join("181-%s.scn" % style)
		var packed := PackedScene.new()
		assert(packed.pack(model) == OK and ResourceSaver.save(packed, output, ResourceSaver.FLAG_COMPRESS) == OK)
		print("ORC SCOUT BAKE: ", style, ", ", rig.get_bone_count(), " bones, ",
			player.get_animation_list().size(), " clips, ", FileAccess.get_sha256(output))
		model.free()
	quit()
