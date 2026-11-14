# SPDX-License-Identifier: GPL-3.0-or-later
extends SceneTree

func _initialize() -> void:
	bake.call_deferred()


func bake() -> void:
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style in ["original", "rounded", "modern"]:
		var donor := folder.path_join("723-%s.scn" % style)
		var model := (load(donor) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		model.scale *= Vector3(.87, 1.05, .86)
		var body := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var original := body.mesh as ArrayMesh
		var mesh := ArrayMesh.new()
		for surface in original.get_surface_count():
			var arrays := original.surface_get_arrays(surface)
			if surface > 0:
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var center := Vector3.ZERO
				for point in vertices:
					center += point / vertices.size()
				for index in vertices.size():
					var point := vertices[index] - center
					vertices[index] = center + Vector3(point.x * 1.18, point.y * 1.60, point.z * .78)
				arrays[Mesh.ARRAY_VERTEX] = vertices
			mesh.add_surface_from_arrays(original.surface_get_primitive_type(surface), arrays)
			var material := original.surface_get_material(surface).duplicate() as StandardMaterial3D
			material.albedo_texture = deplete_skin(material.albedo_texture, surface > 0)
			material.roughness = .9
			mesh.surface_set_material(surface, material)
		body.mesh = mesh
		var scenes := PackedScene.new()
		var output := folder.path_join("334-%s.scn" % style)
		assert(scenes.pack(model) == OK and ResourceSaver.save(scenes, output, ResourceSaver.FLAG_COMPRESS) == OK)
		print("ENSLAVED GOBLIN BAKE: ", style, " ", FileAccess.get_sha256(output))
		model.free()
	quit(0)


func deplete_skin(texture: Texture2D, ear: bool) -> Texture2D:
	var pixels := texture.get_image()
	if pixels.is_compressed():
		assert(pixels.decompress() == OK)
	pixels.convert(Image.FORMAT_RGB8)
	for y in pixels.get_height():
		for x in pixels.get_width():
			var color := pixels.get_pixel(x, y)
			var skin := 1.0 if ear else smoothstep(.012, .052, color.g - color.r)
			var value := smoothstep(.06, .62, color.get_luminance())
			var grey := Color("#2e3944").lerp(Color("#9fabb0"), value)
			pixels.set_pixel(x, y, color.lerp(grey, skin))
	pixels.generate_mipmaps()
	return ImageTexture.create_from_image(pixels)
