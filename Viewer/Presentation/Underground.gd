extends Node
# Dungeons and caves in 3D (docs/DUNGEONS.md). UO marks underground space
# with its black void land (0x244) and cave land; the 2D client simply draws
# the void black. Here, from the converted map (BRW chunks, read directly):
#  - the player is underground near such land (with hysteresis), and the
#    lighting rig blends to darkness: no sky or sun, black fog, a carried light;
#  - districts holding void/cave land draw their terrain as a cave
#    (CaveGround.gdshader), its walls fading into darkness above the head;
#  - every mountain entrance (the invisible 0x3B60-0x3B83 blocker tiles laid
#    in front of it) gains a rock-framed opening with a dark tunnel.
# Client presentation only: positions, movement and the server are unchanged.
const VOID_LAND := 0x244
const ENTRANCE_FIRST := 0x3B60
const ENTRANCE_LAST := 0x3B83
const ENTER_SCORE := 6
const DISTRICT_SCORE := 48
const LAND_BYTES := 24
const STATIC_BYTES := 24+64*64*3
var folder := ""
var elevation := 0.2
var cave_land: Dictionary = {}
var chunks: Dictionary = {}
var districts: Dictionary = {}
var cave_material: ShaderMaterial
var inside := false
var depth := 0.0
var cell := Vector2i(-100000,-100000)

func setup(dataset: String, world: Dictionary) -> void:
	folder = dataset
	elevation = float(world.get("elevationScale",0.2))
	for id in world.get("landData",{}):
		if str(world.landData[id].get("name","")) == "cave": cave_land[int(id)] = true
	cave_material = ShaderMaterial.new()
	cave_material.shader = preload("res://Presentation/CaveGround.gdshader")
	var surfaces := preload("res://Presentation/SurfaceLibrary.gd")
	surfaces.bind(cave_material,"rock","rock_face_03")
	surfaces.bind(cave_material,"gravel","stony_dirt_path")
	surfaces.bind(cave_material,"flag","medieval_blocks_02")
	surfaces.bind(cave_material,"moss","forest_ground_05")

func bytes(at: Vector2i) -> PackedByteArray:
	if chunks.has(at): return chunks[at]
	var path := folder.path_join("%d_%d.brw" % [at.x,at.y])
	var data := FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else PackedByteArray()
	if data.size() < STATIC_BYTES or data.decode_u32(0) != 0x31575242: data = PackedByteArray()
	if chunks.size() > 48: chunks.erase(chunks.keys()[0])
	chunks[at] = data
	return data

static func owner(at: Vector2i) -> Vector2i:
	return Vector2i(floori(at.x/64.0)*64,floori(at.y/64.0)*64)

func land(at: Vector2i) -> Vector2i:
	var chunk := owner(at)
	var data := bytes(chunk)
	if data.is_empty(): return Vector2i(-1,0)
	var offset := LAND_BYTES+((at.y-chunk.y)*64+(at.x-chunk.x))*3
	return Vector2i(data.decode_u16(offset),data.decode_s8(offset+2))

func underground_land(id: int) -> bool:
	return id == VOID_LAND or cave_land.has(id)

func score(at: Vector2i, radius: int, step: int) -> int:
	var count := 0
	for dy in range(-radius,radius+1,step):
		for dx in range(-radius,radius+1,step):
			if underground_land(land(at+Vector2i(dx,dy)).x): count += 1
	return count

func district_underground(at: Vector2i) -> bool:
	if districts.has(at): return districts[at]
	var data := bytes(at)
	var count := 0
	if not data.is_empty():
		for i in 4096:
			if underground_land(data.decode_u16(LAND_BYTES+i*3)): count += 1
	districts[at] = count >= DISTRICT_SCORE
	return districts[at]

# Called every frame with the player's tile and feet height; returns how far
# the presentation is underground (0 outside .. 1 inside), eased over ~1.5 s.
func update(at: Vector2i, feet: float, delta: float) -> float:
	if at != cell:
		cell = at
		if inside: inside = underground_land(land(at).x) or score(at,18,3) > 0
		else: inside = underground_land(land(at).x) or score(at,12,2) >= ENTER_SCORE
	depth = move_toward(depth,1.0 if inside else 0.0,delta/1.5)
	cave_material.set_shader_parameter("viewer_height",feet)
	cave_material.set_shader_parameter("enclosure",depth)
	return depth

