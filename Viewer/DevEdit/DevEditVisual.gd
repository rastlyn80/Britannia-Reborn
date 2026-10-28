extends SceneTree
# Graphical two-client demonstration: two real Godot clients (run this twice,
# --role=a and --role=b) log in with the two development accounts, return to
# the Britain start point, open developer edit mode and join one session.
# A places an approved asset, hides a baked decorative static and brushes
# terrain; B shares a preview and observes. Both record edit-to-visible
# latency (wall clock, same machine), frame times and screenshots under
# outputs/validation/. A returns its edits to baseline at the end.
var scene: Node3D
var role := "a"
var out := ""
var frames: Array[float] = []
var previous_us := 0
var marks: Array = []
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

func sync_path() -> String: return out.path_join("dev-edit-sync.json")

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
	scene.get_viewport().get_texture().get_image().save_png(out.path_join("dev-edit-%s-%s.png" % [role,name]))
	# PNG encoding blocks this frame; keep it out of the next measured window.
	await process_frame
	await process_frame

func mark(name: String) -> void:
	marks.append({"name":name,"frame":frames.size()})

func frame_window(from: int, to: int) -> Dictionary:
	var slice: Array = frames.slice(from,to)
	if slice.is_empty(): return {}
	slice.sort()
	return {"frames":slice.size(),"p50":slice[slice.size()/2],"p95":slice[mini(slice.size()-1,int(slice.size()*0.95))],"max":slice[-1]}

func fail(message: String) -> void:
	push_error(message)
	result.error = message
	finish(1)

