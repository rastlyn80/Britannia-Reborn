# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceModeCreatureVisual.gd"

func _ready() -> void:
	super._ready()
	terrain.extent = Vector2(1.95, 2.35)


func set_hue(value: int) -> void:
	super.set_hue(value)
	if treatment == "modern" and is_instance_valid(model):
		apply_matte_shell()


func apply_matte_shell() -> void:
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var material := mesh.get_surface_override_material(surface) as ShaderMaterial
			if material:
				material.set_shader_parameter("skin_roughness", .88)
				material.set_shader_parameter("detail_strength", .18)


func web_origin() -> Variant:
	if dead or current_clip != "NavreySilkLift" or action_remaining <= 0.0:
		return null
	skeleton.force_update_all_bone_transforms()
	var spinnerets := skeleton.find_bone("bone02")
	return skeleton.to_global(skeleton.get_bone_global_pose(spinnerets) * Vector3(0.0, .50, -.07))
