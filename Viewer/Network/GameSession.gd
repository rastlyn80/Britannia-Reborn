extends Node
const Login = preload("res://Network/LoginProtocol.gd")
const Huffman = preload("res://Network/HuffmanStream.gd")
const Tables = preload("res://Network/WireTables.gd")

signal characters_received(characters: Array, cities: Array)
signal entered(position: Dictionary)
signal entity_changed(serial: int, position: Dictionary)
signal entity_removed(serial: int)
signal position_reset(position: Dictionary)
signal movement_started(position: Dictionary, seconds: float)
signal movement_result(accepted: bool, position: Dictionary)
signal interaction_confirmed(description: String)
signal message_received(text: String)
signal failed(reason: String)
signal ended
signal inventory_received(items: Array)

var login: Node
var socket := StreamPeerTCP.new()
var decoder := Huffman.new()
var pending := PackedByteArray()
var phase := "idle"
var username := ""
var password := ""
var auth := 0
var deadline := 0
var player := {"serial":0,"x":0,"y":0,"z":0,"direction":0,"facet":1}
var characters := []
var cities := []
var entities := {}
var sequence := 0
var outstanding := -1
var requested_direction := 0
var awaiting_position := false
var backpack := 0
var packet_counts := {}
var last_ping := 0
var next_walk := 0
var movement_deadline := 0
var move_interval := 410
var running := false
var surface: RefCounted
var requested_position := {}
var turn_only := false
var accepted_since_sync := 0
var needs_sync := false
var preview_bounds := Rect2i()
var returning_home := false
var last_boundary_message := 0

static func signed(value: int, bits: int = 8) -> int:
	return value - (1 << bits) if value & (1 << (bits-1)) else value

static func text(bytes: PackedByteArray, offset: int, length: int) -> String:
	var data := bytes.slice(offset, offset+length)
	var end := data.find(0)
	if end >= 0: data = data.slice(0,end)
	return data.get_string_from_ascii()

static func game_handshake(user: String, secret: String, token: int) -> PackedByteArray:
	# Batch seed and game-login bytes into one write; TCP may still fragment them.
	var bytes := Login.uint_be(token,4)
	bytes.append(0x91)
	bytes.append_array(Login.uint_be(token,4))
	bytes.append_array(Login.field(user))
	bytes.append_array(Login.field(secret))
	return bytes

func connect_account(user: String, secret: String) -> void:
	close()
	username = user
	password = secret
	login = Login.new()
	add_child(login)
	login.failed.connect(_fail)
	login.servers_received.connect(func(servers: Array):
		if servers.is_empty(): _fail("No local server available")
		else: login.select_server(servers[0].index))
	login.relay_received.connect(func(address: String, port: int, token: int):
		if address != "127.0.0.1":
			_fail("Development client expects a loopback game server")
			return
		auth = token
		if socket.connect_to_host(address,port) != OK: _fail("Game connection failed")
		else:
			phase = "connecting"
			deadline = Time.get_ticks_msec()+20000)
	phase = "login"
	login.start(user,secret)

func close() -> void:
	if is_instance_valid(login):
		login.close()
		login.queue_free()
	login = null
	socket.disconnect_from_host()
	decoder = Huffman.new()
	pending.clear()
	entities.clear()
	characters.clear()
	cities.clear()
	phase = "idle"
	password = ""
	sequence = 0
	outstanding = -1
	awaiting_position = false
	backpack = 0
	requested_position.clear()
	returning_home = false
	needs_sync = false
	accepted_since_sync = 0
	next_walk = 0
	ended.emit()

func _fail(reason: String) -> void:
	close()
	failed.emit(reason)

func send(bytes: PackedByteArray) -> void:
	if socket.put_data(bytes) != OK: _fail("Game send failed")

