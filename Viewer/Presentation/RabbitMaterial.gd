extends RefCounted
## Preserve the CC0 artist's actual normal and alpha maps; matte fur and dyes.
static func build(source: StandardMaterial3D,hue: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/RabbitSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("fur_cards",source.resource_name=="CC0 rabbit source alpha fur")
	material.set_shader_parameter("use_normal_texture",source.normal_texture!=null)
	if source.normal_texture!=null:material.set_shader_parameter("normal_texture",source.normal_texture);material.set_shader_parameter("normal_strength",source.normal_scale)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
