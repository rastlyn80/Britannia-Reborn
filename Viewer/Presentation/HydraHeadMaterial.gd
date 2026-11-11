# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const ShaderSource := preload("res://Presentation/HydraScaleSurface.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")
const HeadRoots := {
	"bip01 neck1": Color("efc651"), "bip01 r upperarm": Color("24b7d5"),
	"bip01 l upperarm": Color("76ad42"), "bip01 r thigh": Color("d84942"),
	"bip01 l thigh": Color("c4b158"),
}
static var coloured_meshes: Dictionary = {}


static func apply(body: MeshInstance3D, rig: Skeleton3D, hue: int, detail: float) -> void:
	if not body.mesh.has_meta("hydra_head_colours"):
		var id := body.mesh.get_instance_id()
		if not coloured_meshes.has(id):
			coloured_meshes[id] = make_coloured_mesh(body, rig)
		body.mesh = coloured_meshes[id]
	var palette := Hue.palette(hue)
	for index in body.mesh.get_surface_count():
		var original := body.mesh.surface_get_material(index) as StandardMaterial3D
		assert(original != null and original.albedo_texture != null)
		var material := ShaderMaterial.new()
		material.shader = ShaderSource
		material.set_shader_parameter("albedo_texture", original.albedo_texture)
		material.set_shader_parameter("hue_palette", palette)
		material.set_shader_parameter("use_hue", palette != null)
		material.set_shader_parameter("partial_hue", (hue & 0x8000) != 0)
		material.set_shader_parameter("detail_strength", detail)
		body.set_surface_override_material(index, material)


static func make_coloured_mesh(body: MeshInstance3D, rig: Skeleton3D) -> ArrayMesh:
	var source := body.mesh as ArrayMesh
	assert(source != null and source.get_blend_shape_count() == 0)
	var result := ArrayMesh.new()
	var binding_colours := PackedColorArray()
	for bind in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(bind)
		if bone < 0:
			bone = rig.find_bone(body.skin.get_bind_name(bind))
		assert(bone >= 0)
		var colour := Color(0, 0, 0, 0)
		while bone >= 0:
			var name := rig.get_bone_name(bone)
			if HeadRoots.has(name):
				var head_colour: Color = HeadRoots[name]
				colour = head_colour.srgb_to_linear()
				break
			bone = rig.get_bone_parent(bone)
		binding_colours.append(colour)
	for index in source.get_surface_count():
		var arrays := source.surface_get_arrays(index)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var joints: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride := joints.size() / vertices.size()
		assert(stride == 4 or stride == 8)
		var colours := PackedColorArray()
		colours.resize(vertices.size())
		for vertex in vertices.size():
			var colour := Color(0, 0, 0, 0)
			for influence in stride:
				var slot := vertex * stride + influence
				if weights[slot] > 0.0:
					colour += binding_colours[joints[slot]] * weights[slot]
			colours[vertex] = colour
		arrays[Mesh.ARRAY_COLOR] = colours
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if stride == 8 else 0
		result.add_surface_from_arrays(source.surface_get_primitive_type(index), arrays, [], {}, flags)
		assert(result.get_surface_count() == index + 1)
		result.surface_set_material(index, source.surface_get_material(index))
	result.set_meta("hydra_head_colours", true)
	return result
