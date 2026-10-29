extends Node
# Asks the server once for the status of each creature and NPC that comes into
# view (0x34 type 4). The answer (0x11) carries its name and health, so their
# nameplates show real names ("Gwenllian", "a horse") instead of placeholders,
# and health bars have data. A few requests per frame keep a busy street from
# flooding the connection. An unanswered request is repeated a few times
# (status replies can be dropped while a creature is still entering range).
const Login = preload("res://Network/LoginProtocol.gd")
const PER_FRAME := 4
const RETRY_MS := 2500
const TRIES := 6
var session: Node
var asked := {}
var waiting: Array = []
var next_scan := 0

func configure(game: Node) -> void:
	session = game
	session.entity_changed.connect(func(serial: int, _position: Dictionary):
		if serial != int(session.player.get("serial",0)) and not asked.has(serial) and not session.entity_names.has(serial):
			asked[serial] = {"tries":0,"next":0}
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
	var now := Time.get_ticks_msec()
	while not waiting.is_empty() and sent < PER_FRAME:
		var serial: int = waiting.pop_front()
		if session.entities.has(serial) and not session.entity_names.has(serial) and asked.has(serial):
			session.send(query(serial))
			asked[serial].tries += 1
			asked[serial].next = now+RETRY_MS
			sent += 1
	if waiting.is_empty() and now >= next_scan:
		next_scan = now+500
		for serial in asked:
			var state: Dictionary = asked[serial]
			if state.tries > 0 and state.tries < TRIES and now >= int(state.next) and not session.entity_names.has(serial) and session.entities.has(serial):
				state.next = now+RETRY_MS
				waiting.append(serial)
