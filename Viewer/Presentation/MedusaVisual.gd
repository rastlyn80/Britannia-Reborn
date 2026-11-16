# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceGremlinVisual.gd"


func _ready() -> void:
	super._ready()
	terrain.extent = Vector2(.92, .90)
	aim.reach_scale = 1.08


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
				material.set_shader_parameter("skin_roughness", .76 if surface == 0 else .66)


func set_equipment(worn: Array) -> void:
	for item: Dictionary in worn:
		if int(item.get("layer", 0)) != 2 or int(item.get("id", 0)) not in [0x26c2, 0x26cc]:
			continue
		if equip_bow(int(item.get("hue", 0))):
			sync_bow()
		return
	if is_instance_valid(bow):
		bow.hide()
