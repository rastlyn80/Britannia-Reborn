extends Node3D

var world_ready := false
var city_stream: Node3D
# Developer edit mode (F9, DevEdit/); only in live streamed Britain.
var dev_edit: CanvasLayer
var minimap: Control
var lighting_rig: Node3D
var hud_panel: Control
var character_sheet: Control
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
# Small always-on tile readout (top centre) so screenshots carry their place.
var coordinates := Label.new()
var static_root := Node3D.new()
var world_items := preload("res://Presentation/WorldItems.gd").new()
var multis: Node3D
var autowalk: Node
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
# Front end (--front-end, the play launchers): sign in on a stage of its own and
# load districts only once the server names the character's position. Without
# it the viewer keeps its original login panel and preloaded Britain (tests).
var front_end := false
var front: Control
var game_menu: Control
var console: Control
var toasts: Control
var audio: Node3D
var paperdoll_window: Control

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
	# The interface scales with the window and keeps its proportions.
	preload("res://Presentation/InterfaceScale.gd").apply(get_tree().root)
	get_viewport().use_taa = RenderingServer.get_current_rendering_method() == "forward_plus"
	var city_mode := "--city" in OS.get_cmdline_user_args()
	front_end = city_mode and "--front-end" in OS.get_cmdline_user_args()
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
		if not await city_stream.prepare(self,front_end):
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
		dev_edit = preload("res://DevEdit/DevEditMode.gd").new()
		add_child(dev_edit)
		dev_edit.configure(self)
	else:
		movement_surface.index(world)
		game.surface = movement_surface
		game.preview_bounds = Rect2i(int(world.originX),int(world.originY),int(world.width)-1,int(world.height)-1)
		preload("res://Presentation/SurfaceLibrary.gd").source_origin = Vector2(world.originX,world.originY)
		shoreline.index(world,reconstruction.catalog)
		terrain_surface.index(world,shoreline)
		reconstruction.terrain_surface = terrain_surface
		var terrain := MeshInstance3D.new()
		terrain.name = "BlendedTerrain"
		terrain.mesh = terrain_surface.build()
		var terrain_mat := ShaderMaterial.new()
		terrain_mat.shader = preload("res://Presentation/Ground.gdshader")
		terrain_mat.set_shader_parameter("stone_detail",load("res://Art/Quaternius/Village/T_Brick_BaseColor.png"))
		terrain_mat.set_shader_parameter("stone_normal",load("res://Art/Quaternius/Village/T_Brick_Normal.png"))
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"paving","cobblestone_floor_03")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"ground","forest_ground_04")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"grass","leafy_grass")
		preload("res://Presentation/SurfaceLibrary.gd").bind(terrain_mat,"meadow","aerial_grass_rock")
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
	lighting_rig = lighting
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
	coordinates.anchor_left = 0.5
	coordinates.anchor_right = 0.5
	coordinates.offset_left = -120
	coordinates.offset_right = 120
	coordinates.offset_top = 4
	coordinates.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coordinates.add_theme_font_size_override("font_size",13)
	coordinates.add_theme_color_override("font_color",Color(1,1,1,0.75))
	coordinates.add_theme_color_override("font_shadow_color",Color(0,0,0,0.8))
	coordinates.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(coordinates)
	var login_panel := preload("res://Network/LoginPanel.gd").new()
	add_child(game)
	add_child(world_items)
	world_items.configure(self,game)
	multis = preload("res://Presentation/MultiPresenter.gd").new()
	add_child(multis)
	multis.configure(self)
	login_panel.session = game
	canvas.add_child(login_panel)
	if city_mode:
		minimap = preload("res://Presentation/Minimap.gd").new()
		if minimap.configure(self,city_stream.folder.get_base_dir().path_join("minimap/index.json")):
			canvas.add_child(minimap)
		else:
			minimap.free()
			minimap = null
	var vitals := preload("res://Network/VitalsCard.gd").new()
	canvas.add_child(vitals)
	vitals.configure(game)
	character_sheet = preload("res://Network/CharacterSheet.gd").new()
	canvas.add_child(character_sheet)
	character_sheet.configure(game)
	vitals.opened.connect(func(): character_sheet.toggle("character"))
	login_panel.button(login_panel.world_controls,"Character (C)",func(): character_sheet.toggle("character"))
	login_panel.button(login_panel.world_controls,"Skills (K)",func(): character_sheet.toggle("skills"))
	_add_modern_hud(canvas,login_panel)
	# Classic/modern Britain: restart loads the matching prepared city cache.
	var graphics_mode := preload("res://Presentation/GraphicsMode.gd")
	var graphics_button: Button = login_panel.button(login_panel.world_controls,"Britain: %s" % ("modern" if graphics_mode.modern() else "classic"),func(): pass)
	graphics_button.tooltip_text = "Switch Britain between the classic reviewed look and the modern pack models. Takes effect after restart."
	graphics_button.pressed.connect(func():
		graphics_mode.set_modern(not graphics_mode.modern())
		graphics_button.text = "Britain: %s (restart)" % ("modern" if graphics_mode.modern() else "classic"))
	login_panel.controller_toggled.connect(func(enabled: bool): controller_enabled = enabled)
	hud_panel = login_panel
	if front_end: _add_front_end(login_panel,panel)
	login_panel.sky_requested.connect(cycle_sky)
	if lighting_rig and login_panel.sky_button: login_panel.sky_button.text = lighting_rig.sky_label()
	game.entity_changed.connect(_entity_changed)
	game.appearance_changed.connect(_appearance_changed)
	game.mobile_action_received.connect(func(request: Dictionary):
		var serial:=int(request.get("serial",0))
		if avatars.has(serial):avatars[serial].receive_native_action(request))
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
		status.text = "BRITAIN / TRAMMEL\nWASD move / Shift run / Space hop\nRight mouse look / Wheel zoom / B backpack / F6 return\nC character / K skills / Click object / E use nearest"
		panel.position = Vector2(24,get_viewport().get_visible_rect().size.y-130)
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
	# The status panel's first line carries the player's tile, so screenshots
	# of defects identify their place.
	if game.phase == "world":
		var tile := "%d, %d, %d" % [int(game.player.x),int(game.player.y),int(game.player.z)]
		if coordinates.text != tile: coordinates.text = tile
	if game.phase == "world" and status.text.begins_with("BRITAIN / TRAMMEL"):
		var line := "BRITAIN / TRAMMEL  ·  %d, %d, %d" % [int(game.player.x),int(game.player.y),int(game.player.z)]
		var rest := status.text.substr(status.text.find("
"))
		if not status.text.begins_with(line+"
"): status.text = line+rest
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
		var follow := avatar.position+Vector3(0,float(avatar.get_meta("camera_height",1.4))+avatar.ground_offset+avatar.jump.height*0.25,0)
		pivot.position = pivot.position.lerp(follow,1.0-exp(-18.0*delta)) if camera_target_ready else follow
		camera_target_ready = true
		avatar.visual_root.visible = boom.get_hit_length() > 1.15
		avatar.get_node("Nameplate").visible = avatar.visual_root.visible
	pivot.rotation = Vector3(pitch,yaw,0)
	boom.collision_mask = 3 if game.phase == "world" and not map_view else 0
	boom.set_distance(distance,delta)
	# Trees between the camera and the player open a soft see-through circle.
	var clearing: bool = game.phase == "world" and avatars.has(player_serial) and not map_view
	var chest: Vector3 = avatars[player_serial].global_position+Vector3.UP*(1.0+avatars[player_serial].ground_offset) if clearing else Vector3.ZERO
	preload("res://Presentation/FoliageClearance.gd").update(chest,camera.global_position,1.5 if clearing else 0.0)
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

# Client-only sky view: server time, always day or always night (F7).
# Modern HUD (docs/MODERN_UI.md): quickbar with classic macro actions on
# Shift/Ctrl/Alt sets, skills, spellbook and backpack windows, target frame,
# journal, window menu and notices.
func _add_modern_hud(canvas: CanvasLayer, login_panel: Control) -> void:
	var captions := preload("res://Network/ScreenLabels.gd").new()
	captions.camera = camera
	canvas.add_child(captions)
	canvas.move_child(captions,0)
	var damage := preload("res://Network/DamageNumbers.gd").new()
	canvas.add_child(damage)
	canvas.move_child(damage,1)
	damage.configure(self,camera)
	var effects := preload("res://Presentation/EffectPresenter.gd").new()
	add_child(effects)
	effects.configure(self)
	audio = preload("res://Presentation/AudioPlayer.gd").new()
	add_child(audio)
	audio.configure(self)
	var runner := preload("res://Network/ActionRunner.gd").new()
	add_child(runner)
	runner.configure(game)
	runner.hovered = world_items.hovered_serial
	var names := preload("res://Network/MobileNames.gd").new()
	add_child(names)
	names.configure(game)
	var journal := preload("res://Network/Journal.gd").new()
	canvas.add_child(journal)
	journal.configure(game)
	var target := preload("res://Network/TargetFrame.gd").new()
	canvas.add_child(target)
	target.configure(game)
	var death := preload("res://Network/DeathScreen.gd").new()
	canvas.add_child(death)
	canvas.move_child(death,2)
	death.configure(game)
	var buff_bar := preload("res://Network/BuffBar.gd").new()
	canvas.add_child(buff_bar)
	buff_bar.configure(game)
	toasts = preload("res://Network/Toasts.gd").new()
	canvas.add_child(toasts)
	toasts.configure(game)
	var quickbar := preload("res://Network/Quickbar.gd").new()
	canvas.add_child(quickbar)
	# The journal ends before the quickbar on any screen shape (full width when there is room).
	var fit_journal := func():
		if not is_instance_valid(journal) or not is_instance_valid(quickbar): return
		journal.offset_right = clampf(quickbar.get_global_rect().position.x-16.0,300.0,540.0)
	get_viewport().size_changed.connect(func(): fit_journal.call_deferred())
	quickbar.resized.connect(func(): fit_journal.call_deferred())
	fit_journal.call_deferred()
	quickbar.configure(runner)
	runner.feedback.connect(func(text: String): journal.add(text,"Quickbar"))
	var skills := preload("res://Network/SkillsWindow.gd").new()
	canvas.add_child(skills)
	skills.configure(game)
	var spellbook := preload("res://Network/SpellbookWindow.gd").new()
	canvas.add_child(spellbook)
	spellbook.configure(runner)
	spellbook.add_requested.connect(quickbar.add_to_first_empty)
	var studio := preload("res://Presentation/ItemStudio.gd").new()
	add_child(studio)
	studio.configure(world_items)
	studio.tile_builder = multis.tile_model
	var inspector := preload("res://Network/InspectWindow.gd").new()
	canvas.add_child(inspector)
	inspector.configure(game,world_items)
	var backpack := preload("res://Network/BackpackWindow.gd").new()
	canvas.add_child(backpack)
	backpack.configure(game)
	backpack.add_requested.connect(quickbar.add_to_first_empty)
	backpack.inspect_requested.connect(inspector.inspect)
	var paperdoll := preload("res://Network/PaperdollWindow.gd").new()
	canvas.add_child(paperdoll)
	paperdoll.configure(game)
	paperdoll_window = paperdoll
	# Context menus and shops in the modern style; the old panel stops answering.
	var vendor := preload("res://Network/VendorWindow.gd").new()
	canvas.add_child(vendor)
	vendor.configure(game)
	var party := preload("res://Network/PartyFrames.gd").new()
	canvas.add_child(party)
	party.configure(game)
	var trade := preload("res://Network/TradeWindow.gd").new()
	canvas.add_child(trade)
	trade.configure(game)
	var book := preload("res://Network/BookWindow.gd").new()
	canvas.add_child(book)
	book.configure(game)
	var board := preload("res://Network/BoardWindow.gd").new()
	canvas.add_child(board)
	board.configure(game)
	autowalk = preload("res://Presentation/AutoWalk.gd").new()
	add_child(autowalk)
	autowalk.configure(game)
	var world_map := preload("res://Network/WorldMapWindow.gd").new()
	canvas.add_child(world_map)
	world_map.configure(self)
	world_map.hide()
	var server_map := preload("res://Network/ServerMapWindow.gd").new()
	canvas.add_child(server_map)
	server_map.configure(game)
	server_map.hide()
	var facet_notice := preload("res://Network/FacetNotice.gd").new()
	canvas.add_child(facet_notice)
	facet_notice.configure(game)
	var helm := preload("res://Network/HelmPanel.gd").new()
	canvas.add_child(helm)
	helm.configure(game)
	var designer := preload("res://Network/HouseDesigner.gd").new()
	canvas.add_child(designer)
	designer.configure(self)
	designer.hide()
	var placing := preload("res://Presentation/PlacementGhost.gd").new()
	add_child(placing)
	placing.configure(self,canvas)
	var arrow := preload("res://Network/QuestArrow.gd").new()
	canvas.add_child(arrow)
	canvas.move_child(arrow,1)
	arrow.configure(self)
	# Books and boards have their own windows; the old item list stays closed.
	for old in login_panel.get_children():
		if old.get_script() == preload("res://Network/ItemBrowser.gd"):
			game.book_received.connect(func(_b: Dictionary): old.panel.hide.call_deferred())
			game.board_received.connect(func(_b: Dictionary): old.panel.hide.call_deferred())
	var craft := preload("res://Network/CraftWindow.gd").new()
	canvas.add_child(craft)
	craft.configure(game)
	var dialogs := preload("res://Network/ServerDialogs.gd").new()
	canvas.add_child(dialogs)
	dialogs.configure(game)
	var menu_popup := preload("res://Network/ContextMenu.gd").new()
	canvas.add_child(menu_popup)
	menu_popup.configure(game)
	for child in login_panel.get_children():
		if child.get_script() == preload("res://Network/ShopPanel.gd"):
			if game.context_received.is_connected(child.context): game.context_received.disconnect(child.context)
			if game.vendor_received.is_connected(child.shop): game.vendor_received.disconnect(child.shop)
	# The modern backpack and container windows replace the plain item list;
	# it still shows books and bulletin boards.
	var containers := {}
	for child in login_panel.get_children():
		if child.get_script() == preload("res://Network/ItemBrowser.gd"):
			game.container_opened.connect(func(serial: int):
				(func():
					if serial == int(game.board_serial): return
					child.panel.hide()
					# Spellbooks open as containers; the spellbook window shows them.
					if int(game.known_items.get(serial,game.world_items.get(serial,{})).get("id",0)) in preload("res://Network/SpellbookWindow.gd").BOOKS or game.module("items").spellbooks.has(serial): return
					if serial == int(game.backpack): return
					if containers.has(serial) and is_instance_valid(containers[serial]):
						containers[serial].move_to_front()
						return
					var window := preload("res://Network/ContainerWindow.gd").new()
					canvas.add_child(window)
					window.open(game,serial,Vector2(140+containers.size()*40,150+containers.size()*34))
					window.position = Vector2(140+containers.size()*40,150+containers.size()*34) if containers.size() > 0 else window.position
					containers[serial] = window
					window.closed.connect(func(closed: int): containers.erase(closed))).call_deferred())
	var editor := preload("res://Network/SlotEditor.gd").new()
	canvas.add_child(editor)
	quickbar.edit_requested.connect(func(row: int, layer: String, index: int): editor.open(quickbar,row,layer,index))
	var menu := preload("res://Network/MenuBar.gd").new()
	canvas.add_child(menu)
	game.entered.connect(func(_position: Dictionary): menu.show())
	# In the world the journal takes the old key-help panel's corner, and the
	# minimap sits above the window menu.
	game.entered.connect(func(_position: Dictionary): status.get_parent().hide.call_deferred())
	game.ended.connect(func(): status.get_parent().show())
	if minimap:
		minimap.offset_top -= 72
		minimap.offset_bottom -= 72
	game.ended.connect(menu.hide)
	var open := func(window: String) -> bool:
		match window:
			"character", "Paperdoll": paperdoll.toggle()
			"Status": character_sheet.toggle("character")
			"backpack", "Backpack": backpack.toggle()
			"skills", "Skills": skills.toggle()
			"spellbook": spellbook.toggle()
			"journal", "Journal": journal.visible = not journal.visible
			"menu":
				if game_menu: game_menu.toggle()
				else: return false
			"map", "World Map": world_map.toggle()
			_: return false
		return true
	menu.chosen.connect(func(window: String):
		if not open.call(window): quickbar.show_feedback("The %s is not in this client yet." % window))
	runner.window_requested.connect(func(window: String, verb: String):
		if verb == "Quit": get_tree().quit()
		elif verb in ["Open","Close"] and open.call(window): pass
		else: quickbar.show_feedback("%s %s is not in this client yet." % [verb,window]))
	runner.client_requested.connect(func(action: String, option: String):
		if action == "Zoom":
			distance = 5.5 if option in ["","Default Zoom"] else clampf(distance+(-0.8 if option == "Zoom In" else 0.8),1.2,22.0)
		else: quickbar.show_feedback("%s is not in this client yet." % action))

# The front end, game menu, target prompt, console and connection chip that
# replace the old right-hand panel (docs/MODERN_UI.md).
func _add_front_end(login_panel: Control, help_panel: Control) -> void:
	login_panel.hide()
	help_panel.hide()
	var hud: CanvasLayer = help_panel.get_parent()
	var target := preload("res://Network/TargetPrompt.gd").new()
	hud.add_child(target)
	target.configure(game)
	console = preload("res://Network/DevConsole.gd").new()
	hud.add_child(console)
	console.configure(game)
	var chip := preload("res://Network/ConnectionChip.gd").new()
	hud.add_child(chip)
	chip.configure(game)
	game.movement_result.connect(func(accepted: bool, _position: Dictionary):
		if not accepted: toasts.notify("Movement","blocked; the server corrected your position",preload("res://Network/ModernSkin.gd").AMBER))
	game.entered.connect(func(_position: Dictionary):
		toasts.notify("Tip","E uses the nearest object · Esc opens the game menu"),CONNECT_ONE_SHOT)
	var front_layer := CanvasLayer.new()
	front_layer.layer = 10
	add_child(front_layer)
	front = preload("res://Network/FrontEnd.gd").new()
	front_layer.add_child(front)
	front.configure(game,self,login_panel)
	var menu_layer := CanvasLayer.new()
	menu_layer.layer = 20
	add_child(menu_layer)
	game_menu = preload("res://Network/GameMenu.gd").new()
	menu_layer.add_child(game_menu)
	game_menu.configure(self)
	game.module("player").logged_out.connect(_logged_out)
	front_end_shown(true)

func front_end_shown(shown: bool) -> void:
	accept_player_input = not shown
	# The world's own 3D view is not drawn under the front end's stage.
	get_viewport().disable_3d = shown

func region_contains(x: int, y: int) -> bool:
	return city_stream == null or city_stream.bounds.has_point(Vector2i(x,y))

func district_progress() -> Vector2i:
	return city_stream.progress() if city_stream and game.phase == "world" else Vector2i.ZERO

# Log out properly: ask the server (0xD1) and close on its acknowledgement
# (or after 3 s). `next` tells the front end where to go: the sign-in screen,
# or straight back to the character list ("characters").
var logging_out := false
func log_out(next := "signin") -> void:
	if front: front.after_end = next
	if game.phase != "world":
		game.close()
		return
	preload("res://Network/CharacterLooks.gd").remember(front.account,str(front.chosen.get("name","")),preload("res://Network/CharacterLooks.gd").capture(game))
	logging_out = true
	game.send(preload("res://Network/Packets/Player.gd").logout_request())
	get_tree().create_timer(3.0).timeout.connect(func(): if logging_out: _logged_out())

func _logged_out() -> void:
	if not logging_out: return
	logging_out = false
	game.close()

func open_settings() -> void:
	game_menu.open()
	game_menu._settings()

func open_console() -> void:
	console.open()

func cycle_sky() -> void:
	if not lighting_rig: return
	var label: String = lighting_rig.cycle_sky()
	if hud_panel and hud_panel.sky_button: hud_panel.sky_button.text = label
	game.message_received.emit(label.replace(" (F7)","")+" — view only; server time unchanged")

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
		if dev_edit and dev_edit.active: dev_edit.click(event.position)
		else: world_items.click(event.position,event.double_click)
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
		if event.keycode == KEY_F7: cycle_sky()
		if event.keycode == KEY_F9 and dev_edit: dev_edit.toggle()
		if event.keycode == KEY_B: game.open_backpack()
		if event.keycode == KEY_E: world_items.nearest()
		if event.keycode == KEY_C and game.phase == "world" and not get_viewport().gui_get_focus_owner() is LineEdit:
			if paperdoll_window: paperdoll_window.toggle()
			else: character_sheet.toggle("character")
		if event.keycode == KEY_K and game.phase == "world": character_sheet.toggle("skills")
		if event.keycode == KEY_ESCAPE:
			if not front_end: get_tree().quit()
			elif front.visible: pass
			elif not game.target_request.is_empty(): game.target_item()
			else: game_menu.toggle()
		if event.keycode == KEY_QUOTELEFT and front_end and game.phase == "world" and not get_viewport().gui_get_focus_owner() is LineEdit:
			if console.visible: console.hide()
			else: console.open()
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
		avatar.initial_body = int(position.get("body",0))
		var label := Label3D.new()
		label.name = "Nameplate"
		# Never a placeholder: the real name arrives with the status reply (MobileNames).
		label.text = "You" if serial == game.player.serial else str(game.entity_names.get(serial,""))
		label.position.y = 2.2
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 32
		avatar.add_child(label)
		preload("res://Network/ScreenLabels.gd").track(label)
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
	avatars[serial].apply_server_appearance(position,game.mobile_equipment.get(serial,{}).values(),game.appearance_for(serial))
	# Imported humanoid faces +Z; UO direction 0 faces north (-Z).
	directions[serial] = PI-int(position.direction)*PI/4
	if tracks[serial].position.distance_to(location) > 8.0: avatars[serial].reset_presentation()
	tracks[serial].push(location,float(game.move_interval)/1000.0 if serial == player_serial else preload("res://Presentation/HorseVisual.gd").step_seconds(game.mobile_equipment.get(serial,{}).values(),bool(position.get("running",false)))+.005)
	targets[serial] = location

func _appearance_changed(serial: int) -> void:
	if not avatars.has(serial): return
	var entity: Dictionary = game.player if serial==int(game.player.serial) else game.entities.get(serial,{})
	avatars[serial].apply_server_appearance(entity,game.mobile_equipment.get(serial,{}).values(),game.appearance_for(serial))

func _entity_removed(serial: int) -> void:
	if avatars.has(serial):
		avatars[serial].queue_free()
		avatars.erase(serial)
		targets.erase(serial)
		tracks.erase(serial)
		directions.erase(serial)
