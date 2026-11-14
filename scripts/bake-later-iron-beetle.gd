# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/bake-swamp-widow-juka-actions.gd"

const Extra := {
	"IronGuard": [15, .70], "IronAlert": [23, .90], "ReadyStance": [25, 1.45],
	"IronLift": [26, 1.04], "IronSift": [27, .90], "IronArm": [28, .78],
	"Death": [2, .88], "Death2": [3, .93],
}
const Joints := ["bip01", "bip01 spine", "bip01 spine1", "bip01 spine2", "bip01 neck",
	"bip01 l upperarm", "bip01 r upperarm", "bip01 l forearm", "bip01 r forearm",
	"bip01 l hand", "bip01 r hand"]

func run() -> void:
	var donor := Registry.entry(48)
	var folder := OS.get_environment("BR_LATER_CREATURE_OUTPUT")
	assert(not folder.is_empty() and DirAccess.dir_exists_absolute(folder))
	for style: String in ["original", "rounded", "modern"]:
		var path := Registry.asset_path(donor, style)
		assert(FileAccess.get_sha256(path) == donor.asset_sha256[style])
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		var rig := model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
		var player := model.find_children("*", "AnimationPlayer", true, false)[0] as AnimationPlayer
		var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		var source := mesh.mesh as ArrayMesh
		var altered := ArrayMesh.new()
		var tail_bindings := {}
		var shell_bindings := []
		for binding: int in range(mesh.skin.get_bind_count()):
			var bone := mesh.skin.get_bind_bone(binding)
			var name: String = rig.get_bone_name(bone) if bone >= 0 else mesh.skin.get_bind_name(binding)
			if name.begins_with("bip01 tail"):
				tail_bindings[binding] = true
			elif name == "bip01 spine2":
				shell_bindings.append(binding)
		assert(not tail_bindings.is_empty() and shell_bindings.size() == 1)
		for surface: int in range(source.get_surface_count()):
			var data := source.surface_get_arrays(surface)
			var points: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
			var bones: PackedInt32Array = data[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = data[Mesh.ARRAY_WEIGHTS]
			var stride := bones.size() / points.size()
			var trim := PackedByteArray()
			trim.resize(points.size())
			for index: int in range(points.size()):
				var tail_influence := 0.0
				for slot: int in range(stride):
					if tail_bindings.has(bones[index * stride + slot]):
						tail_influence += weights[index * stride + slot]
				trim[index] = 1 if tail_influence > .60 else 0
				points[index] = shape(points[index])
			var kept := PackedInt32Array()
			for triangle: int in range(0, indices.size(), 3):
				var a := indices[triangle]
				var b := indices[triangle + 1]
				var c := indices[triangle + 2]
				if trim[a] + trim[b] + trim[c] < 2:
					kept.append_array(PackedInt32Array([a, b, c]))
			data[Mesh.ARRAY_VERTEX] = points
			data[Mesh.ARRAY_INDEX] = kept
			altered.add_surface_from_arrays(source.surface_get_primitive_type(surface), data)
			altered.surface_set_material(surface, brushed_iron(source.surface_get_material(surface)))
		add_shell(altered, shell_bindings[0])
		mesh.mesh = altered
		var skin := Ground.skin_points(mesh, rig)
		var library := player.get_animation_library("").duplicate(true) as AnimationLibrary
		player.remove_animation_library("")
		player.add_animation_library("", library)
		for name: String in Extra:
			var record: Array = Extra[name]
			var clip := fit_grounded(player, rig, [skin], record[1], "__root", Joints, pose_iron.bind(record[0]))
			if library.has_animation(name):
				library.remove_animation(name)
			assert(library.add_animation(name, clip) == OK)
		model.scale = Vector3(.74, .80, .70)
		player.stop()
		rig.reset_bone_poses()
		var scene := PackedScene.new()
		var target := folder.path_join("714-%s.scn" % style)
		assert(scene.pack(model) == OK and ResourceSaver.save(scene, target, ResourceSaver.FLAG_COMPRESS) == OK)
		model.free()
		print("IRON BEETLE FIT: ", style, " ", FileAccess.get_sha256(target))
	quit(0)

func shape(at: Vector3) -> Vector3:
	var rear := smoothstep(-1.20, -0.28, at.y)
	var raised_tail := rear * smoothstep(.60, 1.62, at.z)
	var shell := sin(PI * smoothstep(-2.80, -0.40, at.y)) * smoothstep(.26, .55, at.z) * (1.0 - raised_tail)
	at.x *= 1.0 + .23 * shell - .27 * raised_tail
	at.y -= .50 * raised_tail
	at.z += .20 * shell - .96 * raised_tail
	return at

func add_shell(mesh: ArrayMesh, binding: int) -> void:
	var shell := SphereMesh.new()
	shell.radial_segments = 32
	shell.rings = 12
	var arrays := shell.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var bones := PackedInt32Array()
	var weights := PackedFloat32Array()
	var extent := Vector3(.80, 1.47, .40)
	var centre := Vector3(0, -1.43, .57)
	for index: int in range(vertices.size()):
		var source := vertices[index]
		var normal := normals[index]
		vertices[index] = centre + Vector3(source.x, -source.z, source.y) * extent * 2.0
		normals[index] = (Vector3(normal.x, -normal.z, normal.y) / extent).normalized()
		uvs[index] = Vector2(source.x + .5, source.z + .5)
		bones.append_array(PackedInt32Array([binding, 0, 0, 0]))
		weights.append_array(PackedFloat32Array([1, 0, 0, 0]))
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TANGENT] = null
	arrays[Mesh.ARRAY_BONES] = bones
	arrays[Mesh.ARRAY_WEIGHTS] = weights
	var panel_atlas := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y: int in range(panel_atlas.get_height()):
		for x: int in range(panel_atlas.get_width()):
			var seam := exp(-pow(absf(float(x) / 127 - .5) * 72.0, 2.0))
			var arched := float(y) / 128.0 - .22 * pow(float(x) / 127.0 - .5, 2.0)
			var grooves := pow(.5 + .5 * sin(arched * TAU * 7), 17.0)
			var grain := sin(x * 3.13 + y * 11.71) * .045
			var colour := Color("#8d9fae").lerp(Color("#23323d"), clampf(.71 * maxf(seam, grooves) + grain, 0.0, 1.0))
			panel_atlas.set_pixel(x, y, colour)
	panel_atlas.generate_mipmaps()
	var steel := StandardMaterial3D.new()
	steel.albedo_texture = ImageTexture.create_from_image(panel_atlas)
	steel.metallic = .74
	steel.roughness = .5
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(mesh.get_surface_count() - 1, steel)

