extends RefCounted
## Original RGBA controls cutouts independently of the private generated coat.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/LichSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_atlas",load("res://local-art/creatures/"+str(entry.source_alpha_texture)))
	material.set_shader_parameter("albedo_gain",.72);material.set_shader_parameter("detail_strength",.12)
	material.set_shader_parameter("use_accent",str(entry.kind)=="liche_liche_lord_retro")
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
