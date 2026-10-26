extends Node3D

var world_ready := false
var city_stream: Node3D
var minimap: Control
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
var world_items := preload("res://Presentation/WorldItems.gd").new()
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
var mouse_looking := false
var mouse_return := Vector2.ZERO
var controller_enabled := false
var intent_facing := 0.0
var has_move_intent := false
var accept_player_input := true
var shoreline := preload("res://Presentation/ShorelinePlan.gd").new()
var terrain_surface := preload("res://Presentation/TerrainSurface.gd").new()
var interior_shell := preload("res://Presentation/InteriorShell.gd").new()
var movement_surface := preload("res://Presentation/MovementSurface.gd").new()

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
	get_viewport().use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"
	var city_mode := "--city" in OS.get_cmdline_user_args()
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
	if city_mode:
		var loading := Label.new()
		loading.text = "Loading nearby prepared districts…"
		loading.position = Vector2(32,32)
		add_child(loading)
		await get_tree().process_frame
		city_stream = preload("res://Presentation/LiveDistricts.gd").new()
		add_child(static_root)
		add_child(diagnostics)
		static_root.add_child(city_stream)
		if not await city_stream.prepare(self):
			get_tree().quit(1)
			return
		loading.queue_free()
		world = city_stream.world
		reconstruction = city_stream.reconstruction
		interior_shell = city_stream.shell
		movement_surface = city_stream.surface
		game.surface = movement_surface
		game.preview_bounds = Rect2i(world.originX,world.originY,world.width,world.height)
		game.destination_ready = city_stream.destination_ready
	else:
		movement_surface.index(world)
		game.surface = movement_surface
		game.preview_bounds = Rect2i(int(world.originX),int(world.originY),int(world.width)-1,int(world.height)-1)
		preload("res://Presentation/SurfaceLibrary.gd").source_origin = Vector2(world.originX,world.originY)
		shoreline.index(world,reconstruction.catalog)
		terrain_surface.index(world,shoreline)
		var terrain := MeshInstance3D.new()
		terrain.name = "BlendedTerrain"
		terrain.mesh = terrain_surface.build()
		var terrain_mat := ShaderMaterial.new()
		terrain_mat.shader = preload("res://Presentation/Ground.gdshader")
		terrain_mat.set_shader_parameter("stone_detail",load("res://Art/Quaternius/Village/T_Brick_BaseColor.png"))
		terrain_mat.set_shader_parameter("stone_normal",load("res://Art/Quaternius/Village/T_Brick_Normal.png"))
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"paving","cobblestone_floor_03")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"ground","forest_ground_04")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"rock","rock_face_03")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"wood","brown_planks_03")
		shoreline.apply(terrain_mat)
		terrain.material_override = terrain_mat
		add_child(terrain)
		add_child(static_root)
		add_child(diagnostics)
		reconstruction.shoreline = shoreline
		reconstruction.show_boundary_fragments = map_view
		reconstruction.index(world)
		for cell in terrain_surface.wooden_cells:
			var source: Dictionary = terrain_surface.wooden_cells[cell]
			var ordinal: int = terrain_surface.source_ordinals[cell]
			var floor_root := Node3D.new()
			floor_root.name = "ConstructedLandFloor_%d_%d" % [source.x,source.y]
			floor_root.position = point(source.x,source.y,source.z)+Vector3(0.5,0,0.5)
			floor_root.set_meta("solid",true)
			floor_root.add_child(reconstruction.floors.slab(-ordinal-1,reconstruction.floors.material()))
			static_root.add_child(floor_root)
			collision_builder.add_visual(floor_root)
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
		if not map_view:
			interior_shell.index(world,reconstruction)
			var shell := interior_shell.build(world,reconstruction)
			static_root.add_child(shell)
			collision_builder.add_visual(shell)
			for at in reconstruction.floors.repairs:
				var patch := Node3D.new()
				patch.name = "DerivedFloorRepair_%d_%d_%d" % [at.x,at.y,at.z]
				patch.position = point(at.x,at.y,at.z)+Vector3(0.5,0,0.5)
				patch.set_meta("solid",true)
				patch.add_child(reconstruction.floors.slab(at,reconstruction.floors.material()))
				static_root.add_child(patch)
				collision_builder.add_visual(patch)
		print("ART COVERAGE: %d accounted / %d unresolved" % [reconstruction.mapped,reconstruction.unresolved])
		collision_builder.finish(self,terrain)
		if not coverage_path.is_empty(): reconstruction.save_report(coverage_path)
		print("PRESENTATION COLLISION: %d triangles in chunk bodies; %d grouped source components" % [collision_builder.triangles,reconstruction.grouped])
	var lighting := preload("res://Presentation/LightingRig.gd").new()
	lighting.name = "DistrictLighting"
	add_child(lighting)
	lighting.configure(self,world,reconstruction,map_view,not city_mode)
	game.environment_changed.connect(lighting.receive_server_environment)
	game.ended.connect(lighting.reset_server_environment)
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
	add_child(world_items)
	world_items.configure(self,game)
	login_panel.session = game
	canvas.add_child(login_panel)
	if city_mode:
		minimap = preload("res://Presentation/Minimap.gd").new()
		if minimap.configure(self,city_stream.folder.get_base_dir().path_join("minimap/index.json")):
			canvas.add_child(minimap)
		else:
			minimap.free()
			minimap = null
	login_panel.controller_toggled.connect(func(enabled: bool): controller_enabled = enabled)
	game.entity_changed.connect(_entity_changed)
	game.vendor_received.connect(func(serial: int,_stock: Array):
		if avatars.has(serial): avatars[serial].get_node("Nameplate").text = game.entity_names.get(serial,"Vendor")+" · shopkeeper")
	game.entity_name_received.connect(func(serial: int, name_text: String):
		if avatars.has(serial): avatars[serial].get_node("Nameplate").text = name_text)
	game.position_reset.connect(func(position: Dictionary):
		var at := entity_point(position.x,position.y,position.z)
		if tracks.has(position.serial): tracks[position.serial].reset(at)
		if avatars.has(position.serial):
			avatars[position.serial].position = at
			avatars[position.serial].reset_presentation()
		pivot.position = at+Vector3(0,1.4,0)
		camera_target_ready = true)
	game.movement_started.connect(func(position: Dictionary,seconds: float):
		if tracks.has(player_serial): tracks[player_serial].push(entity_point(position.x,position.y,position.z),seconds))
	game.entity_removed.connect(_entity_removed)
	game.movement_result.connect(func(accepted: bool, position: Dictionary):
		if not accepted and tracks.has(position.serial):
			tracks[position.serial].reset(entity_point(position.x,position.y,position.z)))
	game.entered.connect(func(position: Dictionary):
		player_serial = position.serial
		intent_facing = PI-int(position.direction)*PI/4
		_entity_changed(player_serial,position)
		distance = 5.5
		boom.visual_distance = distance
		boom.spring_length = distance
		pitch = -0.28
		pivot.position = entity_point(position.x,position.y,position.z)+Vector3(0,1.4,0)
		camera_target_ready = true
		status.text = "BRITAIN / TRAMMEL\nWASD move / Shift run / Space hop\nRight mouse look / Wheel zoom / B backpack / F6 return\nClick object / E use nearest"
		panel.position = Vector2(24,700)
		status.add_theme_font_size_override("font_size",15)
		panel.reset_size.call_deferred()
		if position.facet != 1 or position.x < int(world.originX) or position.x >= int(world.originX)+int(world.width) or position.y < int(world.originY) or position.y >= int(world.originY)+int(world.height):
			status.text = "Outside the converted area.\nPress F6 or click Return to Britain.")
	game.ended.connect(func():
		for serial in avatars.keys(): _entity_removed(serial)
		player_serial = 0)
	status.add_theme_font_size_override("font_size",18)
	status.text = "UO WORLD STUDIO / BRITAIN\n%s\nTrammel / x %d-%d / y %d-%d\n%d samples / %d static records\n\nRight mouse: orbit / Wheel: zoom / WASD: pan\nTab: statics / R: camera reset / Esc: quit\nEast +X / South +Z / elevation x 0.2 -> +Y" % [world.provenance,world.originX,int(world.originX)+int(world.width)-1,world.originY,int(world.originY)+int(world.height)-1,world.terrain.size(),world.statics.size()]
	panel.add_child(status)
	world_ready = true
	print("VIEWER PASS: schema, coordinate transform, %d terrain samples, %d statics" % [world.terrain.size(),world.statics.size()])

