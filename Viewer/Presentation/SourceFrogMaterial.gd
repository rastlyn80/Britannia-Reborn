extends RefCounted
## Private source-UV skin, authored moist relief and weighted tongue treatment.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SourceFrogSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_atlas",load("res://local-art/creatures/"+str(entry.source_atlas_texture)))
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
