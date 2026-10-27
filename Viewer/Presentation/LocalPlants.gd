extends RefCounted
# Optional owner-licensed bushes (Tree Creator atlases) and small plants (FBX)
# converted by scripts/import-unity-nature.py into the ignored res://local-art
# folder. When absent, callers keep the CC0 library plants.
const Trees := preload("res://Presentation/LocalTrees.gd")
const BASE := "res://local-art"
# UO vegetation kinds / names -> converted plant name prefixes and heights (m).
const RULES := [
	{"match":"fern","group":"plants","prefixes":["fern_"],"height":0.75},
	# Tropical Nature Pack plants for the jungle/desert graphics (exact names).
	{"match":"blade plant","group":"plants","prefixes":["plant3","plant4","plantsb6"],"height":1.1},
	{"match":"snake plant","group":"plants","prefixes":["plant3","plant4","plantsb6"],"height":1.0},
	{"match":"fan plant","group":"plants","prefixes":["plant15","plant11"],"height":0.8},
	{"match":"elephant ear","group":"plants","prefixes":["plant5","plant6","plant7","plantsb3"],"height":1.0},
	{"match":"ponytail palm","group":"plants","prefixes":["plant10"],"height":1.0},
	{"match":"century plant","group":"plants","prefixes":["plant10"],"height":1.2},
	{"match":"yucca","group":"plants","prefixes":["plant10"],"height":1.3},
	{"match":"water plants","group":"plants","prefixes":["plant9"],"height":0.7},
	{"kind":"bush","group":"bushes","prefixes":[""],"height":1.3},
	{"kind":"grass","group":"plants","prefixes":["tallgrass_"],"height":0.55,"tint":"b8c48a"},
	{"kind":"flower","group":"plants","prefixes":["wildflowers_grp","lavender_","groundcover_1"],"height":0.45},
]
# Packages authored Z-up (3ds Max); Unity rotated them on import, Godot does not.
const Z_UP_SOURCES := ["BIG Environment Pack"]
static var catalogs: Dictionary = {}
static var entries: Dictionary = {}
static var scenes: Dictionary = {}
static var materials: Dictionary = {}

static func items(group: String) -> Array:
	if not catalogs.has(group):
		var path: String = BASE+"/"+group+"/catalog.json"
		var names: Array = []
		if FileAccess.file_exists(path):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if parsed is Dictionary:
				entries[group] = parsed.get("items",{})
				names = entries[group].keys()
		names.sort()
		catalogs[group] = names
	return catalogs[group]

static func signature() -> String:
	var text := ""
	for group in ["bushes","plants"]:
		var path: String = BASE+"/"+group+"/catalog.json"
		text += FileAccess.get_sha256(path) if FileAccess.file_exists(path) else "none"
	return text

static func rule(kind: String, name: String) -> Dictionary:
	for entry in RULES:
		if entry.has("match") and str(entry.match) in name.to_lower(): return entry
		if entry.get("kind","") == kind: return entry
	return {}

static func choices(entry: Dictionary) -> Array:
	var names: Array = []
	for name in items(str(entry.group)):
		for prefix in entry.prefixes:
			if str(name).begins_with(str(prefix)):
				names.append(name)
				break
	return names

# Unity tints detail grass with a terrain "healthy" colour; the textures alone
# are dark, so rules may carry an equivalent multiplier (applied at 2x).
static func plant_material(name: String, tint := "") -> StandardMaterial3D:
	if not materials.has(name):
		var surface := StandardMaterial3D.new()
		surface.albedo_texture = load(BASE+"/plants/"+name+"/albedo.png")
		surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		surface.alpha_scissor_threshold = 0.4
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
		surface.roughness = 0.9
		if tint != "": surface.albedo_color = Color(Color(tint).r*2.0,Color(tint).g*2.0,Color(tint).b*2.0)
		materials[name] = surface
	return materials[name]

static func z_up(name: String) -> bool:
	var source := str(entries.get("plants",{}).get(name,{}).get("source",""))
	for prefix in Z_UP_SOURCES:
		if source.begins_with(prefix): return true
	return false

static func _collect(node: Node, transform: Transform3D, parts: Array) -> void:
	var combined: Transform3D = transform*(node.transform if node is Node3D else Transform3D.IDENTITY)
	if node is MeshInstance3D and node.mesh: parts.append({"mesh":node.mesh,"transform":combined})
	for child in node.get_children(): _collect(child,combined,parts)

# A plant for a UO vegetation record, bottom-centred and uniformly scaled.
static func build(kind: String, name: String, x: int, y: int) -> Node3D:
	var entry := rule(kind,name)
	if entry.is_empty(): return null
	var names := choices(entry)
	if names.is_empty(): return null
	var chosen: String = names[absi(x*73856093^y*19349663)%names.size()]
	var height: float = float(entry.height)*(0.85+0.3*float(absi(x*31+y*17)%11)/10.0)
	var model: Node3D
	var box: AABB
	if entry.group == "bushes":
		var mesh := Trees.mesh(chosen,"bushes")
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		for surface in mesh.get_surface_count():
			instance.set_surface_override_material(surface,Trees.material(chosen,"leav" in mesh.surface_get_name(surface),"bushes"))
		instance.set_meta("lod_cell",true)
		model = instance
		box = mesh.get_aabb()
	else:
		# Plain mesh nodes, not an instanced FBX scene: overrides on nodes inside
		# an instanced scene do not survive district packing.
		var path: String = BASE+"/plants/"+chosen+"/"+chosen+".fbx"
		if not scenes.has(path):
			var parts: Array = []
			var scene: PackedScene = load(path)
			if scene:
				var sample: Node3D = scene.instantiate()
				if z_up(chosen): sample.rotation.x = -PI/2
				_collect(sample,Transform3D.IDENTITY,parts)
				sample.free()
			scenes[path] = parts
		if scenes[path].is_empty(): return null
		model = Node3D.new()
		box = scenes[path][0].transform*scenes[path][0].mesh.get_aabb()
		for part in scenes[path]:
			var mesh_node := MeshInstance3D.new()
			mesh_node.mesh = part.mesh
			mesh_node.transform = part.transform
			mesh_node.material_override = plant_material(chosen,str(entry.get("tint","")))
			mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(mesh_node)
			box = box.merge(part.transform*part.mesh.get_aabb())
	var k := height/maxf(0.01,box.size.y)
	var holder := Node3D.new()
	model.scale *= k
	model.position = Vector3(-box.get_center().x*k,-box.position.y*k,-box.get_center().z*k)
	holder.add_child(model)
	holder.rotation.y = fmod(float(x*17+y*31),TAU)
	holder.set_meta("local_plant",chosen)
	return holder