func _process(delta: float) -> void:
	if not world_ready: return
	if city_stream and game.phase == "world":
		city_stream.follow(Vector2i(game.player.x,game.player.y))
	var movement := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): movement.z -= 1
	if Input.is_physical_key_pressed(KEY_S): movement.z += 1
	if Input.is_physical_key_pressed(KEY_A): movement.x -= 1
	if Input.is_physical_key_pressed(KEY_D): movement.x += 1
	var joypads: Array = Input.get_connected_joypads() if controller_enabled else []
	if not joypads.is_empty():
		var joy: int = joypads[0]
		var stick := Vector2(Input.get_joy_axis(joy,JOY_AXIS_LEFT_X),Input.get_joy_axis(joy,JOY_AXIS_LEFT_Y))
		if stick.length() > 0.35: movement += Vector3(stick.x,0,stick.y)
		var look := Vector2(Input.get_joy_axis(joy,JOY_AXIS_RIGHT_X),Input.get_joy_axis(joy,JOY_AXIS_RIGHT_Y))
		if look.length() > 0.35:
			yaw -= look.x*delta*2.0
			pitch = clampf(pitch-look.y*delta*1.5,-1.5,0.9)
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or not accept_player_input: movement = Vector3.ZERO
	var jump_down := Input.is_physical_key_pressed(KEY_SPACE)
	if not joypads.is_empty(): jump_down = jump_down or Input.is_joy_button_pressed(joypads[0],JOY_BUTTON_A)
	if jump_down and not jump_pressed and not focus is LineEdit and accept_player_input: jump_requested = true
	jump_pressed = jump_down
	has_move_intent = game.phase == "world" and movement != Vector3.ZERO
	if game.phase == "world":
		if movement != Vector3.ZERO:
			var desired := movement.rotated(Vector3.UP,yaw)
			intent_facing = atan2(desired.x,desired.z)
			var direction := int(round(atan2(desired.x,-desired.z)*4.0/PI)) & 7
			game.walk(direction,Input.is_physical_key_pressed(KEY_SHIFT) or (not joypads.is_empty() and Input.is_joy_button_pressed(joypads[0],JOY_BUTTON_LEFT_STICK)))
	else: pivot.position += movement * delta * 20
	for serial in avatars:
		var before: Vector3 = avatars[serial].position
		avatars[serial].position = tracks[serial].advance(delta)
		var travelled := before.distance_to(avatars[serial].position)
		avatars[serial].animate(travelled > 0.00001,intent_facing if serial == player_serial else directions[serial],delta,travelled/maxf(delta,0.00001))
	if game.phase == "world" and avatars.has(player_serial):
		var avatar: Node3D = avatars[player_serial]
		var follow := avatar.position+Vector3(0,1.4+avatar.ground_offset+avatar.jump.height*0.25,0)
		pivot.position = pivot.position.lerp(follow,1.0-exp(-18.0*delta)) if camera_target_ready else follow
		camera_target_ready = true
		avatar.visual_root.visible = boom.get_hit_length() > 1.15
		avatar.get_node("Nameplate").visible = avatar.visual_root.visible
	pivot.rotation = Vector3(pitch,yaw,0)
	boom.collision_mask = 3 if game.phase == "world" and not map_view else 0
	boom.set_distance(distance,delta)
	ticks += 1
	if ticks == 15 and screenshot != "":
		await RenderingServer.frame_post_draw
		var error := get_viewport().get_texture().get_image().save_png(screenshot)
		print("SCREENSHOT ",error," ",screenshot)
		get_tree().quit(error)

