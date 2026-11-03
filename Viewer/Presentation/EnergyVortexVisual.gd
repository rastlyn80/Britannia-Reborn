extends "res://Presentation/WispVisual.gd"

const Hues = preload("res://Presentation/HumanHue.gd")


func set_hue(value: int) -> void:
	hue = value
	if model == null:
		return
	var palette: Texture2D = Hues.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		var surface := mesh.get_surface_override_material(0) as ShaderMaterial
		if surface == null:
			surface = mesh.mesh.surface_get_material(0).duplicate() as ShaderMaterial
			surface.set_meta("snapshot_uniform_time", true)
			mesh.set_surface_override_material(0, surface)
		surface.set_shader_parameter("hue_palette", palette)
		surface.set_shader_parameter("use_hue", palette != null)
		surface.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
		surface.set_shader_parameter("phase", energy_phase)


func _exit_tree() -> void:
	if is_instance_valid(model):
		for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
			mesh.set_surface_override_material(0, null)
