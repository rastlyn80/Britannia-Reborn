extends RefCounted
static func build(value: int,phase: float,ash: bool) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/FireElementalSurface.gdshader")
	material.set_meta("snapshot_uniform_time",true)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(value)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(value&0x8000)!=0);material.set_shader_parameter("phase",phase);material.set_shader_parameter("dust",ash)
	return material
