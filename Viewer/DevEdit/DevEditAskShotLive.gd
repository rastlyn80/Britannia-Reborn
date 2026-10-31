extends SceneTree
# Live check that an ask sent from the editor panel saves what the asker
# sees (graphical, real local ModernUO, -- --city): asks once, waits for the
# screenshot beside the bridge, then closes the ask.
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
	mode.ask_box.text = "test: screenshot check, please ignore"
	mode.ask_claude()
	var id := [0]
	if not await until(func():
		for k in mode.state.asks:
			if mode.state.asks[k].text.begins_with("test: screenshot check"): id[0] = int(k)
		return id[0] > 0 and FileAccess.file_exists(mode.State.shot_path(id[0])),20): return finish("no screenshot (ask %d, wanted %d)" % [id[0],mode.shots_wanted])
	print("ASK SHOT: ",mode.State.shot_path(id[0]))
	mode.state.resolve(id[0],"declined",mode.sender())
	await create_timer(1.0).timeout
	finish("")

func finish(error: String) -> void:
	print("ASK SHOT: ",error if error != "" else "done")
	if scene: scene.game.close()
	quit(1 if error != "" else 0)
