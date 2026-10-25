extends SceneTree
var scene: Node3D
var started := 0
var phase := "connecting"
var phase_time := 0.0
var origin := Vector2i.ZERO
var accepted := 0
var jump_peak := 0.0
var obstruction_verified := false
var camera_image := false
var apex_image := false
var target_y := 1589
var movement_key := KEY_S

func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)

func snapshot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var directory := OS.get_environment("UO_GRAPHICS_OUTPUT")
	var error := root.get_texture().get_image().save_png(directory.path_join(name))
	if error != OK:
		push_error("Screenshot failed")
		quit(1)

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	started = Time.get_ticks_msec()
	scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.game.failed.connect(func(reason: String):
		push_error(reason)
		quit(1))
	scene.game.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				scene.game.select_character(character.slot,character.name)
				return
		push_error("Create the normal Britain test character first")
		quit(1))
	scene.game.entered.connect(func(position: Dictionary):
		origin = Vector2i(position.x,position.y)
		target_y = 1594 if absi(origin.y-1589) < 2 else 1589
		movement_key = KEY_S if origin.y < target_y else KEY_W
		print("LIVE START ",position," target corridor y ",target_y)
		phase = "running"
		scene.yaw = 0
		key(KEY_SHIFT,true)
		key(movement_key,true))
	scene.game.movement_result.connect(func(ok: bool,_position: Dictionary):
		if ok: accepted += 1)
	scene.game.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))

func _process(delta: float) -> bool:
	if not is_instance_valid(scene): return false
	phase_time += delta
	if Time.get_ticks_msec()-started > 30000:
		push_error("Graphics integration timed out in phase "+phase)
		quit(1)
	if phase == "running":
		var current := Vector2i(scene.game.player.x,scene.game.player.y)
		if current.y == target_y and current.distance_to(origin) >= 2 and accepted >= 2:
			key(movement_key,false)
			key(KEY_SHIFT,false)
			phase = "settling"
			phase_time = 0
	elif phase == "settling" and phase_time > 0.6:
		phase = "camera"
		phase_time = 0
		scene.yaw = -PI/2
		scene.pitch = -0.15
		scene.distance = 7
	elif phase == "camera" and phase_time > 0.4:
		obstruction_verified = scene.boom.get_hit_length() < 2.0
		print("LIVE CAMERA: obstruction distance ",scene.boom.get_hit_length())
		if not obstruction_verified:
			push_error("Expected the Britain corridor wall to retract the real camera")
			quit(1)
		if not camera_image:
			camera_image = true
			snapshot("camera-wall.png")
		scene.yaw = 0.3
		scene.pitch = -0.45
		phase = "jump-wait"
		phase_time = 0
	elif phase == "jump-wait" and phase_time > 0.5:
		key(KEY_SPACE,true)
		phase = "jump"
		phase_time = 0
	elif phase == "jump":
		key(KEY_SPACE,false)
		var avatar: Node3D = scene.avatars[scene.player_serial]
		jump_peak = maxf(jump_peak,avatar.jump.height)
		if avatar.jump.height > 0.7 and not apex_image:
			apex_image = true
			snapshot("jump-apex.png")
		if phase_time > 1.2:
			if not apex_image or avatar.jump.airborne or avatar.jump.height != 0:
				push_error("Real viewer jump did not complete, peak "+str(jump_peak))
				quit(1)
			else:
				print("GRAPHICS LIVE PASS: accepted server run, real corridor camera obstruction, keyboard jump/apex/landing; peak ",jump_peak)
				scene.game.close()
				quit()
	return false
