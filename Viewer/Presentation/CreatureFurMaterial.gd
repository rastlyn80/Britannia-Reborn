extends RefCounted
## Matte fur interpretation, original atlas untouched. Dark eyes remain distinct.
static func build(source: StandardMaterial3D,hue: int,detail: float=.32) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureFurSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0);material.set_shader_parameter("detail_strength",detail)
	return material
