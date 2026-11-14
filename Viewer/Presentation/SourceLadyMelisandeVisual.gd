# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceModeCreatureVisual.gd"

const Cutout := preload("res://Presentation/CreatureCutoutSurface.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")
var material_treatment := ""


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette := Hue.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for index in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(index) as StandardMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var material := mesh.get_surface_override_material(index) as ShaderMaterial
			if material == null or material_treatment != treatment:
				material = ShaderMaterial.new()
				material.shader = Cutout
				material.set_shader_parameter("albedo_texture", source.albedo_texture)
				material.set_shader_parameter("source_alpha_texture", source.albedo_texture)
				material.set_meta("snapshot_uniforms", true)
				mesh.set_surface_override_material(index, material)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			material.set_shader_parameter("detail_strength", detail if treatment == "modern" else 0.0)
	material_treatment = treatment
