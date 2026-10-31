extends Node
const Login = preload("res://Network/LoginProtocol.gd")
const Huffman = preload("res://Network/HuffmanStream.gd")
const Tables = preload("res://Network/WireTables.gd")

signal characters_received(characters: Array, cities: Array)
signal entered(position: Dictionary)
signal entity_changed(serial: int, position: Dictionary)
signal entity_removed(serial: int)
signal appearance_changed(serial: int)
signal mobile_action_received(action: Dictionary)
signal position_reset(position: Dictionary)
signal movement_started(position: Dictionary, seconds: float)
signal movement_result(accepted: bool, position: Dictionary)
signal interaction_confirmed(description: String)
signal message_received(text: String)
# Speech with its speaker, for the overhead text: message type (0 regular,
# 2 emote, 6 label, 8 whisper, 9 yell, 10 spell...) and hue.
signal speech_received(serial: int, text: String, type: int, hue: int)
signal failed(reason: String)
signal ended
signal inventory_received(items: Array)
signal items_changed
signal transfer_result(success: bool, description: String)
signal context_received(menu: Dictionary)
signal vendor_received(vendor: int, stock: Array)
signal vendor_closed(vendor: int)
signal entity_name_received(serial: int, name: String)
const Commerce = preload("res://Network/CommerceProtocol.gd")
const Character = preload("res://Network/CharacterProtocol.gd")
# Player character sheet: native status, skills (by skill ID) and stat locks.
signal status_changed(status: Dictionary)
signal skills_changed(skills: Dictionary)
var player_status := {}
var skills := {}
var known_items := {}
var equipment := {}
var mobile_equipment := {}
var mobile_statistics := {}
var last_mobile_actions := {}
const MobileLook = preload("res://Network/MobileAppearance.gd")
var context_menu := {}
var vendor_prices := {}
var vendor_serial := 0
var vendor_stock := []
var pending_transfer := {}
var transfer_deadline := 0
var next_item_action := 0
var placement_serial := 0
var entity_names := {}
var gold := -1
var requested_icons := {}
var icons_dirty := false
var next_icon_save := 0
signal world_item_changed(serial: int, item: Dictionary)
signal world_item_removed(serial: int)
# Houses and boats (multis: 0xF3 data type 2, legacy 0x1A graphics from 0x4000).
signal multi_changed(serial: int, multi: Dictionary)
signal multi_removed(serial: int)
var multis := {}
signal container_opened(serial: int)
signal container_contents_received(serial: int, items: Array)
signal item_label_received(serial: int, label: String)
var quiet_labels := {}
signal book_received(book: Dictionary)
signal board_received(board: Dictionary)
signal board_post_received(post: Dictionary)
signal gump_received(gump: Dictionary)
signal gump_closed(type: int)
var gumps := {}
signal target_changed(active: bool)
var target_request := PackedByteArray()
var books := {}
var board_serial := 0
var board_posts := {}
var world_items := {}
var container_serial := 0
var container_items := {}
var labels := preload("res://Network/ItemLabels.gd").new()
signal environment_changed(state: Dictionary)
# ModernUO's real wait for a kind of action (our ActionTimers extension):
# milliseconds left, 0 ready, -1 held until further notice.
signal action_wait(kind: String, milliseconds: int)
# Developer edit session records (system messages prefixed UCEDIT1|).
signal dev_edit_received(line: String)

var environment_state := {}
var last_environment_request := -30000
# Speech packets are throttled server-side; edit commands are spaced out.
var dev_edit_queue: Array[String] = []
var next_dev_edit := 0

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
var destination_ready := Callable()
var preview_bounds := Rect2i()
var returning_home := false
var last_boundary_message := 0
# Protocol systems (Network/Packets/*): each registers the server packets it
# parses here. Packets nothing handles are counted for the protocol census.
const MODULES := {
	"tooltips":preload("res://Network/Packets/Tooltips.gd"),
	"mobiles":preload("res://Network/Packets/Mobiles.gd"),
	"messages":preload("res://Network/Packets/Messages.gd"),
	"environment":preload("res://Network/Packets/Environment.gd"),
	"effects":preload("res://Network/Packets/Effects.gd"),
	"combat":preload("res://Network/Packets/Combat.gd"),
	"connection":preload("res://Network/Packets/Connection.gd"),
	"items":preload("res://Network/Packets/Items.gd"),
	"player":preload("res://Network/Packets/Player.gd"),
	"buffs":preload("res://Network/Packets/Buffs.gd"),
	"dialogs":preload("res://Network/Packets/Dialogs.gd"),
	"social":preload("res://Network/Packets/Social.gd"),
	"world":preload("res://Network/Packets/WorldSystems.gd"),
	"requests":preload("res://Network/Packets/Requests.gd"),
}
# Server packets the match in _handle handles itself (ProtocolTests checks
# that every packet ModernUO sends is here or routed to a module).
# 0x53 popup messages, as ClassicUO words them.
const POPUPS := ["Incorrect password.","This character no longer exists.","This character already exists.","Could not attach to the game server.","Could not attach to the game server.","Another character from this account is already in the world.","Synchronisation error; please reconnect.","You have been idle too long. If you do nothing in the next minute you will be logged out.","Could not attach to the game server.","This character is being transferred."]
const OWN_PACKETS := [0x6c,0xb0,0xdd,0xd4,0x66,0x71,0xa9,0xbd,0x1b,0x55,0x20,0x21,0x22,0x78,0x77,0x6e,0xe2,0x72,0xf3,0x1a,0x27,0x74,0x3b,0x11,0xa1,0xa2,0xa3,0x3a,0x25,0xc1,0x1d,0x2e,0xbf,0x24,0x3c,0x4f,0x4e,0x65,0x1c,0xae,0x82,0x53]
# 0xBF subcommands the match below handles itself.
const OWN_EXTENDED := [0x04,0x08,0x14,0x19]
var modules := {}
var routes := {}
var extended_routes := {}
var unhandled := {}
var unhandled_extended := {}

