extends SceneTree
var failures := 0
var checks := 0
func check(ok: bool, title: String) -> void:
	checks += 1
	if ok: print("PASS ",title)
	else:
		failures += 1
		push_error(title)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var memory := preload("res://Network/LoginMemory.gd").new()
	memory.path = "user://regression-login.vault"
	check(memory.save_login("fixture-user","fixture-password"),"Windows encrypted login save")
	var saved := memory.load_login()
	check(saved.get("username") == "fixture-user" and saved.get("password") == "fixture-password","saved login roundtrip")
	var bytes := FileAccess.get_file_as_bytes(memory.path)
	check(bytes.hex_encode().find("fixture-password".to_utf8_buffer().hex_encode()) == -1,"vault does not contain plaintext password")
	check(memory.save_login("new-user","new-password") and memory.load_login().get("username") == "new-user","latest login replaces previous login")
	memory.forget()
	check(not FileAccess.file_exists(memory.path),"forget removes saved login")
	var scene: Node3D = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	check(not scene.controller_enabled,"connected controllers cannot rotate camera unless enabled")
	var initial: float = scene.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100,20)
	scene._input(motion)
	check(is_equal_approx(scene.yaw,initial),"ordinary mouse movement leaves camera stationary")
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	scene._unhandled_input(press)
	scene._input(motion)
	check(is_equal_approx(scene.yaw,initial-0.3),"right drag changes camera using mouse delta")
	press.pressed = false
	scene._input(press)
	var released: float = scene.yaw
	scene._input(motion)
	check(not scene.mouse_looking and is_equal_approx(scene.yaw,released),"release stops look even before GUI routing")
	press.pressed = true
	scene._unhandled_input(press)
	scene._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not scene.mouse_looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE,"focus loss restores mouse")
	await process_frame
	check(is_equal_approx(scene.yaw,released),"idle camera remains stationary")
	scene.queue_free()
	await process_frame
	print("INPUT/MEMORY: ",checks," checks, ",failures," failures")
	quit(failures)
