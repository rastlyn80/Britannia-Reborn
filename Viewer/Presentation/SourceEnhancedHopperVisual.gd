# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/HopperActionsVisual.gd"

const WingShader := preload("SourceEnhancedHopperWing.gdshader")
const Hue := preload("res://Presentation/HumanHue.gd")


func _ready() -> void:
	entry = entry.duplicate()
	entry["grounded_gestures"] = entry.get("grounded_gestures", []) + entry.get("archive_grounded_gestures", [])
	super._ready()
	var wings := model.find_child("HopperWings", true, false) as MeshInstance3D
	assert(wings != null)
	skin = skin.duplicate(true)
	append_wing_skin(Ground.skin_points(wings, skeleton))
	fall.skin = skin


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	var wings := model.find_child("HopperWings", true, false) as MeshInstance3D
	if wings == null:
		return
	var palette: Texture2D = Hue.palette(value) if treatment == "modern" else null
	for surface in wings.mesh.get_surface_count():
		var atlas := wings.mesh.surface_get_material(surface) as StandardMaterial3D
		var material := ShaderMaterial.new()
		material.shader = WingShader
		material.set_shader_parameter("wing_atlas", atlas.albedo_texture)
		material.set_shader_parameter("hue_palette", palette)
		material.set_shader_parameter("use_hue", palette != null)
		material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
		material.set_shader_parameter("membrane", surface == 1)
		wings.set_surface_override_material(surface, material)


func append_wing_skin(wings: Dictionary) -> void:
	var offset: int = skin.bones.size()
	skin.bones.append_array(wings.bones)
	skin.bind_poses.append_array(wings.bind_poses)
	for wing_surface: Dictionary in wings.surfaces:
		var surface := wing_surface.duplicate()
		var bindings: PackedInt32Array = surface.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		surface.bindings = bindings
		skin.surfaces.append(surface)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in source.entry.get("archive_grounded_gestures", []):
		global_transform = source.global_transform
	return super.begin_death_from(source)
