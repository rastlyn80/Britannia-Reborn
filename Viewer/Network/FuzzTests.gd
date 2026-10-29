extends SceneTree
# Malformed-packet fuzzing (protocol Phase 6): every packet type ModernUO can
# send, and every 0xBF subcommand, is fed random contents the way the network
# framing would deliver them: fixed-size packets at their exact size,
# variable ones at random lengths with a matching length field. A script
# error anywhere while handling one counts as a failure for that packet type.
# Seeded, so a failure reproduces.
const Tests = preload("res://Network/ProtocolTests.gd")
const ROUNDS := 60

class Catch extends Logger:
	var errors: Array = []
	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void:
		# Script errors, and engine errors raised from a script call (bad
		# rectangles, failed decompression…): those name the script frame.
		var frame := ""
		for trace in script_backtraces:
			if trace.get_frame_count() > 0:
				frame = "%s:%d " % [trace.get_frame_file(0).get_file(),trace.get_frame_line(0)]
				break
		# A corrupt stream that passes the zlib header check fails inside the
		# engine's decompress; the callers check the size and drop it.
		if function == "decompress": return
		if error_type == ERROR_TYPE_SCRIPT or file.begins_with("res://") or frame != "":
			errors.append("%s%s:%d %s %s" % [frame,file.get_file(),line,function,rationale if rationale != "" else code])
	func _log_message(_message: String, _error: bool) -> void: pass

var catch := Catch.new()
var session: Node
var rng := RandomNumberGenerator.new()
var failures := {}
var checked := 0

func _initialize() -> void: call_deferred("run")

func world_session() -> Node:
	var game: Node = preload("res://Network/GameSession.gd").new()
	root.add_child(game)
	game.phase = "world"
	game.player.merge({"serial":7,"x":1602,"y":1591,"z":20,"facet":1,"body":400,"direction":0},true)
	game.backpack = 0x40000001
	return game