func _process(_delta: float) -> void:
	if phase in ["idle","login"]: return
	socket.poll()
	var state := socket.get_status()
	if state == StreamPeerTCP.STATUS_CONNECTED:
		if phase == "connecting":
			socket.set_no_delay(true)
			send(game_handshake(username,password,auth))
			password = ""
			phase = "characters_pending"
		var available := socket.get_available_bytes()
		if available > 0:
			var data := socket.get_data(mini(available,65536))
			if data[0] != OK:
				_fail("Game receive failed")
				return
			feed(decoder.decode(data[1]))
	elif state != StreamPeerTCP.STATUS_CONNECTING:
		_fail("Game server disconnected")
		return
	if phase in ["connecting","characters_pending","entering"] and Time.get_ticks_msec() > deadline:
		_fail("Game handshake timed out")
	if phase == "world" and Time.get_ticks_msec()-last_ping > 10000:
		send(PackedByteArray([0x73,0]))
		last_ping = Time.get_ticks_msec()
	if returning_home and Time.get_ticks_msec() > movement_deadline:
		returning_home = false
		next_walk = 0
		message_received.emit("Return to Britain was not confirmed. Check that preview tools are enabled on the local server.")
	if phase == "world" and needs_sync and outstanding == -1 and not awaiting_position and (accepted_since_sync >= 12 or Time.get_ticks_msec() > next_walk+120):
		request_position()
	if phase == "world" and (outstanding != -1 or awaiting_position) and Time.get_ticks_msec() > movement_deadline:
		_fail("Movement response timed out; reconnect to resynchronise")

static func packet_length(id: int) -> int:
	var overrides := {0x00:106,0x0b:7,0x16:-1,0x31:-1,0xe1:-1,0xe3:-1,0xe6:5,0xe7:12,0xe8:13,0xe9:75,0xea:3,0x08:15,0x25:21,0xee:10,0xef:21,0xb9:5,0x24:9,0x99:30,0xba:10,0xf3:26,0xf1:9,0xf2:25,0xfa:1,0xfb:2,0xd5:9,0xfd:2}
	return overrides.get(id,Tables.LENGTHS[id] if id < Tables.LENGTHS.size() else -1)

func feed(bytes: PackedByteArray) -> void:
	pending.append_array(bytes)
	if pending.size() > 1048576:
		_fail("Game receive buffer limit exceeded")
		return
	while not pending.is_empty():
		var id := int(pending[0])
		var length := packet_length(id)
		if length == -1:
			if pending.size() < 3: return
			length = Login.read_be(pending,1,2)
			if length < 3:
				_fail("Invalid variable packet length")
				return
		if length <= 0:
			_fail("Invalid packet 0x%02x" % id)
			return
		if pending.size() < length: return
		var packet := pending.slice(0,length)
		pending = pending.slice(length)
		packet_counts[id] = packet_counts.get(id,0)+1
		_handle(packet)

