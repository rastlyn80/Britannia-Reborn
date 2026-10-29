extends SceneTree
# End-to-end Commit with two graphical clients (--role=a / --role=b, plus
# -- --city --classic-britain). A places an asset, hides a baked decorative
# static and raises terrain, then commits: the session edits are folded into
# the committed overrides, only the affected districts rebake in a background
# process, both running clients reload those districts without restarting, and
# the committed edits leave the live session. Records timings, reloaded
# districts, frame times and before/after screenshots in outputs/validation.
var scene: Node3D
var role := "a"
var out := ""
var frames: Array[float] = []
var previous_us := 0
var result := {}

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if previous_us > 0: frames.append((now-previous_us)/1000.0)
	previous_us = now
	return false

func _initialize() -> void: call_deferred("run")

func wall() -> float: return Time.get_unix_time_from_system()*1000.0

func until(test: Callable, seconds: float = 20.0) -> bool:
	var start := Time.get_ticks_msec()
	while not test.call():
		if Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true

func sync_path() -> String: return out.path_join("dev-commit-sync.json")

func publish(event: String, value: Variant) -> void:
	var data: Dictionary = {}
	if FileAccess.file_exists(sync_path()): data = JSON.parse_string(FileAccess.get_file_as_string(sync_path()))
	data[event] = value
	var file := FileAccess.open(sync_path(),FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func shared(event: String) -> Variant:
	if not FileAccess.file_exists(sync_path()): return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(sync_path()))
	return data.get(event) if data is Dictionary else null

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png(out.path_join("dev-commit-%s-%s.png" % [role,name]))
	await process_frame
	await process_frame

func window(from: int) -> Dictionary:
	var slice: Array = frames.slice(from)
	if slice.is_empty(): return {}
	slice.sort()
	return {"frames":slice.size(),"p50":slice[slice.size()/2],"p95":slice[mini(slice.size()-1,int(slice.size()*0.95))],"max":slice[-1]}

func finish(code: int) -> void:
	var file := FileAccess.open(out.path_join("dev-commit-%s.json" % role),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("DEV COMMIT VISUAL %s: %s" % [role.to_upper(),JSON.stringify(result)])
	if scene: scene.game.close()
	quit(code)

func run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--role="): role = arg.substr(7)
	out = ProjectSettings.globalize_path("res://../outputs/validation")
	DirAccess.make_dir_recursive_absolute(out)
	if role == "a" and FileAccess.file_exists(sync_path()): DirAccess.remove_absolute(sync_path())
	scene = load("res://Main.tscn").instantiate()
	root.add_child(scene)
	scene.accept_player_input = false
	if not await until(func(): return scene.world_ready,180): result.error = "startup";finish(1);return
	scene.game.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				scene.game.select_character(character.slot,character.name)
				return)
	var entered := [false]
	scene.game.entered.connect(func(_p: Dictionary): entered[0] = true)
	scene.game.connect_account(OS.get_environment("UO_DEV_USER")+("2" if role == "b" else ""),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return entered[0],40): result.error = "entry";finish(1);return
	scene.game.return_to_britain()
	await until(func(): return Vector2i(scene.game.player.x,scene.game.player.y) == Vector2i(1602,1591),10)
	if not await until(func(): return scene.city_stream.settled(),60): result.error = "settle";finish(1);return
	scene.distance = 11.0
	scene.pitch = -0.62
	scene.yaw = -0.45 if role == "a" else -0.15
	var mode: CanvasLayer = scene.dev_edit
	mode.toggle()
	if not await until(func(): return mode.state.synced,15): result.error = "join";finish(1);return
	await until(func(): return not mode.overlay.warming,30)
	publish("joined_"+role,wall())
	await until(func(): return shared("joined_a") != null and shared("joined_b") != null,90)
	var stream: Node3D = scene.city_stream
	var reloads_before: int = stream.reloads
	if role == "a": await role_a(mode,stream,reloads_before)
	else: await role_b(mode,stream,reloads_before)

