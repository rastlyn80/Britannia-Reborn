extends "res://Network/Packets/PacketModule.gd"
# The world's clock, season, feature flags, view range, sound and music.
# ClassicUO: SetTime (0x5B), Season (0xBC), EnableLockedFeatures (0xB9),
# ClientViewRange (0xC8), PlaySoundEffect (0x54), PlayMusic (0x6D).
signal sound(request: Dictionary)
signal music(index: int)
var features := 0
var view_range := 18
var season := 0
var server_time := {}
var music_index := -1
# Map patch counts per facet (0xBF 0x18); our world comes from converted
# files, so they are kept for diagnostics only.
var map_patches: Array = []

func routes() -> void:
	session.route(0x5b,func(p: PackedByteArray):
		server_time = {"hour":u8(p,1),"minute":u8(p,2),"second":u8(p,3)}
		session._environment_update({"server_clock":server_time}))
	session.route(0xbc,func(p: PackedByteArray):
		season = mini(u8(p,1),4)
		session._environment_update({"season":season}))
	session.route(0xb9,func(p: PackedByteArray): features = u32(p,1) if p.size() >= 5 else u16(p,1))
	session.route(0xc8,func(p: PackedByteArray): view_range = u8(p,1))
	session.route(0x54,func(p: PackedByteArray):
		sound.emit({"mode":u8(p,1),"id":u16(p,2),"volume":u16(p,4),"x":u16(p,6),"y":u16(p,8),"z":i16(p,10)}))
	session.route_extended(0x18,func(p: PackedByteArray):
		map_patches.clear()
		for i in u32(p,5):
			if 9+i*8+8 > p.size(): break
			map_patches.append({"statics":u32(p,9+i*8),"land":u32(p,13+i*8)}))
	session.route(0x6d,func(p: PackedByteArray):
		music_index = -1 if p.size() == 3 and u8(p,1) == 0x1f and u8(p,2) == 0xff else u16(p,1)
		music.emit(music_index))

func reset() -> void:
	features = 0
	music_index = -1
	server_time = {}

# The client's view range (0xC8 out), sent after entering the world.
static func view_range_packet(tiles: int) -> PackedByteArray:
	return PackedByteArray([0xc8,clampi(tiles,5,24)])
