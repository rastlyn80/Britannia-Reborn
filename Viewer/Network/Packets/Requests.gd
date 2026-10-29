extends "res://Network/Packets/PacketModule.gd"
# Client requests ModernUO accepts that no other module builds: spells and
# targeted skills (0xBF 0x1C, 0x2D, 0x2E, 0x30), equip and unequip macros
# (0xEC, 0xED), combat moves (0xBF 0x09 disarm, 0x0A stun), emote
# animations (0xBF 0x0E), screen size and language (0xBF 0x05, 0x0B),
# closing a status bar (0xBF 0x0C), old-style property query (0xBF 0x10),
# books (0x66 pages, 0xD4 header, 0x93 old header), bulletin boards (0x71),
# ASCII speech (0x03), disconnect (0x01) and public house content (0xFB).
# Formats follow ModernUO's readers and ClassicUO's OutgoingPackets.
#
# Not sent on purpose (enhanced or third-party client only, or switched off
# on this shard): 0xE1 client type, 0xA4 system info, 0xD0 configuration
# file, 0xD9 hardware info, 0xF4 crash report, 0xFA Ultima Store,
# 0xF0/0xF1 new movement and time sync, 0xBE assistant version.

static func _extended(sub: int, payload := PackedByteArray()) -> PackedByteArray:
	var body := be16(sub)
	body.append_array(payload)
	return variable(0xbf,body)

# Cast a spell by id (1-based), optionally from a given spellbook.
static func cast_spell(spell: int, book := 0) -> PackedByteArray:
	var payload := be16(1 if book else 0)
	if book: payload.append_array(be32(book))
	payload.append_array(be16(spell))
	return _extended(0x1c,payload)
# Cast straight at a target (spell id 1-based).
static func targeted_spell(spell: int, target: int) -> PackedByteArray:
	var payload := be16(spell)
	payload.append_array(be32(target))
	return _extended(0x2d,payload)
static func targeted_skill(skill: int, target: int) -> PackedByteArray:
	var payload := be16(skill)
	payload.append_array(be32(target))
	return _extended(0x2e,payload)
# Target a resource of a kind (0 ore, 1 sand, 2 wood, 3 graves, 4 red mushrooms).
static func target_resource(item: int, kind: int) -> PackedByteArray:
	var payload := be32(item)
	payload.append_array(be16(kind))
	return _extended(0x30,payload)
static func disarm() -> PackedByteArray: return _extended(0x09)
static func stun() -> PackedByteArray: return _extended(0x0a)
static func animate(action: int) -> PackedByteArray: return _extended(0x0e,be32(action))
static func screen_size(width: int, height: int) -> PackedByteArray:
	var payload := be32(width)
	payload.append_array(be32(height))
	return _extended(0x05,payload)
static func language(code := "ENU") -> PackedByteArray:
	var payload := code.left(3).to_ascii_buffer()
	payload.resize(4)
	return _extended(0x0b,payload)
static func close_status(serial: int) -> PackedByteArray: return _extended(0x0c,be32(serial))
static func query_properties(serial: int) -> PackedByteArray: return _extended(0x10,be32(serial))

# Dress or undress several items at once.
static func equip_items(serials: Array) -> PackedByteArray:
	var payload := PackedByteArray([serials.size()])
	for serial in serials: payload.append_array(be32(int(serial)))
	return variable(0xec,payload)
static func unequip_layers(layers: Array) -> PackedByteArray:
	var payload := PackedByteArray([layers.size()])
	for layer in layers: payload.append_array(be16(int(layer)))
	return variable(0xed,payload)

# Write pages of a book: {page index (1-based): [lines]}.
static func book_pages(book: int, pages: Dictionary) -> PackedByteArray:
	var payload := be32(book)
	payload.append_array(be16(pages.size()))
	for index in pages:
		payload.append_array(be16(int(index)))
		payload.append_array(be16(pages[index].size()))
		for line in pages[index]:
			payload.append_array(str(line).to_utf8_buffer())
			payload.append(0)
	return variable(0x66,payload)
static func book_header(book: int, title: String, author: String) -> PackedByteArray:
	var payload := be32(book)
	payload.append_array(PackedByteArray([0,0,0,0]))
	for text in [title,author]:
		var bytes: PackedByteArray = text.to_utf8_buffer()
		payload.append_array(be16(bytes.size()))
		payload.append_array(bytes)
	return variable(0xd4,payload)
static func old_book_header(book: int, title: String, author: String) -> PackedByteArray:
	var packet := PackedByteArray([0x93])
	packet.append_array(be32(book))
	packet.append_array(PackedByteArray([0,0,0,0]))
	for field in [[title,60],[author,30]]:
		var bytes: PackedByteArray = str(field[0]).to_ascii_buffer()
		bytes.resize(field[1])
		packet.append_array(bytes)
	return packet

# Bulletin boards: post (optionally replying) and remove a message.
static func board_post(board: int, subject: String, lines: Array, reply_to := 0) -> PackedByteArray:
	var payload := PackedByteArray([5])
	payload.append_array(be32(board))
	payload.append_array(be32(reply_to))
	var title := subject.to_ascii_buffer()
	payload.append(title.size()+1)
	payload.append_array(title)
	payload.append(0)
	payload.append(lines.size())
	for line in lines:
		var bytes: PackedByteArray = str(line).to_ascii_buffer()
		payload.append(bytes.size()+1)
		payload.append_array(bytes)
		payload.append(0)
	return variable(0x71,payload)
static func board_remove(board: int, message: int) -> PackedByteArray:
	var payload := PackedByteArray([6])
	payload.append_array(be32(board))
	payload.append_array(be32(message))
	return variable(0x71,payload)

# Plain ASCII speech (0x03): type, hue, font, text.
static func ascii_speech(text: String, kind := 0, hue := 0x3b2, font := 3) -> PackedByteArray:
	var payload := PackedByteArray([kind])
	payload.append_array(be16(hue))
	payload.append_array(be16(font))
	payload.append_array(text.to_ascii_buffer())
	payload.append(0)
	return variable(0x03,payload)
static func disconnect_notice() -> PackedByteArray:
	var packet := PackedByteArray([0x01])
	packet.append_array(be32(0xffffffff))
	return packet
static func public_house_content(show: bool) -> PackedByteArray: return PackedByteArray([0xfb,1 if show else 0])