func _init() -> void:
	for key in MODULES:
		modules[key] = MODULES[key].new()
		modules[key].attach(self)

func module(key: String) -> RefCounted:
	return modules.get(key)

func route(id: int, handler: Callable) -> void:
	if not routes.has(id): routes[id] = []
	routes[id].append(handler)

func route_extended(sub: int, handler: Callable) -> void:
	if not extended_routes.has(sub): extended_routes[sub] = []
	extended_routes[sub].append(handler)

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

func connect_account(user: String, secret: String, port: int = 2593) -> void:
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
	login.start(user,secret,port)

func close() -> void:
	if is_instance_valid(login):
		login.close()
		login.queue_free()
	login = null
	socket.disconnect_from_host()
	decoder = Huffman.new()
	quiet_labels.clear()
	pending.clear()
	entities.clear()
	world_items.clear()
	multis.clear()
	container_items.clear()
	known_items.clear()
	equipment.clear()
	mobile_equipment.clear()
	mobile_statistics.clear()
	last_mobile_actions.clear()
	pending_transfer.clear()
	next_item_action = 0
	placement_serial = 0
	vendor_prices.clear()
	vendor_stock.clear()
	context_menu.clear()
	entity_names.clear()
	vendor_serial = 0
	gold = -1
	player_status.clear()
	skills.clear()
	gumps.clear()
	books.clear()
	board_posts.clear()
	board_serial = 0
	target_request.clear()
	container_serial = 0
	environment_state.clear()
	last_environment_request = -30000
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
	unhandled.clear()
	unhandled_extended.clear()
	for key in modules: modules[key].reset()
	ended.emit()

func _fail(reason: String) -> void:
	close()
	failed.emit(reason)

func send(bytes: PackedByteArray) -> void:
	if socket.put_data(bytes) != OK: _fail("Game send failed")

