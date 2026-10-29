extends "res://Network/Packets/PacketModule.gd"
# Cliloc messages with an affix (0xCC): a cliloc line with text added before
# or after it, optionally forced to a system message. ClassicUO:
# DisplayClilocString. (0xC1 without affix stays in GameSession.)
signal spoken(serial: int, text: String, system: bool)

func routes() -> void:
	session.route(0xcc,_affixed)

func _affixed(p: PackedByteArray) -> void:
	if p.size() < 49: return
	var serial := u32(p,3)
	var kind := u8(p,9)
	var cliloc := u32(p,14)
	var flags := u8(p,18)
	var affix: Array = ascii_z(p,49)
	var arguments := utf16(p,int(affix[1]),p.size()-int(affix[1]),false)
	var text: String = session.labels.resolve(cliloc,arguments)
	if not str(affix[0]).is_empty(): text = str(affix[0])+text if flags & 1 else text+str(affix[0])
	var system := (flags & 2) != 0 or kind == 1 or serial == 0xffffffff
	spoken.emit(serial,text,system)
	if not system: session.speech_received.emit(serial,text,kind,u16(p,10))
	if session.world_items.has(serial): session.item_label_received.emit(serial,text)
	session._server_text(text,system)
