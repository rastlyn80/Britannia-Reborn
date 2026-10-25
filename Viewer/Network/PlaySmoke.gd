extends SceneTree
const Session = preload("res://Network/GameSession.gd")
var client: Node
var start := 0
var spawned := false
var acknowledged := false
var exact_position := false
var interaction := false
var attempted := 0
var rejected := false
var origin := Vector2i.ZERO
var direction := 6 # west towards a source-data wall near the Britain starting corridor
var recovered := false

func _initialize() -> void:
	start = Time.get_ticks_msec()
	client = Session.new()
	root.add_child(client)
	client.failed.connect(func(reason: String):
		push_error(reason)
		print("PACKETS ",client.packet_counts)
		quit(1))
	client.characters_received.connect(func(characters: Array, cities: Array):
		print("PLAY PASS: character list ",characters)
		for character in characters:
			if not character.name.is_empty():
				client.select_character(character.slot,character.name)
				return
		for city in cities:
			if city.name == "Britain":
				print("Creating test character in Britain")
				client.create_character("Britain Explorer",0,city.index)
				return
		push_error("Britain starting city missing")
		quit(1))
	client.entered.connect(func(position: Dictionary):
		spawned = true
		origin = Vector2i(position.x,position.y)
		print("PLAY PASS: entered world ",position," backpack ",client.backpack)
		client.open_backpack())
	client.movement_result.connect(func(accepted: bool, position: Dictionary):
		acknowledged = acknowledged or accepted
		if not accepted:
			direction = (direction+1)%8
			rejected = true
		elif rejected: recovered = true
		print("PLAY MOVE ",accepted," ",position))
	client.entity_changed.connect(func(serial: int,position: Dictionary):
		if spawned and serial == client.player.serial and acknowledged and Vector2i(position.x,position.y) != origin:
			exact_position = true
			print("PLAY PASS: exact server position after ACK ",position))
	client.interaction_confirmed.connect(func(description: String):
		interaction = true
		print("PLAY PASS: ",description))
	client.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))

func _process(_delta: float) -> bool:
	if spawned and Time.get_ticks_msec()-start > 1500 and attempted < 16 and client.outstanding == -1 and not client.awaiting_position:
		if client.walk(direction): attempted += 1
	if spawned and acknowledged and exact_position and interaction and rejected and recovered:
		print("PLAY SMOKE PASSED: real spawn, blocked movement rejection, recovery ACK, changed exact position, backpack")
		client.close()
		quit(0)
	if Time.get_ticks_msec()-start > 25000:
		push_error("Play smoke timed out")
		print("phase ",client.phase," packets ",client.packet_counts," backpack ",client.backpack)
		client.close()
		quit(1)
	return false