func _process(_delta: float) -> void:
	if phase == "world":
		for key in modules: modules[key].tick()
	if icons_dirty and Time.get_ticks_msec()>=next_icon_save:
		var path := "res://item-art-requests.local.json"
		if FileAccess.file_exists(path):
			var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if prior is Array:
				for id in prior: requested_icons[int(id)] = true
		var file := FileAccess.open(path,FileAccess.WRITE)
		if file: file.store_string(JSON.stringify(requested_icons.keys()))
		icons_dirty = false
		next_icon_save = Time.get_ticks_msec()+1000
	if not pending_transfer.is_empty() and Time.get_ticks_msec() > transfer_deadline:
		finish_transfer(false,"No server confirmation. Reopen the container to refresh.")
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
	if phase == "world" and Time.get_ticks_msec()-last_environment_request > 10000:
		send(speech_packet("[PreviewEnvironment"))
		last_environment_request = Time.get_ticks_msec()
		next_dev_edit = maxi(next_dev_edit,Time.get_ticks_msec()+60)
	if phase == "world" and not dev_edit_queue.is_empty() and Time.get_ticks_msec() >= next_dev_edit:
		send(speech_packet(dev_edit_queue.pop_front()))
		next_dev_edit = Time.get_ticks_msec()+60
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
	var routed := routes.has(id)
	if routed:
		for handler in routes[id]: handler.call(p)
	if id == 0xbf and p.size() >= 5:
		var sub := Login.read_be(p,3,2)
		if extended_routes.has(sub):
			for handler in extended_routes[sub]: handler.call(p)
		elif not sub in OWN_EXTENDED: unhandled_extended[sub] = int(unhandled_extended.get(sub,0))+1
	match id:
		0x6c:
			if p.size() != 19: return
			target_request = p.duplicate() if p[6] != 3 else PackedByteArray()
			target_changed.emit(not target_request.is_empty())
		0xb0,0xdd:
			var gump := preload("res://Network/GumpProtocol.gd").decode(p)
			if gump.is_empty():
				message_received.emit("Unsupported or malformed server window received.")
				return
			var requested_art := preload("res://Network/GumpProtocol.gd").art_ids(gump)
			var request_path := "res://gump-art-requests.local.json"
			if FileAccess.file_exists(request_path):
				var prior: Variant = JSON.parse_string(FileAccess.get_file_as_string(request_path))
				if prior is Array:
					for value in prior:
						if not requested_art.has(int(value)): requested_art.append(int(value))
			var request_file := FileAccess.open(request_path,FileAccess.WRITE)
			if request_file: request_file.store_string(JSON.stringify(requested_art))
			gumps[int(gump.type)] = gump
			gump_received.emit(gump)
		0xd4,0x66,0x71:
			var response := preload("res://Network/ItemResponses.gd").decode(p)
			if response.is_empty(): return
			var serial := int(response.serial)
			match response.kind:
				"cover","pages":
					if not (world_items.has(serial) or container_items.has(serial) or books.has(serial)): return
					var book: Dictionary = books.get(serial,{"serial":serial,"title":"Book","author":"","pages":{}})
					if response.kind == "cover": book.merge(response,true)
					else: book.pages.merge(response.pages,true)
					books[serial] = book
					book_received.emit(book)
				"board":
					if not world_items.has(serial): return
					board_serial = serial
					board_posts.clear()
					container_serial = serial
					container_items.clear()
					board_received.emit(response)
				"post":
					if serial != board_serial: return
					board_posts[int(response.post)] = response
					board_post_received.emit(response)
		0xa9:
			var count := int(p[3]) if p.size() > 3 else 0
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
			var version := Login.version_text().to_ascii_buffer()
			version.append(0)
			var response := PackedByteArray([0xbd])
			response.append_array(Login.uint_be(version.size()+3,2))
			response.append_array(version)
			send(response)
		0x1b:
			player.serial = Login.read_be(p,1,4)
			player.body = Login.read_be(p,9,2)
			player.x = Login.read_be(p,11,2)
			player.y = Login.read_be(p,13,2)
			player.z = signed(Login.read_be(p,15,2),16)
			player.direction = int(p[17]) & 7
		0x55:
			phase = "world"
			last_ping = Time.get_ticks_msec()
			entered.emit(player.duplicate())
			request_character()
			# As the classic client does after login: its view range.
			send(preload("res://Network/Packets/Environment.gd").view_range_packet(18))
		0x20:
			if Login.read_be(p,1,4) == player.serial:
				player.body = Login.read_be(p,5,2)
				player.hue = Login.read_be(p,8,2)
				player.flags = int(p[10])
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
			var snapshot := MobileLook.snapshot(p)
			if snapshot.is_empty(): return
			var entity: Dictionary = snapshot.entity
			var serial := int(entity.serial)
			entity.facet = player.facet
			entities[serial] = entity
			mobile_equipment[serial] = snapshot.worn
			if serial == player.serial:
				equipment = snapshot.worn.duplicate(true)
				player.body = entity.body
				# Worn at login: known like any other item, so it can be used
				# (a hatchet in hand, a spellbook) and dragged.
				for layer in equipment:
					var worn: Dictionary = equipment[layer]
					if not worn.has("container"): worn.container = serial
					if not worn.has("layer"): worn.layer = int(layer)
					remember_item(worn)
				player.hue = entity.hue
				player.flags = entity.flags
				player.notoriety = entity.notoriety
				for worn: Dictionary in equipment.values():
					remember_item(worn)
					if int(worn.layer)==21: backpack = int(worn.serial)
			appearance_changed.emit(serial)
			entity_changed.emit(serial,entity)
		0x77:
			var serial := Login.read_be(p,1,4)
			var entity := {"serial":serial,"body":Login.read_be(p,5,2),"hue":Login.read_be(p,13,2),"x":Login.read_be(p,7,2),"y":Login.read_be(p,9,2),"z":signed(p[11]),"direction":int(p[12])&7,"running":(int(p[12])&0x80)!=0,"flags":int(p[15]),"notoriety":int(p[16]),"facet":player.facet}
			entities[serial] = entity
			entity_changed.emit(serial,entity)
		0x6e,0xe2:
			var action := MobileLook.action(p)
			if not action.is_empty():
				var mobile: Dictionary = player if int(action.serial)==int(player.serial) else entities.get(int(action.serial),{})
				action.body = int(mobile.get("body",0))
				last_mobile_actions[int(action.serial)] = action
				mobile_action_received.emit(action.duplicate(true))
		0x72:
			player.flags=(int(player.get("flags",0))&~0x40)|(0x40 if p[1]!=0 else 0)
			appearance_changed.emit(int(player.serial))
		0xf3:
			if p.size() == 26 and int(p[3]) in [0,2]:
				var item := {"serial":Login.read_be(p,4,4),"id":Login.read_be(p,8,2),"amount":Login.read_be(p,11,2),"x":Login.read_be(p,15,2)&0x7fff,"y":Login.read_be(p,17,2)&0x3fff,"z":signed(p[19]),"hue":Login.read_be(p,21,2),"flags":int(p[23]),"facet":player.facet}
				if int(p[3]) == 2:
					item.id = int(item.id)&0x3fff
					_multi(item)
				else: _world_item(item)
		0x1a:
			var item := legacy_item(p)
			if not item.is_empty():
				item.facet = player.facet
				if int(item.id) >= 0x4000:
					item.id = int(item.id)-0x4000
					_multi(item)
				else: _world_item(item)
		0x27:
			# Lift refusal reasons as the classic client words them.
			var reasons := ["You cannot pick that up.","That is too far away.","That is out of sight.","That item does not belong to you.","You are already holding an item."]
			finish_transfer(false,reasons[int(p[1])] if p.size() > 1 and int(p[1]) < reasons.size() else "The server refused to move that item.")
		0x74:
			var prices := Commerce.prices(p)
			if not prices.is_empty(): vendor_prices[int(prices.container)] = prices.entries
		0x3b:
			if p.size() >= 8:
				next_item_action = Time.get_ticks_msec()+1100
				vendor_closed.emit(Login.read_be(p,3,4))
		0x11:
			if p.size() >= 43:
				var serial := Login.read_be(p,3,4)
				entity_names[serial] = text(p,7,30)
				entity_name_received.emit(serial,entity_names[serial])
				if not mobile_statistics.has(serial): mobile_statistics[serial] = {}
				mobile_statistics[serial].merge(Character.status(p),true)
				if serial == int(player.serial) and int(p[42]) > 0 and p.size() >= 62: gold = Login.read_be(p,58,4)
				if serial == int(player.serial):
					player_status.merge(Character.status(p),true)
					status_changed.emit(player_status)
				appearance_changed.emit(serial)
		0xa1,0xa2,0xa3:
			var vital := Character.vital(p)
			if not vital.is_empty():
				var serial := int(vital.serial)
				if not mobile_statistics.has(serial): mobile_statistics[serial] = {}
				mobile_statistics[serial].merge(vital,true)
			if not vital.is_empty() and int(vital.serial) == int(player.serial):
				player_status.merge(vital,true)
				status_changed.emit(player_status)
			if not vital.is_empty(): appearance_changed.emit(int(vital.serial))
		0x3a:
			var update := Character.skills(p)
			if update.is_empty(): return
			if update.full: skills.clear()
			skills.merge(update.skills,true)
			skills_changed.emit(skills)
		0x25:
			if p.size()!=21: return
			var serial := Login.read_be(p,1,4)
			_remove_world_item(serial)
			remember_item({"serial":serial,"id":Login.read_be(p,5,2)+int(p[7]),"amount":Login.read_be(p,8,2),"container":Login.read_be(p,15,4),"x":Login.read_be(p,10,2),"y":Login.read_be(p,12,2),"hue":Login.read_be(p,19,2)})
		0xc1:
			if p.size() >= 50:
				var serial := Login.read_be(p,3,4)
				var label := labels.resolve(Login.read_be(p,14,4),little_unicode_text(p,48))
				speech_received.emit(serial,label,int(p[9]),Login.read_be(p,10,2))
				item_label_received.emit(serial,label)
				if not quiet_labels.has(serial): message_received.emit(label)
				quiet_labels.erase(serial)
		0x1d:
			var serial := Login.read_be(p,1,4)
			if not pending_transfer.is_empty() and int(pending_transfer.serial)==serial: pending_transfer.lifted = true
			entities.erase(serial)
			mobile_equipment.erase(serial)
			mobile_statistics.erase(serial)
			last_mobile_actions.erase(serial)
			_forget_worn(serial)
			entity_removed.emit(serial)
			_remove_world_item(serial)
			known_items.erase(serial)
			for layer in equipment.keys():
				if int(equipment[layer].serial) == serial: equipment.erase(layer)
			if container_items.erase(serial): inventory_received.emit(container_items.values())
			items_changed.emit()
		0x2e:
			if p.size() != 15: return
			var owner := Login.read_be(p,9,4)
			var item := {"serial":Login.read_be(p,1,4),"id":Login.read_be(p,5,2),"amount":1,"layer":int(p[8]),"container":owner,"hue":Login.read_be(p,13,2)}
			_forget_worn(int(item.serial))
			if not mobile_equipment.has(owner): mobile_equipment[owner] = {}
			mobile_equipment[owner][int(item.layer)] = item
			if owner == int(player.serial):
				equipment[item.layer] = item
				if item.layer == 21: backpack = int(item.serial)
			remember_item(item)
			appearance_changed.emit(owner)
		0xbf:
			if p.size()>=12 and Login.read_be(p,3,2)==0x14:
				context_menu = Commerce.context(p)
				if not context_menu.is_empty(): context_received.emit(context_menu)
			if p.size() == 13 and Login.read_be(p,3,2) == 4:
				var type := Login.read_be(p,5,4)
				gumps.erase(type)
				gump_closed.emit(type)
			var locks := Character.stat_locks(p)
			if not locks.is_empty() and int(locks.serial) == int(player.serial):
				player_status.locks = locks
				status_changed.emit(player_status)
			if p.size() >= 6 and Login.read_be(p,3,2) == 8:
				if player.facet != int(p[5]):
					for serial in world_items.keys()+multis.keys(): _remove_world_item(serial)
				player.facet = int(p[5])
		0x24:
			next_item_action = maxi(next_item_action,Time.get_ticks_msec()+1100)
			if Login.read_be(p,5,2)==0x30:
				vendor_serial = Login.read_be(p,1,4)
				vendor_stock.clear()
				for parent in vendor_prices:
					var stock := contents_of(int(parent))
					stock.sort_custom(func(a: Dictionary,b: Dictionary): return int(a.x)<int(b.x))
					var prices: Array = vendor_prices[parent]
					if stock.size()!=prices.size(): continue
					for i in stock.size(): vendor_stock.append(stock[i].merged(prices[i]))
				vendor_received.emit(vendor_serial,vendor_stock)
				return
			container_serial = Login.read_be(p,1,4)
			container_items.clear()
			container_opened.emit(container_serial)
			interaction_confirmed.emit("Container opened by server (0x%08x)" % container_serial)
		0x3c:
			if p.size() < 5: return
			var count := Login.read_be(p,3,2)
			if p.size() != 5+count*20:
				_fail("Invalid inventory packet length")
				return
			var items := []
			for i in count:
				var offset := 5+i*20
				items.append({"serial":Login.read_be(p,offset,4),"id":Login.read_be(p,offset+4,2),"amount":Login.read_be(p,offset+7,2),"container":Login.read_be(p,offset+14,4),"x":Login.read_be(p,offset+9,2),"y":Login.read_be(p,offset+11,2),"hue":Login.read_be(p,offset+18,2)})
			var parents := {}
			for item in items: parents[int(item.container)] = true
			if items.is_empty(): parents[container_serial] = true
			for serial in known_items.keys():
				if parents.has(int(known_items[serial].get("container",0))): known_items.erase(serial)
			container_items.clear()
			for item in items:
				remember_item(item)
				_remove_world_item(item.serial)
				if item.container == container_serial: container_items[item.serial] = item
			inventory_received.emit(container_items.values())
			container_contents_received.emit(container_serial,container_items.values())
			if container_serial == board_serial:
				for item in container_items.values(): request_board_post(int(item.serial),false)
		0x4f:
			_environment_update({"global_light":clampi(int(p[1]),0,31)})
		0x4e:
			if Login.read_be(p,1,4) == player.serial:
				_environment_update({"personal_light":clampi(int(p[5]),0,31)})
		0x65:
			_environment_update({"weather_type":int(p[1]),"density":clampi(int(p[2]),0,70),"temperature":signed(p[3])})
		0x1c:
			if p.size() > 44:
				var label := text(p,44,p.size()-44)
				var serial := Login.read_be(p,3,4)
				speech_received.emit(serial,label,int(p[9]),Login.read_be(p,10,2))
				if world_items.has(serial): item_label_received.emit(serial,label)
				if not quiet_labels.has(serial): _server_text(label,serial == 0xffffffff)
				quiet_labels.erase(serial)
		0xae:
			if p.size() >= 50:
				var label := unicode_text(p,48)
				var serial := Login.read_be(p,3,4)
				speech_received.emit(serial,label,int(p[9]),Login.read_be(p,10,2))
				if world_items.has(serial): item_label_received.emit(serial,label)
				if not quiet_labels.has(serial): _server_text(label,serial == 0xffffffff)
				quiet_labels.erase(serial)
		0x82: _fail(Login.rejection(int(p[1]) if p.size() > 1 else 4))
		0x53:
			# Popup messages: most refuse entry, but 7 only warns of idling.
			var code := int(p[1]) if p.size() > 1 else 3
			if code == 7: message_received.emit(POPUPS[7])
			else: _fail(POPUPS[code] if code < POPUPS.size() else "The server refused the character (%d)." % code)
		_:
			if not routed: unhandled[id] = int(unhandled.get(id,0))+1

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

