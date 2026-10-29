extends "res://Network/Packets/PacketModule.gd"
# The player's own state beyond status: death and resurrection (0x2C, 0xAF),
# paperdoll (0x88), profile (0xB8), server change (0x76), pathfinding hints
# (0x38), pet bonding (0xBF 0x19 cmd 0), race change (0xBF 0x2A), special
# move toggles (0xBF 0x25), character list changes (0x86, 0x81) and delete
# results (0x85), logout ack (0xD1), invalid map (0xC6), time sync (0xF2),
# walk sequence reset (0x7B). ClassicUO: DeathScreen, DisplayDeath,
# OpenPaperdoll, CharacterProfile, Pathfinding, UpdateCharacterList, Logout.
signal died(dead: bool)
signal death_animation(killed: int, corpse: int)
signal paperdoll(info: Dictionary)
signal profile(info: Dictionary)
signal path_step(point: Vector3i)
signal character_list(names: Array)
signal delete_result(code: int)
signal logged_out
signal race_change_requested(female: bool, race: int)
signal special_move(ability: int, active: bool)
var dead := false
var bonded := {}
var paperdolls := {}
var profiles := {}
const DELETE_REASONS := ["That character password is invalid.","That character does not exist.","That character is being played right now.","That character is not old enough to delete.","That character is queued for backup.","The request could not be carried out."]

func routes() -> void:
	session.route(0x2c,func(p: PackedByteArray):
		dead = u8(p,1) != 1
		died.emit(dead))
	session.route(0xaf,func(p: PackedByteArray): death_animation.emit(u32(p,1),u32(p,5)))
	session.route(0x88,func(p: PackedByteArray):
		var info := {"serial":u32(p,1),"title":ascii(p,5,60),"war":u8(p,65)&1 != 0,"can_lift":u8(p,65)&2 != 0}
		paperdolls[info.serial] = info
		paperdoll.emit(info))
	session.route(0xb8,_profile)
	session.route(0x76,func(p: PackedByteArray):
		session.player.merge({"x":u16(p,1),"y":u16(p,3),"z":i16(p,5)},true)
		session.request_position())
	session.route(0x38,func(p: PackedByteArray): path_step.emit(Vector3i(u16(p,1),u16(p,3),i16(p,5))))
	session.route_extended(0x19,func(p: PackedByteArray): if u8(p,5) == 0 and p.size() >= 11: bonded[u32(p,6)] = u8(p,10) != 0)
	session.route_extended(0x2a,func(p: PackedByteArray): race_change_requested.emit(u8(p,5) != 0,u8(p,6)))
	session.route_extended(0x25,func(p: PackedByteArray): special_move.emit(u16(p,5),u8(p,7) != 0))
	for id in [0x86,0x81]: session.route(id,_characters)
	session.route(0x85,func(p: PackedByteArray):
		delete_result.emit(u8(p,1))
		session.message_received.emit(DELETE_REASONS[u8(p,1)] if u8(p,1) < DELETE_REASONS.size() else "Character deletion failed."))
	session.route(0xd1,func(_p: PackedByteArray): logged_out.emit())
	session.route(0xc6,func(_p: PackedByteArray): session.message_received.emit("The server reports this map is not available to your client."))
	session.route(0xf2,func(_p: PackedByteArray): pass)
	session.route(0x7b,func(_p: PackedByteArray): pass)

func reset() -> void:
	dead = false
	bonded.clear()
	paperdolls.clear()
	profiles.clear()

func _profile(p: PackedByteArray) -> void:
	var serial := u32(p,3)
	var header: Array = ascii_z(p,7)
	var at: int = header[1]
	var footer := utf16(p,at,p.size()-at,false)
	at += footer.length()*2+2
	var body := utf16(p,at,p.size()-at,false)
	profiles[serial] = {"serial":serial,"header":header[0],"footer":footer,"body":body}
	profile.emit(profiles[serial])

func _characters(p: PackedByteArray) -> void:
	var names: Array = []
	var at := 4 if p[0] == 0x86 else 5
	for i in u8(p,3):
		if at+60 > p.size(): break
		names.append(ascii(p,at,30))
		at += 60
	var list: Array = []
	for i in names.size(): list.append({"slot":i,"name":names[i]})
	session.characters = list
	character_list.emit(names)

# --- requests ---
# Ghost choice after death (0x2C: 0 = resurrect, 1 = remain a ghost).
static func death_choice(action: int) -> PackedByteArray: return PackedByteArray([0x2c,action])
# Paperdoll of a mobile: double-click with the paperdoll bit for the player.
static func open_paperdoll(serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x06])
	packet.append_array(be32(serial|0x80000000))
	return packet
# Profile request (0xB8 mode 0) and update (mode 1, new body text).
static func profile_request(serial: int) -> PackedByteArray:
	var payload := PackedByteArray([0])
	payload.append_array(be32(serial))
	return variable(0xb8,payload)
static func profile_update(serial: int, body: String) -> PackedByteArray:
	var payload := PackedByteArray([1])
	payload.append_array(be32(serial))
	payload.append_array(be16(1))
	payload.append_array(be16(body.length()))
	for i in body.length(): payload.append_array(be16(body.unicode_at(i)))
	return variable(0xb8,payload)
# Delete a character from the list (0x83: password field, slot, client IP).
static func delete_character(slot: int, password: String = "") -> PackedByteArray:
	var packet := PackedByteArray([0x83])
	var field := password.to_ascii_buffer()
	field.resize(30)
	packet.append_array(field)
	packet.append_array(be32(slot))
	packet.append_array(be32(0x7f000001))
	return packet
static func logout_request() -> PackedByteArray: return PackedByteArray([0xd1,0])
# Race change answer (0xBF 0x2A): skin hue, hair and beard choices; with no
# values it declines.
static func race_change_reply(hue := -1, hair := 0, hair_hue := 0, beard := 0, beard_hue := 0) -> PackedByteArray:
	var payload := be16(0x2a)
	if hue >= 0:
		for value in [hue,hair,hair_hue,beard,beard_hue]: payload.append_array(be16(value))
	return variable(0xbf,payload)
# Rename a pet or follower (0x75: serial, 30-byte name).
static func rename(serial: int, name: String) -> PackedByteArray:
	var packet := PackedByteArray([0x75])
	packet.append_array(be32(serial))
	var field := name.to_ascii_buffer()
	field.resize(30)
	packet.append_array(field)
	return packet
