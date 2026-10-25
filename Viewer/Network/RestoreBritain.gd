extends SceneTree
const Session = preload("res://Network/GameSession.gd")
var client: Node
var start := 0

func _initialize() -> void:
	start = Time.get_ticks_msec()
	client = Session.new()
	root.add_child(client)
	client.failed.connect(func(reason: String):
		push_error(reason)
		quit(1))
	client.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				client.select_character(character.slot,character.name)
				return)
	client.entered.connect(func(position: Dictionary):
		print("Restoring test character to Britain preview by ordinary server-validated walking: ",position)
		if position.x != 1602:
			push_error("Recovery only supports the tested north/south corridor")
			quit(1))
	client.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))

func _process(_delta: float) -> bool:
	if client.phase == "world":
		if client.player.y == 1589 and not client.awaiting_position:
			print("RESTORE PASS: ",client.player)
			client.close()
			quit(0)
		else: client.walk(4 if client.player.y < 1589 else 0)
	if Time.get_ticks_msec()-start > 60000:
		push_error("Recovery timed out")
		client.close()
		quit(1)
	return false
