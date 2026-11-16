# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLaterFlyingVisual.gd"


func _ready() -> void:
	super._ready()
	terrain.extent = Vector2(3.2, 3.7)


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
				material.set_shader_parameter("skin_roughness", .79)


func receive_action(request: Dictionary) -> bool:
	var classic: bool = request.get("protocol") == "classic"
	var action := int(request.get("action", -1))
	var melee: bool = (classic and action in [4, 5, 6]) or (request.get("protocol") == "new" and request.get("type") == 0)
	if melee and breath_origin() is Vector3:
		return true
	var stock_breath: bool = classic and action == 12 and request.get("frames") == 5 and request.get("repeat_count") == 1 \
		and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0
	if not stock_breath:
		return super.receive_action(request)
	var accepted := super.receive_action(request.merged({"action": 27, "frames": 0}, true))
	if accepted:
		set_meta("native_action", request.duplicate(true))
	return accepted


func breath_origin() -> Variant:
	if dead or current_clip != "StygianBreath" or action_remaining <= 0.0:
		return null
	skeleton.force_update_all_bone_transforms()
	var jaw := skeleton.find_bone("box14")
	return skeleton.to_global(skeleton.get_bone_global_pose(jaw).origin)
