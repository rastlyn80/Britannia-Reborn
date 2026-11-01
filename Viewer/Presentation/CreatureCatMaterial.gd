extends RefCounted
## Preserve the source's three colour regions and fixed authored eye surfaces.
static func build(source: StandardMaterial3D,hue: int) -> Material:
	if source.resource_name.begins_with("CatEye"):return source
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureCatSurface.gdshader")
	material.set_shader_parameter("source_colour",source.albedo_color)
	material.set_shader_parameter("pink_region",source.resource_name=="CatPink")
	material.set_shader_parameter("white_region",source.resource_name=="CatWhite")
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
