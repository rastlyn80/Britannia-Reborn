extends RefCounted
# Data-driven replacements of stand-in props by pinned CC0 Poly Haven scans
# and museum scans (prop-replacements.json): keyed by the UO item name, scaled uniformly to a
# real height so the model keeps its own proportions. Used for map statics
# (Reconstruction) and server-placed items (WorldItems) alike.
static var table := {}

static func key(name: String) -> String:
	var plain := name.to_lower()
	var marker := RegEx.create_from_string("%[^%]*%")
	return marker.sub(plain,"",true).strip_edges()

static func entry(name: String) -> Dictionary:
	if table.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/prop-replacements.json"))
		table = data.items if data is Dictionary else {"": {}}
	return table.get(key(name),{})

static func has(name: String) -> bool:
	return not entry(name).is_empty()

# reconstruction: Reconstruction.gd instance (its fitted() caches bounds).
static func build(reconstruction: RefCounted, name: String) -> Node3D:
	var found := entry(name)
	if found.is_empty(): return null
	# "Objaverse/name" entries are reduced museum/Sketchfab scans (Art/Objaverse).
	var model := str(found.model)
	var path := "Objaverse/%s/%s.glb" % [model.trim_prefix("Objaverse/"),model.trim_prefix("Objaverse/")] if model.begins_with("Objaverse/") else "PolyHaven/%s/%s_1k.gltf" % [model,model]
	if not ResourceLoader.exists("res://Art/"+path): return null
	var probe: Node3D = reconstruction.fitted(path,Vector3.ONE)
	probe.free()
	var box: AABB = reconstruction.bounds[path]
	# Flat goods (cutlery, trays, bread, ore) scale by their length instead.
	var factor := float(found.length)/maxf(maxf(box.size.x,box.size.z),0.001) if found.has("length") else float(found.height)/maxf(box.size.y,0.001)
	var placed: Node3D = reconstruction.fitted(path,box.size*factor)
	placed.set_meta("replacement",model)
	return placed