func create_character(name: String, slot: int, city: int, female: bool = false, appearance: Dictionary = {}) -> void:
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
	send(creation_packet(name,slot,city,female,appearance))

static func creation_packet(name: String, slot: int, city: int, female: bool = false, appearance: Dictionary = {}) -> PackedByteArray:
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
	p.append_array(PackedByteArray([3 if female else 2,40,30,20,40,30,27,30,17,30,1,30]))
	for value in [int(appearance.get("skin_hue",0x03ea)),int(appearance.get("hair_id",0)),int(appearance.get("hair_hue",0)),int(appearance.get("beard_id",0)),int(appearance.get("beard_hue",0)),city]: p.append_array(Login.uint_be(value,2))
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
	if not turn_only and destination_ready.is_valid():
		var offset: Vector2i = preload("res://Presentation/MovementSurface.gd").OFFSETS[direction & 7]
		if not destination_ready.call(Vector2i(player.x,player.y)+offset): return false
	# The pinned PlayerMobile has zero-cost turns; a turn must not consume a
	# full 410 ms walking interval. Keep a short packet-rate guard for input jitter.
	move_interval = 20 if turn_only else roundi(preload("res://Presentation/HorseVisual.gd").step_seconds(equipment.values(),run)*1000.)+5
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
	if phase == "world" and backpack != 0 and pending_transfer.is_empty():
		next_item_action = Time.get_ticks_msec()+1100
		var p := PackedByteArray([6])
		p.append_array(Login.uint_be(backpack,4))
		send(p)

