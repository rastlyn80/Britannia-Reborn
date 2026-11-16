# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceModeCreatureVisual.gd"


func _ready() -> void:
	super._ready()
	terrain.extent = Vector2(1.18, 1.15)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or treatment != "modern":
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as ShaderMaterial
			if material:
				material.shader = preload("res://Presentation/CreatureVertexTintSurface.gdshader")
				material.set_shader_parameter("use_vertex_tint", true)
				material.set_shader_parameter("skin_roughness", .90 if surface == 0 else .76)
