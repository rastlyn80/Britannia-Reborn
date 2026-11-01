extends RefCounted
## Keep licensed marine PBR maps and dark facial features under native dyes.
static func build(source: StandardMaterial3D,hue: int,detail: float) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/CreatureMarineSurface.gdshader")
	for channel in ["albedo","normal","roughness"]:
		var texture: Texture2D=source.get(channel+"_texture")
		material.set_shader_parameter(channel+"_texture",texture);material.set_shader_parameter("has_"+channel,texture!=null)
	material.set_shader_parameter("albedo_colour",source.albedo_color)
	material.set_shader_parameter("normal_strength",source.normal_scale*detail/.32)
	material.set_shader_parameter("roughness_value",source.roughness)
	material.set_shader_parameter("wetness",.7)
	var channel:=Vector4.ZERO
	match source.roughness_texture_channel:
		BaseMaterial3D.TEXTURE_CHANNEL_GREEN:channel.y=1.
		BaseMaterial3D.TEXTURE_CHANNEL_BLUE:channel.z=1.
		BaseMaterial3D.TEXTURE_CHANNEL_ALPHA:channel.w=1.
		_:channel.x=1.
	material.set_shader_parameter("roughness_channel",channel)
	var feature:=source.resource_name.to_lower().contains("eye") or source.resource_name.to_lower().contains("nose") or source.resource_name.to_lower().contains("mouth")
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	material.set_shader_parameter("hue_palette",palette);material.set_shader_parameter("use_hue",palette!=null and not feature);material.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return material