# Speech keywords ("bank", "vendor buy", boat orders) go out encoded.
static func speech_packet(message: String) -> PackedByteArray:
	return preload("res://Network/SpeechKeywords.gd").packet(message)

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

# Developer edit commands do not resynchronise movement, unlike send_command.
func send_dev_edit(command: String) -> bool:
	var line := "[DevEdit "+command
	if phase != "world" or speech_packet(line).is_empty(): return false
	dev_edit_queue.append(line)
	return true

func return_to_britain() -> void:
	if phase != "world": return
	returning_home = true
	requested_position.clear()
	needs_sync = false
	send_command("[PreviewHome")

func _environment_update(values: Dictionary) -> void:
	environment_state.merge(values,true)
	environment_changed.emit(environment_state.duplicate())

func _server_text(message: String, system: bool = false) -> void:
	if system and message.begins_with("UCENV1|"):
		var fields := message.split("|")
		if fields.size() != 4 or not fields[1].is_valid_int() or not fields[2].is_valid_int() or not fields[3].is_valid_float(): return
		var hour := int(fields[1])
		var minute := int(fields[2])
		var seconds := float(fields[3])
		if hour < 0 or hour > 23 or minute < 0 or minute > 59 or seconds < 1 or seconds > 3600: return
		_environment_update({"minute_of_day":hour*60+minute,"seconds_per_minute":seconds,"sample_msec":Time.get_ticks_msec()})
		return
	if system and message.begins_with("UCWAIT1|"):
		var parts := message.split("|")
		if parts.size() == 3 and parts[1] in ["skill","spell","bandage","heal_potion"] and parts[2].is_valid_int(): action_wait.emit(parts[1],int(parts[2]))
		return
	if system and message.begins_with("UCEDIT1|"):
		dev_edit_received.emit(message.substr(8))
		return
	message_received.emit(message)

