extends Node
# Asks the server once for the status of each creature and NPC that comes into
# view (0x34 type 4). The answer (0x11) carries its name and health, so their
# nameplates show real names ("Gwenllian", "a horse") instead of placeholders,
# and health bars have data. A few requests per frame keep a busy street from
# flooding the connection.
const Login = preload("res://Network/LoginProtocol.gd")
const PER_FRAME := 4
var session: Node
var asked := {}
var waiting: Array = []

func configure(game: Node) -> void:
	session = game
	session.entity_changed.connect(func(serial: int, _position: Dictionary):
		if serial != int(session.player.get("serial",0)) and not asked.has(serial) and not session.entity_names.has(serial):
			asked[serial] = true
			waiting.append(serial))
	session.entity_removed.connect(func(serial: int): asked.erase(serial))
	session.ended.connect(func():
		asked.clear()
		waiting.clear())

static func query(serial: int) -> PackedByteArray:
	var packet := PackedByteArray([0x34,0xed,0xed,0xed,0xed,4])
	packet.append_array(Login.uint_be(serial,4))
	return packet

func _process(_delta: float) -> void:
	if session == null or session.phase != "world": return
	var sent := 0
	while not waiting.is_empty() and sent < PER_FRAME:
		var serial: int = waiting.pop_front()
		if session.entities.has(serial) and not session.entity_names.has(serial):
			session.send(query(serial))
			sent += 1
