extends RefCounted
static func build(source: StandardMaterial3D,hue: int,detail: float,partial_mask: Texture2D=null) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureFeatherSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("normal_texture",source.normal_texture)
	material.set_shader_parameter("roughness_texture",source.roughness_texture)
	material.set_shader_parameter("partial_hue_mask",partial_mask);material.set_shader_parameter("use_partial_mask",partial_mask!=null)
	material.set_shader_parameter("normal_strength",source.normal_scale*detail/.32)
	var channel:=Vector4.ZERO
	match source.roughness_texture_channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:channel.y=1.
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:channel.z=1.
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:channel.w=1.
		_:channel.x=1.
	material.set_shader_parameter("roughness_channel",channel)
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
