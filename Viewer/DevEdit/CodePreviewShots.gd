extends SceneTree
# Before/after pictures of a code fix preview: renders the same prepared
# district from the published cache and from a preview bake with one camera.
#   -- --before=<near_X_Y.res> [--after=<near_X_Y.res>] --at=x,y,z --out=<prefix>
#      [--views=yaw:pitch:distance;...] [--origin=1088,1408]
# Writes <prefix>-<view>-before.png / -after.png (local, ignored outputs).
var origin := Vector2(1088,1408)

func _initialize() -> void: call_deferred("run")

func point(x: float, y: float, z: float) -> Vector3:
	return Vector3(x-origin.x,z*0.2,y-origin.y)

func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var kv := arg.trim_prefix("--").split("=",true,1)
		if kv.size() == 2: args[kv[0]] = kv[1]
	if args.has("origin"):
		var o: PackedStringArray = args.origin.split(",")
		origin = Vector2(float(o[0]),float(o[1]))
	var at: PackedStringArray = str(args.get("at","0,0,0")).split(",")
	var target := point(float(at[0])+0.5,float(at[1])+0.5,float(at[2]))
	var views: Array = []
	for v in str(args.get("views","45:-30:14;135:-30:14;225:-30:14;315:-30:14")).split(";",false):
		var f: PackedStringArray = v.split(":")
		views.append([float(f[0]),float(f[1]),float(f[2])])
	root.size = Vector2i(1280,800)
	var scene := Node3D.new()
	root.add_child(scene)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50,30,0)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9fc3e6")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color(0.75,0.75,0.8)
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 55
	scene.add_child(camera)
	camera.make_current()
	for phase in ["before","after"]:
		if not args.has(phase): continue
		var resource: Resource = ResourceLoader.load(str(args[phase]),"",ResourceLoader.CACHE_MODE_IGNORE)
		if resource == null or resource.get("root_scene") == null:
			push_error("Cannot load prepared district: "+str(args[phase]))
			quit(1)
			return
		# Prepared districts are a root plus parts, installed progressively in game.
		var district: Node3D = resource.root_scene.instantiate()
		for part in resource.parts: district.add_child(part.instantiate())
		district.show()
		scene.add_child(district)
		for i in views.size():
			var v: Array = views[i]
			var yaw := deg_to_rad(v[0])
			var pitch := deg_to_rad(v[1])
			var offset := Vector3(sin(yaw)*cos(pitch),-sin(pitch),cos(yaw)*cos(pitch))*float(v[2])
			camera.position = target+offset
			camera.look_at(target)
			for f in 4: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("%s-%d-%s.png" % [args.get("out","shot"),i,phase])
		district.free()
		await process_frame
	print("CODE PREVIEW SHOTS: done")
	quit()