func brushed_iron(source: Material) -> StandardMaterial3D:
	var original := source as StandardMaterial3D
	var material := original.duplicate() as StandardMaterial3D
	var atlas := original.albedo_texture.get_image()
	if atlas.is_compressed():
		assert(atlas.decompress() == OK)
	atlas.convert(Image.FORMAT_RGBA8)
	for y: int in range(atlas.get_height()):
		for x: int in range(atlas.get_width()):
			var texel := atlas.get_pixel(x, y)
			var light := smoothstep(.10, .74, texel.get_luminance())
			var iron := Color("#1e2b36").lerp(Color("#d3e0e5"), light)
			iron.a = texel.a
			atlas.set_pixel(x, y, iron)
	atlas.generate_mipmaps()
	material.albedo_texture = ImageTexture.create_from_image(atlas)
	material.metallic = .75
	material.roughness = .49
	return material

func pose_iron(rig: Skeleton3D, phase: float, group: int) -> void:
	var impulse := smoothstep(.10, .37, phase) * (1.0 - smoothstep(.57, .93, phase))
	var fall := smoothstep(.20, .90, phase) if group in [2, 3] else 0.0
	var twist := .66 if group == 3 else -.18
	turn_world(rig, "bip01", Vector3.FORWARD, twist * fall)
	turn_world(rig, "bip01 spine", Vector3.RIGHT, -.16 * fall + .13 * impulse)
	turn_world(rig, "bip01 spine2", Vector3.RIGHT, .20 * fall - .22 * impulse)
	turn_world(rig, "bip01 neck", Vector3.RIGHT, .24 * impulse)
	for side: String in ["l", "r"]:
		var sign := 1.0 if side == "l" else -1.0
		var reach := impulse if group != 27 or side == "l" else .35 * impulse
		turn_world(rig, "bip01 " + side + " upperarm", Vector3.UP, sign * (.28 * fall - .31 * reach))
		turn_world(rig, "bip01 " + side + " forearm", Vector3.RIGHT, -.39 * reach + .13 * fall)
		turn_world(rig, "bip01 " + side + " hand", Vector3.FORWARD, sign * (.30 * fall + .19 * impulse))
