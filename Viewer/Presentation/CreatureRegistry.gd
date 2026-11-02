extends RefCounted
## The accepted index is generated locally only after skin and GPU validation.
const Visual=preload("res://Presentation/CreatureVisual.gd")
static var entries: Dictionary={}
static var loaded:=false
static func load_index() -> void:
	if loaded:return
	loaded=true
	for path in ["res://Art/Creatures/index.json","res://local-art/creatures/accepted-index.json"]:
		if not FileAccess.file_exists(path):continue
		var value: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
		if not value is Dictionary:continue
		for record: Dictionary in value.get("entries",[]):
			if record.get("status","")!="validated":continue
			for identity: Dictionary in record.get("bodies",[]):entries[int(identity.body)]=record
static func entry(body: int) -> Dictionary:
	load_index();return entries.get(body,{})
static func supports_body(body: int) -> bool:
	var record:=entry(body)
	return not record.is_empty() and ResourceLoader.exists(asset_path(record))
static func asset_path(record: Dictionary,treatment: String="modern") -> String:
	return str(record.get("assets",{}).get(treatment,"res://local-art/creatures/"+str(record.get("kind",""))+"-"+treatment+".gltf"))
static func create(body: int) -> Node3D:
	var record:=entry(body)
	var result: Node3D
	var presentation_script:=str(record.get("presentation_script",""))
	if not presentation_script.is_empty():
		# Generated owned manifests may select a project renderer, never code
		# from an input archive, external path or nested/relative location.
		assert(presentation_script=="res://Presentation/"+presentation_script.get_file() and presentation_script.ends_with(".gd"),"Creature renderer must be an owned presentation script")
		result=load(presentation_script).new()
		assert(result is Visual,"Creature renderer must retain the source visual contract")
	elif record.get("kind","")=="eagle":result=preload("res://Presentation/EagleVisual.gd").new()
	elif record.get("kind","")=="rabbit":result=preload("res://Presentation/RabbitVisual.gd").new()
	elif record.get("kind","")=="wisp":result=preload("res://Presentation/WispVisual.gd").new()
	elif record.get("kind","")=="air_elemental":result=preload("res://Presentation/AirElementalVisual.gd").new()
	elif record.get("kind","")=="fire_elemental":result=preload("res://Presentation/FireElementalVisual.gd").new()
	elif record.get("kind","")=="chicken":result=preload("res://Presentation/ChickenVisual.gd").new()
	elif record.get("kind","")=="serpents_snake_giant_ice":result=preload("res://Presentation/IceSerpentVisual.gd").new()
	elif record.get("family","")=="liches":result=preload("res://Presentation/LichVisual.gd").new()
	elif record.get("bounds_mode","")=="weighted_skin":result=preload("res://Presentation/SmallSnakeVisual.gd").new()
	elif record.get("kind","")=="bogling":result=preload("res://Presentation/BoglingVisual.gd").new()
	elif record.get("contact_kind","")=="measured_limbs":result=preload("res://Presentation/MeasuredCreatureVisual.gd").new()
	elif record.get("contact_kind","")=="source_biped":result=preload("res://Presentation/SourceBipedVisual.gd").new()
	else:result=Visual.new()
	result.entry=record;return result
static func matches(visual: Node3D,body: int) -> bool:return visual is Visual and visual.kind==str(entry(body).get("kind",""))
