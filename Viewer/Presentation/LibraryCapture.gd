extends SceneTree
# Review renders of every converted library model (one PNG each) for
# scripts/compare-items.py --library. Local only: owner-licensed art.
#   --out=DIR
const Library := preload("res://Presentation/LocalLibrary.gd")

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var out := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): out = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(out)
	root.size = Vector2i(256,256)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("2b261f")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d8dde6")
	settings.ambient_light_energy = 0.75
	environment.environment = settings
	stage.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55,-20,0)
	sun.light_energy = 1.25
	stage.add_child(sun)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.6
	camera.position = Vector3(1,0.85,1).normalized()*20.0+Vector3(0,0.5,0)
	stage.add_child(camera)
	camera.look_at(Vector3(0,0.5,0))
	var count := 0
	for slot in Library.slots():
		for entry in Library.slots()[slot]:
			Library.excluded.clear()
			var node := Library.build(slot,0,0,Vector3(1,1,1),false,str(entry.name))
			if node == null: continue
			stage.add_child(node)
			for frame in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(out.path_join(str(entry.name)+".png"))
			node.free()
			count += 1
	print("LIBRARY CAPTURE: %d models" % count)
	quit(0)