# LiveDistricts calls this for each district it shows (near and far).
func dress(kind: String, at: Vector2i, node: Node3D) -> void:
	if kind == "macro": return
	if district_underground(at):
		for mesh: MeshInstance3D in node.find_children("*","MeshInstance3D",true,false):
			if _ground(mesh.material_override): mesh.material_override = cave_material
			elif mesh.mesh:
				for surface in mesh.mesh.get_surface_count():
					if _ground(mesh.get_surface_override_material(surface)) or _ground(mesh.mesh.surface_get_material(surface)): mesh.set_surface_override_material(surface,cave_material)
	if kind != "near": return
	for entrance in entrances(at):
		var mouth := build_mouth(entrance)
		node.add_child(mouth)
		# Entrance transforms are in the stream's frame (source tiles), like
		# the district nodes themselves.
		mouth.transform = node.transform.affine_inverse()*entrance.transform

static func _ground(material: Material) -> bool:
	return material is ShaderMaterial and material.shader and material.shader.resource_path == "res://Presentation/Ground.gdshader"

# Entrances whose blocker cluster is centred in this district: where the
# hillside starts to rise behind the blockers, facing downhill.
func entrances(at: Vector2i) -> Array:
	var blockers: Array[Vector2i] = []
	var own := false
	for dy in range(-1,2):
		for dx in range(-1,2):
			var chunk := at+Vector2i(dx,dy)*64
			var data := bytes(chunk)
			if data.is_empty(): continue
			for i in data.decode_u32(20):
				var offset := STATIC_BYTES+i*7
				var id := data.decode_u16(offset)
				if id < ENTRANCE_FIRST or id > ENTRANCE_LAST: continue
				blockers.append(chunk+Vector2i(data.decode_u8(offset+2),data.decode_u8(offset+3)))
				if dx == 0 and dy == 0: own = true
	if not own: return []
	var result: Array = []
	for cluster in clusters(blockers):
		var center := Vector2.ZERO
		for tile in cluster: center += Vector2(tile)+Vector2(0.5,0.5)
		center /= cluster.size()
		if owner(Vector2i(center.floor())) != at: continue
		var entrance := place(center,cluster)
		if not entrance.is_empty(): result.append(entrance)
	return result

static func clusters(tiles: Array[Vector2i]) -> Array:
	var open: Dictionary = {}
	for tile in tiles: open[tile] = true
	var result: Array = []
	while not open.is_empty():
		var seed: Vector2i = open.keys()[0]
		open.erase(seed)
		var group: Array[Vector2i] = [seed]
		var index := 0
		while index < group.size():
			for dy in range(-2,3):
				for dx in range(-2,3):
					var next: Vector2i = group[index]+Vector2i(dx,dy)
					if open.has(next):
						open.erase(next)
						group.append(next)
			index += 1
		result.append(group)
	return result

func height(at: Vector2) -> float:
	var base := Vector2i(at.floor())
	var f := at-Vector2(base)
	var a := float(land(base).y)
	var b := float(land(base+Vector2i.RIGHT).y)
	var c := float(land(base+Vector2i.DOWN).y)
	var d := float(land(base+Vector2i.ONE).y)
	return lerpf(lerpf(a,b,f.x),lerpf(c,d,f.x),f.y)*elevation

func place(center: Vector2, cluster: Array) -> Dictionary:
	# Uphill: the height gradient around the cluster.
	var uphill := Vector2.ZERO
	var base := height(center)
	for dy in range(-6,7):
		for dx in range(-6,7):
			var offset := Vector2(dx,dy)
			if offset == Vector2.ZERO: continue
			uphill += offset.normalized()*(height(center+offset)-base)/offset.length()
	if uphill.length() < 0.5: return {}
	uphill = uphill.normalized()
	# Walk uphill to the foot of the rise (2 m above the cluster's ground).
	var foot := center
	var found := false
	for step in 16:
		var probe := center+uphill*(step*0.5)
		if height(probe) >= base+2.0:
			foot = center+uphill*maxf(0.0,step*0.5-1.0)
			found = true
			break
	if not found: return {}
	var across := Vector2(-uphill.y,uphill.x)
	var low := INF
	var high := -INF
	for tile in cluster:
		var side := (Vector2(tile)+Vector2(0.5,0.5)-center).dot(across)
		low = minf(low,side)
		high = maxf(high,side)
	var width := clampf((high-low)*0.55+1.6,2.6,4.6)
	var floor_y := height(foot)
	var outward := Vector3(-uphill.x,0,-uphill.y)
	var basis := Basis.looking_at(-outward,Vector3.UP)
	var position := Vector3(foot.x,floor_y,foot.y)
	return {"transform":Transform3D(basis,position),"width":width,"height":clampf(width*0.78,2.3,3.4)}

