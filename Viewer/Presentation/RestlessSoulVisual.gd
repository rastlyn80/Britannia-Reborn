extends "res://Presentation/SourcePreservingCreatureVisual.gd"

const Hue := preload("res://Presentation/HumanHue.gd")
const Surface := preload("res://Presentation/RestlessSoulSurface.gdshader")

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or treatment != "modern":
		return
	var palette := Hue.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		if not mesh.visible or mesh.mesh == null:
			continue
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			assert(original != null and original.albedo_texture != null)
			var material := ShaderMaterial.new()
			material.shader = Surface
			material.set_shader_parameter("albedo_texture", original.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			mesh.set_surface_override_material(surface, material)
