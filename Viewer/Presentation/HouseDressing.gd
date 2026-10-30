extends RefCounted
# Lived-in dressing for houses (classic and custom), added around the shell
# MultiPresenter builds tile by tile from the server layout. Nothing here
# touches the layout itself: walls, floors, stairs and doors stay exactly the
# server's, and every piece sits outside the walls or on the roof.
# - a stone chimney stack on the ridge end, with drifting smoke;
# - window boxes of flowers under the windows, facing out;
# - warm hanging lanterns either side of the front steps;
# - shrubs and flower clumps along the sides and back, never in front;
# - ivy climbing a couple of masonry corners.
# Choices are seeded by the house serial, so a house always looks the same.
const Crafted = preload("res://Presentation/CraftedProps.gd")
const FLOWERS := ["Reduced/flower_gazania/flower_gazania_0.gltf","Reduced/flower_gazania/flower_gazania_1.gltf","Reduced/flower_empodium/flower_empodium_0.gltf","Reduced/periwinkle_plant/periwinkle_plant_0.gltf","Reduced/periwinkle_plant/periwinkle_plant_2.gltf"]
const SHRUBS := ["Objaverse/juniper/juniper.glb","Objaverse/hedge_scan/hedge_scan.glb"]
const MASONRY := ["stone","brick","sandstone","marble","dungeon","cave","basalt"]

# parts: [graphic, dx, dy, dz] relative to the multi; local positions follow
# Reconstruction.build minus MultiPresenter's anchor offset.
static func dress(root: Node3D, parts: Array, recon: RefCounted, world: Dictionary, serial: int, chimney := true) -> void:
	var origin := Vector2(float(world.originX),float(world.originY))
	var scale := float(world.elevationScale)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = serial
	var walls := {}
	var windows: Array = []
	var roofs: Array = []
	var stairs: Array = []
	var cells := {}
	var low := Vector2i(100000,100000)
	var high := Vector2i(-100000,-100000)
	var base_z := 1000
	var masonry := 0
	var total_walls := 0
	for part in parts:
		var g := int(part[0])
		var at := Vector2i(int(part[1]),int(part[2]))
		var kind := str(recon.rule_for(g).get("kind",""))
		if kind == "": continue
		# Inside means walls, floors and steps; roof eaves overhang the outside.
		if kind != "roof":
			cells[at] = true
			low = low.min(at)
			high = high.max(at)
		match kind:
			"wall","corner","window","trim":
				walls[at] = true
				base_z = mini(base_z,int(part[3]))
				total_walls += 1
				var name := str(world.staticData.get(str(g),{}).get("name",""))
				if preload("res://Presentation/Facade.gd").family_for(name) in MASONRY: masonry += 1
				if kind == "window": windows.append(part)
			"roof": roofs.append(part)
			"stairs","landing": stairs.append(part)
	if walls.is_empty(): return
	var dressing := Node3D.new()
	dressing.name = "HouseDressing"
	root.add_child(dressing)
	var local := func(dx: float, dy: float, dz: float) -> Vector3:
		return Vector3(dx-origin.x+0.5,dz*scale,dy-origin.y+0.5)
	# The front: the side the lowest stairs stand on (south by default).
	var front := Vector2i(0,1)
	var steps: Array = stairs.filter(func(p): return int(p[3]) <= base_z+6)
	if not steps.is_empty():
		var s: Array = steps[0]
		var centre := Vector2(low+high)/2.0
		var off := Vector2(float(s[1])-centre.x,float(s[2])-centre.y)
		front = Vector2i(signi(int(off.x)),0) if absf(off.x)/maxf(1.0,float(high.x-low.x)) > absf(off.y)/maxf(1.0,float(high.y-low.y)) else Vector2i(0,signi(int(off.y)))
		if front == Vector2i.ZERO: front = Vector2i(0,1)
	if chimney: _chimney(dressing,roofs,local,rnd,scale)
	_window_boxes(dressing,windows,walls,cells,local,rnd,scale)
	_lanterns(dressing,steps,front,local,scale,base_z)
	_garden(dressing,low,high,front,local,rnd)
	if masonry*2 >= total_walls: _ivy(dressing,low,high,front,local,rnd,base_z)

static func _fitted(path: String, size: Vector3) -> Node3D:
	if not ResourceLoader.exists("res://Art/"+path): return null
	var model: Node3D = (load("res://Art/"+path) as PackedScene).instantiate()
	var box := AABB()
	var first := true
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		var part: AABB = (mesh as MeshInstance3D).transform*(mesh as MeshInstance3D).get_aabb()
		box = part if first else box.merge(part)
		first = false
	# Plants keep their height; very wide ones are held to 1.5x the given width.
	var k := minf(size.y/maxf(box.size.y,0.001),1.5*minf(size.x/maxf(box.size.x,0.001),size.z/maxf(box.size.z,0.001)))
	var holder := Node3D.new()
	model.scale = Vector3.ONE*k
	model.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*k
	holder.add_child(model)
	return holder

