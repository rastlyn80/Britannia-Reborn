extends "res://Presentation/WispVisual.gd"

const Surface = preload("res://Presentation/FetidEssenceSurface.gdshader")

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		if material != null:
			var uniforms := {}
			for name in ["core", "density", "energy_colour", "hue_palette", "use_hue", "partial_hue", "phase"]:
				uniforms[name] = material.get_shader_parameter(name)
			material.shader = Surface
			for name: String in uniforms:
				material.set_shader_parameter(name, uniforms[name])
