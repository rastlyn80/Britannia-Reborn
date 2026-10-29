extends Node
## Direct classic UO login transport. World-session compression is a separate layer.

signal servers_received(servers: Array)
signal relay_received(address: String, port: int, token: int)
signal failed(reason: String)

var socket := StreamPeerTCP.new()
var pending := PackedByteArray()
var phase := "idle"
var deadline := 0
var login_packet := PackedByteArray()

static func uint_be(value: int, count: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	for shift in range(count - 1, -1, -1): bytes.append((value >> (shift * 8)) & 255)
	return bytes

static func read_be(bytes: PackedByteArray, start: int, count: int) -> int:
	var value := 0
	for i in count: value = (value << 8) | bytes[start + i]
	return value

static func field(text: String) -> PackedByteArray:
	var bytes := text.to_ascii_buffer()
	bytes.resize(30)
	return bytes

# The client version we announce: the owner's installed client (client.exe
# 7.0.102.3), so the server formats packets for the same data files.
const CLIENT_VERSION := [7,0,102,3]

static func version_text() -> String:
	return ".".join(CLIENT_VERSION.map(func(v): return str(v)))

static func seed_packet(seed_value: int = 0x12345678) -> PackedByteArray:
	var bytes := PackedByteArray([0xef])
	for value in [seed_value]+CLIENT_VERSION: bytes.append_array(uint_be(value, 4))
	return bytes

static func account_packet(username: String, password: String) -> PackedByteArray:
	var bytes := PackedByteArray([0x80])
	bytes.append_array(field(username))
	bytes.append_array(field(password))
	bytes.append(0xff)
	return bytes

func start(username: String, password: String, port: int = 2593) -> void:
	close()
	# This milestone deliberately targets the local development server.
	for text in [username, password]:
		if text.is_empty() or text.length() > 30:
			_fail("Credentials must contain 1–30 ASCII characters")
			return
		for code in text.length():
			if text.unicode_at(code) < 32 or text.unicode_at(code) > 126:
				_fail("Credentials must contain printable ASCII")
				return
	login_packet = account_packet(username, password)
	if socket.connect_to_host("127.0.0.1", port) != OK:
		_fail("Could not connect to local ModernUO")
		return
	phase = "connecting"
	deadline = Time.get_ticks_msec() + 15000

func select_server(index: int) -> void:
	if phase != "servers": return
	var packet := PackedByteArray([0xa0])
	packet.append_array(uint_be(index, 2))
	if socket.put_data(packet) != OK:
		_fail("Server selection send failed")
		return
	phase = "relay"
	deadline = Time.get_ticks_msec() + 15000

func close() -> void:
	socket.disconnect_from_host()
	pending.clear()
	login_packet.clear()
	phase = "idle"

func _fail(reason: String) -> void:
	close()
	failed.emit(reason)

func _process(_delta: float) -> void:
	if phase == "idle" or phase == "complete": return
	socket.poll()
	var state := socket.get_status()
	if state == StreamPeerTCP.STATUS_CONNECTED:
		if phase == "connecting":
			if socket.put_data(seed_packet()) != OK or socket.put_data(login_packet) != OK:
				_fail("Login send failed")
				return
			login_packet.clear()
			phase = "login"
		var available := socket.get_available_bytes()
		if available > 0:
			var received := socket.get_data(available)
			if received[0] != OK:
				_fail("Login receive failed")
				return
			feed(received[1])
	elif state != StreamPeerTCP.STATUS_CONNECTING:
		_fail("Local server disconnected")
		return
	if phase in ["connecting","login","relay"] and Time.get_ticks_msec() >= deadline:
		_fail("Local server login timed out")

func feed(bytes: PackedByteArray) -> void:
	pending.append_array(bytes)
	if pending.size() > 65535:
		_fail("Login response exceeds packet limit")
		return
	while not pending.is_empty():
		var id := pending[0]
		var length := 0
		if id == 0xa8:
			if pending.size() < 3: return
			length = read_be(pending, 1, 2)
			if length < 6:
				_fail("Invalid server list length")
				return
		elif id == 0x82: length = 2
		elif id == 0x8c: length = 11
		else:
			_fail("Unsupported login packet 0x%02x" % id)
			return
		if pending.size() < length: return
		var packet := pending.slice(0, length)
		pending = pending.slice(length)
		if id == 0x82:
			_fail(rejection(int(packet[1])))
			return
		if id == 0xa8:
			if phase != "login":
				_fail("Unexpected server list")
				return
			var count := read_be(packet, 4, 2)
			if length != 6 + count * 40:
				_fail("Server list count/length mismatch")
				return
			var servers := []
			for i in count:
				var offset := 6 + i * 40
				var name_bytes := packet.slice(offset + 2, offset + 34)
				var terminator := name_bytes.find(0)
				if terminator >= 0: name_bytes = name_bytes.slice(0, terminator)
				var name := name_bytes.get_string_from_ascii()
				servers.append({"index": read_be(packet, offset, 2), "name": name})
			phase = "servers"
			servers_received.emit(servers)
		elif id == 0x8c:
			if phase != "relay":
				_fail("Unexpected game relay")
				return
			var address := "%d.%d.%d.%d" % [packet[1],packet[2],packet[3],packet[4]]
			phase = "complete"
			socket.disconnect_from_host()
			relay_received.emit(address, read_be(packet, 5, 2), read_be(packet, 7, 4))
			return

# 0x82 login rejections, as ClassicUO words them.
const REJECTIONS := ["Incorrect account name or password.","Someone is already using this account.","This account has been blocked.","This account's credentials are invalid.","There was a problem communicating with the server.","The concurrency limit has been met.","The time limit has been met.","General authentication failure."]
static func rejection(code: int) -> String:
	return REJECTIONS[code] if code >= 0 and code < REJECTIONS.size() else "Login rejected (reason %d)." % code
