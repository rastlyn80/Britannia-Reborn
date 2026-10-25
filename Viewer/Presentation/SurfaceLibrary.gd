extends RefCounted
static var sets := {}
static var textures := {}
static var source_origin := Vector2.ZERO
static func bind(material: ShaderMaterial,prefix: String,id: String) -> void:
 if sets.is_empty():
  var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
  for entry in manifest.sets: sets[entry.id] = entry
 material.set_shader_parameter("source_origin",source_origin)
 var entry: Dictionary = sets[id]
 for map in entry.maps:
  var path := "res://Art/Surfaces/"+str(map.file)
  if not textures.has(path): textures[path] = load(path)
  assert(textures[path] != null,"Missing verified surface texture: "+path)
  var role := "normal_map" if prefix == "surface" and str(map.role) == "normal" else str(map.role)
  material.set_shader_parameter(prefix+"_"+role,textures[path])
 material.set_shader_parameter(prefix+"_scale",Vector2(1.0/float(entry.sizeMeters[0]),1.0/float(entry.sizeMeters[1])))