func _world_item(item: Dictionary) -> void:
	remember_item(item.merged({"container":0}))
	world_items[item.serial] = item
	world_item_changed.emit(item.serial,item.duplicate())

func _remove_world_item(serial: int) -> void:
	if world_items.erase(serial): world_item_removed.emit(serial)
	if multis.erase(serial): multi_removed.emit(serial)

func _multi(item: Dictionary) -> void:
	world_items.erase(int(item.serial))
	multis[int(item.serial)] = item
	multi_changed.emit(int(item.serial),item.duplicate())

static func legacy_item(p: PackedByteArray) -> Dictionary:
	if p.size() < 14: return {}
	var serial := Login.read_be(p,3,4)
	var graphic := Login.read_be(p,7,2)
	var cursor := 9
	var amount := 1
	if serial & 0x80000000:
		if cursor+2 > p.size(): return {}
		amount = Login.read_be(p,cursor,2)
		cursor += 2
	if graphic & 0x8000:
		if cursor+1 > p.size(): return {}
		graphic = (graphic&0x7fff)+int(p[cursor])
		cursor += 1
	if cursor+5 > p.size(): return {}
	var x := Login.read_be(p,cursor,2)
	var y := Login.read_be(p,cursor+2,2)
	cursor += 4
	if x & 0x8000: cursor += 1
	if cursor >= p.size(): return {}
	var z := signed(p[cursor])
	cursor += 1
	var hue := 0
	var flags := 0
	if y & 0x8000:
		if cursor+2 > p.size(): return {}
		hue = Login.read_be(p,cursor,2)
		cursor += 2
	if y & 0x4000:
		if cursor >= p.size(): return {}
		flags = int(p[cursor])
	return {"serial":serial&0x7fffffff,"id":graphic,"amount":amount,"x":x&0x7fff,"y":y&0x3fff,"z":z,"hue":hue,"flags":flags}

# Ask the server for an item's label without echoing it to the message log
# (street signs and plaques show their names on the boards themselves).
func request_label(serial: int) -> bool:
	if phase != "world" or not world_items.has(serial): return false
	quiet_labels[serial] = true
	var click := PackedByteArray([9])
	click.append_array(Login.uint_be(serial,4))
	send(click)
	return true

# Attack request (0x05), as the native client sends for a double-click on a
# creature while in war mode; ModernUO decides whether the fight starts.
func attack(serial: int) -> bool:
	if phase != "world" or serial == int(player.get("serial",0)) or not entities.has(serial): return false
	send(preload("res://Network/ActionProtocol.gd").attack(serial))
	return true

func in_war_mode() -> bool:
	return (int(player.get("flags",0)) & 0x40) != 0

func use_mobile(serial: int) -> bool:
	if phase!="world" or not pending_transfer.is_empty():return false
	if serial!=int(player.get("serial",0)) and not entities.has(serial):return false
	# Mount ownership, range, war mode and all permission checks belong to ModernUO.
	next_item_action=Time.get_ticks_msec()+1100
	send(preload("res://Network/ActionProtocol.gd").double_click(serial))
	return true