# Chimney on the highest roof tile nearest a ridge end, smoking gently.
static func _chimney(parent: Node3D, roofs: Array, local: Callable, rnd: RandomNumberGenerator, scale: float) -> void:
	if roofs.is_empty(): return
	var top := 0
	for p in roofs: top = maxi(top,int(p[3]))
	var ridge: Array = roofs.filter(func(p): return int(p[3]) >= top-3)
	var pick: Array = ridge[0]
	for p in ridge:
		if int(p[1])+int(p[2]) > int(pick[1])+int(pick[2]): pick = p
	var at: Vector3 = local.call(float(pick[1]),float(pick[2]),float(pick[3]))
	var stack := Node3D.new()
	stack.name = "Chimney"
	stack.position = at+Vector3(0,0.15,0)
	var stone := Crafted._mat("castle_wall_varriation",Color("b8b0a4"),0.0,0.9,2.0)
	Crafted._box(stack,Vector3(0.62,1.5,0.62),Vector3(0,0.55,0),stone)
	Crafted._box(stack,Vector3(0.74,0.12,0.74),Vector3(0,1.36,0),stone)
	for x in [-0.14,0.14]: Crafted._cyl(stack,0.08,0.22,Vector3(x,1.52,0),Crafted._mat("medieval_red_brick",Color("9a6a52"),0.0,0.9,6.0),Vector3.ZERO,-1,10)
	var smoke := GPUParticles3D.new()
	smoke.amount = 26
	smoke.lifetime = 6.0
	smoke.position = Vector3(0,1.7,0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.25,1,0.1)
	process.spread = 12.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.12,0.05,0.05)
	process.damping_min = 0.05
	process.damping_max = 0.1
	var grow := Curve.new(); grow.add_point(Vector2(0,0.35)); grow.add_point(Vector2(1,2.4))
	var grow_texture := CurveTexture.new(); grow_texture.curve = grow
	process.scale_curve = grow_texture
	var fade := Gradient.new()
	fade.set_color(0,Color(0.82,0.8,0.78,0.5)); fade.set_color(1,Color(0.75,0.75,0.75,0.0))
	var ramp := GradientTexture1D.new(); ramp.gradient = fade
	process.color_ramp = ramp
	smoke.process_material = process
	var quad := QuadMesh.new(); quad.size = Vector2(0.55,0.55)
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.vertex_color_use_as_albedo = true
	look.albedo_texture = preload("res://Presentation/ShipMotion.gd").soft_dot()
	quad.material = look
	smoke.draw_pass_1 = quad
	smoke.preprocess = 6.0
	stack.add_child(smoke)
	parent.add_child(stack)

# Window boxes on the outside face of each window, at sill height.
static func _window_boxes(parent: Node3D, windows: Array, walls: Dictionary, cells: Dictionary, local: Callable, rnd: RandomNumberGenerator, scale: float) -> void:
	var done := {}
	for p in windows:
		var at := Vector2i(int(p[1]),int(p[2]))
		var key := Vector3i(at.x,at.y,int(p[3]))
		if done.has(key): continue
		done[key] = true
		# Outside is the neighbour with no building tile at all.
		var out := Vector2i.ZERO
		for side in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
			if not cells.has(at+side):
				out = side
				break
		if out == Vector2i.ZERO: continue
		var box := Node3D.new()
		box.name = "WindowBox"
		var centre: Vector3 = local.call(float(at.x),float(at.y),float(p[3]))
		box.position = centre+Vector3(out.x*0.62,0.95,out.y*0.62)
		box.rotation.y = atan2(float(out.x),float(out.y))
		var wood := Crafted._mat("medieval_wood",Color("8a6a4a"),0.0,0.85,4.0)
		Crafted._box(box,Vector3(0.78,0.2,0.24),Vector3(0,0,0),wood)
		Crafted._box(box,Vector3(0.7,0.04,0.18),Vector3(0,0.1,0),Crafted._mat("brown_mud_dry",Color("4a3426"),0.0,0.95,6.0))
		for i in 3:
			var bloom := _fitted(FLOWERS[rnd.randi()%FLOWERS.size()],Vector3(0.3,0.32,0.22))
			if bloom:
				bloom.position = Vector3(-0.24+i*0.24,0.1,0)
				bloom.rotation.y = rnd.randf()*TAU
				box.add_child(bloom)
		parent.add_child(box)

