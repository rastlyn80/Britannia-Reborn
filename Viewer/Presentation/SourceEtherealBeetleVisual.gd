extends "res://Presentation/SourceBeetleVisual.gd"

const SpectralSurface = preload("res://Presentation/SourceEtherealBeetleSurface.gdshader")
const Hue = preload("res://Presentation/HumanHue.gd")

func _ready() -> void:
	super._ready()
	set_meta("equine_profile", {"ethereal": true})

func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null or treatment != "modern":
		return
	var palette: Texture2D = null if value == 0x4001 else Hue.palette(value)
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var source := mesh.mesh.surface_get_material(surface) as StandardMaterial3D
			if source == null or source.albedo_texture == null:
				continue
			var material := ShaderMaterial.new()
			material.shader = SpectralSurface
			material.set_shader_parameter("atlas", source.albedo_texture)
			material.set_shader_parameter("hue_palette", palette)
			material.set_shader_parameter("use_hue", palette != null)
			material.set_shader_parameter("partial_hue", (value & 0x8000) != 0)
			mesh.set_surface_override_material(surface, material)
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
