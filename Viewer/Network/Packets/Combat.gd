extends "res://Network/Packets/PacketModule.gd"
# Combat feedback: damage numbers (0x0B, 0xBF 0x22), swings (0x2F), the
# server's current attack target (0xAA), weapon-ability reset (0xBF 0x21),
# forced player moves (0x97) and run/walk speed mode (0xBF 0x26).
# ClassicUO: Damage, Swing, AttackCharacter, MovePlayer, ExtendedCommand.
signal damaged(serial: int, amount: int)
signal swung(attacker: int, defender: int)
signal attack_target_changed(serial: int)
signal ability_cleared
var attack_target := 0
var speed_mode := 0

func routes() -> void:
	session.route(0x0b,func(p: PackedByteArray): damaged.emit(u32(p,1),u16(p,5)))
	session.route_extended(0x22,func(p: PackedByteArray): if p.size() >= 11: damaged.emit(u32(p,6),u8(p,10)))
	session.route(0x2f,func(p: PackedByteArray): swung.emit(u32(p,2),u32(p,6)))
	session.route(0xaa,func(p: PackedByteArray):
		attack_target = u32(p,1)
		attack_target_changed.emit(attack_target))
	session.route_extended(0x21,func(_p: PackedByteArray): ability_cleared.emit())
	session.route_extended(0x26,func(p: PackedByteArray): speed_mode = u8(p,5))
	# The server pushed the player one step: ask for the authoritative spot.
	session.route(0x97,func(_p: PackedByteArray): session.request_position())

func reset() -> void:
	attack_target = 0
	speed_mode = 0