func use_item(serial: int) -> bool:
	if not pending_transfer.is_empty(): return false
	if phase != "world" or not (world_items.has(serial) or known_items.has(serial)): return false
	# Clothing, armour and jewellery are put on by double-clicking them, as by
	# dropping them on the paperdoll; the server decides. Hand-held items
	# (layers 1 and 2: weapons, tools, spellbooks, torches) keep their use.
	if wear_on_use(serial): return move_item(serial,int(player.get("serial",0)),true)
	next_item_action = Time.get_ticks_msec()+1100
	var click := PackedByteArray([9])
	click.append_array(Login.uint_be(serial,4))
	send(click)
	var use := PackedByteArray([6])
	use.append_array(Login.uint_be(serial,4))
	send(use)
	return true

func wear_on_use(serial: int) -> bool:
	var item: Dictionary = known_items.get(serial,{})
	if item.is_empty() or int(item.get("container",0)) == 0: return false
	# Already worn (its container is a mobile) or not in your reach of packs.
	if int(item.get("container",0)) == int(player.get("serial",0)) or entities.has(int(item.get("container",0))): return false
	var layer := preload("res://Network/PaperdollWindow.gd").layer_of(int(item.get("id",0)))
	return layer != 0 and not layer in [1,2,11,16,21,25]

static func little_unicode_text(bytes: PackedByteArray, start: int) -> String:
	var end := start
	while end+1 < bytes.size():
		if bytes[end] == 0 and bytes[end+1] == 0: break
		end += 2
	return bytes.slice(start,end).get_string_from_utf16()

func request_board_post(serial: int, content: bool = true) -> bool:
	if phase != "world" or board_serial == 0 or not container_items.has(serial): return false
	var packet := PackedByteArray([0x71,0,12,3 if content else 4])
	packet.append_array(Login.uint_be(board_serial,4))
	packet.append_array(Login.uint_be(serial,4))
	send(packet)
	return true

static func target_packet(request: PackedByteArray, item: Dictionary = {}) -> PackedByteArray:
	if request.size() != 19: return PackedByteArray()
	var packet := PackedByteArray([0x6c,0])
	packet.append_array(request.slice(2,7))
	packet.append_array(Login.uint_be(int(item.get("serial",0)),4))
	packet.append_array(Login.uint_be(int(item.get("x",65535)),2))
	packet.append_array(Login.uint_be(int(item.get("y",65535)),2))
	packet.append_array(PackedByteArray([0,int(item.get("z",0))&255]))
	packet.append_array(Login.uint_be(int(item.get("id",0)),2))
	return packet

# Answer the open target cursor with a place (0x6C type 1): a map static
# (a tree for a hatchet, ore for a pickaxe, water for a fishing pole) by its
# graphic and exact cell, or bare ground with graphic 0. ModernUO checks the
# static against its own map. High Seas clients send a surface at its top,
# so its height is added back, as the native client does.
func target_location(x: int, y: int, z: int, graphic: int = 0) -> bool:
	if phase != "world" or target_request.is_empty(): return false
	var packet := target_packet(target_request,{"serial":0,"x":x,"y":y,"z":z,"id":graphic})
	packet[1] = 1
	send(packet)
	target_request.clear()
	target_changed.emit(false)
	return true

func target_item(serial: int = 0) -> bool:
	if phase != "world" or target_request.is_empty(): return false
	var item: Dictionary = {}
	if serial == int(player.serial): item = player
	elif world_items.has(serial): item = world_items[serial]
	elif container_items.has(serial): item = container_items[serial]
	elif serial != 0: return false
	send(target_packet(target_request,item))
	target_request.clear()
	target_changed.emit(false)
	return true

func respond_gump(gump: Dictionary, button: int, switches: Array = [], entries: Dictionary = {}) -> bool:
	if phase != "world" or not gumps.has(int(gump.type)) or int(gumps[int(gump.type)].serial) != int(gump.serial): return false
	var packet := preload("res://Network/GumpProtocol.gd").response(gump,button,switches,entries)
	if packet.is_empty(): return false
	send(packet)
	gumps.erase(int(gump.type))
	return true

func request_help() -> void:
	if phase != "world": return
	var packet := PackedByteArray([0x9b])
	packet.resize(258)
	send(packet)

func contents_of(parent: int) -> Array:
	var result := []
	for item in known_items.values():
		if int(item.get("container",0)) == parent: result.append(item)
	return result
func appearance_for(serial: int) -> Dictionary:
	var entity: Dictionary = player if serial==int(player.serial) else entities.get(serial,{"serial":serial})
	var stats: Dictionary = player_status if serial==int(player.serial) else mobile_statistics.get(serial,{})
	return MobileLook.profile(entity,mobile_equipment.get(serial,{}).values(),stats,str(entity_names.get(serial,stats.get("name",""))))
func set_war_mode(enabled: bool) -> void:
	if phase=="world":send(PackedByteArray([0x72,1 if enabled else 0,0,0x32,0]))
func request_emote(name: String) -> bool:
	if phase!="world" or name!="bow":return false
	var payload:=PackedByteArray([0xc7]);payload.append_array(name.to_ascii_buffer());payload.append(0)
	var packet:=PackedByteArray([0x12]);packet.append_array(Login.uint_be(payload.size()+3,2));packet.append_array(payload);send(packet)
	return true
