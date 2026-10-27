extends RefCounted
# Several photoscans per repeated surface, packed into texture arrays. Shaders
# pick a variant per two-metre cell (a Latin-square pattern, so neighbours never
# repeat), blend neighbouring cells softly and pull every variant toward the
# family's average colour, so a wall or a square reads as one material with
# natural variation and no visible tiling. Arrays are built once from the
# pinned CC0 Poly Haven sets (Art/Surfaces) and cached in res://Art/Surfaces/variants (ignored, regenerated).
const FAMILIES := {
	"plaster":["white_rough_plaster","plastered_wall_02","plastered_wall_03","plastered_wall_04","white_plaster_02"],
	"brick":["medieval_red_brick","brick_wall_02","brick_wall_08","castle_brick_02_red","church_bricks_03"],
	"stone":["medieval_blocks_03","medieval_blocks_02","medieval_blocks_05","castle_brick_07","castle_wall_varriation"],
	"cobbles":["cobblestone_floor_03","cobblestone_floor_01","cobblestone_floor_04","cobblestone_floor_07","cobblestone_02"],
	"dirt":["forest_ground_04","dirt","brown_mud_dry","stony_dirt_path","park_dirt"],
	"grass":["leafy_grass","sparse_grass","grass_ground","forest_ground_05","aerial_grass_rock"],
}
const SIZE := 1024
static var built := {}
static var sets := {}

static func _sets() -> Dictionary:
	if sets.is_empty():
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
		for entry in manifest.sets: sets[entry.id] = entry
	return sets

static func _file(id: String, role: String) -> String:
	for map in _sets()[id].maps:
		if str(map.role) == role: return "res://Art/Surfaces/"+str(map.file)
	return ""

static func _layer(path: String, normal: bool) -> Image:
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	if image.get_width() != SIZE or image.get_height() != SIZE: image.resize(SIZE,SIZE,Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps(normal)
	image.compress(Image.COMPRESS_S3TC,Image.COMPRESS_SOURCE_NORMAL if normal else Image.COMPRESS_SOURCE_SRGB)
	return image

static func _mean(path: String) -> Vector3:
	var image: Image = (load(path) as Texture2D).get_image()
	if image.is_compressed(): image.decompress()
	image.convert(Image.FORMAT_RGB8)
	image.resize(8,8,Image.INTERPOLATE_BILINEAR)
	var sum := Vector3.ZERO
	for y in 8:
		for x in 8:
			var c := image.get_pixel(x,y)
			sum += Vector3(c.r,c.g,c.b)
	return sum/64.0

# {albedo: Texture2DArray, normal: Texture2DArray, scale: PackedFloat32Array, mean: PackedVector3Array}
static func family(name: String) -> Dictionary:
	if built.has(name): return built[name]
	var ids: Array = FAMILIES[name]
	var key := ""
	for id in ids: key += str(_sets()[id].maps[0].sha256)
	# Inside res:// (ignored) so baked district scenes can reference the arrays.
	var cache := "res://Art/Surfaces/variants/%s-%s.res" % [name,key.sha256_text().substr(0,12)]
	var arrays := {}
	for role in ["albedo","normal"]:
		var path := cache.replace(".res","-%s.res" % role)
		var array: Texture2DArray = load(path) if ResourceLoader.exists(path) else null
		if array == null:
			var layers: Array[Image] = []
			for id in ids: layers.append(_layer(_file(id,role),role == "normal"))
			array = Texture2DArray.new()
			array.create_from_images(layers)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://Art/Surfaces/variants"))
			ResourceSaver.save(array,path)
		arrays[role] = array
	var scale := PackedFloat32Array()
	var mean := PackedVector3Array()
	for id in ids:
		scale.append(1.0/float(_sets()[id].sizeMeters[0]))
		mean.append(_mean(_file(id,"albedo")))
	built[name] = {"albedo":arrays.albedo,"normal":arrays.normal,"scale":scale,"mean":mean}
	return built[name]

# Binds prefix_variant_albedo/_normal/_scale/_mean/_count on a shader material.
static func bind(material: ShaderMaterial, prefix: String, name: String) -> void:
	if not FAMILIES.has(name): return
	var data := family(name)
	material.set_shader_parameter(prefix+"_variant_albedo",data.albedo)
	material.set_shader_parameter(prefix+"_variant_normal",data.normal)
	material.set_shader_parameter(prefix+"_variant_scale",data.scale)
	material.set_shader_parameter(prefix+"_variant_mean",data.mean)
	material.set_shader_parameter(prefix+"_variant_count",data.scale.size())
