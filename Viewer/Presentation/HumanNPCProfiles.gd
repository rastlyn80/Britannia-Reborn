extends RefCounted
## Native human-type identities share the licensed body/wardrobe, never monster actions.
## Candidates stay private until their family graphics/native/corpse gates pass.
static var entries: Dictionary={
	744: {"body":744,"name":"Vampiric Embrace / male","female":false,"skin":"vampiric"},
	745: {"body":745,"name":"Vampiric Embrace / female","female":true,"skin":"vampiric"},
}
static var loaded:=false
static func load_index() -> void:
	if loaded:return
	loaded=true
	var path:="res://local-art/human-npcs/accepted-index.json"
	if not FileAccess.file_exists(path):return
	var index: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not index is Dictionary:return
	for profile: Dictionary in index.get("profiles",[]):
		if profile.get("status","")!="validated" or profile.get("skin","")!="savage":continue
		var body:=int(profile.get("body",0))
		# These original body IDs have audited native human/female semantics.
		if body not in [183,184,185,186] or bool(profile.get("female",false))!=(body in [184,186]):continue
		entries[body]=profile
static func entry(body: int) -> Dictionary:
	load_index();return entries.get(body,{})
static func supports_body(body: int) -> bool:return not entry(body).is_empty()
static func female(body: int) -> bool:return bool(entry(body).get("female",false))
