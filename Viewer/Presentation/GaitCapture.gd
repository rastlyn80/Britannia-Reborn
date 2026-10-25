extends SceneTree
func _initialize() -> void: call_deferred("capture")
func capture() -> void:
	var stage := Node3D.new()
	root.add_child(stage)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50,-30,0)
	light.light_energy = 1.0
	light.shadow_enabled = true
	stage.add_child(light)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("24333d")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("d6dfeb")
	env.environment.ambient_light_energy = 0.5
	stage.add_child(env)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(18,12)
	plane.mesh = mesh
	plane.position = Vector3(4.5,-0.01,2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("697575")
	plane.material_override = mat
	stage.add_child(plane)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12
	stage.add_child(camera)
	camera.look_at_from_position(Vector3(4.5,8.0,15),Vector3(4.5,0.8,2))
	for row in 2:
		for column in 4:
			var avatar := preload("res://Presentation/Avatar.gd").new()
			stage.add_child(avatar)
			avatar.position = Vector3(column*3,0,row*4)
			avatar.rotation.y = -0.55
			var clip := "Walk" if row == 0 else "Jog_Fwd"
			avatar.animator.play(clip,0)
			avatar.animator.advance(0)
			avatar.animator.seek(avatar.animator.get_animation(clip).length*column/4.0,true)
			avatar.animator.pause()
			var label := Label3D.new()
			label.text = "%s · %d%%" % [clip,column*25]
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = avatar.position+Vector3(0,2.4,0)
			label.font_size = 42
			stage.add_child(label)
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://../outputs/validation/gait-contact-sheet.png"
	var error := root.get_texture().get_image().save_png(ProjectSettings.globalize_path(output))
	print("GAIT CAPTURE: ",error)
	quit(error)
