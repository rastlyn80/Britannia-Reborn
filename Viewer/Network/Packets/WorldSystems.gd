extends "res://Network/Packets/PacketModule.gd"
# Maps (0x90/0xF5 details, 0x56 pins), house placement (0x99 multi target),
# custom houses (0xD8 design, 0xBF 0x1D revision, 0xBF 0x20 begin/end),
# boats (0xF6) and mahjong tables (0xDA), with their requests (map pins,
# placement, house designer 0xD7 commands, design queries). ClassicUO:
# MapData, DisplayMap, MultiPlacement, CustomHouse, BoatMoving.
signal map_opened(map: Dictionary)
signal map_command(serial: int, command: int, point: Vector2i, editable: bool)
signal placement_requested(request: Dictionary)
signal house_design(serial: int)
signal house_revision(serial: int, revision: int)
signal customizing(serial: int, active: bool)
signal boat_moved(boat: Dictionary)
signal mahjong(packet: PackedByteArray)
var maps := {}
var placement := {}
# House serial -> {revision, planes: [{mode, z, tiles: [{id,x,y,z}] or ids}]}
var designs := {}
var revisions := {}
var customizing_house := 0

func routes() -> void:
	for id in [0x90,0xf5]: session.route(id,_map)
	session.route(0x56,func(p: PackedByteArray): map_command.emit(u32(p,1),u8(p,5),Vector2i(u16(p,7),u16(p,9)),u8(p,6) != 0))
	session.route(0x99,func(p: PackedByteArray):
		placement = {"ground":u8(p,1) != 0,"id":u32(p,2),"flags":u8(p,6),"multi":u16(p,18),"offset":Vector3i(i16(p,20),i16(p,22),i16(p,24))}
		placement_requested.emit(placement))
	session.route(0xd8,_design)
	session.route_extended(0x1d,func(p: PackedByteArray):
		revisions[u32(p,5)] = u32(p,9)
		house_revision.emit(u32(p,5),u32(p,9)))
	session.route_extended(0x20,func(p: PackedByteArray):
		var active := u8(p,9) == 4
		customizing_house = u32(p,5) if active else 0
		customizing.emit(u32(p,5),active))
	session.route(0xf6,_boat)
	session.route(0xda,func(p: PackedByteArray): mahjong.emit(p))

func reset() -> void:
	maps.clear()
	placement = {}
	designs.clear()
	revisions.clear()
	customizing_house = 0

func _map(p: PackedByteArray) -> void:
	var map := {"serial":u32(p,1),"gump":u16(p,5),"from":Vector2i(u16(p,7),u16(p,9)),"to":Vector2i(u16(p,11),u16(p,13)),"size":Vector2i(u16(p,15),u16(p,17)),"facet":u16(p,19) if p[0] == 0xf5 else 0}
	maps[map.serial] = map
	map_opened.emit(map)

func _design(p: PackedByteArray) -> void:
	var serial := u32(p,5)
	var planes: Array = []
	var at := 18
	for plane in u8(p,17):
		if at+4 > p.size(): break
		var header := u32(p,at)
		at += 4
		var unpacked := ((header & 0xff0000) >> 16) | ((header & 0xf0) << 4)
		var packed := ((header & 0xff00) >> 8) | ((header & 0x0f) << 8)
		var plane_z := (header & 0x0f000000) >> 24
		var mode := (header & 0xf0000000) >> 28
		if packed <= 0 or at+packed > p.size(): continue
		var data := p.slice(at,at+packed).decompress(unpacked,FileAccess.COMPRESSION_DEFLATE) if u8(p,3) == 3 else p.slice(at,at+packed)
		at += packed
		planes.append(decode_plane(data,mode,plane_z))
	designs[serial] = {"revision":u32(p,9),"planes":planes}
	house_design.emit(serial)

# Plane modes: 0 = id,x,y,z; 1 = id,x,y at the plane's floor height;
# 2 = ids row by row over the house's bounds (resolved by the presenter).
static func decode_plane(data: PackedByteArray, mode: int, plane_z: int) -> Dictionary:
	var z := (plane_z-1)%4*20+7 if plane_z > 0 else 0
	var plane := {"mode":mode,"z":z,"plane":plane_z,"tiles":[],"ids":[]}
	match mode:
		0:
			for i in data.size()/5:
				var id := u16(data,i*5)
				if id: plane.tiles.append({"id":id,"x":i8(data,i*5+2),"y":i8(data,i*5+3),"z":i8(data,i*5+4)})
		1:
			for i in data.size()/4:
				var id := u16(data,i*4)
				if id: plane.tiles.append({"id":id,"x":i8(data,i*4+2),"y":i8(data,i*4+3),"z":z})
		_:
			for i in data.size()/2: plane.ids.append(u16(data,i*2))
	return plane

func _boat(p: PackedByteArray) -> void:
	var boat := {"serial":u32(p,3),"speed":u8(p,7),"moving":u8(p,8),"facing":u8(p,9),"x":u16(p,10),"y":u16(p,12),"z":i16(p,14),"passengers":[]}
	var at := 18
	for i in u16(p,16):
		if at+10 > p.size(): break
		boat.passengers.append({"serial":u32(p,at),"x":u16(p,at+4),"y":u16(p,at+6),"z":i16(p,at+8)})
		at += 10
	boat_moved.emit(boat)

# --- requests ---
# Map pin edits (0x56): 1 add, 2 insert, 3 move, 4 remove, 5 clear, 6 toggle editing.
static func map_pin(serial: int, command: int, point := Vector2i.ZERO, index := 0) -> PackedByteArray:
	var packet := PackedByteArray([0x56])
	packet.append_array(be32(serial))
	packet.append(command)
	packet.append(index)
	packet.append_array(be16(point.x))
	packet.append_array(be16(point.y))
	return packet

# House designer commands (0xD7, encoded): backup 0x02, restore 0x03,
# commit 0x04, delete 0x05 (tile), build 0x06 (tile), close 0x0C,
# stairs 0x0D, sync 0x0E, clear 0x10, level 0x12, roof 0x13,
# roof delete 0x14, revert 0x1A.
static func designer(player: int, command: int, payload := PackedByteArray()) -> PackedByteArray:
	var body := be32(player)
	body.append_array(be16(command))
	body.append_array(payload)
	body.append(0x0a)
	return variable(0xd7,body)

# Tile commands as encoded ints: build 0x06 and stairs 0x0D (item, x, y);
# delete 0x05, roof 0x13 and roof delete 0x14 (item, x, y, z).
static func designer_tile(player: int, command: int, item: int, x: int, y: int, z := 0) -> PackedByteArray:
	var payload := PackedByteArray()
	for value in [item,x,y] + ([z] if command in [0x05,0x13,0x14] else []):
		payload.append(0)
		payload.append_array(be32(value))
	return designer(player,command,payload)

# Switch the designer to a floor (0x12).
static func designer_level(player: int, level: int) -> PackedByteArray:
	var payload := PackedByteArray([0])
	payload.append_array(be32(level))
	return designer(player,0x12,payload)

# Ask for a house design (0xBF 0x1E) after a newer revision is announced.
static func design_query(house: int) -> PackedByteArray:
	var payload := be16(0x1e)
	payload.append_array(be32(house))
	return variable(0xbf,payload)
