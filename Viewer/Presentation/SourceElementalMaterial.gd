extends RefCounted
## UV-bound snow grains; relief/dye regions are authored, not recovered maps.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SourceElementalSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_atlas",load("res://local-art/creatures/"+str(entry.source_atlas_texture)))
	material.set_shader_parameter("albedo_gain",.72);material.set_shader_parameter("detail_strength",.4)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
