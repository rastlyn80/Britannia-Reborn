extends SceneTree
# Code fix preview in the running game (graphical, real local ModernUO):
# -- --city --preview=<id>. Opens the preview from the panel, checks the
# changed districts are swapped to the preview bake in place, captures
# after/before pictures at the first example, and switches back.
var scene: Node3D
var passed := 0
var failed := 0
var frames: Array[float] = []
var previous_us := 0

func check(condition: bool, name: String) -> void:
	if condition: passed += 1
	else:
		failed += 1
		print("FAIL ",name)

func _process(_delta: float) -> bool:
	var now := Time.get_ticks_usec()
	if previous_us > 0: frames.append((now-previous_us)/1000.0)
	previous_us = now
	return false

func _initialize() -> void: call_deferred("run")

func until(test: Callable, seconds: float) -> bool:
	var start := Time.get_ticks_msec()
	while not test.call():
		if Time.get_ticks_msec()-start > seconds*1000: return false
		await process_frame
	return true

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	scene.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://../outputs/validation/code-preview-%s.png" % name))
	await process_frame
	await process_frame

func run() -> void:
	var id := "gable-under-roof"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--preview="): id = arg.substr(10)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://../outputs/validation"))
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
	scene.game.return_to_britain()
	await until(func(): return Vector2i(scene.game.player.x,scene.game.player.y) == Vector2i(1602,1591),10)
	var stream: Node3D = scene.city_stream
	if not await until(func(): return stream.settled(),90): return finish("settle")
	var mode: CanvasLayer = scene.dev_edit
	mode.toggle()
	if not await until(func(): return mode.state.synced,15): return finish("join")
	var before: int = stream.reloads
	mode.review(["codepreview "+id],0)
	check(mode.pending.size() == 1 and mode.pending[0].kind == "codepreview","codepreview opens a review card")
	check(mode.overlay.beacons.size() > 0,"example beacons drawn (%d)" % mode.overlay.beacons.size())
	print("CODE PREVIEW LIVE: player %d,%d; loaded %s; previewing %d; reloading %d" % [scene.game.player.x,scene.game.player.y,str(stream.loaded.keys()),stream.preview_districts.size(),stream.reloading.size()])
	var mark := frames.size()
	var swapped: bool = await until(func(): return stream.reloads > before and stream.reloading.is_empty(),120)
	var window: Array = frames.slice(mark)
	window.sort()
	print("CODE PREVIEW LIVE: %d district(s) swapped, worst frame %.0f ms" % [stream.reloads-before,window[-1] if not window.is_empty() else 0.0])
	check(swapped,"nearby changed districts swapped to the preview bake in place")
	var district := Vector2i(1408,1600)
	check(stream.path_for("near",district).contains("previews"),"district 1408,1600 now reads the preview bake")
	scene.distance = 12.0
	scene.pitch = -0.5
	await create_timer(2.0).timeout
	await capture("after")
	mode.show_code(false)
	before = stream.reloads
	check(await until(func(): return stream.reloads > before and stream.reloading.is_empty(),120) and not stream.path_for("near",district).contains("previews"),"Before switches back to the published world")
	await create_timer(2.0).timeout
	await capture("before")
	mode.cancel()
	check(mode.overlay.beacons.is_empty() and not mode.code_row.visible,"Cancel clears the preview card and beacons")
	finish("")

func finish(error: String) -> void:
	if error != "": check(false,error)
	print("CODE PREVIEW LIVE: %d passed, %d failed" % [passed,failed])
	if scene: scene.game.close()
	quit(failed)
