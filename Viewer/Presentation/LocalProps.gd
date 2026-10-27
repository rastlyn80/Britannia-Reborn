extends RefCounted
# Optional owner-licensed props (Dexsoft Medieval Village packs) converted by
# scripts/import-dexsoft-props.py into the ignored res://local-art/props folder.
# When absent, callers keep their CC0 or procedural models.
const BASE := "res://local-art/props"
# Prop kind -> height in metres the model is scaled to (uniformly).
const HEIGHTS := {"barrel":0.88,"crate":0.62,"tub":0.42,"haystack":1.15}
static var entries: Variant = null
static var parts: Dictionary = {}

static func items() -> Dictionary:
	if entries == null:
		entries = {}
		var path := BASE+"/catalog.json"
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary: entries = parsed.get("items",{})
	return entries

static func signature() -> String:
	var path := BASE+"/catalog.json"
	return FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "none"

# Static records: CityProps model + tiledata name -> local prop kind, or "".
static func kind_for(model: String, name_text: String) -> String:
	if model == "container" and ("barrel" in name_text or "keg" in name_text): return "barrel"
	if model == "container" and "crate" in name_text: return "crate"
	if model == "fountain" and "water tub" in name_text: return "tub"
	if model == "resource" and name_text in ["hay","sheaf of hay"]: return "haystack"
	return ""

static func _choices(kind: String) -> Array:
	var names: Array = []
	for name in items():
		if str(items()[name].get("kind","")) == kind: names.append(name)
	names.sort()
	return names

# A bottom-centred prop for this kind, picked stably per source cell, or null.
static func build(kind: String, x: int, y: int, scale := 1.0) -> Node3D:
	var names := _choices(kind)
	if names.is_empty(): return null
	var chosen: String = names[absi(x*73856093^y*19349663)%names.size()]
	if not parts.has(chosen):
		var mesh: Mesh = load(BASE+"/"+chosen+"/"+chosen+".obj")
		parts[chosen] = mesh
	var mesh: Mesh = parts[chosen]
	if mesh == null: return null
	var box := mesh.get_aabb()
	var k: float = float(HEIGHTS.get(kind,1.0))*scale/maxf(0.01,box.size.y)
	var model := MeshInstance3D.new()
	model.mesh = mesh
	model.scale = Vector3.ONE*k
	model.position = Vector3(-box.get_center().x*k,-box.position.y*k,-box.get_center().z*k)
	var holder := Node3D.new()
	holder.add_child(model)
	# Quarter turns keep square crates aligned with walls.
	holder.rotation.y = float(absi(x*17+y*31)%4)*PI/2
	holder.set_meta("local_prop",chosen)
	return holder
