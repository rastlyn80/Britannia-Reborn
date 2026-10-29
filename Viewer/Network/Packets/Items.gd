extends "res://Network/Packets/PacketModule.gd"
# Item movement feedback and spellbook contents: drag animations (0x23),
# drop acknowledgement (0x29), corpse equipment (0x89), new-style spellbook
# contents (0xBF 0x1B) and packed item lists (0xF7). ClassicUO: DragAnimation,
# DropItemAccepted, CorpseEquipment, ExtendedCommand 0x1B, PacketList.
signal dragged(drag: Dictionary)
signal drop_accepted
signal corpse_equipment(corpse: int, worn: Dictionary)
signal spellbook_changed(book: int)
# Spellbook serial -> {graphic, offset (first spell id), spells: Array[int]}.
var spellbooks := {}
# Corpse serial -> {layer: item serial}.
var corpses := {}

func routes() -> void:
	session.route(0x23,func(p: PackedByteArray):
		if p.size() >= 26: dragged.emit({"graphic":u16(p,1),"hue":u16(p,4),"amount":u16(p,6),"source":u32(p,8),"from":Vector3i(u16(p,12),u16(p,14),i8(p,16)),"target":u32(p,17),"to":Vector3i(u16(p,21),u16(p,23),i8(p,25))}))
	session.route(0x29,func(_p: PackedByteArray): drop_accepted.emit())
	session.route(0x89,_corpse)
	session.route_extended(0x1b,_spellbook)
	session.route(0xf7,_packet_list)

func reset() -> void:
	spellbooks.clear()
	corpses.clear()

func _corpse(p: PackedByteArray) -> void:
	var corpse := u32(p,3)
	var worn := {}
	var at := 7
	while at+5 <= p.size() and p[at] != 0:
		worn[u8(p,at)] = u32(p,at+1)
		at += 5
	corpses[corpse] = worn
	corpse_equipment.emit(corpse,worn)

static func spells_from(p: PackedByteArray) -> Dictionary:
	if p.size() < 23: return {}
	var offset := u16(p,13)
	var spells: Array[int] = []
	for i in 8:
		for bit in 8:
			if u8(p,15+i) & (1<<bit): spells.append(offset+i*8+bit)
	return {"graphic":u16(p,11),"offset":offset,"spells":spells}

func _spellbook(p: PackedByteArray) -> void:
	var book := u32(p,7)
	spellbooks[book] = spells_from(p)
	spellbook_changed.emit(book)

# 0xF7: a count, then complete 0xF3 world-object packets back to back.
func _packet_list(p: PackedByteArray) -> void:
	var at := 5
	for i in u16(p,3):
		if at+26 > p.size() or p[at] != 0xf3: break
		session._handle(p.slice(at,at+26))
		at += 26