func _handle(p: PackedByteArray) -> void:
	var id := int(p[0])
	match id:
		0xa9:
			var count := int(p[3])
			if p.size() < 5+count*60:
				_fail("Truncated character list")
				return
			characters.clear()
			for i in count: characters.append({"slot":i,"name":text(p,4+i*60,30)})
			var offset := 4+count*60
			var city_count := int(p[offset])
			cities.clear()
			for i in city_count:
				var start := offset+1+i*89
				if start+89 > p.size():
					_fail("Truncated starting cities")
					return
				cities.append({"index":int(p[start]),"name":text(p,start+1,32),"x":Login.read_be(p,start+65,4),"y":Login.read_be(p,start+69,4),"z":signed(Login.read_be(p,start+73,4),32),"facet":Login.read_be(p,start+77,4)})
			phase = "characters"
			characters_received.emit(characters,cities)
		0xbd:
			var version := "7.0.104.0".to_ascii_buffer()
			version.append(0)
			var response := PackedByteArray([0xbd])
			response.append_array(Login.uint_be(version.size()+3,2))
			response.append_array(version)
			send(response)
		0x1b:
			player.serial = Login.read_be(p,1,4)
			player.x = Login.read_be(p,11,2)
			player.y = Login.read_be(p,13,2)
			player.z = signed(Login.read_be(p,15,2),16)
			player.direction = int(p[17]) & 7
		0x55:
			phase = "world"
			last_ping = Time.get_ticks_msec()
			entered.emit(player.duplicate())
		0x20:
			if Login.read_be(p,1,4) == player.serial:
				player.x = Login.read_be(p,11,2)
				player.y = Login.read_be(p,13,2)
				player.z = signed(p[18])
				player.direction = int(p[17]) & 7
				if awaiting_position: sequence = 0 # classic resync resets the server movement sequence
				awaiting_position = false
				needs_sync = false
				accepted_since_sync = 0
				if returning_home and player.facet == 1 and player.x == 1602 and player.y == 1591 and player.z == 20:
					returning_home = false
					next_walk = 0
					position_reset.emit(player.duplicate())
				entity_changed.emit(player.serial,player.duplicate())
		0x21:
			player.x = Login.read_be(p,2,2)
			player.y = Login.read_be(p,4,2)
			player.direction = int(p[6]) & 7
			player.z = signed(p[7])
			sequence = 0
			outstanding = -1
			awaiting_position = false
			requested_position.clear()
			needs_sync = false
			next_walk = Time.get_ticks_msec()+80
			movement_result.emit(false,player.duplicate())
			entity_changed.emit(player.serial,player.duplicate())
		0x22:
			if outstanding == int(p[1]):
				outstanding = -1
				if turn_only:
					player.direction = requested_direction
				elif not requested_position.is_empty():
					player = requested_position.duplicate()
					needs_sync = true
					accepted_since_sync += 1
				else:
					request_position()
				requested_position.clear()
				movement_result.emit(true,player.duplicate())
				if not awaiting_position: entity_changed.emit(player.serial,player.duplicate())
		0x78:
			if p.size() < 23: return
			var serial := Login.read_be(p,3,4)
			var entity := {"serial":serial,"x":Login.read_be(p,9,2),"y":Login.read_be(p,11,2),"z":signed(p[13]),"direction":int(p[14])&7,"running":(int(p[14])&0x80)!=0,"facet":player.facet}
			entities[serial] = entity
			if serial == player.serial:
				var offset := 19
				while offset+4 <= p.size() and Login.read_be(p,offset,4) != 0:
					if offset+9 > p.size(): break
					if p[offset+6] == 21: backpack = Login.read_be(p,offset,4)
					offset += 9
			entity_changed.emit(serial,entity)
		0x77:
			var serial := Login.read_be(p,1,4)
			var entity := {"serial":serial,"x":Login.read_be(p,7,2),"y":Login.read_be(p,9,2),"z":signed(p[11]),"direction":int(p[12])&7,"running":(int(p[12])&0x80)!=0,"facet":player.facet}
			entities[serial] = entity
			entity_changed.emit(serial,entity)
		0x1d:
			var serial := Login.read_be(p,1,4)
			entities.erase(serial)
			entity_removed.emit(serial)
		0x2e:
			if p[8] == 21 and Login.read_be(p,9,4) == player.serial: backpack = Login.read_be(p,1,4)
		0xbf:
			if p.size() >= 6 and Login.read_be(p,3,2) == 8: player.facet = int(p[5])
		0x24: interaction_confirmed.emit("Backpack opened by server (0x%08x)" % Login.read_be(p,1,4))
		0x3c:
			if p.size() < 5: return
			var count := Login.read_be(p,3,2)
			if p.size() != 5+count*20:
				_fail("Invalid inventory packet length")
				return
			var items := []
			for i in count:
				var offset := 5+i*20
				items.append({"serial":Login.read_be(p,offset,4),"id":Login.read_be(p,offset+4,2),"amount":Login.read_be(p,offset+7,2),"container":Login.read_be(p,offset+14,4)})
			inventory_received.emit(items)
		0x1c:
			if p.size() > 44: message_received.emit(text(p,44,p.size()-44))
		0xae:
			if p.size() >= 50: message_received.emit(unicode_text(p,48))
		0x82: _fail("Game login rejected")
		0x53: _fail("Character entry rejected (%d)" % p[1])

func select_character(slot: int, name: String) -> void:
	if phase != "characters": return
	var p := PackedByteArray([0x5d])
	p.append_array(Login.uint_be(0xedededed,4))
	p.append_array(Login.field(name))
	p.append_array(PackedByteArray([0,0]))
	p.append_array(Login.uint_be(0,4))
	p.resize(65)
	p.append_array(Login.uint_be(slot,4))
	p.append_array(Login.uint_be(0x7f000001,4))
	phase = "entering"
	deadline = Time.get_ticks_msec()+20000
	send(p)

func create_character(name: String, slot: int, city: int) -> void:
	if phase != "characters": return
	if name.length() < 2 or name.length() > 29:
		failed.emit("Choose a 2–29 character name")
		return
	for i in name.length():
		if name.unicode_at(i) < 32 or name.unicode_at(i) > 126:
			failed.emit("This prototype supports printable ASCII character names")
			return
	phase = "entering"
	deadline = Time.get_ticks_msec()+20000
	send(creation_packet(name,slot,city))