func finish(code: int) -> void:
	result.marks = marks
	result.idle = frame_window(maxi(0,frames.size()-240),frames.size())
	var file := FileAccess.open(out.path_join("dev-edit-%s.json" % role),FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	print("DEV EDIT VISUAL %s: %s" % [role.to_upper(),JSON.stringify(result)])
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
	if not await until(func(): return scene.world_ready,180): fail("city startup timeout");return
	scene.game.characters_received.connect(func(characters: Array,_cities: Array):
		for character in characters:
			if not character.name.is_empty():
				scene.game.select_character(character.slot,character.name)
				return)
	var entered := [false]
	scene.game.entered.connect(func(_p: Dictionary): entered[0] = true)
	scene.game.connect_account(OS.get_environment("UO_DEV_USER")+("2" if role == "b" else ""),OS.get_environment("UO_DEV_PASSWORD"))
	if not await until(func(): return entered[0],40): fail("world entry timeout");return
	scene.game.return_to_britain()
	await until(func(): return Vector2i(scene.game.player.x,scene.game.player.y) == Vector2i(1602,1591),10)
	if not await until(func(): return scene.city_stream.settled(),60): fail("districts did not settle");return
	scene.distance = 11.0
	scene.pitch = -0.62
	# Both cameras look the same way so each sees the edits made in front of A.
	scene.yaw = -0.45 if role == "a" else -0.15
	await create_timer(2.0).timeout
	var mode: CanvasLayer = scene.dev_edit
	mode.toggle()
	if not await until(func(): return mode.state.synced,15): fail("dev session join failed: "+mode.state.denied);return
	await until(func(): return not mode.overlay.warming,30)
	result.warm_readback_us = mode.overlay.stats.readback_us.duplicate()
	result.editor = mode.state.me
	publish("joined_"+role,wall())
	if not await until(func(): return shared("joined_a") != null and shared("joined_b") != null,90): fail("other client never joined");return
	await until(func(): return mode.state.editors.size() >= 2,10)
	result.editors = mode.state.editors.keys()
	await capture("joined")
	if role == "a": await role_a(mode)
	else: await role_b(mode)

func role_a(mode: CanvasLayer) -> void:
	var state = mode.state
	var send: Callable = mode.sender()
	var player := Vector2(scene.game.player.x,scene.game.player.y)
	var z := int(scene.game.player.z)
	var forward := Vector2(-sin(scene.yaw),-cos(scene.yaw))
	var spot := (player+forward*4.0).round()
	await create_timer(2.0).timeout
	# 1. Place an approved asset in front of the camera.
	mark("place")
	var sent := wall()
	publish("place_sent",sent)
	var placed: int = state.place(4153,spot.x,spot.y,z,30,send)
	if not await until(func(): return state.requests.get(placed,{}).get("status","") != "pending",10): fail("place unanswered");return
	await until(func(): return mode.latency_ms.size() >= 1,5)
	mark("place-end")
	result.place_latency_ms = mode.latency_ms[-1] if not mode.latency_ms.is_empty() else -1
	await create_timer(1.5).timeout
	await capture("placed")
	# 2. Hide the nearest editable baked decorative static.
	var nearest := {}
	var best := INF
	for at in mode.overlay.districts:
		for record in mode.overlay.districts[at].records:
			var d := Vector2(record.x,record.y).distance_to(spot)
			if d < best and d < 14 and mode.overlay.info_for(record).editable and mode.overlay.info_for(record).kind in ["flower","bush","grass","prop","mushroom","tree","log","rock"]:
				best = d
				nearest = record
	if not nearest.is_empty():
		result.hidden_static = nearest.target
		mode.select(nearest.target,nearest)
		await capture("static-before")
		mark("hide")
		publish("hide_sent",wall())
		var hide: int = state.set_state(nearest.target,"hide","hide",send)
		await until(func(): return state.requests.get(hide,{}).get("status","") != "pending",10)
		await until(func(): return mode.latency_ms.size() >= 2,5)
		mark("hide-end")
		result.hide_latency_ms = mode.latency_ms[-1]
		result.hide_status = state.requests[hide].status
		await create_timer(1.0).timeout
		await capture("static-hidden")
		mode.select("",{})
	# 3. Terrain brush beside the start point; record rebuilt districts and stalls.
	var rebuilt_before: int = mode.overlay.stats.terrain_rebuilt.size()
	mark("brush")
	publish("brush_sent",wall())
	var centre := (player+forward*7.0+Vector2(forward.y,-forward.x)*3.0).round()
	result.brush_centre = [centre.x,centre.y]
	var brush: int = state.brush(int(centre.x),int(centre.y),4,14,"dirt",send)
	await until(func(): return state.requests.get(brush,{}).get("status","") != "pending",10)
	await until(func(): return mode.latency_ms.size() >= 3,10)
	mark("brush-end")
	result.brush_latency_ms = mode.latency_ms[-1]
	result.brush_districts = mode.overlay.stats.terrain_rebuilt.slice(rebuilt_before).map(func(e: Dictionary): return str(e.district))
	result.terrain_job_us = mode.overlay.stats.terrain_job_us
	result.terrain_swap_us = mode.overlay.stats.terrain_swap_us
	result.readback_us = mode.overlay.stats.readback_us
	result.static_apply_us = mode.overlay.stats.static_apply_us
	await create_timer(1.0).timeout
	await capture("terrain")
	# 4. Observe B's shared preview.
	publish("ready_for_preview",wall())
	if await until(func(): return not state.previews.is_empty() and state.previews.keys().any(func(a: String): return a != state.me),20):
		await create_timer(1.0).timeout
		await capture("sees-b-preview")
		result.saw_b_preview = state.previews
	publish("a_done",wall())
	await until(func(): return shared("b_done") != null,30)
	# Return every edit this run made to baseline.
	for target in state.targets.keys():
		if state.author_of(target) == state.me and state.state_of(target) != "":
			var reset: int = state.set_state(target,"","restore",send)
			await until(func(): return state.requests.get(reset,{}).get("status","") != "pending",10)
	# Frame windows run from each command to its visible result, before any
	# screenshot is encoded.
	result.windows = {}
	for i in marks.size():
		if not str(marks[i].name).ends_with("-end") and i+1 < marks.size(): result.windows[marks[i].name] = frame_window(marks[i].frame,marks[i+1].frame+1)
	finish(0)

func role_b(mode: CanvasLayer) -> void:
	var state = mode.state
	var arrivals := {}
	var frame_at := {}
	state.targets_changed.connect(func(targets: Array, seq: int, author: String, action: String):
		if author == state.me or action == "sync": return
		arrivals[action] = {"seq":seq,"received":wall(),"targets":targets.size()}
		frame_at[action] = frames.size())
	# Edit-to-visible on this client: A's send time to B's next drawn frame
	# after the overlay applied (terrain: after its rebuild swapped in).
	for entry in [["place","place_sent"],["hide","hide_sent"],["brush","brush_sent"]]:
		if not await until(func(): return arrivals.has(entry[0]),40): continue
		while not mode.overlay.idle(): await process_frame
		await RenderingServer.frame_post_draw
		var sent: Variant = shared(entry[1])
		result[entry[0]+"_cross_client_ms"] = wall()-float(sent) if sent != null else -1
		result[entry[0]+"_frames"] = frame_window(int(frame_at[entry[0]]),frames.size())
		await create_timer(1.0).timeout
		await capture("sees-a-"+entry[0])
	result.b_terrain_rebuilt = mode.overlay.stats.terrain_rebuilt.map(func(e: Dictionary): return str(e.district))
	await until(func(): return shared("ready_for_preview") != null,30)
	var player := Vector2(scene.game.player.x,scene.game.player.y)
	state.preview("n","a:3204:%s:%s:%d:0" % [State_number(player.x-1.0),State_number(player.y+1.0),int(scene.game.player.z)],mode.sender())
	await create_timer(3.0).timeout
	await capture("own-preview")
	await until(func(): return shared("a_done") != null,30)
	state.clear_preview(mode.sender())
	publish("b_done",wall())
	finish(0)

static func State_number(value: float) -> String:
	return preload("res://DevEdit/DevEditState.gd").number(value)
