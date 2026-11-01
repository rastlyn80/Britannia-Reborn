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
	# Auto-apply and Undo: this client asks, Claude (the bridge) proposes
	# "give Hatchet", the client applies it at once; Undo removes it.
	var mode: CanvasLayer = scene.dev_edit
	mode.toggle()
	if not await until(func(): return mode.state.synced,15): return finish("join")
	var pack := int(scene.game.backpack)
	var count := func() -> int:
		var n := 0
		for serial in scene.game.known_items:
			if int(scene.game.known_items[serial].get("container",0)) == pack and int(scene.game.known_items[serial].get("id",0)) == 0xF43: n += 1
		return n
	var before: int = count.call()
	mode.ask_box.text = "test: auto-apply check, please ignore"
	mode.ask_claude()
	var ask := [0]
	if not await until(func():
		for k in mode.state.asks:
			if str(mode.state.asks[k].text).begins_with("test: auto-apply"): ask[0] = int(k)
		return ask[0] > 0,15): return finish("ask")
	var inbox := ProjectSettings.globalize_path("res://../work/dev-edit-bridge/inbox.txt")
	var file := FileAccess.open(inbox,FileAccess.READ_WRITE)
	file.seek_end()
	file.store_string("propose %d give Hatchet
" % ask[0])
	file.close()
	var applied: bool = await until(func(): return count.call() > before,30)
	print("AUTO APPLY LIVE: hatchets %d -> %d, applied without Accept %s, ask %s" % [before,count.call(),applied,mode.state.asks[ask[0]].status])
	mode.undo_ask(ask[0])
	var undone: bool = await until(func(): return count.call() == before,20)
	print("AUTO APPLY LIVE: after Undo hatchets %d, undone %s" % [count.call(),undone])
	finish("")

func finish(error: String) -> void:
	print("AUTO APPLY LIVE: ",error if error != "" else "done")
	if scene: scene.game.close()
	quit(1 if error != "" else 0)
