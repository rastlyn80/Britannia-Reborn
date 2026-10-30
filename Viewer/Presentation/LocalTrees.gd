extends RefCounted
# Optional owner-licensed trees converted by scripts/import-unity-nature.py into
# the ignored res://local-art/trees folder. When absent, callers keep the CC0
# library trees, so the public build never depends on purchased art.
const BASE := "res://local-art"
const ROOT := BASE+"/trees"
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
	# Seasonal looks (seasonal()): autumn, bare and snow-white trees.
	"fall leaves":["woa_01","a_beech_01","a_tree_01"],
	"red maple":["woa_01","a_beech_01"],
	"yellow willow":["dead_tree_06","wtree_02_01"],
	"bare oak":["wtree_02_01","dead_tree_01","wtreeb_01_01"],
	"bare plum":["wtree_01_01","wtreeb_01_01"],
	"white tree":["wtreebf_01_01","wtreesnow_01_01"],
	"silversapling leaves":["wtreesnow_01_01","wtreebf_01_01"],
}
# Graphics UO draws leafless, autumn-red or white whatever crown they carry.
const SEASONAL_IDS := {8779:"yellow willow",8780:"bare oak",8781:"bare oak",9334:"white tree",9335:"white tree",9336:"red maple",9337:"red maple",9338:"red maple",9339:"red maple",9340:"red maple",9341:"red maple",9342:"red maple",9965:"bare plum",9966:"bare plum"}
# Presented heights in metres; proportions are kept (uniform scale).
const HEIGHTS := {"fall leaves":4.6,"bare plum":4.4,"white tree":5.2,"silversapling leaves":4.0,"sapling":2.6,"apple tree":4.6,"peach tree":4.4,"spider tree":5.5,"cedar tree":8.5,"tuscany pine":9.0,"cypress tree":8.0}
const DEFAULT_HEIGHT := 7.2
# Leaf colour multipliers per species (the pack has no crimson autumn tree).
const TINTS := {"red maple":Color(1.0,0.42,0.38)}
static var catalog: Dictionary = {}
static var loaded := false
static var meshes: Dictionary = {}
static var materials: Dictionary = {}

static func available() -> bool:
	if not loaded:
		loaded = true
		if FileAccess.file_exists(CATALOG):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
			if parsed is Dictionary: catalog = parsed.get("items",parsed.get("trees",{}))
	return not catalog.is_empty()

# The seasonal species for a tree graphic or the crowns in its cell, or "".
static func seasonal(id: int, crowns: String) -> String:
	if SEASONAL_IDS.has(id): return SEASONAL_IDS[id]
	for crown in ["fall leaves","silversapling leaves"]:
		if crown in crowns: return crown
	return ""

static func variants(tree_name: String) -> Array:
	var names: Array = []
	for name in SPECIES.get(tree_name.to_lower(),SPECIES["tree"]):
		if catalog.has(name) and FileAccess.file_exists(ROOT+"/"+name+"/"+name+".obj"): names.append(name)
	return names

static func signature() -> String:
	return FileAccess.get_sha256(CATALOG) if FileAccess.file_exists(CATALOG) else "none"

# Mesh with generated detail levels, cached beside the converted source.
static func mesh(name: String, group := "trees") -> ArrayMesh:
	var folder := BASE+"/"+group+"/"+name
	if meshes.has(folder): return meshes[folder]
	var cached := folder+"/"+name+".lod.res"
	var result: ArrayMesh
	if ResourceLoader.exists(cached): result = load(cached)
	if result == null:
		var source: Mesh = load(folder+"/"+name+".obj")
		var importer := ImporterMesh.new()
		for surface in source.get_surface_count():
			importer.add_surface(source.surface_get_primitive_type(surface),source.surface_get_arrays(surface),[],{},null,source.surface_get_name(surface))
		importer.generate_lods(25.0,60.0,[])
		result = importer.get_mesh()
		ResourceSaver.save(result,ProjectSettings.globalize_path(cached))
	meshes[folder] = result
	return result

# Coarsest generated detail level, one mesh per surface, for distant scenery.
static func far_surfaces(name: String, group := "trees") -> Array:
	var source: Mesh = load(BASE+"/"+group+"/"+name+"/"+name+".obj")
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

static func material(name: String, leaves: bool, group := "trees", tint := Color.WHITE) -> StandardMaterial3D:
	if not leaves: tint = Color.WHITE
	var key := group+"/"+name+("/leaves" if leaves else "/bark")+("" if tint == Color.WHITE else "/"+tint.to_html())
	if not materials.has(key):
		var surface := StandardMaterial3D.new()
		surface.albedo_texture = load(BASE+"/"+group+"/"+name+"/diffuse.png")
		surface.albedo_color = tint
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
		instance.set_surface_override_material(surface,material(name,"leav" in source.surface_get_name(surface),"trees",TINTS.get(tree_name,Color.WHITE)))
	instance.transform = placement(tree_name,name,x,y)
	instance.set_meta("lod_cell",true)
	var node := Node3D.new()
	node.add_child(instance)
	node.set_meta("local_tree",name)
	return node
