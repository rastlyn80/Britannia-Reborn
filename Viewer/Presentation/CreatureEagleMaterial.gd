extends RefCounted
## Authored colour-region tinting. This is not a recovered native dye mask.
static func build(source: StandardMaterial3D,hue: int) -> Material:
	if source.resource_name.begins_with("EagleEye"):return source
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureEagleSurface.gdshader")
	material.set_shader_parameter("source_colour",source.albedo_color)
	material.set_shader_parameter("feather_region",source.resource_name in ["EagleHead","EagleWings"])
	material.set_shader_parameter("white_region",source.resource_name=="EagleHead")
	material.set_shader_parameter("tintable_partial",source.resource_name=="EagleWings")
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
