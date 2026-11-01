extends RefCounted
## Explicit cyclic phase and authored dense-cloud partial hue regions.
static func build(hue: int,phase: float,dust: bool=false) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=preload("res://Presentation/AirElementalSurface.gdshader")
	result.set_shader_parameter("phase",phase);result.set_shader_parameter("dust",dust);result.set_meta("snapshot_uniform_time",true)
	# Native AirElemental uses the spectral sentinel, not ordinary dye one.
	var palette: Texture2D=null if hue==0x4001 else preload("res://Presentation/HumanHue.gd").palette(hue)
	result.set_shader_parameter("hue_palette",palette);result.set_shader_parameter("use_hue",palette!=null);result.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return result
