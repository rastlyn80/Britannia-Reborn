extends SceneTree
var scene: Node3D
var phase := "login"
var started := 0
var elapsed := 0.0
var origin := {}
var expected := {}
var direction := 6
var steps := 0
var predicted := 0
var warmup := 0.0
var first_visual_ms := -1
var request_time := 0
var origin_render := Vector3.ZERO
var last_sync := 0
var observer: Node
var observer_ready := false
var observed := false

func _initialize() -> void: call_deferred("start")
func start() -> void:
	started = Time.get_ticks_msec()
	scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.accept_player_input = false
	scene.game.failed.connect(func(reason: String): fail(reason))
	scene.game.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				scene.game.select_character(character.slot,character.name)
				return
		fail("No test character"))
	scene.game.entered.connect(func(position: Dictionary):
		origin = position.duplicate()
		for candidate in [6,0,2,4]:
			var at := position.duplicate()
			var valid := true
			for i in 3:
				at = scene.movement_surface.predict(at,candidate)
				if at.is_empty():
					valid = false
					break
			if valid:
				direction = candidate
				expected = at
				phase = "warmup"
				return
		fail("Current position "+str(position)+" has no conservative three-step test route; no movement issued"))
	scene.game.movement_started.connect(func(_position: Dictionary,_seconds: float):
		predicted += 1
		if scene.game.outstanding == -1 or scene.tracks[scene.player_serial].queue.is_empty(): fail("Render prediction did not start before ACK")
		if request_time == 0:
			request_time = Time.get_ticks_msec()
			origin_render = scene.avatars[scene.player_serial].position)
	scene.game.movement_result.connect(func(accepted: bool,position: Dictionary):
		if not accepted:
			fail("Server rejected conservative route; stopped without retrying")
			return
		if phase in ["out","back"] and not scene.game.turn_only:
			steps += 1
			if steps == 3:
				phase = "verify-out" if phase == "out" else "verify-back"
				elapsed = 0
				last_sync = int(scene.game.packet_counts.get(0x20,0)))
	observer = preload("res://Network/GameSession.gd").new()
	root.add_child(observer)
	observer.failed.connect(func(reason: String): fail("Observer: "+reason))
	observer.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				observer.select_character(character.slot,character.name)
				return
		fail("No existing observer character"))
	observer.entered.connect(func(_position: Dictionary): observer_ready = true)
	observer.entity_changed.connect(func(serial: int,position: Dictionary):
		if not origin.is_empty() and serial == scene.game.player.serial and (position.x != origin.x or position.y != origin.y): observed = true)
	observer.connect_account(OS.get_environment("UO_DEV_USER")+"2",OS.get_environment("UO_DEV_PASSWORD"))
	scene.game.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))

func fail(reason: String) -> void:
	push_error(reason)
	phase = "failed"
	if scene: scene.game.close()
	if is_instance_valid(observer): observer.close()
	quit(1)

func _process(delta: float) -> bool:
	if not scene or phase in ["login","failed"]: return false
	if Time.get_ticks_msec()-started > 30000:
		fail("Movement validation timed out in "+phase)
		return false
	elapsed += delta
	if request_time > 0 and first_visual_ms == -1 and scene.avatars[scene.player_serial].position.distance_to(origin_render) > 0.005:
		first_visual_ms = Time.get_ticks_msec()-request_time
	if phase == "warmup" and elapsed > 0.8 and observer_ready:
		phase = "out"
		elapsed = 0
	if phase in ["out","back"]:
		var travel_direction := direction if phase == "out" else (direction+4)&7
		scene.intent_facing = PI-travel_direction*PI/4
		scene.game.walk(travel_direction,phase == "back")
	elif phase in ["verify-out","verify-back"] and elapsed > 0.8:
		if int(scene.game.packet_counts.get(0x20,0)) <= last_sync:
			fail("Idle elevation reconciliation not received")
			return false
		var target: Dictionary = expected if phase == "verify-out" else origin
		var position: Dictionary = scene.game.player
		if position.x != target.x or position.y != target.y or position.z != target.z:
			fail("Prediction disagreed with authoritative XYZ: "+str(position))
			return false
		if phase == "verify-out":
			print("LIVE WALK PASS: three predicted endpoints match authoritative XYZ; first visible motion ",first_visual_ms," ms")
			phase = "back"
			steps = 0
			elapsed = 0
		else:
			if predicted != 6 or first_visual_ms < 0 or first_visual_ms > 150 or not observed:
				fail("Prediction responsiveness/count failed: "+str(first_visual_ms)+" ms, "+str(predicted)+" starts")
				return false
			print("LIVE LOCOMOTION PASS: six predictions before ACK, walk/run, second client observed movement, exact XYZ after idle sync, returned to original position")
			phase = "capture"
			capture()
	return false

func capture() -> void:
	scene.yaw = -0.4
	scene.pitch = -0.22
	scene.distance = 5.0
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	var path := OS.get_environment("UO_GRAPHICS_OUTPUT").path_join("street-locomotion.png")
	var error := root.get_texture().get_image().save_png(path)
	scene.game.close()
	observer.close()
	quit(error)

