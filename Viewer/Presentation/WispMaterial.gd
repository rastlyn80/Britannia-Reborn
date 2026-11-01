extends RefCounted
## Authored energy regions; native hue flags and static snapshot phase retained.
static func build(source: ShaderMaterial,hue: int,phase: float) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=preload("res://Presentation/WispSurface.gdshader")
	for parameter in ["core","density","energy_colour"]:result.set_shader_parameter(parameter,source.get_shader_parameter(parameter))
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	result.set_shader_parameter("hue_palette",palette);result.set_shader_parameter("use_hue",palette!=null);result.set_shader_parameter("partial_hue",(hue&0x8000)!=0);result.set_shader_parameter("phase",phase)
	result.set_meta("snapshot_uniform_time",true)
	return result
