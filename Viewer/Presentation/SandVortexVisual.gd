extends "res://Presentation/EnergyVortexVisual.gd"

const Dust = preload("res://Presentation/SandVortexSurface.gdshader")


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var material := mesh.get_surface_override_material(0) as ShaderMaterial
		if material == null or material.shader == Dust:
			continue
		var twist: float = material.get_shader_parameter("twist")
		material.shader = Dust
		material.set_shader_parameter("twist", twist)
		material.set_shader_parameter("hue_palette", Hues.palette(value))
		material.set_shader_parameter("use_hue", Hues.palette(value) != null)
		material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
		material.set_shader_parameter("phase", energy_phase)
