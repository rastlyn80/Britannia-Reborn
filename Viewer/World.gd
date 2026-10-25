extends Node3D

var world: Dictionary
var pivot := Node3D.new()
var camera := Camera3D.new()
var yaw := -0.45
var pitch := -0.75
var distance := 65.0
var ticks := 0
var screenshot := ""
var hide_ui := false
var map_view := false
var status := Label.new()
var static_root := Node3D.new()
var game := preload("res://Network/GameSession.gd").new()
var avatars := {}
var targets := {}
var player_serial := 0
const Motion = preload("res://Presentation/MotionTrack.gd")
const Avatar = preload("res://Presentation/Avatar.gd")
const Reconstruction = preload("res://Presentation/Reconstruction.gd")
var tracks := {}
var directions := {}
var reconstruction := Reconstruction.new()
var diagnostics := Node3D.new()
var collision_builder := preload("res://Presentation/CollisionBuilder.gd").new()
var boom := preload("res://Presentation/CameraBoom.gd").new()
var jump_pressed := false
var jump_requested := false
var camera_target_ready := false
var coverage_path := ""

func point(x: int, y: int, z: int) -> Vector3:
	return Vector3(x - int(world.originX), z * float(world.elevationScale), y - int(world.originY))

func entity_point(x: int, y: int, z: int) -> Vector3:
	# Characters stand at tile centres, consistently with static footprints.
	return point(x,y,z)+Vector3(0.5,0,0.5)

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
		if arg == "--hide-ui": hide_ui = true
		if arg == "--map-view": map_view = true
		if arg.begins_with("--coverage="): coverage_path = arg.substr(11)
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
			var name := str(Reconstruction.info(world,a.id,false).get("name",""))
			if name == "NODRAW": continue
			for t in [a,b,c,b,d,c]:
				surface.set_color(Reconstruction.terrain_color(name))
				surface.set_uv(Vector2(t.x,t.y))
				surface.set_uv2(Vector2(2 if name == "wooden floor" else (1 if name in ["cobblestones","stone","brick"] else 0),0))
				surface.add_vertex(point(t.x,t.y,t.z))
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.mesh = surface.commit()
	var terrain_mat := ShaderMaterial.new()
	terrain_mat.shader = preload("res://Presentation/Ground.gdshader")
	terrain.material_override = terrain_mat
	add_child(terrain)
	add_child(static_root)
	add_child(diagnostics)
	reconstruction.index(world)
	for ordinal in world.statics.size():
		var s: Dictionary = world.statics[ordinal]
		var replacement: Node3D = reconstruction.build(s,world,ordinal)
		if replacement:
			static_root.add_child(replacement)
			collision_builder.add_visual(replacement)
			continue
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.18,0.18,0.18)
		mesh.mesh = box
		mesh.position = point(s.x,s.y,s.z) + Vector3(0.5,0.09,0.5)
		mesh.material_override = material(Color("e7ba70"))
		diagnostics.add_child(mesh)
	print("ART COVERAGE: %d accounted / %d unresolved" % [reconstruction.mapped,reconstruction.unresolved])
	collision_builder.finish(self,terrain)
	if not coverage_path.is_empty(): reconstruction.save_report(coverage_path)
	print("PRESENTATION COLLISION: %d triangles in chunk bodies; %d grouped source components" % [collision_builder.triangles,reconstruction.grouped])
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-25,0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_SKY
	env.environment.sky = Sky.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color("638aa9")
	sky.sky_horizon_color = Color("d5e2dd")
	sky.ground_horizon_color = Color("d5e2dd")
	env.environment.sky.sky_material = sky
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color("b4c7db")
	env.environment.ambient_light_energy = 0.4
	add_child(env)
	add_child(pivot)
	pivot.position = Vector3(float(world.width)/2,0,float(world.height)/2)
	pivot.add_child(boom)
	boom.add_child(camera)
	camera.near = 0.06
	if map_view:
		yaw = 0
		pitch = -PI/2
		distance = 150
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(world.height)
		boom.collision_mask = 0
		boom.visual_distance = distance
	camera.far = 1500
	var canvas := CanvasLayer.new()
	canvas.visible = not hide_ui
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
	game.movement_result.connect(func(accepted: bool, position: Dictionary):
		if not accepted and tracks.has(position.serial):
			tracks[position.serial].reset(entity_point(position.x,position.y,position.z)))
	game.entered.connect(func(position: Dictionary):
		player_serial = position.serial
		_entity_changed(player_serial,position)
		distance = 7
		boom.visual_distance = distance
		boom.spring_length = distance
		pitch = -0.55
		pivot.position = entity_point(position.x,position.y,position.z)+Vector3(0,1.4,0)
		camera_target_ready = true
		status.text = "BRITAIN / TRAMMEL\n%d source pieces accounted for\n\nWASD: move • Shift: run • Space: hop\nDrag: orbit • Wheel: zoom • B: backpack\nServer validates horizontal movement" % reconstruction.mapped
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
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var joy: int = joypads[0]
		var stick := Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
		if stick.length() > 0.2: movement += Vector3(stick.x,0,stick.y)
		var look := Vector2(Input.get_joy_axis(joy,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy,JOY_AXIS_RIGHT_Y))
		if look.length() > 0.2:
			yaw -= look.x*delta*2.0
			pitch = clampf(pitch-look.y*delta*1.5,-1.5,0.9)
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit: movement = Vector3.ZERO
	var jump_down := Input.is_physical_key_pressed(KEY_SPACE)
	if not joypads.is_empty(): jump_down = jump_down or Input.is_joy_button_pressed(joypads[0],JOY_BUTTON_A)
	if jump_down and not jump_pressed and not focus is LineEdit: jump_requested = true
	jump_pressed = jump_down
	if game.phase == "world":
		if movement != Vector3.ZERO:
			var desired := movement.rotated(Vector3.UP,yaw)
			var direction := int(round(atan2(desired.x,-desired.z)*4.0/PI)) & 7
			game.walk(direction,Input.is_physical_key_pressed(KEY_SHIFT) or (not joypads.is_empty() and Input.is_joy_button_pressed(joypads[0],JOY_BUTTON_LEFT_STICK)))
	else: pivot.position += movement * delta * 20
	for serial in avatars:
		var before: Vector3 = avatars[serial].position
		avatars[serial].position = tracks[serial].advance(delta)
		var travelled := before.distance_to(avatars[serial].position)
		avatars[serial].animate(travelled > 0.00001,directions[serial],delta,travelled/maxf(delta,0.00001))
	if game.phase == "world" and avatars.has(player_serial):
		var avatar: Node3D = avatars[player_serial]
		var follow := avatar.position+Vector3(0,1.4+avatar.jump.height*0.25,0)
		pivot.position = pivot.position.lerp(follow,1.0-exp(-18.0*delta)) if camera_target_ready else follow
		camera_target_ready = true
		avatar.visual_root.visible = boom.get_hit_length() > 1.15
		avatar.get_node("Nameplate").visible = avatar.visual_root.visible
	pivot.rotation = Vector3(pitch,yaw,0)
	boom.collision_mask = 1 if game.phase == "world" and not map_view else 0
	boom.set_distance(distance,delta)
	ticks += 1
	if ticks == 15 and screenshot != "":
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(screenshot)
		print("SCREENSHOT ",error," ",screenshot)
		get_tree().quit(error)

func _physics_process(delta: float) -> void:
	if game.phase != "world" or not avatars.has(player_serial):
		jump_requested = false
		return
	var avatar: Node3D = avatars[player_serial]
	var clearance := boom.headroom(get_world_3d().direct_space_state,avatar.position)
	if jump_requested:
		avatar.jump.start(clearance)
		jump_requested = false
	avatar.jump.advance(delta,clearance)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)):
		yaw -= event.relative.x * 0.005
		pitch = clampf(pitch-event.relative.y*0.005,-1.5,0.9)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.2,distance-(0.8 if game.phase == "world" else 4))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(22 if game.phase == "world" else 250,distance+(0.8 if game.phase == "world" else 4))
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_B: game.open_backpack()
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_TAB: diagnostics.visible = not diagnostics.visible
		if event.keycode == KEY_R:
			yaw = -0.45
			pitch = -0.55 if game.phase == "world" else -0.75
			distance = 7 if game.phase == "world" else 65
			pivot.position = Vector3(float(world.width)/2,0,float(world.height)/2)

func _entity_changed(serial: int,position: Dictionary) -> void:
	if position.facet != 1: return
	var location := entity_point(position.x,position.y,position.z)
	if not avatars.has(serial):
		var avatar := Avatar.new()
		var label := Label3D.new()
		label.name = "Nameplate"
		label.text = "You" if serial == game.player.serial else "Player %d" % serial
		label.position.y = 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 32
		avatar.add_child(label)
		avatar.position = location
		add_child(avatar)
		avatars[serial] = avatar
		tracks[serial] = Motion.new()
		tracks[serial].reset(location)
	# Imported humanoid faces +Z; UO direction 0 faces north (-Z).
	directions[serial] = PI-int(position.direction)*PI/4
	if tracks[serial].position.distance_to(location) > 8.0: avatars[serial].jump.reset()
	tracks[serial].push(location,float(game.move_interval)/1000.0 if serial == player_serial else (0.21 if position.get("running",false) else 0.41))
	targets[serial] = location

func _entity_removed(serial: int) -> void:
	if avatars.has(serial):
		avatars[serial].queue_free()
		avatars.erase(serial)
		targets.erase(serial)
		tracks.erase(serial)
		directions.erase(serial)