func _physics_process(delta: float) -> void:
	if not world_ready: return
	if game.phase != "world" or not avatars.has(player_serial):
		jump_requested = false
		return
	var avatar: Node3D = avatars[player_serial]
	var clearance := boom.headroom(get_world_3d().direct_space_state,avatar.position+Vector3.UP*avatar.ground_offset)
	if jump_requested:
		avatar.jump.start(clearance)
		jump_requested = false
	avatar.jump.advance(delta,clearance)

func stop_mouse_look() -> void:
	if not mouse_looking: return
	mouse_looking = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_viewport().warp_mouse(mouse_return)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: stop_mouse_look()

func _input(event: InputEvent) -> void:
	# Handle release before GUI routing, including releases over a login field.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		stop_mouse_look()
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE and mouse_looking:
		stop_mouse_look()
		get_viewport().set_input_as_handled()
	if event is InputEventMouseMotion and mouse_looking:
		yaw -= event.relative.x * 0.003
		pitch = clampf(pitch-event.relative.y*0.003,-1.35,0.65)
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game.placement_serial:
		game.placement_serial = 0
		game.message_received.emit("Item placement cancelled.")
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not mouse_looking:
		world_items.click(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		mouse_return = get_viewport().get_mouse_position()
		mouse_looking = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(1.2,distance-(0.8 if game.phase == "world" else 4))
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(22 if game.phase == "world" else 250,distance+(0.8 if game.phase == "world" else 4))
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F6: game.return_to_britain()
		if event.keycode == KEY_B: game.open_backpack()
		if event.keycode == KEY_E: world_items.nearest()
		if event.keycode == KEY_ESCAPE: get_tree().quit()
		if event.keycode == KEY_TAB: diagnostics.visible = not diagnostics.visible
		if event.keycode == KEY_R:
			yaw = -0.45
			pitch = -0.28 if game.phase == "world" else -0.75
			distance = 5.5 if game.phase == "world" else 65
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
		var picker := StaticBody3D.new()
		picker.set_meta("server_mobile",serial)
		picker.collision_layer = 4
		picker.collision_mask = 0
		var shape := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.35
		capsule.height = 1.9
		shape.shape = capsule
		shape.position.y = 0.95
		picker.add_child(shape)
		avatar.add_child(picker)
		avatars[serial] = avatar
		tracks[serial] = Motion.new()
		tracks[serial].reset(location)
	# Imported humanoid faces +Z; UO direction 0 faces north (-Z).
	directions[serial] = PI-int(position.direction)*PI/4
	if tracks[serial].position.distance_to(location) > 8.0: avatars[serial].reset_presentation()
	tracks[serial].push(location,float(game.move_interval)/1000.0 if serial == player_serial else (0.21 if position.get("running",false) else 0.41))
	targets[serial] = location

func _entity_removed(serial: int) -> void:
	if avatars.has(serial):
		avatars[serial].queue_free()
		avatars.erase(serial)
		targets.erase(serial)
		tracks.erase(serial)
		directions.erase(serial)
