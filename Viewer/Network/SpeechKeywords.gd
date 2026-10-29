extends RefCounted
# Speech keywords (speech.mul, prepared by scripts/prepare-speech.py): ModernUO
# recognises spoken commands ("bank", "vendor buy", boat orders, "guards") by
# the keyword ids the client sends with its speech, not by the text. A line
# that matches any keyword goes out encoded (0xAD type | 0xC0: 12-bit count and
# ids, then UTF-8); others as plain UTF-16. Matching and packing follow
# ClassicUO's SpeechesLoader and Send_UnicodeSpeechRequest. Without the
# prepared table every line is sent plain, as before.
const PATH := "res://local-speech/keywords.json"
static var table: Array = []
static var loaded := false

static func entries() -> Array:
	if not loaded:
		loaded = true
		if FileAccess.file_exists(PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
			if parsed is Array:
				for row in parsed:
					var text := str(row[1])
					var words: Array = []
					for piece in text.split("*",false): words.append(piece.to_lower())
					table.append({"id":int(row[0]),"words":words,"open_start":text.begins_with("*"),"open_end":text.ends_with("*")})
	return table

static func _is_letter(c: String) -> bool:
	return c.to_lower() != c.to_upper()

static func matches(input: String, entry: Dictionary) -> bool:
	var lower := input.to_lower()
	for word in entry.words:
		var w: String = word
		if w.is_empty() or w.length() > lower.length(): continue
		if not entry.open_start and not lower.begins_with(w): continue
		if not entry.open_end and not lower.ends_with(w): continue
		var at := lower.find(w)
		while at >= 0:
			var before_ok := at == 0 or not _is_letter(lower[at-1])
			var after_ok := at+w.length() >= lower.length() or not _is_letter(lower[at+w.length()])
			if before_ok and after_ok: return true
			at = lower.find(w,at+1)
	return false

static func keywords(text: String) -> Array:
	var found: Array = []
	var line := text.strip_edges()
	for entry in entries():
		if matches(line,entry) and not int(entry.id) in found: found.append(int(entry.id))
	found.sort()
	return found

# The 12-bit packing: count, then ids, as ClassicUO writes it.
static func pack(ids: Array) -> PackedByteArray:
	var bytes := PackedByteArray()
	var count := ids.size()
	bytes.append((count >> 4) & 255)
	var nibble := count & 15
	var odd := false
	for id in ids:
		if odd:
			bytes.append((int(id) >> 4) & 255)
			nibble = int(id) & 15
		else:
			bytes.append(((nibble << 4) | ((int(id) >> 8) & 15)) & 255)
			bytes.append(int(id) & 255)
		odd = not odd
	if not odd: bytes.append((nibble << 4) & 255)
	return bytes

static func packet(text: String, type := 0, hue := 0x03b2, font := 3) -> PackedByteArray:
	if text.is_empty() or text.length() > 128 or "\n" in text or "\r" in text or text.to_utf8_buffer().has(0): return PackedByteArray()
	var ids := keywords(text)
	var packet := PackedByteArray([0xad,0,0,(type | 0xc0) if not ids.is_empty() else type,(hue >> 8) & 255,hue & 255,(font >> 8) & 255,font & 255,69,78,85,0])
	if ids.is_empty():
		var utf16 := text.to_utf16_buffer()
		for i in range(0,utf16.size(),2):
			packet.append(utf16[i+1])
			packet.append(utf16[i])
		packet.append_array(PackedByteArray([0,0]))
	else:
		packet.append_array(pack(ids))
		packet.append_array(text.to_utf8_buffer())
		packet.append(0)
	packet[1] = packet.size() >> 8
	packet[2] = packet.size() & 255
	return packet