var zero_heavy := false
func random_bytes(count: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(count)
	for i in count:
		# Mostly small values, as real fields are; some full-range noise. The
		# stateful pass uses mostly zeros, so serials name the primed objects.
		if zero_heavy: bytes[i] = 0 if rng.randf() < 0.7 else rng.randi_range(0,8)
		else: bytes[i] = rng.randi_range(0,255) if rng.randf() < 0.5 else rng.randi_range(0,8)
	return bytes

# Mobiles, items, containers, a party, a boat and a house under serials 1-8.
func prime(game: Node) -> void:
	for serial in range(1,9):
		game.entities[serial] = {"serial":serial,"body":400 if serial%2 else 0xc9,"x":1600+serial,"y":1590,"z":20,"direction":0,"hue":0,"flags":0,"notoriety":1,"facet":1}
		game.mobile_statistics[serial] = {"hits":10,"hits_max":20}
		var item := {"serial":0x40000000+serial,"id":0xe75,"amount":1,"x":1600,"y":1590+serial,"z":20,"hue":0,"flags":0,"facet":1}
		game.world_items[serial] = item.merged({"serial":serial})
		game.known_items[serial] = item.merged({"serial":serial,"container":1})
	game.multis[5] = {"serial":5,"id":0,"x":1600,"y":1600,"z":-5,"facet":1}
	game.module("social").party = [7,1,2]

func pass_over(rounds: int, tag: String) -> void:
	for id in Tests.SERVER_SENDS:
		var length: int = session.packet_length(id)
		for round in rounds:
			var packet: PackedByteArray
			if length > 0:
				packet = random_bytes(length)
			else:
				var size := 3+rng.randi_range(0,120 if round%3 else 8)
				packet = random_bytes(size)
				packet[1] = size >> 8
				packet[2] = size & 255
			packet[0] = id
			if id == 0xbf and packet.size() >= 5:
				var sub: int = Tests.SERVER_EXTENDED[round%Tests.SERVER_EXTENDED.size()]
				packet[3] = 0
				packet[4] = sub
				feed("%s0xBF 0x%02X" % [tag,sub],packet)
			else:
				feed("%s0x%02X" % [tag,id],packet)

const GUMP_WORDS := ["button","buttontileart","checkbox","checkertrans","croppedtext","gumppic","gumppictiled","htmlgump","itemproperty","noclose","nodispose","nomove","noresize","page","group","endgroup","radio","resizepic","text","textentry","textentrylimited","tilepic","tilepichue","tooltip","xmfhtmlgump","xmfhtmlgumpcolor","xmfhtmltok","mastergump","picinpic","gumppichued","echandleinput"]

# Structured gumps: random layouts from the real command words, with missing,
# extra and absurd arguments, decoded and then built into a window.
func gump_pass(rounds: int) -> void:
	for round in rounds:
		var layout := ""
		for c in rng.randi_range(1,24):
			var words: Array = [GUMP_WORDS[rng.randi_range(0,GUMP_WORDS.size()-1)]]
			for a in rng.randi_range(0,10):
				words.append(str(rng.randi_range(-20,70000)) if rng.randf() < 0.85 else ["@x@","@@","-","999999999999","abc",""][rng.randi_range(0,5)])
			layout += "{ %s }" % " ".join(words)
		var texts: Array = []
		for t in rng.randi_range(0,4): texts.append("line %d" % t)
		var packet := PackedByteArray([0xb0,0,0])
		packet.append_array(Tests.be(rng.randi_range(1,8),4))
		packet.append_array(Tests.be(0x1000+round,4))
		packet.append_array(Tests.be(rng.randi_range(0,500),4))
		packet.append_array(Tests.be(rng.randi_range(0,500),4))
		var bytes := layout.to_utf8_buffer()
		bytes.append(0)
		packet.append_array(Tests.be(bytes.size(),2))
		packet.append_array(bytes)
		packet.append_array(Tests.be(texts.size(),2))
		for text in texts:
			packet.append_array(Tests.be(text.length(),2))
			for ch in text: packet.append_array(Tests.be(ch.unicode_at(0),2))
		packet[1] = packet.size() >> 8
		packet[2] = packet.size() & 255
		catch.errors.clear()
		var decoded: Dictionary = preload("res://Network/GumpProtocol.gd").decode(packet)
		session._handle(packet)
		if not decoded.is_empty():
			var view: Control = preload("res://Network/GumpView.gd").new()
			root.add_child(view)
			view.configure(session,decoded)
			view.free()
		checked += 1
		if not catch.errors.is_empty() and not failures.has("gump"):
			failures["gump"] = [catch.errors[0],layout.substr(0,160)]

func feed(label: String, packet: PackedByteArray) -> void:
	catch.errors.clear()
	session._handle(packet)
	checked += 1
	if not catch.errors.is_empty() and not failures.has(label):
		failures[label] = [catch.errors[0],packet.slice(0,24).hex_encode()]

# --scene: the same fuzz against the full client (Main.tscn with --city), so
# every window and presenter reacting to the packets is exercised too.
func scene_session() -> Node:
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	var started := Time.get_ticks_msec()
	while not scene.world_ready and Time.get_ticks_msec()-started < 180000: await process_frame
	var game: Node = scene.game
	game.phase = "world"
	game.player.merge({"serial":7,"x":1602,"y":1591,"z":20,"facet":1,"body":400,"direction":0},true)
	game.backpack = 0x40000001
	return game

func run() -> void:
	OS.add_logger(catch)
	rng.seed = 20261029
	if "--scene" in OS.get_cmdline_user_args():
		session = await scene_session()
		prime(session)
		pass_over(20,"scene ")
		zero_heavy = true
		pass_over(20,"scene known ")
		gump_pass(100)
		# Let the windows and presenters process what they were sent.
		for frame in 120: await process_frame
		OS.remove_logger(catch)
		report()
		return
	session = world_session()
	pass_over(ROUNDS,"")
	# Stateful: the same packets against a session that knows serials 1-8.
	session.queue_free()
	session = world_session()
	prime(session)
	zero_heavy = true
	pass_over(ROUNDS,"known ")
	gump_pass(400)
	OS.remove_logger(catch)
	report()

func report() -> void:
	var labels: Array = failures.keys()
	labels.sort()
	for label in labels:
		print("FAIL %s: %s  [%s]" % [label,failures[label][0],failures[label][1]])
	print("FUZZ TESTS: %d packets, %d packet types failing" % [checked,failures.size()])
	quit(1 if not failures.is_empty() else 0)
