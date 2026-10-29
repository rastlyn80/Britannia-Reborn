extends "res://Network/Packets/PacketModule.gd"
# What the server says about other creatures beyond position and body:
# health-bar flags (0x16/0x17: poison, yellow "can't be harmed" bar),
# full attributes (0x2D) and name replies (0x98). ClassicUO:
# NewHealthbarUpdate, MobileAttributes, UpdateName.
signal flags_changed(serial: int)

func routes() -> void:
	session.route(0x16,_bar_flags)
	session.route(0x17,_bar_flags)
	session.route(0x2d,_attributes)
	session.route(0x98,_name)

func _stats(serial: int) -> Dictionary:
	if not session.mobile_statistics.has(serial): session.mobile_statistics[serial] = {}
	return session.mobile_statistics[serial]

func _bar_flags(p: PackedByteArray) -> void:
	if p.size() < 9: return
	var serial := u32(p,3)
	var stats := _stats(serial)
	for i in u16(p,7):
		var at := 9+i*3
		if at+3 > p.size(): break
		match u16(p,at):
			1: stats.poisoned = p[at+2] != 0
			2: stats.yellow_bar = p[at+2] != 0
	if serial == int(session.player.get("serial",0)):
		session.player_status.poisoned = stats.get("poisoned",false)
		session.status_changed.emit(session.player_status)
	flags_changed.emit(serial)

func _attributes(p: PackedByteArray) -> void:
	if p.size() < 17: return
	var serial := u32(p,1)
	_stats(serial).merge({"hits_max":u16(p,5),"hits":u16(p,7),"mana_max":u16(p,9),"mana":u16(p,11),"stam_max":u16(p,13),"stam":u16(p,15)},true)
	if serial == int(session.player.get("serial",0)):
		session.player_status.merge(_stats(serial),true)
		session.status_changed.emit(session.player_status)
	flags_changed.emit(serial)

func _name(p: PackedByteArray) -> void:
	if p.size() < 37: return
	var serial := u32(p,3)
	var name := ascii(p,7,30)
	if name.is_empty(): return
	session.entity_names[serial] = name
	session.entity_name_received.emit(serial,name)

# Ask for a mobile's name (0x98 out: serial only).
static func name_request(serial: int) -> PackedByteArray:
	return variable(0x98,be32(serial))
