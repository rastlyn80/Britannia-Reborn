extends RefCounted
## Explicit phase permits a genuinely static corpse, unlike shader TIME.
static func build(hue: int=0,phase: float=0.) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=preload("res://Presentation/WaterElementalSurface.gdshader")
	result.set_meta("snapshot_uniform_time",true)
	result.set_shader_parameter("water_time",phase)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	result.set_shader_parameter("hue_palette",palette);result.set_shader_parameter("use_hue",palette!=null);result.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return result
