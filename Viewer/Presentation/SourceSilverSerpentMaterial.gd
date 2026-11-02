extends RefCounted
## Source opacity and partial-dye classification remain independent of new RGB.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> Material:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SourceSilverSerpentSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_atlas",load("res://local-art/creatures/"+str(entry.source_alpha_texture)))
	material.set_shader_parameter("albedo_gain",.68);material.set_shader_parameter("detail_strength",.35)
	material.set_shader_parameter("use_source_alpha",true);material.set_shader_parameter("darken_authored_eyes",true)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
