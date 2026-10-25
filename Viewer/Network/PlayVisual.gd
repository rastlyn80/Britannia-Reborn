extends SceneTree
const Session = preload("res://Network/GameSession.gd")
var scene: Node
var other: Node
var start := 0
var original := Vector2i.ZERO
var primary_ready := false
var other_ready := false
var moved := false
var opened := false
var held := false
var captured := false

func attach(client: Node, second: bool) -> void:
	client.failed.connect(func(reason: String):
		push_error(reason)
		quit(1))
	client.characters_received.connect(func(characters: Array,cities: Array):
		for character in characters:
			if not character.name.is_empty():
				client.select_character(character.slot,character.name)
				return
		for city in cities:
			if city.name == "Britain": client.create_character("Britain Companion" if second else "Britain Explorer",0,city.index))
	client.entered.connect(func(position: Dictionary):
		if second: other_ready = true
		else:
			primary_ready = true
			original = Vector2i(position.x,position.y)
			client.open_backpack())
	client.interaction_confirmed.connect(func(_description: String): opened = true)
	client.entity_changed.connect(func(serial: int,position: Dictionary):
		if not second and primary_ready and serial == client.player.serial and Vector2i(position.x,position.y) != original: moved = true)
	var user := OS.get_environment("UO_DEV_USER")
	client.connect_account(user+"2" if second else user,OS.get_environment("UO_DEV_PASSWORD"))

func _initialize() -> void:
	start = Time.get_ticks_msec()
	scene = load("res://Main.tscn").instantiate()
	root.add_child.call_deferred(scene)
	await process_frame
	attach(scene.game,false)
	other = Session.new()
	root.add_child(other)
	attach(other,true)

func _process(_delta: float) -> bool:
	if primary_ready and other_ready and not held:
		held = true
		# Exercise the actual world's keyboard controller, not a mock avatar.
		scene.yaw = 0
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.pressed = true
		Input.parse_input_event(event)
	if moved and opened and scene.avatars.size() >= 2 and not captured:
		captured = true
		var event := InputEventKey.new()
		event.physical_keycode = KEY_W
		event.pressed = false
		Input.parse_input_event(event)
		capture()
	if Time.get_ticks_msec()-start > 35000:
		push_error("Visual play test timed out")
		quit(1)
	return false

func capture() -> void:
	# Allow the presentation interpolation to reach the server-authorised target.
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("UO_PLAY_SCREENSHOT")
	var error := root.get_texture().get_image().save_png(path)
	print("VISUAL PLAY PASS: real scene, keyboard movement, two avatars, backpack, screenshot ",error)
	scene.game.close()
	other.close()
	quit(error)
