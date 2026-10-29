extends "res://Network/Packets/PacketModule.gd"
# Round-trip time from the keep-alive ping (0x73 sent every 10 s by
# GameSession, echoed by the server).
var latency_ms := -1

func routes() -> void:
	session.route(0x73,func(_p: PackedByteArray): latency_ms = Time.get_ticks_msec()-int(session.last_ping))

func reset() -> void:
	latency_ms = -1