func remember_item(item: Dictionary) -> void:
	if not item.has("layer"): _forget_worn(int(item.serial))
	if not requested_icons.has(int(item.id)):
		requested_icons[int(item.id)] = true
		icons_dirty = true
	var serial := int(item.serial)
	known_items[serial] = item
	if int(item.get("container",0)) == container_serial: container_items[serial] = item
	else: container_items.erase(serial)
	if not pending_transfer.is_empty() and serial == int(pending_transfer.serial):
		if int(item.get("container",0)) == int(pending_transfer.destination): finish_transfer(true,"Item move confirmed by server.")
		elif pending_transfer.get("lifted",false) and int(item.get("container",0)) == int(pending_transfer.source): finish_transfer(false,"Server returned the item to its original location.")
	items_changed.emit()
func _forget_worn(serial: int) -> void:
	for owner in mobile_equipment.keys():
		var changed := false
		for layer in mobile_equipment[owner].keys():
			if int(mobile_equipment[owner][layer].serial)==serial:
				mobile_equipment[owner].erase(layer)
				if int(owner)==int(player.serial): equipment.erase(layer)
				changed = true
		if changed: appearance_changed.emit(int(owner))
func finish_transfer(success: bool, description: String) -> void:
	if pending_transfer.is_empty(): return
	next_item_action = maxi(next_item_action,Time.get_ticks_msec()+1100)
	pending_transfer.clear()
	transfer_result.emit(success,description)
	message_received.emit(description)
func move_item(serial: int, destination: int, equip_item: bool = false, ground_point: Vector3i = Vector3i(-999,-999,-999)) -> bool:
	if phase != "world" or not pending_transfer.is_empty() or not known_items.has(serial) or serial == backpack: return false
	var item: Dictionary = known_items[serial]
	var source := int(item.get("container",0))
	if source == destination: return false
	pending_transfer = {"serial":serial,"source":source,"destination":destination,"lifted":false}
	var delay := maxf(0.0,float(next_item_action-Time.get_ticks_msec())/1000.0)
	transfer_deadline = Time.get_ticks_msec()+int(delay*1000)+8000
	next_item_action = Time.get_ticks_msec()+int(delay*1000)+1100
	var packet := Commerce.lift(serial,int(item.get("amount",1)))
	if equip_item: packet.append_array(Commerce.equip(serial,int(player.serial)))
	else: packet.append_array(Commerce.drop(serial,destination,(ground_point if ground_point.x!=-999 else Vector3i(int(player.x),int(player.y),int(player.z))) if destination == 0 else Vector3i(-1,-1,0)))
	if delay > 0:
		get_tree().create_timer(delay).timeout.connect(func():
			if phase == "world" and not pending_transfer.is_empty() and int(pending_transfer.serial)==serial: send(packet))
	else: send(packet)
	return true
func request_context(serial: int) -> bool:
	if phase != "world" or not (entities.has(serial) or known_items.has(serial)): return false
	vendor_prices.clear()
	send(Commerce.context_request(serial))
	var status := PackedByteArray([0x34,0xed,0xed,0xed,0xed,4])
	status.append_array(Login.uint_be(serial,4))
	if entities.has(serial): send(status)
	return true
func choose_context(index: int) -> bool:
	if phase != "world" or context_menu.is_empty(): return false
	for option in context_menu.options:
		if int(option.index)==index and (int(option.flags)&1)==0:
			send(Commerce.context_reply(int(context_menu.serial),index))
			return true
	return false
func buy_item(serial: int,amount: int = 1) -> bool:
	if phase != "world" or vendor_serial == 0: return false
	for item in vendor_stock:
		if int(item.serial)==serial and amount>0 and amount<=int(item.amount):
			next_item_action = Time.get_ticks_msec()+1100
			send(Commerce.buy(vendor_serial,serial,amount))
			return true
	return false

func begin_place(serial: int) -> bool:
	if phase!="world" or not pending_transfer.is_empty() or not known_items.has(serial): return false
	placement_serial = serial
	message_received.emit("Click a nearby floor or ground surface to place the item. Escape cancels.")
	return true

# Ask the server for the player's full status and skill list.
func request_character() -> void:
	if phase != "world" or int(player.serial) == 0: return
	send(Character.query(int(player.serial),false))
	send(Character.query(int(player.serial),true))

func use_skill(id: int) -> bool:
	if phase != "world" or not Character.USABLE.has(id): return false
	send(Character.use_skill(id))
	return true

# Lock: 0 raise, 1 lower, 2 locked. The server applies it without echoing.
func set_skill_lock(id: int, lock: int) -> bool:
	if phase != "world" or not skills.has(id): return false
	send(Character.skill_lock(id,lock))
	skills[id].lock = clampi(lock,0,2)
	skills_changed.emit(skills)
	return true

# Stat: 0 strength, 1 dexterity, 2 intelligence.
func set_stat_lock(stat: int, lock: int) -> bool:
	if phase != "world" or stat < 0 or stat > 2: return false
	send(Character.stat_lock(stat,lock))
	return true
