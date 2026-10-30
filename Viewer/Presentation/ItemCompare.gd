extends SceneTree
# Renders what this client draws for catalogue graphics from the classic
# isometric viewpoint (south-east, looking north-west), one PNG per graphic,
# for side-by-side review against the original art (scripts/compare-items.py).
#   --catalog=PATH  --out=DIR  --ids=1,2,3
# Floors, roofs, lava and water are shown as a 3x3 patch, walls as a 3-cell run.
const Provenance := preload("res://Presentation/ArtProvenance.gd")
const PATCH := ["floor","roof","lava","water","landing","carpet"]
const RUN := ["wall","window","corner","trim","fence","arch"]

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := {}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.trim_prefix("--").split("=",true,1)
		if parts.size() == 2: args[parts[0]] = parts[1]
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(args.catalog).trim_prefix("window.CATALOG=").trim_suffix(";"))
	var items := {}
	for item in catalog.items: items[int(item.id)] = item
	DirAccess.make_dir_recursive_absolute(args.out)
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
	stage.add_child(camera)
	var done := 0
	for text in str(args.ids).split(","):
		var id := int(text)
		if not items.has(id): continue
		var item: Dictionary = items[id]
		# The catalogue shows empty tiledata names as "unnamed"; the client sees "".
		var data := {str(id):{"name":"" if str(item.name) == "unnamed" else str(item.name),"height":int(item.height),"flags":Provenance.flag_bits(item.flags)}}
		var world := {"elevationScale":0.2,"originX":100,"originY":100,"width":8,"height":8,"terrain":[],"statics":[],"staticData":data,"landData":{}}
		var probe := preload("res://Presentation/Reconstruction.gd").new()
		probe.index({"elevationScale":0.2,"originX":100,"originY":100,"width":8,"height":8,"terrain":[],"statics":[{"x":103,"y":103,"z":0,"id":id}],"staticData":data,"landData":{}})
		var kind := str(probe.rule_for(id).get("kind",""))
		var cells := [Vector2i(103,103)]
		if kind in PATCH: cells = [Vector2i(102,102),Vector2i(103,102),Vector2i(104,102),Vector2i(102,103),Vector2i(103,103),Vector2i(104,103),Vector2i(102,104),Vector2i(103,104),Vector2i(104,104)]
		elif kind in RUN: cells = [Vector2i(102,103),Vector2i(103,103),Vector2i(104,103)] if str(probe.rule_for(id).get("axis","x")) == "x" else [Vector2i(103,102),Vector2i(103,103),Vector2i(103,104)]
		for cell in cells: world.statics.append({"x":cell.x,"y":cell.y,"z":0,"id":id})
		var recon := preload("res://Presentation/Reconstruction.gd").new()
		recon.index(world)
		var holder := Node3D.new()
		stage.add_child(holder)
		for i in world.statics.size():
			var node: Node3D = recon.build(world.statics[i],world,i)
			if node: holder.add_child(node)
		var box := AABB()
		var first := true
		for mesh in holder.find_children("*","VisualInstance3D",true,false):
			var part: AABB = mesh.global_transform*mesh.get_aabb()
			box = part if first else box.merge(part)
			first = false
		if first: box = AABB(Vector3(3,0,3),Vector3(1,0.2,1))
		var centre := box.get_center()
		camera.size = maxf(1.2,maxf(box.size.y*1.25,Vector2(box.size.x,box.size.z).length()*1.05))
		camera.position = centre+Vector3(1,0.85,1).normalized()*30.0
		camera.look_at(centre)
		for frame in 3: await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(str(args.out).path_join("%d.png" % id))
		holder.free()
		done += 1
	print("ITEM COMPARE: %d renders" % done)
	quit(0)
