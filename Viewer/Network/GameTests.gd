extends SceneTree
const Huffman = preload("res://Network/HuffmanStream.gd")
const Game = preload("res://Network/GameSession.gd")
const Login = preload("res://Network/LoginProtocol.gd")
var checks := 0
var failures := 0

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL "+description)
	else: print("PASS ",description)

func _initialize() -> void:
	var decoder := Huffman.new()
	check(decoder.decode(PackedByteArray([0xd0])).is_empty(),"Huffman terminal padding")
	check(decoder.decode(PackedByteArray([0x34])) == PackedByteArray([0]),"independent Huffman zero vector")
	check(decoder.decode(PackedByteArray([0xfe])) == PackedByteArray([1]) and decoder.decode(PackedByteArray([0x80])).is_empty(),"Huffman split symbol/terminal state")
	check(decoder.decode(PackedByteArray([0x34,0xfe,0x80])) == PackedByteArray([0,1]),"coalesced compressed packets")
	check(Game.signed(255) == -1 and Game.signed(65516,16) == -20,"signed world elevations")
	var handshake := Game.game_handshake("tester","password",0x89abcdef)
	check(handshake.size() == 69 and handshake[4] == 0x91 and Login.read_be(handshake,0,4) == Login.read_be(handshake,5,4),"batched game seed and authentication token")
	var creation := Game.creation_packet("Test Player",3,1)
	check(creation.size() == 106 and creation[0] == 0xf8,"modern character creation length")
	check(Game.text(creation,10,30) == "Test Player" and creation[70] == 2 and creation[71]+creation[72]+creation[73] == 90,"creation name, human race and stats")
	check(Login.read_be(creation,92,2) == 1 and Login.read_be(creation,94,4) == 3,"creation city and slot offsets")
	check(Game.packet_length(0xf3) == 26 and Game.packet_length(0x24) == 9 and Game.packet_length(0xb9) == 5,"version-specific packet sizes")
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	var positions := []
	var failures_seen := []
	game.entity_changed.connect(func(_serial: int,position: Dictionary): positions.append(position))
	game.failed.connect(func(reason: String): failures_seen.append(reason))
	var confirmation := PackedByteArray([0x1b,0,0,0,7,0,0,0,0,1,0x90,6,0x42,6,0x37,0xff,0xec,2])
	confirmation.resize(37)
	for byte in confirmation: game.feed(PackedByteArray([byte]))
	check(game.player.serial == 7 and game.player.x == 1602 and game.player.y == 1591 and game.player.z == -20,"fragmented spawn packet coordinate offsets")
	game.awaiting_position = true
	game.sequence = 8
	var update := PackedByteArray([0x20,0,0,0,7,1,0x90,0,0,0,0,6,0x43,6,0x38,0,0,3,0xfb])
	game.feed(update)
	check(game.player.x == 1603 and game.player.z == -5 and not game.awaiting_position and game.sequence == 0,"authoritative resync and sequence reset")
	# Death, a teleport or the young ghost's move to a healer: the server resets
	# its movement and never answers a step still in flight. That step must not
	# time out into a disconnect.
	game.outstanding = 11
	game.sequence = 12
	game.movement_deadline = Time.get_ticks_msec()-1
	game.feed(PackedByteArray([0x20,0,0,0,7,1,0x92,0,0,0,0,6,0x43,6,0x38,0,0,3,0xfb]))
	check(game.outstanding == -1 and not game.awaiting_position and game.sequence == 0 and game.player.body == 0x192,"a server player update (death, teleport) resets the walker: no step is left waiting to time out into a disconnect")
	game.feed(PackedByteArray([0x21,0,6,0x42,6,0x37,2,0xff]))
	check(game.player.x == 1602 and game.player.z == -1 and game.outstanding == -1,"rejected movement correction")
	game.feed(PackedByteArray([0x77,0,0,0,9,1,0x90,6,0x44,6,0x39,20,4,0,0,0,1]))
	check(game.entities[9].x == 1604 and game.entities[9].y == 1593,"remote movement replication")
	game.feed(PackedByteArray([0x1d,0,0,0,9]))
	check(not game.entities.has(9),"remote entity removal")
	# Your own pets come from our server (PetReport: ModernUO's ControlMaster),
	# never from the status rename flag, which staff have for every creature.
	var changes := []
	game.pets_changed.connect(func(serial: int): changes.append(serial))
	game._server_text("UCPET1|8193,8194",true)
	check(game.owned_pets.has(8193) and game.owned_pets.has(8194) and changes.size() == 2,"the creatures our server reports as yours are your pets")
	var wild := PackedByteArray([0x11,0,43])
	wild.append_array(Login.uint_be(8195,4))
	var wild_name := "a giant serpent".to_ascii_buffer()
	wild_name.resize(30)
	wild.append_array(wild_name)
	wild.append_array(PackedByteArray([0,100,0,100,1,0]))
	game.feed(wild)
	check(not game.owned_pets.has(8195),"a wild creature a staff character may rename is not shown as a pet")
	game._server_text("UCPET1|8194",true)
	check(not game.owned_pets.has(8193) and game.owned_pets.has(8194) and changes.size() == 3,"a released pet stops being shown as yours")
	game.feed(PackedByteArray([0xa9,0,2]))
	check(failures_seen.size() == 1,"malformed variable framing rejection")
	game.queue_free()
	print("GAME CHECKS: %d passed / %d total" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
