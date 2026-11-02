extends RefCounted
## Source-opacity-bound flesh and gel; generated RGBA is a detail layer.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SourceAmorphousSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_atlas",load("res://local-art/creatures/"+str(entry.source_atlas_texture)))
	material.set_shader_parameter("gel_surface",entry.get("amorphous_surface","")=="slime")
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
