extends SceneTree
# Picture of the developer chat in the running game (graphical, real local
# ModernUO, -- --city --out=<prefix>): one ask, Claude's replies, a proposal
# card; then the ask is closed.
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
	var mode: CanvasLayer = scene.dev_edit
	mode.toggle()
	if not await until(func(): return mode.state.synced,15): return finish("join")
	mode.ask_box.text = "test: what does this building need?"
	mode.ask_claude()
	await create_timer(4.0).timeout
	var id := 0
	for k in mode.state.asks: id = maxi(id,int(k))
	mode.review(["pet horse"],id)
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	print("CHAT SHOT: panel %s at %s, view %s, offsets %d..%d anchors %.1f..%.1f" % [mode.panel.size,mode.panel.position,scene.get_viewport().get_visible_rect().size,mode.panel.offset_left,mode.panel.offset_right,mode.panel.anchor_left,mode.panel.anchor_right])
	scene.get_viewport().get_texture().get_image().save_png(str(args.get("out","chat"))+".png")
	mode.cancel()
	mode.state.resolve(id,"declined",mode.sender())
	await create_timer(1.0).timeout
	finish("")

func finish(error: String) -> void:
	print("CHAT SHOT: ",error if error != "" else "done")
	if scene: scene.game.close()
	quit(1 if error != "" else 0)
