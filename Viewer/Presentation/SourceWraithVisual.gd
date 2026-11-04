extends "res://Presentation/CreatureVisual.gd"

const SpectralSurface := preload("res://Presentation/WraithSpectralSurface.gdshader")

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or (value & 0x4000) == 0:
		return
	var atlas := load("res://local-art/creatures/" + str(entry.source_alpha_texture)) as Texture2D
	var spectral := ShaderMaterial.new()
	spectral.shader = SpectralSurface
	spectral.set_shader_parameter("source_atlas", atlas)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			mesh.set_surface_override_material(surface, spectral)