# Hanging lanterns on short iron posts either side of the front steps.
static func _lanterns(parent: Node3D, steps: Array, front: Vector2i, local: Callable, scale: float, base_z: int) -> void:
	if steps.is_empty(): return
	var low := Vector2i(100000,100000)
	var high := Vector2i(-100000,-100000)
	for s in steps:
		low = low.min(Vector2i(int(s[1]),int(s[2])))
		high = high.max(Vector2i(int(s[1]),int(s[2])))
	var across := Vector2i(1,0) if front.y != 0 else Vector2i(0,1)
	var outer := low if front.x < 0 or front.y < 0 else high
	for end in [low-across,high+across]:
		var cell := Vector2i(end.x if across.x != 0 else outer.x,end.y if across.y != 0 else outer.y)
		var post := Node3D.new()
		post.name = "DoorLantern"
		post.position = local.call(float(cell.x),float(cell.y),float(base_z))
		var iron := Crafted._steel("2c2a28")
		Crafted._cyl(post,0.035,2.1,Vector3(0,1.05,0),iron,Vector3.ZERO,-1,8)
		Crafted._box(post,Vector3(0.05,0.05,0.4),Vector3(0,2.05,-front.y*0.18-front.x*0.0),iron)
		var lamp := _fitted("Objaverse/lantern_hanging_metal/lantern_hanging_metal.glb",Vector3(0.28,0.42,0.28))
		if lamp:
			lamp.position = Vector3(front.x*0.0,1.62,0)
			post.add_child(lamp)
		var light := OmniLight3D.new()
		light.light_color = Color("ffbe6e"); light.light_energy = 0.9; light.omni_range = 5.0
		light.position = Vector3(0,1.8,0)
		post.add_child(light)
		parent.add_child(post)

# Shrubs and flowers just outside the footprint, along the sides and back.
static func _garden(parent: Node3D, low: Vector2i, high: Vector2i, front: Vector2i, local: Callable, rnd: RandomNumberGenerator) -> void:
	var ring: Array = []
	for x in range(low.x,high.x+1):
		ring.append([Vector2i(x,low.y-1),Vector2i(0,-1)])
		ring.append([Vector2i(x,high.y+1),Vector2i(0,1)])
	for y in range(low.y,high.y+1):
		ring.append([Vector2i(low.x-1,y),Vector2i(-1,0)])
		ring.append([Vector2i(high.x+1,y),Vector2i(1,0)])
	var garden := Node3D.new()
	garden.name = "Garden"
	for entry in ring:
		if entry[1] == front: continue
		if rnd.randf() > 0.7: continue
		var cell: Vector2i = entry[0]
		var shrub := rnd.randf() < 0.45
		var piece := _fitted(SHRUBS[rnd.randi()%SHRUBS.size()] if shrub else FLOWERS[rnd.randi()%FLOWERS.size()],Vector3(1.2,1.1+rnd.randf()*0.5,1.2) if shrub else Vector3(0.85,0.6,0.85))
		if piece == null: continue
		piece.position = local.call(float(cell.x),float(cell.y),0.0)+Vector3(rnd.randf_range(-0.2,0.2),0,rnd.randf_range(-0.2,0.2))
		piece.rotation.y = rnd.randf()*TAU
		garden.add_child(piece)
	parent.add_child(garden)

# Ivy up two of the masonry corners, never the front ones.
static func _ivy(parent: Node3D, low: Vector2i, high: Vector2i, front: Vector2i, local: Callable, rnd: RandomNumberGenerator, base_z: int) -> void:
	var corners := [[Vector2i(low.x,high.y),Vector2i(-1,1)],[Vector2i(high.x,high.y),Vector2i(1,1)],[Vector2i(low.x,low.y),Vector2i(-1,-1)],[Vector2i(high.x,low.y),Vector2i(1,-1)]]
	var used := 0
	for corner in corners:
		var diagonal: Vector2i = corner[1]
		if (front.y != 0 and diagonal.y == front.y) or (front.x != 0 and diagonal.x == front.x): continue
		if used >= 2 or rnd.randf() < 0.25: continue
		var ivy := _fitted("Objaverse/ivy_hanging/ivy_hanging.glb",Vector3(1.1,2.6,0.5))
		if ivy == null: return
		var cell: Vector2i = corner[0]
		ivy.position = local.call(float(cell.x),float(cell.y),float(base_z))+Vector3(diagonal.x*0.52,0,diagonal.y*0.52)
		ivy.rotation.y = atan2(float(diagonal.x),float(diagonal.y))
		parent.add_child(ivy)
		used += 1
