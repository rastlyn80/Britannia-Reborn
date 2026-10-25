extends SceneTree
const Session = preload("res://Network/GameSession.gd")
var clients := []
var ready_clients := [false,false]
var start := 0
var initial := Vector2i.ZERO
var observed := false
var opened := false
var saw_rejection := false
var move_time := 0
var direction := 0

func _initialize() -> void:
	start = Time.get_ticks_msec()
	for index in 2:
		var client := Session.new()
		clients.append(client)
		root.add_child(client)
		client.failed.connect(func(reason: String):
			push_error("Client %d: %s" % [index,reason])
			print("PACKET COUNTS ",client.packet_counts)
			quit(1))
		client.characters_received.connect(func(characters: Array,cities: Array):
			for character in characters:
				if not character.name.is_empty():
					client.select_character(character.slot,character.name)
					return
			for city in cities:
				if city.name == "Britain":
					client.create_character("Britain Companion",0,city.index)
					return)
		client.entered.connect(func(position: Dictionary):
			ready_clients[index] = true
			print("MULTIPLAYER: client ",index," entered ",position)
			if index == 0:
				initial = Vector2i(position.x,position.y)
				client.open_backpack())
		client.interaction_confirmed.connect(func(_description: String): opened = true)
		client.movement_result.connect(func(accepted: bool,_position: Dictionary):
			if not accepted:
				saw_rejection = true
				direction = (direction+1)%8
				print("MULTIPLAYER PASS: server rejection corrected client"))
		client.entity_changed.connect(func(serial: int,position: Dictionary):
			if index == 1 and ready_clients[0] and serial == clients[0].player.serial and Vector2i(position.x,position.y) != initial:
				observed = true
				print("MULTIPLAYER PASS: second client observed primary move ",position))
		var user := OS.get_environment("UO_DEV_USER")
		if index == 1: user += "2"
		client.connect_account(user,OS.get_environment("UO_DEV_PASSWORD"))

func _process(_delta: float) -> bool:
	if ready_clients[0] and ready_clients[1] and Time.get_ticks_msec() > move_time:
		move_time = Time.get_ticks_msec()+550
		clients[0].walk(direction)
	if observed and opened:
		print("MULTIPLAYER SMOKE PASSED: two real characters, replicated movement, server backpack interaction")
		for client in clients: client.close()
		quit(0)
	if Time.get_ticks_msec()-start > 35000:
		push_error("Multiplayer test timed out: observed=%s opened=%s" % [observed,opened])
		for client in clients: client.close()
		quit(1)
	return false
