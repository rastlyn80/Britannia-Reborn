extends RefCounted
# One protocol system (tooltips, health, effects…): it registers the server
# packets it parses with GameSession's router, keeps that system's state and
# announces changes with its own signals. Field order follows ClassicUO's
# PacketHandlers/OutgoingPackets (work/reference, BSD-2-Clause) and ModernUO.
var session: Node

func attach(game: Node) -> void:
	session = game
	routes()

# Override: session.route(id, handler) / session.route_extended(sub, handler).
func routes() -> void: pass

# Override: forget everything when the connection closes.
func reset() -> void: pass

# Override: per-frame work (outgoing queues), called while in the world.
func tick() -> void: pass

static func u8(p: PackedByteArray, at: int) -> int: return int(p[at]) if at < p.size() else 0
static func i8(p: PackedByteArray, at: int) -> int:
	var v := u8(p,at)
	return v-256 if v >= 128 else v
static func u16(p: PackedByteArray, at: int) -> int: return (u8(p,at)<<8)|u8(p,at+1)
static func i16(p: PackedByteArray, at: int) -> int:
	var v := u16(p,at)
	return v-65536 if v >= 32768 else v
static func u32(p: PackedByteArray, at: int) -> int: return (u16(p,at)<<16)|u16(p,at+2)
static func ascii(p: PackedByteArray, at: int, length: int) -> String:
	var end := mini(at+length,p.size())
	var out := PackedByteArray()
	for i in range(at,end):
		if p[i] == 0: break
		out.append(p[i])
	return out.get_string_from_ascii()
# Zero-terminated ASCII from at; returns [text, offset after the terminator].
static func ascii_z(p: PackedByteArray, at: int) -> Array:
	var out := PackedByteArray()
	var i := at
	while i < p.size() and p[i] != 0:
		out.append(p[i])
		i += 1
	return [out.get_string_from_ascii(),i+1]
static func utf16(p: PackedByteArray, at: int, byte_count: int, little: bool) -> String:
	var out := ""
	var i := at
	while i+1 < mini(at+byte_count,p.size()):
		var code := (u8(p,i+1)<<8|u8(p,i)) if little else u16(p,i)
		if code == 0: break
		out += char(code)
		i += 2
	return out
static func be32(value: int) -> PackedByteArray:
	return PackedByteArray([(value>>24)&255,(value>>16)&255,(value>>8)&255,value&255])
static func be16(value: int) -> PackedByteArray:
	return PackedByteArray([(value>>8)&255,value&255])
# A variable-length client packet: id, 2-byte length, payload.
static func variable(id: int, payload: PackedByteArray) -> PackedByteArray:
	var packet := PackedByteArray([id])
	packet.append_array(be16(payload.size()+3))
	packet.append_array(payload)
	return packet
