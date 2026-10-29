extends "res://Network/Packets/PacketModule.gd"
# Buffs and debuffs on the player (0xDF): icon, title and description from
# clilocs, and a duration in seconds. They feed the buff bar and the quickbar
# action timers. ClassicUO: BuffDebuff, BuffGump.
signal changed
# icon id -> {icon, title, description, seconds, started_ms, ends_ms}
var active := {}

func routes() -> void:
	session.route(0xdf,_buff)

func reset() -> void:
	active.clear()

func _buff(p: PackedByteArray) -> void:
	if p.size() < 11: return
	var icon := u16(p,7)
	if u16(p,9) == 0 or p.size() < 46:
		active.erase(icon)
		changed.emit()
		return
	var seconds := u16(p,23)
	var title_cliloc := u32(p,28)
	var description_cliloc := u32(p,32)
	# Arguments follow a length word and a "\0\t" pair, little-endian text.
	var arguments := utf16(p,46,p.size()-46,true)
	var labels: RefCounted = session.labels
	var now := Time.get_ticks_msec()
	active[icon] = {"icon":icon,"title":labels.resolve(title_cliloc,arguments),"description":labels.resolve(description_cliloc,arguments) if description_cliloc else "","seconds":seconds,"started_ms":now,"ends_ms":now+seconds*1000 if seconds > 0 else 0}
	changed.emit()

# Seconds left (0 for buffs without a timer).
func remaining(icon: int) -> float:
	var entry: Dictionary = active.get(icon,{})
	if entry.is_empty() or int(entry.ends_ms) == 0: return 0.0
	return maxf(0.0,(int(entry.ends_ms)-Time.get_ticks_msec())/1000.0)
