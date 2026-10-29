extends "res://Network/Packets/PacketModule.gd"
# Graphic effects: moving bolts, fixed and on-mobile sparkles, lightning
# (0x70; 0xC0 adds hue and blend; 0xC7 particle effects add explosion data).
# ClassicUO: GraphicEffect. The presentation layer draws them.
signal spawned(effect: Dictionary)
const KINDS := ["moving","lightning","fixed_location","fixed_mobile"]

func routes() -> void:
	for id in [0x70,0xc0,0xc7]: session.route(id,_effect)

static func parse(p: PackedByteArray) -> Dictionary:
	if p.size() < 28: return {}
	var effect := {"kind":KINDS[u8(p,1)] if u8(p,1) < 4 else "screen","source":u32(p,2),"target":u32(p,6),"graphic":u16(p,10),
		"from":Vector3i(u16(p,12),u16(p,14),i8(p,16)),"to":Vector3i(u16(p,17),u16(p,19),i8(p,21)),
		"speed":u8(p,22),"duration":u8(p,23),"fixed_direction":u8(p,26) != 0,"explodes":u8(p,27) != 0,"hue":0,"blend":0}
	if p[0] != 0x70 and p.size() >= 36:
		effect.hue = u32(p,28)
		effect.blend = u32(p,32)%7
	if p[0] == 0xc7 and p.size() >= 47:
		effect.merge({"tile":u16(p,36),"explode_effect":u16(p,38),"explode_sound":u16(p,40),"serial":u32(p,42),"layer":u8(p,46)})
	return effect

func _effect(p: PackedByteArray) -> void:
	var effect := parse(p)
	if not effect.is_empty(): spawned.emit(effect)