func role_a(mode: CanvasLayer, stream: Node3D, reloads_before: int) -> void:
	var state = mode.state
	var send: Callable = mode.sender()
	var player := Vector2(scene.game.player.x,scene.game.player.y)
	var z := int(scene.game.player.z)
	var forward := Vector2(-sin(scene.yaw),-cos(scene.yaw))
	var spot := (player+forward*4.0).round()
	var placed: int = state.place(2451,spot.x,spot.y,z,30,send)
	await until(func(): return state.requests.get(placed,{}).get("status","") != "pending",10)
	var hidden := ""
	for at in mode.overlay.districts:
		for record in mode.overlay.districts[at].records:
			if hidden == "" and Vector2(record.x,record.y).distance_to(spot) < 10 and mode.overlay.info_for(record).editable and mode.overlay.info_for(record).kind in ["flower","grass","bush","mushroom"]: hidden = record.target
	if hidden != "":
		var h: int = state.set_state(hidden,"hide","hide",send)
		await until(func(): return state.requests.get(h,{}).get("status","") != "pending",10)
	var centre := (player+forward*7.0+Vector2(forward.y,-forward.x)*3.0).round()
	var brush: int = state.brush(int(centre.x),int(centre.y),3,10,"dirt",send)
	await until(func(): return state.requests.get(brush,{}).get("status","") != "pending",10)
	await until(func(): return mode.overlay.idle(),15)
	await create_timer(1.5).timeout
	await capture("before-commit")
	result.session_edits_before = mode.session_edits().size()
	result.hidden = hidden
	# Commit (the Accept step of the reviewed commit plan).
	mode.review_commit()
	result.commit_scope = mode.plan_label.text
	var started := wall()
	var frame_mark := frames.size()
	publish("commit_started",started)
	mode.accept()
	if not await until(func(): return mode.bake_pid == 0 and mode.committing.is_empty(),900): result.error = "bake did not finish";finish(1);return
	result.bake_ms = wall()-started
	result.frames_during_bake = window(frame_mark)
	frame_mark = frames.size()
	if not await until(func(): return stream.reloads > reloads_before and stream.reloading.is_empty(),120): result.error = "no reload";finish(1);return
	await until(func(): return mode.session_edits().is_empty() and mode.overlay.idle(),30)
	result.commit_to_reloaded_ms = wall()-started
	result.reloaded_districts = stream.reloads-reloads_before
	result.session_edits_after = mode.session_edits().size()
	result.frames_during_reload = window(frame_mark)
	result.slow_phases = stream.slow_phases.filter(func(e: Dictionary): return float(e.ms) > 30.0).slice(-12)
	result.hidden_still_rendered = mode.overlay.record_for(hidden).size() > 0 and mode.overlay.districts[mode.overlay.owner(mode.overlay.record_for(hidden).x,mode.overlay.record_for(hidden).y)].map.has(mode.overlay.record_for(hidden).key)
	var committed: Dictionary = preload("res://Presentation/ManualOverrides.gd").read(preload("res://Presentation/ManualOverrides.gd").committed_path(stream.dataset()))
	result.committed_file = {"statics":committed.get("statics",{}).size(),"placed":committed.get("placed",{}).size(),"terrain":committed.get("terrain",{}).size()}
	result.undo_offers_commit = state.undo_candidate() > 0 and state.history[state.undo_candidate()].action == "commit"
	var log_path := ProjectSettings.globalize_path("res://../outputs/britain/prepared/index.json")
	result.index_files = JSON.parse_string(FileAccess.get_file_as_string(log_path)).get("files",{})
	await create_timer(2.0).timeout
	await capture("after-commit")
	publish("a_done",wall())
	await until(func(): return shared("b_done") != null,60)
	finish(0)

func role_b(mode: CanvasLayer, stream: Node3D, reloads_before: int) -> void:
	await until(func(): return shared("commit_started") != null,300)
	await until(func(): return mode.overlay.idle(),15)
	await create_timer(1.0).timeout
	await capture("before-commit")
	var frame_mark := frames.size()
	if await until(func(): return stream.reloads > reloads_before and stream.reloading.is_empty() and mode.session_edits().is_empty(),900):
		result.commit_to_reloaded_ms = wall()-float(shared("commit_started"))
		result.reloaded_districts = stream.reloads-reloads_before
		result.frames_during_reload = window(frame_mark)
		await until(func(): return mode.overlay.idle(),15)
		await create_timer(2.0).timeout
		await capture("after-commit")
	else: result.error = "B never reloaded"
	publish("b_done",wall())
	finish(0 if not result.has("error") else 1)
