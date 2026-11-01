extends RefCounted
## Original cutout alpha is independent of the authored RGB eye registration.
static func build(source: StandardMaterial3D,entry: Dictionary,hue: int) -> Material:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/IceSerpentSurface.gdshader")
	material.set_shader_parameter("albedo_gain",.62);material.set_shader_parameter("detail_strength",.15)
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("source_alpha_texture",load("res://local-art/creatures/"+str(entry.source_alpha_texture)))
	var warp: Array=entry.eye_registration
	material.set_shader_parameter("eye_registration",Vector4(float(warp[0]),float(warp[1]),float(warp[2]),float(warp[3])))
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
