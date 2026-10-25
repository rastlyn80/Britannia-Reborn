extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var avatar := preload("res://Presentation/Avatar.gd").new()
	stage.add_child(avatar)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35,-30,0)
	sun.light_energy = 1.2
	stage.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b4c7db")
	environment.environment.ambient_light_energy = 0.7
	stage.add_child(environment)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(2,1.7,3)
	camera.look_at(Vector3(0,0.95,0))
	var label := Label.new()
	label.text = "QUATERNIUS / CHARACTER PREVIEW\nUniversal Base + Fantasy Peasant + Universal Animation Library\nFixed preview appearance; equipment mapping comes later"
	label.position = Vector2(24,24)
	stage.add_child(label)
	for i in 20: await process_frame
	avatar.animator.advance(0.1)
	await RenderingServer.frame_post_draw
	var path := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): path = arg.substr(13)
	if path.is_empty():
		push_error("Supply --screenshot=PATH")
		quit(1)
		return
	quit(root.get_texture().get_image().save_png(path))
