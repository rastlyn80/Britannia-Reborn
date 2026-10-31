extends RefCounted
## Creature UVs move with the rig; terrain/world-space projection is not used.
static func studio_reflections(environment: Environment) -> void:
	environment.sky=Sky.new();environment.sky.sky_material=ProceduralSkyMaterial.new()
	environment.reflected_light_source=Environment.REFLECTION_SOURCE_SKY
static func build(record: Dictionary,hue: int,detail: float) -> ShaderMaterial:
	var result:=ShaderMaterial.new();result.shader=preload("res://Presentation/CreatureMineralSurface.gdshader")
	for role: String in record.maps:
		result.set_shader_parameter(role+"_texture",load("res://local-art/creatures/"+str(record.maps[role])))
	result.set_shader_parameter("mineral_colour",Color(str(record.colour)))
	result.set_shader_parameter("metallic_strength",float(record.metallic))
	result.set_shader_parameter("roughness_range",Vector2(float(record.roughness_range[0]),float(record.roughness_range[1])))
	result.set_shader_parameter("normal_strength",float(record.normal_strength)*detail/.32)
	result.set_shader_parameter("uv_scale",float(record.uv_scale))
	var palette:=preload("res://Presentation/HumanHue.gd").palette(hue)
	result.set_shader_parameter("hue_palette",palette);result.set_shader_parameter("use_hue",palette!=null);result.set_shader_parameter("partial_hue",(hue&0x8000)!=0)
	return result
