extends RefCounted

# Conservative prediction: source-backed flat/gentle ground and floor surfaces.
# Steep slopes, missing chunks and ambiguous supports use a server position update.
const OFFSETS = [Vector2i(0,-1),Vector2i(1,-1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1),Vector2i(-1,1),Vector2i(-1,0),Vector2i(-1,-1)]
var terrain := {}
var statics := {}
var land_data := {}
var static_data := {}

func index(world: Dictionary) -> void:
	terrain.clear()
	statics.clear()
	land_data = world.get("landData",{})
	static_data = world.get("staticData",{})
	for tile in world.terrain: terrain[Vector2i(tile.x,tile.y)] = tile
	for tile in world.statics:
		var cell := Vector2i(tile.x,tile.y)
		if not statics.has(cell): statics[cell] = []
		statics[cell].append(tile)

func supported(cell: Vector2i, z: int) -> bool:
	var support := false
	var land := land_height(cell)
	if not land.is_empty(): support = int(land.z) == z and int(land.spread) <= 4
	for tile in statics.get(cell,[]):
		var data: Dictionary = static_data.get(str(int(tile.id)),{})
		if data.is_empty(): return false
		var flags := int(data.get("flags",0))
		var height := int(data.get("height",0))
		var top := int(tile.z)+(height/2 if flags & 0x400 else height)
		if flags & 0x200 and not flags & 0x40 and top == z: support = true
		# Body clearance. Wet or impassable source statics must never be predicted through.
		if flags & 0xc0 and int(tile.z) < z+16 and int(tile.z)+maxi(height,1) > z: return false
	return support

func predict(player: Dictionary, direction: int) -> Dictionary:
	var cell := Vector2i(player.x,player.y)
	var offset: Vector2i = OFFSETS[direction & 7]
	var z := int(player.z)
	if not supported(cell,z): return {}
	var destination := z
	if not supported(cell+offset,destination):
		var land := land_height(cell+offset)
		if land.is_empty() or abs(int(land.z)-z) > 2 or not supported(cell+offset,int(land.z)): return {}
		destination = int(land.z)
	if offset.x != 0 and offset.y != 0:
		if not supported(cell+Vector2i(offset.x,0),z) or not supported(cell+Vector2i(0,offset.y),z): return {}
	var result := player.duplicate()
	result.x += offset.x
	result.y += offset.y
	result.z = destination
	result.direction = direction & 7
	return result

func land_height(cell: Vector2i) -> Dictionary:
	var heights: Array[int] = []
	for offset in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i(1,1)]:
		var tile: Dictionary = terrain.get(cell+offset,{})
		if tile.is_empty(): return {}
		var data: Dictionary = land_data.get(str(int(tile.id)),{})
		if offset == Vector2i.ZERO and (data.is_empty() or int(data.get("flags",0)) & 0xc0 or data.get("name") == "NODRAW"): return {}
		heights.append(int(tile.z))
	# Choose the gentler diagonal for both triangulation and centre elevation.
	var centre := (heights[0]+heights[3])*0.5 if abs(heights[0]-heights[3]) <= abs(heights[1]-heights[2]) else (heights[1]+heights[2])*0.5
	return {"z":int(floor(centre)),"spread":heights.max()-heights.min()}
