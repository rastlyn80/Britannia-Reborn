extends RefCounted
const Hue=preload("res://Presentation/HumanHue.gd")
const SLOTS={22:"robe",6:"hat",3:"shoes"}
static func slots(worn: Array) -> Dictionary:
	var result: Dictionary={}
	for item: Dictionary in worn:
		var layer:=int(item.get("layer",0))
		if SLOTS.has(layer):result[SLOTS[layer]]=int(item.get("hue",0))
	return result
static func build(source: StandardMaterial3D,body_hue: int,worn_slots: Dictionary,detail: float) -> ShaderMaterial:
	var material:=ShaderMaterial.new();material.shader=preload("res://Presentation/SourceMageSurface.gdshader")
	material.set_shader_parameter("albedo_texture",source.albedo_texture)
	material.set_shader_parameter("detail_strength",detail)
	var body:=Hue.palette(body_hue)
	material.set_shader_parameter("body_palette",body);material.set_shader_parameter("use_body",body!=null);material.set_shader_parameter("body_partial",(body_hue&0x8000)!=0)
	for slot: String in SLOTS.values():
		var value:=int(worn_slots.get(slot,0));var palette:=Hue.palette(value)
		material.set_shader_parameter(slot+"_palette",palette);material.set_shader_parameter("use_"+slot,palette!=null)
		material.set_shader_parameter(slot+"_present",worn_slots.has(slot));material.set_shader_parameter(slot+"_partial",(value&0x8000)!=0)
	return material