static func creation_packet(name: String, slot: int, city: int) -> PackedByteArray:
	var p := PackedByteArray([0xf8])
	p.append_array(Login.uint_be(0xedededed,4))
	p.append_array(Login.uint_be(0xffffffff,4))
	p.append(0)
	p.append_array(Login.field(name))
	p.append_array(PackedByteArray([0,0]))
	p.append_array(Login.uint_be(0,4))
	p.append_array(Login.uint_be(1,4))
	p.append_array(Login.uint_be(0,4))
	p.append(0) # custom profession: selected city is respected
	p.resize(70)
	p.append_array(PackedByteArray([2,40,30,20,40,30,27,30,17,30,1,30]))
	for value in [0x03ea,0,0,0,0,city]: p.append_array(Login.uint_be(value,2))
	p.append_array(Login.uint_be(slot,4))
	p.append_array(Login.uint_be(0x7f000001,4))
	p.append_array(Login.uint_be(2,2))
	p.append_array(Login.uint_be(3,2))
	return p

static func movement_packet(direction: int, seq: int, run: bool = false) -> PackedByteArray:
	var packet := PackedByteArray([2,(direction&7)|(0x80 if run else 0),seq])
	packet.append_array(Login.uint_be(0,4))
	return packet

func walk(direction: int, run: bool = false) -> bool:
	if phase != "world" or returning_home or outstanding != -1 or awaiting_position or Time.get_ticks_msec() < next_walk: return false
	turn_only = (direction & 7) != int(player.direction)
	if preview_bounds.has_area() and not turn_only:
		var offset: Vector2i = preload("res://Presentation/MovementSurface.gd").OFFSETS[direction & 7]
		if player.facet != 1 or not preview_bounds.has_point(Vector2i(player.x,player.y)+offset):
			if Time.get_ticks_msec()-last_boundary_message > 800:
				message_received.emit("Edge of the converted area. Use Return to Britain (F6).")
				last_boundary_message = Time.get_ticks_msec()
			return false
	# The pinned PlayerMobile has zero-cost turns; a turn must not consume a
	# full 410 ms walking interval. Keep a short packet-rate guard for input jitter.
	move_interval = 20 if turn_only else (205 if run else 405)
	running = run
	next_walk = Time.get_ticks_msec()+move_interval
	requested_direction = direction & 7
	requested_position = surface.predict(player,requested_direction) if surface != null and not turn_only else {}
	var p := movement_packet(direction,sequence,run)
	outstanding = sequence
	movement_deadline = Time.get_ticks_msec()+5000
	sequence = 1 if sequence == 255 else sequence+1
	send(p)
	if not requested_position.is_empty(): movement_started.emit(requested_position.duplicate(),float(move_interval)/1000.0)
	return true

func request_position() -> void:
	awaiting_position = true
	needs_sync = false
	movement_deadline = Time.get_ticks_msec()+5000
	send(PackedByteArray([0x22,0,0]))

func open_backpack() -> void:
	if phase == "world" and backpack != 0:
		var p := PackedByteArray([6])
		p.append_array(Login.uint_be(backpack,4))
		send(p)

static func speech_packet(message: String) -> PackedByteArray:
	if message.is_empty() or message.length() > 128 or "\n" in message or "\r" in message or message.to_utf8_buffer().has(0): return PackedByteArray()
	var bytes := PackedByteArray([0xad,0,0,0,0x03,0xb2,0,3,69,78,85,0])
	var utf16 := message.to_utf16_buffer()
	for i in range(0,utf16.size(),2):
		bytes.append(utf16[i+1])
		bytes.append(utf16[i])
	bytes.append_array(PackedByteArray([0,0]))
	bytes[1] = bytes.size() >> 8
	bytes[2] = bytes.size() & 255
	return bytes

static func unicode_text(bytes: PackedByteArray, start: int) -> String:
	var little_endian := PackedByteArray()
	for i in range(start,bytes.size()-1,2):
		if bytes[i] == 0 and bytes[i+1] == 0: break
		little_endian.append(bytes[i+1])
		little_endian.append(bytes[i])
	return little_endian.get_string_from_utf16()

func send_command(command: String) -> bool:
	if phase != "world" or not command.begins_with("["): return false
	var packet := speech_packet(command)
	if packet.is_empty(): return false
	send(packet)
	request_position()
	return true

func return_to_britain() -> void:
	if phase != "world": return
	returning_home = true
	requested_position.clear()
	needs_sync = false
	send_command("[PreviewHome")
