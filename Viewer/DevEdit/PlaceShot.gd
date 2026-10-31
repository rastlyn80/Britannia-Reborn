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
	var views: PackedStringArray = str(args.get("views","0:-0.4:8")).split(";",false)
	for i in views.size():
		var v: PackedStringArray = views[i].split(":")
		scene.yaw = float(v[0])
		scene.pitch = float(v[1])
		scene.distance = float(v[2])
		await create_timer(1.5).timeout
		await RenderingServer.frame_post_draw
		scene.get_viewport().get_texture().get_image().save_png("%s-%d.png" % [args.get("out","place"),i])
	finish("")

func finish(error: String) -> void:
	print("PLACE SHOT: ",error if error != "" else "done")
	if scene: scene.game.close()
	quit(1 if error != "" else 0)
