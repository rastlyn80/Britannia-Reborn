extends SceneTree
# Live picture of a place in the running game (graphical, real local
# ModernUO): logs in as UO_DEV_USER, travels to --at=x,y,z, waits for the
# world there to stream in and saves one picture per --views=yaw:pitch:distance
# to --out=<prefix>-<n>.png. Used to check a fix before the owner looks.
var scene: Node3D

func _initialize() -> void: call_deferred("run")

func until(test: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not test.call():
		if Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true

func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=",true,1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	var at: PackedStringArray = str(args.get("at","1602,1591,20")).split(",")
	scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.accept_player_input = false
	if not await until(func(): return scene.world_ready,180): return finish("startup")
	scene.game.characters_received.connect(func(characters: Array,_cities: Array):
		for c in characters:
			if not c.name.is_empty():
				scene.game.select_character(c.slot,c.name)
				return)
	var entered := [false]
	scene.game.entered.connect(func(_p: Dictionary): entered[0] = true)
	scene.game.connect_account(OS.get_environment("UO_DEV_USER"),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return entered[0],40): return finish("entry")
	scene.game.travel_to(int(at[0]),int(at[1]),int(at[2]))
	if not await until(func(): return absi(int(scene.game.player.x)-int(at[0])) <= 1 and absi(int(scene.game.player.y)-int(at[1])) <= 1,20): return finish("travel")
	await create_timer(3.0).timeout
	if not await until(func(): return scene.city_stream.settled(),120): return finish("settle")
	await create_timer(4.0).timeout
	var backpack: Control = null
	for node in scene.find_children("*","",true,false):
		if node.get_script() == preload("res://Network/BackpackWindow.gd"): backpack = node
	print("BACKPACK LIVE: window found ",backpack != null,", visible ",backpack.visible if backpack else false,", focus ",scene.get_viewport().gui_get_focus_owner())
	for pressed in [true,false]:
		var key := InputEventKey.new()
		key.keycode = KEY_B
		key.physical_keycode = KEY_B
		key.pressed = pressed
		Input.parse_input_event(key)
		await process_frame
	await create_timer(2.0).timeout
	print("BACKPACK LIVE: after B visible ",backpack.visible if backpack else false)
	var pack := int(scene.game.backpack)
	var item := 0
	for serial in scene.game.known_items:
		if int(scene.game.known_items[serial].get("container",0)) == pack: item = int(serial)
	print("BACKPACK LIVE: pack %d, an item %d" % [pack,item])
	if item != 0:
		scene.game.message_received.connect(func(t: String): print("BACKPACK LIVE: server says ",t))
		var me := Vector3i(int(scene.game.player.x),int(scene.game.player.y),int(scene.game.player.z))
		print("BACKPACK LIVE: player at ",me)
		print("BACKPACK LIVE: drop at your feet sent ",scene.game.move_item(item,0))
		await create_timer(8.0).timeout
		var landed: Dictionary = scene.game.world_items.get(item,{})
		print("BACKPACK LIVE: on the ground ",not landed.is_empty()," at ",Vector2i(int(landed.get("x",0)),int(landed.get("y",0))))
		if not landed.is_empty():
			scene.game.move_item(item,pack)
			await create_timer(3.0).timeout
			print("BACKPACK LIVE: picked back up ",int(scene.game.known_items.get(item,{}).get("container",0)) == pack)
	var catcher: Control = null
	for node in scene.find_children("*","",true,false):
		if node.get_script() == preload("res://Network/WorldDrop.gd"): catcher = node
	if catcher and item != 0:
		var view := scene.get_viewport().get_visible_rect().size
		var spot := Vector2(view.x*0.42,view.y*0.62)
		print("BACKPACK LIVE: world drop accepts ",catcher._can_drop_data(spot,{"item_serial":item}))
		catcher._drop_data(spot,{"item_serial":item})
		await create_timer(8.0).timeout
		var landed: Dictionary = scene.game.world_items.get(item,{})
		print("BACKPACK LIVE: dragged onto the world -> on the ground ",not landed.is_empty()," at ",Vector2i(int(landed.get("x",0)),int(landed.get("y",0))))
		if not landed.is_empty():
			scene.game.move_item(item,pack)
			await create_timer(3.0).timeout
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png(str(args.get("out","pack"))+".png")
	finish("")

func finish(error: String) -> void:
	print("BACKPACK LIVE: ",error if error != "" else "done")
	if scene: scene.game.close()
	quit(1 if error != "" else 0)
