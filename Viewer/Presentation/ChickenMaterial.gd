extends RefCounted
## Original hen maps; authored body/comb colour regions preserve dark eyes.
static func build(source: StandardMaterial3D,hue: int) -> Material:
	if source.albedo_texture==null and source.roughness<.5:return source
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/ChickenSurface.gdshader")
	material.set_shader_parameter("source_colour",source.albedo_color)
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("use_texture",source.albedo_texture!=null)
	material.set_shader_parameter("use_normal",source.normal_texture!=null)
	material.set_shader_parameter("normal_strength",source.normal_scale)
	material.set_shader_parameter("source_roughness",source.roughness)
	material.set_shader_parameter("partial_region",source.albedo_texture!=null)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
