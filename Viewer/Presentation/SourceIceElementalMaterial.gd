extends RefCounted
## Authored ice response; the original unresolved _m map is deliberately unused.
static func build(source: StandardMaterial3D,hue: int,detail: float) -> ShaderMaterial:
	var result:=ShaderMaterial.new()
	result.shader=preload("res://Presentation/SourceIceElementalSurface.gdshader")
	result.set_shader_parameter("albedo_texture",source.albedo_texture)
	result.set_shader_parameter("detail_strength",clampf(detail,0.,1.))
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	result.set_shader_parameter("hue_palette",palette)
	result.set_shader_parameter("use_hue",palette!=null)
	result.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return result
