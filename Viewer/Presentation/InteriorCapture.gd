extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	for child in scene.get_children():
		if child is CanvasLayer: child.visible = false
	scene.camera.reparent(scene)
	scene.camera.global_position = scene.entity_point(1619,1582,0)+Vector3(0,1.65,0)
	scene.camera.look_at(scene.entity_point(1619,1587,0)+Vector3(0,1.8,0))
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var output := OS.get_environment("UO_GRAPHICS_OUTPUT")
	if output.is_empty(): output = ProjectSettings.globalize_path("res://../outputs/validation")
	var result := root.get_texture().get_image().save_png(output.path_join("britain-interior.png"))
	quit(result)
