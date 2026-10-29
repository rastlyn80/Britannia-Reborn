extends RefCounted
# Packets for player actions the quickbar sends (formats as ClassicUO's
# OutgoingPackets writes them and ModernUO's incoming handlers read them).
const Login = preload("res://Network/LoginProtocol.gd")
const SPEECH := {"Say":0,"Emote":2,"Whisper":8,"Yell":9}

# 0x12 text command: type byte and a NUL-terminated ASCII argument.
static func text_command(type: int, argument: String) -> PackedByteArray:
	var packet := PackedByteArray([0x12,0,0,type])
	packet.append_array(argument.to_ascii_buffer())
	packet.append(0)
	packet[1] = packet.size() >> 8
	packet[2] = packet.size() & 255
	return packet

static func cast_spell(id: int) -> PackedByteArray: return text_command(0x56,str(id))
static func open_spellbook(type: int) -> PackedByteArray: return text_command(0x43,str(type))
static func open_door() -> PackedByteArray: return text_command(0x58,"")
static func animate(name: String) -> PackedByteArray: return text_command(0xC7,name)
static func invoke_virtue(id: int) -> PackedByteArray: return text_command(0xF4,str(id))

static func _serial_packet(id: int, serial: int) -> PackedByteArray:
	var packet := PackedByteArray([id])
	packet.append_array(Login.uint_be(serial,4))
	return packet

static func attack(serial: int) -> PackedByteArray: return _serial_packet(0x05,serial)
static func double_click(serial: int) -> PackedByteArray: return _serial_packet(0x06,serial)
static func single_click(serial: int) -> PackedByteArray: return _serial_packet(0x09,serial)

# 0xBF extended command with a 16-bit subcommand.
static func extended(sub: int, payload: PackedByteArray) -> PackedByteArray:
	var packet := PackedByteArray([0xBF,0,0])
	packet.append_array(Login.uint_be(sub,2))
	packet.append_array(payload)
	packet[1] = packet.size() >> 8
	packet[2] = packet.size() & 255
	return packet

# Apply a bandage to a mobile without a target cursor (0xBF 0x2C).
static func bandage(bandage_serial: int, target: int) -> PackedByteArray:
	var payload := Login.uint_be(bandage_serial,4)
	payload.append_array(Login.uint_be(target,4))
	return extended(0x2C,payload)

static func toggle_flying() -> PackedByteArray:
	var payload := Login.uint_be(1,2)
	payload.append_array(Login.uint_be(0,4))
	return extended(0x32,payload)

# Party chat to everyone (0xBF 0x06, subcommand 4), big-endian UTF-16.
static func party_say(text: String) -> PackedByteArray:
	var payload := PackedByteArray([4])
	payload.append_array(_utf16_be(text))
	return extended(0x06,payload)

static func _utf16_be(text: String) -> PackedByteArray:
	var bytes := PackedByteArray()
	var utf16 := text.to_utf16_buffer()
	for i in range(0,utf16.size(),2):
		bytes.append(utf16[i+1])
		bytes.append(utf16[i])
	bytes.append_array(PackedByteArray([0,0]))
	return bytes

# 0xAD unicode speech with a message type (say, emote, whisper, yell). Lines
# with speech keywords go out encoded (Network/SpeechKeywords.gd).
static func speech(text: String, type := 0) -> PackedByteArray:
	return preload("res://Network/SpeechKeywords.gd").packet(text,type)

# 0xD7 encoded commands carry the player serial and a 16-bit command.
static func encoded(player: int, command: int, payload: PackedByteArray) -> PackedByteArray:
	var packet := PackedByteArray([0xD7,0,0])
	packet.append_array(Login.uint_be(player,4))
	packet.append_array(Login.uint_be(command,2))
	packet.append_array(payload)
	packet[1] = packet.size() >> 8
	packet[2] = packet.size() & 255
	return packet

# Weapon special: 1 primary, 2 secondary (0 clears).
static func combat_ability(player: int, index: int) -> PackedByteArray:
	var payload := Login.uint_be(0,4)
	payload.append_array(PackedByteArray([index,0x0A]))
	return encoded(player,0x19,payload)

static func equip_last_weapon(player: int) -> PackedByteArray: return encoded(player,0x1E,PackedByteArray([0x0A]))
static func guild_menu(player: int) -> PackedByteArray: return encoded(player,0x28,PackedByteArray([0x0A]))
static func quest_menu(player: int) -> PackedByteArray: return encoded(player,0x32,PackedByteArray([0x00]))
