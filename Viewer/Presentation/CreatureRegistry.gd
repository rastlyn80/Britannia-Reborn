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
	if record.get("kind","")=="eagle":result=preload("res://Presentation/EagleVisual.gd").new()
	elif record.get("kind","")=="rabbit":result=preload("res://Presentation/RabbitVisual.gd").new()
	elif record.get("kind","")=="wisp":result=preload("res://Presentation/WispVisual.gd").new()
	elif record.get("contact_kind","")=="source_biped":result=preload("res://Presentation/SourceBipedVisual.gd").new()
	else:result=Visual.new()
	result.entry=record;return result
static func matches(visual: Node3D,body: int) -> bool:return visual is Visual and visual.kind==str(entry(body).get("kind",""))
