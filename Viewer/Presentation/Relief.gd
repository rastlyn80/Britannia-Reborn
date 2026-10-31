extends RefCounted
# Mountain relief (docs/MOUNTAINS.md): extra height in metres for terrain
# corners deep inside impassable land, from `Converter relief` (relief.u8 beside
# the BRW chunks, one byte per corner in relief.json's units). Walkable corners
# are always zero. A dataset without the file has no relief.
var path := ""
var origin := Vector2i.ZERO
var size := Vector2i.ZERO
var unit := 0.25
var everything := PackedByteArray()

static func open(folder: String) -> RefCounted:
	var meta_path := folder.path_join("relief.json")
	var data_path := folder.path_join("relief.u8")
	if not FileAccess.file_exists(meta_path) or not FileAccess.file_exists(data_path): return null
	var meta: Variant = JSON.parse_string(FileAccess.get_file_as_string(meta_path))
	if not meta is Dictionary or int(meta.get("schema",0)) != 1: return null
	var relief := new()
	relief.path = data_path
	relief.origin = Vector2i(int(meta.originX),int(meta.originY))
	relief.size = Vector2i(int(meta.width),int(meta.height))
	relief.unit = float(meta.unitMeters)
	if FileAccess.get_size(data_path) != relief.size.x*relief.size.y: return null
	return relief

# Corner -> metres for every corner in `area` (clipped to the map), read row by row.
func area(rect: Rect2i) -> Dictionary:
	var result := {}
	var clipped := rect.intersection(Rect2i(origin,size))
	if not clipped.has_area(): return result
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null: return result
	for y in range(clipped.position.y,clipped.end.y):
		file.seek((y-origin.y)*size.x+clipped.position.x-origin.x)
		var row := file.get_buffer(clipped.size.x)
		for i in row.size():
			if row[i] != 0: result[Vector2i(clipped.position.x+i,y)] = row[i]*unit
	return result

# One corner, from the whole file loaded once (facet-wide horizon builds).
func at(cell: Vector2i) -> float:
	if everything.is_empty(): everything = FileAccess.get_file_as_bytes(path)
	var local := cell-origin
	if local.x < 0 or local.y < 0 or local.x >= size.x or local.y >= size.y: return 0.0
	return everything[local.y*size.x+local.x]*unit