# The opening: an arched rock frame, tunnel walls that darken with depth and
# a black back wall. Local space: +Z faces out of the hill, X across, Y up.
static var mouth_material: ShaderMaterial
static var frame_material: StandardMaterial3D
static func build_mouth(entrance: Dictionary) -> Node3D:
	if mouth_material == null:
		mouth_material = ShaderMaterial.new()
		mouth_material.shader = preload("res://Presentation/CaveMouth.gdshader")
		preload("res://Presentation/SurfaceLibrary.gd").bind(mouth_material,"rock","rock_face_03")
		frame_material = StandardMaterial3D.new()
		frame_material.albedo_color = Color("8f877c")
		frame_material.roughness = 0.92
		frame_material.uv1_triplanar = true
		frame_material.uv1_world_triplanar = true
		frame_material.uv1_scale = Vector3.ONE*0.37
		frame_material.albedo_texture = mouth_material.get_shader_parameter("rock_albedo")
		frame_material.normal_enabled = true
		frame_material.normal_texture = mouth_material.get_shader_parameter("rock_normal")
	var width: float = entrance.width
	var tall: float = entrance.height
	var depth := 2.6
	var outline := arch(width,tall)
	var root := Node3D.new()
	root.name = "CaveMouth"
	root.set_meta("cave_mouth",true)
	# Tunnel and back wall.
	var tunnel := SurfaceTool.new()
	tunnel.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size()-1:
		var a := outline[i]
		var b := outline[i+1]
		for corner in [[a,0.0],[b,0.0],[b,1.0],[a,0.0],[b,1.0],[a,1.0]]:
			tunnel.set_uv(Vector2(corner[1],0))
			tunnel.add_vertex(Vector3(corner[0].x,corner[0].y,-depth*corner[1]))
	# The arch is convex: a fan closes the back wall.
	var middle := Vector2(0,tall*0.4)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i+1)%outline.size()]
		for point in [middle,a,b]:
			tunnel.set_uv(Vector2(1,0))
			tunnel.add_vertex(Vector3(point.x,point.y,-depth))
	var inner := MeshInstance3D.new()
	inner.name = "Opening"
	inner.mesh = tunnel.commit()
	inner.material_override = mouth_material
	inner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inner)
	# Frame: a rough rock band around the arch, reaching back into the hill.
	var frame := SurfaceTool.new()
	frame.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector2(0,tall-width*0.5)
	var rough := FastNoiseLite.new()
	rough.seed = int(entrance.transform.origin.x*31+entrance.transform.origin.z*17)
	rough.frequency = 0.9
	var outer: Array[Vector2] = []
	for point in outline:
		var away := (point-Vector2(0,minf(point.y,center.y))).normalized()
		if point.y <= center.y: away = Vector2(signf(point.x),0)
		outer.append(point+away*(0.55+0.35*rough.get_noise_2d(point.x*3,point.y*3)))
	for i in outline.size()-1:
		var a := outline[i]
		var b := outline[i+1]
		var c := outer[i+1]
		var d := outer[i]
		var front := 0.25
		_quad(frame,Vector3(a.x,a.y,front),Vector3(d.x,d.y,front+0.15),Vector3(c.x,c.y,front+0.15),Vector3(b.x,b.y,front))
		_quad(frame,Vector3(d.x,d.y,front+0.15),Vector3(d.x,d.y,-1.6),Vector3(c.x,c.y,-1.6),Vector3(c.x,c.y,front+0.15))
		_quad(frame,Vector3(a.x,a.y,front),Vector3(b.x,b.y,front),Vector3(b.x,b.y,-0.2),Vector3(a.x,a.y,-0.2))
	frame.generate_normals()
	var band := MeshInstance3D.new()
	band.name = "Frame"
	band.mesh = frame.commit()
	band.material_override = frame_material
	root.add_child(band)
	return root

static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point in [a,b,c,a,c,d]: tool.add_vertex(point)

# A round-topped arch from the left foot over to the right foot (below ground
# level, so the opening meets uneven land).
static func arch(width: float, tall: float) -> PackedVector2Array:
	var r := width*0.5
	var spring := tall-r
	var points := PackedVector2Array([Vector2(-r,-0.8),Vector2(-r,spring)])
	for i in range(1,12):
		var angle := PI-PI*i/12.0
		points.append(Vector2(cos(angle)*r,spring+sin(angle)*r))
	points.append(Vector2(r,spring))
	points.append(Vector2(r,-0.8))
	return points
