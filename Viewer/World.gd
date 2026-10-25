extends Node3D

var world: Dictionary
var pivot := Node3D.new()
var camera := Camera3D.new()
var yaw := -0.45
var pitch := -0.75
var distance := 65.0
var ticks := 0
var screenshot := ""
var status := Label.new()
var static_root := Node3D.new()
var game := preload("res://Network/GameSession.gd").new()
var avatars := {}
var targets := {}
var player_serial := 0

func point(x: int, y: int, z: int) -> Vector3:
	return Vector3(x - int(world.originX), z * float(world.elevationScale), y - int(world.originY))

func material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m

func _ready() -> void:
	var path := "res://world.json"
	if FileAccess.file_exists("res://play-world.json"): path = "res://play-world.json"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--world="): path = arg.substr(8)
		if arg.begins_with("--screenshot="): screenshot = arg.substr(13)
		if arg == "--close-view":
			distance = 40
			yaw = 0.5
			pitch = -0.4
	if not FileAccess.file_exists(path):
		push_error("Missing world.json. Run build.ps1 first.")
		get_tree().quit(1)
		return
	world = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert(int(world.schema) == 1)
	assert(point(int(world.originX)+3,int(world.originY)+7,-5).is_equal_approx(Vector3(3,-1,7)))
	var samples := {}
	for t in world.terrain: samples[Vector2i(t.x,t.y)] = t
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for y in range(int(world.originY), int(world.originY)+int(world.height)-1):
		for x in range(int(world.originX), int(world.originX)+int(world.width)-1):
			var a: Dictionary = samples[Vector2i(x,y)]
			var b: Dictionary = samples[Vector2i(x+1,y)]
			var c: Dictionary = samples[Vector2i(x,y+1)]
			var d: Dictionary = samples[Vector2i(x+1,y+1)]
			# ID colors are diagnostic, not a UO texture or terrain classification.
			var colors := [Color("668e6b"),Color("b6a580"),Color("5089ad")]
			for t in [a,b,c,b,d,c]:
				surface.set_color(colors[int(a.id)%3])
				surface.add_vertex(point(t.x,t.y,t.z))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	var terrain_mat := material(Color.WHITE)
	terrain_mat.vertex_color_use_as_albedo = true
	terrain_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	terrain.material_override = terrain_mat
	add_child(terrain)
	add_child(static_root)
	for s in world.statics:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.7,1.6,0.7)
		mesh.mesh = box
		mesh.position = point(s.x,s.y,s.z) + Vector3(0,0.8,0)
		mesh.material_override = material(Color("e7ba70"))
		static_root.add_child(mesh)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 1.3
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b4c7db")
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	add_child(pivot)
	pivot.position = Vector3(float(world.width)/2,0,float(world.height)/2)
	pivot.add_child(camera)
	camera.far = 1500
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var panel := PanelContainer.new()
	panel.position = Vector2(24,24)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035,0.055,0.08,0.94)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel",style)
	canvas.add_child(panel)
	var login_panel := preload("res://Network/LoginPanel.gd").new()
	add_child(game)
	login_panel.session = game
	canvas.add_child(login_panel)
	game.entity_changed.connect(_entity_changed)
	game.entity_removed.connect(_entity_removed)
	game.entered.connect(func(position: Dictionary):
		player_serial = position.serial
		_entity_changed(player_serial,position)
		distance = 9
		pitch = -0.55
		pivot.position = point(position.x,position.y,position.z)+Vector3(0,1.4,0)
		status.text = "BRITAIN / CONNECTED TO MODERNUO\n%s\nSource crop x %d–%d / y %d–%d\n\nWASD: walk • Drag: orbit • Wheel: zoom\nB: backpack • Tab: static proxies • Esc: quit\nBlue: you • Purple: nearby players\nMovement and interactions validated by server" % [world.provenance,world.originX,int(world.originX)+int(world.width)-1,world.originY,int(world.originY)+int(world.height)-1]
		if position.facet != 1 or position.x < int(world.originX) or position.x >= int(world.originX)+int(world.width) or position.y < int(world.originY) or position.y >= int(world.originY)+int(world.height):
			status.text = "Character is outside the converted Trammel crop.\nNo geography is invented beyond the crop.")
	game.ended.connect(func():
		for serial in avatars.keys(): _entity_removed(serial)
		player_serial = 0)
	status.add_theme_font_size_override("font_size",18)
	status.text = "UO WORLD STUDIO / BRITAIN\n%s\nTrammel • x %d–%d / y %d–%d\n%d samples • %d static proxies\n\nDrag: orbit    Wheel: zoom    WASD: pan\nTab: toggle statics    R: reset    Esc: quit\nEast +X / South +Z / UO elevation × 0.2 → +Y" % [world.provenance,world.originX,int(world.originX)+int(world.width)-1,world.originY,int(world.originY)+int(world.height)-1,world.terrain.size(),world.statics.size()]
	panel.add_child(status)
	print("VIEWER PASS: schema, coordinate transform, %d terrain samples, %d statics" % [world.terrain.size(),world.statics.size()])

func _process(delta: float) -> void:
	var movement := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): movement.z -= 1
	if Input.is_physical_key_pressed(KEY_S): movement.z += 1
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit: movement = Vector3.ZERO
	if game.phase == "world":
		if movement != Vector3.ZERO:
			var desired := movement.rotated(Vector3.UP,yaw)
			var direction := int(round(atan2(desired.x,-desired.z)*4.0/PI)) & 7
			game.walk(direction)
		if avatars.has(player_serial): pivot.position = avatars[player_serial].position+Vector3(0,1.4,0)
	else: pivot.position += movement * delta * 20
	for serial in avatars:
		avatars[serial].position = avatars[serial].position.lerp(targets[serial],minf(1.0,delta*12))
	pivot.rotation = Vector3(pitch,yaw,0)
	camera.position = Vector3(0,0,distance)
	ticks += 1
	if ticks == 15 and screenshot != "":
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(screenshot)
		print("SCREENSHOT ",error," ",screenshot)
		get_tree().quit(error)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch-event.relative.y*0.005,-1.45,-0.1)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(5,distance-4)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(250,distance+4)
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B: game.open_backpack()
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_TAB: static_root.visible = not static_root.visible
		if event.keycode == KEY_R:
			yaw = -0.45
			pitch = -0.55 if game.phase == "world" else -0.75
			distance = 9 if game.phase == "world" else 65
			pivot.position = Vector3(float(world.width)/2,0,float(world.height)/2)

func _entity_changed(serial: int,position: Dictionary) -> void:
	if position.facet != 1: return
	var location := point(position.x,position.y,position.z)
	if not avatars.has(serial):
		var avatar := Node3D.new()
		var body := MeshInstance3D.new()
		var capsule := CapsuleMesh.new()
		capsule.radius = 0.3
		capsule.height = 1.8
		body.mesh = capsule
		body.position.y = 0.9
		body.material_override = material(Color("74d6ff") if serial == game.player.serial else Color("cf83ff"))
		avatar.add_child(body)
		var label := Label3D.new()
		label.text = "You" if serial == game.player.serial else "Player %d" % serial
		label.position.y = 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 32
		avatar.add_child(label)
		avatar.position = location
		add_child(avatar)
		avatars[serial] = avatar
	avatars[serial].rotation.y = -int(position.direction)*PI/4
	targets[serial] = location

func _entity_removed(serial: int) -> void:
	if avatars.has(serial):
		avatars[serial].queue_free()
		avatars.erase(serial)
		targets.erase(serial)
