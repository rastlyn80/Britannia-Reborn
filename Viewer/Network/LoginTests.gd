extends SceneTree

const Protocol = preload("res://Network/LoginProtocol.gd")
var checks := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		push_error("FAIL " + description)
		quit(1)
		return
	checks += 1
	print("PASS ",description)

func _initialize() -> void:
	var seed := Protocol.seed_packet()
	check(seed.size() == 21 and seed[0] == 0xef and seed.slice(1,5) == PackedByteArray([0x12,0x34,0x56,0x78]), "seed framing and big endian")
	var account := Protocol.account_packet("tester", "secret")
	check(account.size() == 62 and account[0] == 0x80 and account[61] == 0xff and account[7] == 0 and account.slice(31,37).get_string_from_ascii() == "secret", "credential field offsets and padding")
	var p := Protocol.new()
	root.add_child(p)
	p.set_process(false)
	p.phase = "login"
	var result := []
	var errors := []
	p.servers_received.connect(func(servers: Array): result.append_array(servers))
	p.failed.connect(func(reason: String): errors.append(reason))
	# Independently assembled server response with nonzero index; split at every byte.
	var packet := PackedByteArray([0xa8,0,46,0x5d,0,1,0,3])
	var name_bytes := "Test shard".to_ascii_buffer()
	name_bytes.resize(32)
	packet.append_array(name_bytes)
	packet.append_array(PackedByteArray([0,0,1,0,0,127]))
	for byte in packet: p.feed(PackedByteArray([byte]))
	check(result.size() == 1 and result[0].index == 3 and result[0].name == "Test shard", "fragmented server list")
	var relay := []
	p.relay_received.connect(func(address: String, port: int, token: int): relay.append([address,port,token]))
	p.phase = "relay"
	p.feed(PackedByteArray([0x8c,127,0,0,1,0x0a,0x21,0x12,0x34,0x56,0x78]))
	check(relay.size() == 1 and relay[0] == ["127.0.0.1",2593,0x12345678], "relay endpoint and auth token")
	p.phase = "login"
	p.feed(PackedByteArray([0xa8,0,6,0x5d,0,1]))
	check(errors.size() == 1 and p.phase == "idle", "reject malformed server list count")
	p.phase = "login"
	p.feed(PackedByteArray([0x82,3]))
	check(errors.size() == 2, "login rejection surfaced")
	p.phase = "login"
	p.feed(PackedByteArray([0x99]))
	check(errors.size() == 3, "unknown login packet fails explicitly")
	p.start("nonASCII-é", "password")
	check(errors.size() == 4, "reject lossy credential encoding")
	print("ALL %d LOGIN CHECKS PASSED" % checks)
	p.queue_free()
	quit(0 if checks == 8 else 1)
