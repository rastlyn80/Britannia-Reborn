extends RefCounted
# Optional owner-licensed trees converted by scripts/import-unity-trees.py into
# the ignored res://local-art/trees folder. When absent, callers keep the CC0
# library trees, so the public build never depends on purchased art.
const ROOT := "res://local-art/trees"
const CATALOG := ROOT+"/catalog.json"
# UO tree names -> preferred species (first available variants are used).
const SPECIES := {
	"oak tree":["oak_1","oak_01","oak_13"],
	"walnut tree":["elm_tree_1","elm_tree_2","hickory_1","maple_1"],
	"tree":["beech_02","elm_tree_1","maple_1","aspen_1","poplar_1","oak_01"],
	"willow tree":["willow_2","willow_1"],
	"cedar tree":["cedar_1","cedar_2","cedar_3"],
	"sapling":["birch_4","birch_5","mtn_ash_3"],
	"o'hii tree":["mtn_ash_1","mtn_ash_2","poplar_1"],
	"apple tree":["mtn_ash_2","mtn_ash_3"],
	"peach tree":["mtn_ash_3","mtn_ash_2"],
	"tuscany pine":["ponderosa_1","ponderosa_2"],
	"cypress tree":["spruce_2","spruce_3"],
	"spider tree":["dead_tree_01","dead_tree_06","dead_oak_01"],
}
# Presented heights in metres; proportions are kept (uniform scale).
const HEIGHTS := {"sapling":2.6,"apple tree":4.6,"peach tree":4.4,"spider tree":5.5,"cedar tree":8.5,"tuscany pine":9.0,"cypress tree":8.0}
const DEFAULT_HEIGHT := 7.2
static var catalog: Dictionary = {}
static var loaded := false
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func available() -> bool:
	if not loaded:
		loaded = true
		if FileAccess.file_exists(CATALOG):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
			if parsed is Dictionary: catalog = parsed.get("trees",{})
	return not catalog.is_empty()

static func variants(tree_name: String) -> Array:
	var names: Array = []
	for name in SPECIES.get(tree_name.to_lower(),SPECIES["tree"]):
		if catalog.has(name) and FileAccess.file_exists(ROOT+"/"+name+"/"+name+".obj"): names.append(name)
	return names

static func signature() -> String:
	return FileAccess.get_sha256(CATALOG) if FileAccess.file_exists(CATALOG) else "none"

# Mesh with generated detail levels, cached beside the converted source.
static func mesh(name: String) -> ArrayMesh:
	if meshes.has(name): return meshes[name]
	var cached := ROOT+"/"+name+"/"+name+".lod.res"
	var result: ArrayMesh
	if ResourceLoader.exists(cached): result = load(cached)
	if result == null:
		var source: Mesh = load(ROOT+"/"+name+"/"+name+".obj")
		var importer := ImporterMesh.new()
		for surface in source.get_surface_count():
			importer.add_surface(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),[],{},null,source.surface_get_name(surface))
		importer.generate_lods(25.0,60.0,[])
		result = importer.get_mesh()
		ResourceSaver.save(result,ProjectSettings.globalize_path(cached))
	meshes[name] = result
	return result

# Coarsest generated detail level, one mesh per surface, for distant scenery.
static func far_surfaces(name: String) -> Array:
	var source: Mesh = load(ROOT+"/"+name+"/"+name+".obj")
	var importer := ImporterMesh.new()
	for surface in source.get_surface_count():
		importer.add_surface(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),[],{},null,source.surface_get_name(surface))
	importer.generate_lods(25.0,60.0,[])
	var parts: Array = []
	for surface in importer.get_surface_count():
		var arrays: Array = importer.get_surface_arrays(surface)
		var count := importer.get_surface_lod_count(surface)
		if count > 0: arrays[Mesh.ARRAY_INDEX] = importer.get_surface_lod_indices(surface,count-1)
		var coarse := ArrayMesh.new()
		coarse.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		parts.append({"mesh":coarse,"leaves":"leav" in importer.get_surface_name(surface)})
	return parts

# Same placement as build(): bottom-centred, uniformly scaled, seeded yaw.
static func placement(tree_name: String, name: String, x: int, y: int) -> Transform3D:
	var box := mesh(name).get_aabb()
	var height: float = HEIGHTS.get(tree_name.to_lower(),DEFAULT_HEIGHT)*(0.9+0.2*float(absi(x*31+y*17)%11)/10.0)
	var k := height/maxf(0.01,box.size.y)
	var local := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*k),Vector3(-box.get_center().x*k,-box.position.y*k,-box.get_center().z*k))
	return Transform3D(Basis(Vector3.UP,fmod(float(x*17+y*31),TAU)),Vector3.ZERO)*local

static func pick(tree_name: String, x: int, y: int) -> String:
	var names := variants(tree_name)
	return "" if names.is_empty() else str(names[absi(x*73856093^y*19349663)%names.size()])

static func material(name: String, leaves: bool) -> StandardMaterial3D:
	var key := name+("/leaves" if leaves else "/bark")
	if not materials.has(key):
		var surface := StandardMaterial3D.new()
		surface.albedo_texture = load(ROOT+"/"+name+"/diffuse.png")
		surface.roughness = 0.85 if leaves else 0.95
		surface.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		if leaves:
			surface.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			surface.alpha_scissor_threshold = 0.45
			surface.cull_mode = BaseMaterial3D.CULL_DISABLED
			surface.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
		materials[key] = surface
	return materials[key]

# A tree for a UO tree name at a source cell, bottom-centred, uniformly scaled.
static func build(tree_name: String, x: int, y: int) -> Node3D:
	var name := pick(tree_name,x,y)
	if name.is_empty(): return null
	var source := mesh(name)
	var instance := MeshInstance3D.new()
	instance.mesh = source
	for surface in source.get_surface_count():
		instance.set_surface_override_material(surface,material(name,"leav" in source.surface_get_name(surface)))
	instance.transform = placement(tree_name,name,x,y)
	var node := Node3D.new()
	node.add_child(instance)
	node.set_meta("local_tree",name)
	return node
