extends RefCounted
# A house multi as one coherent, detailed building, made from its own server
# layout (the component list scripts/prepare-multis.py indexes) and the
# photoscanned surfaces in Art/Surfaces. Every wall stands on its wall cells'
# centre line and every floor at its server height, so what you see is
# exactly where you walk; doors stay the server's own door items, hung in the
# doorway gaps the layout leaves.
#   - a stone plinth to floor level with a projecting cap course;
#   - plank floors;
#   - thick walls in the house's material with real openings: window reveals
#     with oak frames, leaded glass, stone sills and painted shutters; door
#     frames with a small pent canopy on brackets;
#   - plaster houses get an oak frame (sole plate, mid rail, wall plate, corner
#     posts and opening trimmers) and sandstone quoins at the corners;
#   - a clay-tile gable roof with overhanging eaves, exposed rafter tails,
#     fascia, bargeboards, a ridge cap and timber-framed gable ends;
#   - a stone chimney stack with pots and smoke;
#   - stone front steps from the ground to the door.
# The tiles' own names choose the materials: the walls' family (plaster,
# fieldstone, brick, wood siding), the roof covering (clay tiles or wooden
# shingles) and the corners (sandstone quoins, or oak corner posts where the
# layout has wooden posts).
# BakeHouses.gd saves the result per multi id into the ignored
# local-multis/houses folder; MultiPresenter uses the baked scene, or builds
# it on the fly for a supported id.
const SCALE := 0.2
const T := 0.32           # wall thickness (m)
const DOOR_H := 2.52      # door opening height (the server door's DoorwayPlan opening)
const SILL := 0.95        # window sill above the floor
const HEAD := 2.15        # window head above the floor
const WINDOW_W := 0.82
# Every classic house multi ModernUO builds (Houses.cs), reviewed as renders.
const SUPPORTED := [0x64,0x66,0x68,0x6A,0x6C,0x74,0x76,0x78,0x7A,0x7C,0x7E,0x8C,0x96,0x98,0x9A,0x9C,0x9E,0xA0,0xA2]
static var surfaces := {}

static func supported(id: int) -> bool:
	return id in SUPPORTED

# Layout kinds the model draws itself; anything else (fences, counters,
# benches, flowers, posts, signs) keeps its own tile model beside it.
const CONSUMED := ["wall","corner","window","trim","pillar","arch","floor","landing","roof","stairs"]
static func consumes(graphic: int, info: Dictionary) -> bool:
	return str(preload("res://Presentation/RegionalRules.gd").resolve(graphic,info).get("kind","")) in CONSUMED

# World-aligned triplanar photoscan (Art/Surfaces), so neighbouring pieces
# continue the same masonry or plaster without seams.
static func surface(id: String, tint: Color, scale := 0.6, roughness := 0.88) -> StandardMaterial3D:
	var key := "%s/%s/%s" % [id,tint.to_html(),scale]
	if surfaces.has(key): return surfaces[key]
	var m := StandardMaterial3D.new()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Art/Surfaces/manifest.json"))
	for entry in manifest.sets:
		if entry.id != id: continue
		for map in entry.maps:
			if map.role == "albedo": m.albedo_texture = load("res://Art/Surfaces/"+str(map.file))
			if map.role == "normal":
				m.normal_enabled = true
				m.normal_texture = load("res://Art/Surfaces/"+str(map.file))
	m.albedo_color = tint
	m.roughness = roughness
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE*scale
	surfaces[key] = m
	return m

static func _plain(c: Color, metallic := 0.0, roughness := 0.8) -> StandardMaterial3D:
	var key := "plain/%s/%s/%s" % [c.to_html(),metallic,roughness]
	if surfaces.has(key): return surfaces[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	surfaces[key] = m
	return m

static func _box(parent: Node3D, size: Vector3, at: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = m
	mi.position = at
	mi.rotation = rot
	parent.add_child(mi)
	return mi

# Wall family materials (Facade family names).
static func wall_material(family: String) -> StandardMaterial3D:
	match family:
		"stone": return surface("stone_wall",Color("d6cfc2"),0.42)
		"ashlar": return surface("castle_brick_01",Color("d4d0c8"),0.45)
		"sandstone": return surface("medieval_blocks_03",Color("e2cfa8"),0.5)
		"brick": return surface("medieval_red_brick",Color("c09078"),0.6)
		"marble": return surface("marble_01",Color("f4f1ea"),0.3,0.45)
		"wood","log": return surface("weathered_plank_siding",Color("b39a7e"),0.55)
	return surface("mk_limewash",Color("f1eadb"),0.35,0.95)

static func oak() -> StandardMaterial3D: return surface("mk_oak_dark",Color("8a7462"),1.2)
static func stone() -> StandardMaterial3D: return surface("castle_wall_varriation",Color("b9b2a6"),0.45)
static func quoin() -> StandardMaterial3D: return surface("medieval_blocks_03",Color("dccaa2"),0.8)

# parts: [graphic, dx, dy, dz]; tiles: graphic -> {name, height, flags}.
# Returns the building in house coordinates: cell (dx, dy) centre at
# (dx, *, dy), heights in metres (z * 0.2).
static func build(parts: Array, tiles: Dictionary, seed := 0) -> Node3D:
	var Rules := preload("res://Presentation/RegionalRules.gd")
	var Facade := preload("res://Presentation/Facade.gd")
	var rnd := RandomNumberGenerator.new()
	rnd.seed = seed
	var pieces: Array = []    # tall wall tiles: [cell, z, top, family, window]
	var low_pieces: Array = [] # short wall tiles above the ground: [cell, z, top, family]
	var foundation := {}      # Vector2i -> top z
	var flat: Array = []      # floor and landing tiles: [cell, z]
	var roofs: Array = []     # [cell (anchor-shifted), z]
	var stairs: Array = []    # [cell, z, height]
	var gable_family := ""
	var roof_kind := "tile"
	var corners := "quoin"
	for part in parts:
		var g := int(part[0])
		var info: Dictionary = tiles.get(str(g),{})
		var rule: Dictionary = Rules.resolve(g,info)
		var kind := str(rule.get("kind",""))
		var cell := Vector2i(int(part[1]),int(part[2]))
		var z := int(part[3])
		var h := int(info.get("height",0))
		var family := Facade.family_for(str(info.get("name","")))
		var name := str(info.get("name","")).to_lower()
		if "shingle" in name: roof_kind = "shingle"
		if "wooden post" in name: corners = "post"
		match kind:
			"wall","corner","window","trim","pillar","arch":
				# Foundation courses: short pieces that end at ground-floor level.
				if h <= 6 and z+h <= 8: foundation[cell] = maxi(int(foundation.get(cell,0)),z+h)
				elif h >= 10: pieces.append([cell,z,z+h,family,kind == "window"])
				elif h >= 2: low_pieces.append([cell,z,z+h,family])
			"floor","landing": flat.append([cell,z])
			"roof":
				var anchor: Array = rule.get("anchorOffset",[-1,-1])
				roofs.append([cell+Vector2i(int(anchor[0]),int(anchor[1])),z])
			"stairs": stairs.append([cell,z,h])
	var root := Node3D.new()
	root.name = "HouseModel"
	if pieces.is_empty(): return root
	# Short wall tiles: under a pitched roof, those at the eaves and above
	# fill the gables; everywhere else they are walls of their own height
	# (a shop's counter-high front, a loft railing, a roof terrace parapet).
	var eave_z := 100000
	for r in roofs: eave_z = mini(eave_z,int(r[1]))
	for piece in low_pieces:
		if not roofs.is_empty() and int(piece[1]) >= eave_z-1:
			if piece[3] != "": gable_family = piece[3]
		else: pieces.append([piece[0],piece[1],piece[2],piece[3],false])
	# Storeys: wall tiles grouped by the height they stand on (a few z apart
	# still count as one storey). Each storey runs from its floor to the top
	# its own wall tiles reach.
	var storeys: Array = []   # {z, top, walls: {cell: {family, window}}}
	pieces.sort_custom(func(a, b): return int(a[1]) < int(b[1]))
	for piece in pieces:
		var storey: Dictionary = storeys.back() if not storeys.is_empty() and int(piece[1])-int(storeys.back().z) <= 4 else {}
		if storey.is_empty():
			storey = {"z":int(piece[1]),"top":int(piece[2]),"walls":{}}
			storeys.append(storey)
		storey.top = maxi(int(storey.top),int(piece[2]))
		# A tile stacked on a taller one in the same cell does not lower it.
		if storey.walls.has(piece[0]) and int(storey.walls[piece[0]].get("top",0)) >= int(piece[2]): continue
		var known: Dictionary = storey.walls.get(piece[0],{})
		storey.walls[piece[0]] = {"family":piece[3] if piece[3] != "" else str(known.get("family","plaster")),"window":bool(piece[4]) or bool(known.get("window",false)),"top":maxi(int(known.get("top",0)),int(piece[2]))}
	# A storey of short walls only, above the ground, is a parapet round a
	# flat roof or terrace: no openings, no quoins.
	for i in range(1,storeys.size()):
		if int(storeys[i].top)-int(storeys[i].z) < 10: storeys[i].parapet = true
	# The walls' family, the most common over the house.
	var counts := {}
	for storey in storeys:
		for cell in storey.walls: counts[storey.walls[cell].family] = int(counts.get(storey.walls[cell].family,0))+1
	var family: String = counts.keys()[0]
	for f in counts: if int(counts[f]) > int(counts[family]): family = f
	# A fortification (tower, keep, castle) is built of large dressed blocks;
	# fieldstone stays for cottages.
	if family == "stone" and int(counts[family]) >= 120: family = "ashlar"
	var ground: Dictionary = storeys[0]
	var floor_y := float(ground.z)*SCALE
	var low := Vector2i(100000,100000)
	var high := Vector2i(-100000,-100000)
	for cell in ground.walls:
		low = low.min(cell)
		high = high.max(cell)
	var all_low := low
	var all_high := high
	for storey in storeys:
		for cell in storey.walls:
			all_low = all_low.min(cell)
			all_high = all_high.max(cell)
	var centre := Vector2(low+high)/2.0
	# Floors: each floor tile belongs to the storey whose floor it is level
	# with (or the flat roof on top of the last); the rest are stair landings.
	var floors_at: Array = []
	for storey in storeys: floors_at.append({})
	var deck := {}
	var landings: Array = []
	for f in flat:
		var placed := false
		for i in storeys.size():
			if absi(int(f[1])-int(storeys[i].z)) <= 2:
				if storeys[i].has("parapet"): deck[f[0]] = int(f[1])
				else: floors_at[i][f[0]] = int(f[1])
				placed = true
				break
		if placed: continue
		if absi(int(f[1])-int(storeys.back().top)) <= 2: deck[f[0]] = int(f[1])
		else: landings.append([f[0],int(f[1]),0])
	var roofed := {}
	for r in roofs: roofed[r[0]] = true
	var covered := roofed.duplicate()
	for i in range(1,storeys.size()):
		for cell in floors_at[i]: covered[cell] = true
	_plinth(root,foundation,low,high,floor_y)
	var paint: Color = [Color("6e2a26"),Color("2f4a3a"),Color("2c3e5a"),Color("6a5428")][rnd.randi()%4]
	if family in ["wood","log"]: corners = "post"
	var covering := roofing(roof_kind)
	for i in storeys.size():
		var storey: Dictionary = storeys[i]
		var base := float(storey.z)*SCALE
		var top := float(storey.top)*SCALE
		var floors: Dictionary = floors_at[i]
		_floor(root,floors,storey.walls,base,covered if i == 0 else roofed,i > 0)
		var parapet := bool(storey.get("parapet",false))
		_walls(root,storey.walls,floors if not parapet else {},family,base,top,centre,paint,covering,not parapet)
		if family == "plaster" and not parapet: _framing(root,storey.walls,base,top,centre)
		var outer := _outer_corners(storey.walls)
		if corners == "post": _corner_posts(root,outer,base,storey.walls)
		elif not parapet: _quoins(root,outer,base,top,family,storey.walls)
	if not deck.is_empty(): _floor(root,deck,{},float(deck.values()[0])*SCALE,{},true,true)
	# Stairs inside the walls climb between storeys, tile by tile; stairs
	# outside are the front steps up to the ground floor.
	var inside: Array = landings.duplicate()
	var outside: Array = []
	var flight_high := false
	for st in stairs:
		var c: Vector2i = st[0]
		var within: bool = c.x > all_low.x and c.x < all_high.x and c.y > all_low.y and c.y < all_high.y
		if not within and int(st[1]) > int(ground.z)+2: flight_high = true
	for st in stairs:
		var c: Vector2i = st[0]
		var within: bool = c.x > all_low.x and c.x < all_high.x and c.y > all_low.y and c.y < all_high.y
		# Front steps up to the ground floor, unless they are the foot of an
		# outside flight to an upper floor, which is built tile by tile.
		if within or int(st[1]) > int(ground.z)+2 or (flight_high and _touches(stairs,c,int(ground.z)+2)): inside.append([c,int(st[1]),int(st[2]),not within])
		else: outside.append(st)
	_stairs(root,inside,storeys)
	_steps(root,outside,floor_y,centre)
	if not roofs.is_empty():
		# An L- or T-shaped house is roofed as overlapping rectangles, each a
		# gable of its own from its lowest to its highest tiles (cross gables).
		var blocks := _roof_blocks(roofs)
		for block in blocks:
			_roof(root,block,low,high,_eave_of(block),_ridge_of(block),gable_family if gable_family != "" else family,covering)
		_chimney(root,blocks[0],_eave_of(blocks[0]),_ridge_of(blocks[0]),rnd)
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root

# Whether a stair cell joins (through other stair cells) one that climbs
# above the ground floor: the foot of an outside flight.
static func _touches(stairs: Array, start: Vector2i, above: int) -> bool:
	var at := {}
	for st in stairs: at[st[0]] = maxi(int(at.get(st[0],-1000)),int(st[1]))
	var seen := {start:true}
	var open: Array = [start]
	while not open.is_empty():
		var c: Vector2i = open.pop_back()
		if int(at[c]) > above: return true
		for d in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			if at.has(c+d) and not seen.has(c+d):
				seen[c+d] = true
				open.append(c+d)
	return false

static func _eave_of(roofs: Array) -> float:
	var bottom := 100000.0
	for r in roofs: bottom = minf(bottom,float(r[1])*SCALE)
	return bottom

# Interior stairs and landings: each tile a block of stone or oak from the
# storey floor beneath it up to its own top, with a lighter tread, so the
# flight climbs exactly as the tiles do.
static func _stairs(root: Node3D, steps: Array, storeys: Array) -> void:
	if steps.is_empty(): return
	var flight := Node3D.new()
	flight.name = "Stairs"
	root.add_child(flight)
	var body := oak()
	var tread := surface("brown_planks_03",Color("c4a985"),1.2,0.8)
	for st in steps:
		var c: Vector2i = st[0]
		var top_z := int(st[1])+maxi(int(st[2]),1)
		var under := float(storeys[0].z)
		for storey in storeys:
			if float(storey.z) <= float(st[1])+0.5: under = float(storey.z)
		# An outside flight stands on the ground.
		if st.size() > 3 and bool(st[3]): under = 0.0
		var y0 := under*SCALE
		var y1 := float(top_z)*SCALE
		if y1-y0 < 0.05: continue
		_box(flight,Vector3(1.0,y1-y0,1.0),Vector3(c.x,(y0+y1)/2,c.y),body)
		_box(flight,Vector3(1.02,0.05,1.02),Vector3(c.x,y1-0.02,c.y),tread)

static func _plinth(root: Node3D, foundation: Dictionary, low: Vector2i, high: Vector2i, floor_y: float) -> void:
	var base := Node3D.new()
	base.name = "Plinth"
	root.add_child(base)
	var a := Vector2(low)-Vector2(0.5,0.5)
	var b := Vector2(high)+Vector2(0.5,0.5)
	var size := Vector3(b.x-a.x,floor_y,b.y-a.y)
	var mid := Vector3((a.x+b.x)/2,floor_y/2,(a.y+b.y)/2)
	_box(base,size,mid,stone())
	# Cap course: a dressed stone band just proud of the plinth.
	_box(base,Vector3(size.x+0.12,0.14,size.z+0.12),Vector3(mid.x,floor_y-0.07,mid.z),surface("castle_wall_varriation",Color("c4beb4"),0.9))

# Plank floors under cover; stone flags on an open patio or a flat roof.
# Upper floors are thick slabs (their underside is the ceiling below, and
# the soffit of a balcony).
static func _floor(root: Node3D, floors: Dictionary, walls: Dictionary, floor_y: float, covered: Dictionary, upper := false, open_air := false) -> void:
	var boards := surface("brown_planks_03",Color("b49a7a"),0.55,0.8)
	var flags := surface("cobblestone_floor_01",Color("cfc7ba"),0.5,0.9)
	var depth := 0.22 if upper else 0.06
	for cell in floors:
		var open: bool = open_air or (not covered.is_empty() and not covered.has(cell) and not walls.has(cell))
		# A deck in the open (a log cabin's loft) is planked, not flagged.
		if open and upper and not open_air:
			_box(root,Vector3(1.0,depth,1.0),Vector3(cell.x,floor_y-depth/2+0.06,cell.y),boards)
			continue
		_box(root,Vector3(1.0,depth,1.0),Vector3(cell.x,floor_y-depth/2+0.06,cell.y),flags if open else boards)

# Wall arms from each wall cell's centre towards its wall neighbours, with
# window and door openings; doors are gaps between two wall cells in a line.
static func _walls(root: Node3D, walls: Dictionary, floors: Dictionary, family: String, floor_y: float, top: float, centre: Vector2, paint: Color, covering: Material, openings := true) -> void:
	var shell := Node3D.new()
	shell.name = "Walls"
	root.add_child(shell,true)
	var mat := wall_material(family)
	var height := top-floor_y
	var dirs := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
	var doors := {}
	# Doorways are gaps between full-height walls (not between the low walls
	# of a flower bed or a balustrade).
	var tall := func(c: Vector2i) -> bool: return walls.has(c) and (not walls[c].has("top") or float(walls[c].top)*SCALE-floor_y >= DOOR_H+0.3)
	for cell in walls:
		if not tall.call(cell): continue
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			var gap: Vector2i = cell+d
			if not walls.has(gap) and tall.call(gap+d) and floors.has(gap): doors[gap] = d
			# A double door: two open cells between walls in a line.
			elif not walls.has(gap) and not walls.has(gap+d) and tall.call(gap+d*2) and floors.has(gap) and floors.has(gap+d):
				doors[gap] = d
				doors[gap+d] = d
	for cell in walls:
		var w: Dictionary = walls[cell]
		# Each cell rises to its own tiles' top (a half-height log railing
		# round a loft stays half height).
		var cell_top := minf(top,float(w.get("top",9999))*SCALE) if w.has("top") else top
		var h := cell_top-floor_y
		if h < 0.1: continue
		var arms: Array = []
		for d in dirs:
			if walls.has(cell+d) or doors.has(cell+d): arms.append(d)
		if arms.is_empty(): arms = [Vector2i(1,0),Vector2i(-1,0)]
		var glazed: bool = openings and bool(w.window) and _straight(walls,cell) and h >= HEAD+0.3
		_wall_box(shell,Vector3(T,h,T),Vector3(cell.x,floor_y+h/2,cell.y),mat,family,(arms[0] as Vector2i).x != 0)
		for d in arms:
			var along_x: bool = d.x != 0
			var mid := Vector3(cell.x+d.x*0.25,floor_y+h/2,cell.y+d.y*0.25)
			if glazed: _window_arm(shell,cell,d,floor_y,cell_top,mat,family)
			else: _wall_box(shell,Vector3(0.5 if along_x else T,h,T if along_x else 0.5),mid,mat,family,along_x)
		if glazed: _window(shell,cell,walls,floor_y,centre,paint)
	for gap in doors:
		var d: Vector2i = doors[gap]
		# One frame per doorway: a double door's second cell is drawn with the first.
		if doors.has(gap-d): continue
		_doorway(shell,gap,d,floor_y,top,mat,centre,covering,2 if doors.has(gap+d) else 1)

# A piece of wall: a plain box, or for a log house a stack of round logs
# along the wall (one merged mesh per piece), slightly proud of the wall line.
static func _wall_box(parent: Node3D, size: Vector3, at: Vector3, mat: Material, family: String, along_x: bool) -> void:
	if family != "log":
		_box(parent,size,at,mat)
		return
	var length := size.x if along_x else size.z
	var count := maxi(1,roundi(size.y/0.3))
	var r := size.y/count/2.0
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var log := CylinderMesh.new()
	log.top_radius = 1.0
	log.bottom_radius = 1.0
	log.height = 1.0
	log.radial_segments = 10
	log.rings = 1
	for i in count:
		var y := -size.y/2+r*(2*i+1)
		var radius := r*1.12 if (i%2 == 0) else r*1.06
		# The cylinder's own axis (y) is laid along the wall, scaled locally.
		var basis := (Basis(Vector3(0,0,1),PI/2) if along_x else Basis(Vector3(1,0,0),PI/2))*Basis.from_scale(Vector3(radius,length,radius))
		st.append_from(log,0,Transform3D(basis,Vector3(0,y,0)))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = logs()
	mi.position = at
	parent.add_child(mi)

static func logs() -> StandardMaterial3D: return surface("rough_wood",Color("9a7656"),1.6,0.9)

static func _straight(walls: Dictionary, cell: Vector2i) -> bool:
	return (walls.has(cell+Vector2i(1,0)) or walls.has(cell+Vector2i(-1,0))) != (walls.has(cell+Vector2i(0,1)) or walls.has(cell+Vector2i(0,-1)))

# Half an arm of a window cell: solid below the sill and above the head, the
# opening (WINDOW_W wide, centred on the cell) left clear.
static func _window_arm(shell: Node3D, cell: Vector2i, d: Vector2i, floor_y: float, top: float, mat: Material, family := "") -> void:
	var along_x: bool = d.x != 0
	var half := WINDOW_W/2
	var edge := 0.5-half
	var mid_off := half+edge/2
	var side := Vector3(cell.x+d.x*mid_off,floor_y+(top-floor_y)/2,cell.y+d.y*mid_off)
	_wall_box(shell,Vector3(edge if along_x else T,top-floor_y,T if along_x else edge),side,mat,family,along_x)
	var inner := Vector3(cell.x+d.x*half/2,0,cell.y+d.y*half/2)
	_wall_box(shell,Vector3(half if along_x else T,SILL,T if along_x else half),inner+Vector3(0,floor_y+SILL/2,0),mat,family,along_x)
	_wall_box(shell,Vector3(half if along_x else T,top-floor_y-HEAD,T if along_x else half),inner+Vector3(0,floor_y+HEAD+(top-floor_y-HEAD)/2,0),mat,family,along_x)

# Oak frame, cross mullion, leaded glass, stone sill and open painted shutters
# on the outside face.
static func _window(shell: Node3D, cell: Vector2i, walls: Dictionary, floor_y: float, centre: Vector2, paint: Color) -> void:
	var along_x: bool = walls.has(cell+Vector2i(1,0)) or walls.has(cell+Vector2i(-1,0))
	var out := Vector2(0,signf(float(cell.y)-centre.y)) if along_x else Vector2(signf(float(cell.x)-centre.x),0)
	if out == Vector2.ZERO: out = Vector2(0,1) if along_x else Vector2(1,0)
	var win := Node3D.new()
	win.name = "Window"
	win.position = Vector3(cell.x,floor_y,cell.y)
	win.rotation.y = atan2(out.x,out.y)
	shell.add_child(win,true)
	# In this frame +z points out of the house and x runs along the wall.
	var h := HEAD-SILL
	var mid := SILL+h/2
	var glass := _plain(Color("1c262c"),0.35,0.06)
	_box(win,Vector3(WINDOW_W,h,0.03),Vector3(0,mid,0.02),glass)
	var frame := oak()
	for x in [-WINDOW_W/2+0.04,WINDOW_W/2-0.04]: _box(win,Vector3(0.08,h,T+0.06),Vector3(x,mid,0),frame)
	for y in [SILL+0.04,HEAD-0.04]: _box(win,Vector3(WINDOW_W,0.08,T+0.06),Vector3(0,y,0),frame)
	_box(win,Vector3(0.05,h,0.06),Vector3(0,mid,T/2-0.02),frame)
	_box(win,Vector3(WINDOW_W,0.05,0.06),Vector3(0,SILL+h*0.62,T/2-0.02),frame)
	# Leading: a fine diamond lattice over the glass.
	var lead := _plain(Color("3a3a3c"),0.6,0.4)
	for i in 5:
		var x := -WINDOW_W/2+0.08+i*(WINDOW_W-0.16)/4
		_box(win,Vector3(0.012,h*1.15,0.012),Vector3(x,mid,0.04),lead,Vector3(0,0,0.55))
		_box(win,Vector3(0.012,h*1.15,0.012),Vector3(x,mid,0.04),lead,Vector3(0,0,-0.55))
	_box(win,Vector3(WINDOW_W+0.22,0.08,T+0.2),Vector3(0,SILL-0.04,0.08),stone())
	var shutter := surface("wood_shutter",paint,1.4,0.75)
	for side in [-1.0,1.0]:
		var leaf := _box(win,Vector3(WINDOW_W/2,h,0.04),Vector3(side*(WINDOW_W/2+WINDOW_W/4+0.04),mid,T/2+0.03),shutter)
		for y in [SILL+0.18,HEAD-0.18]: _box(win,Vector3(WINDOW_W/2-0.06,0.03,0.015),Vector3(side*(WINDOW_W/2+WINDOW_W/4+0.04),y,T/2+0.06),lead)

# A doorway gap: lintel wall over the opening, oak jambs and head, a threshold
# stone and a small pent canopy on brackets over the outside.
static func _doorway(shell: Node3D, gap: Vector2i, d: Vector2i, floor_y: float, top: float, mat: Material, centre: Vector2, covering: Material, cells := 1) -> void:
	var along_x: bool = d.x != 0
	var over := top-floor_y-DOOR_H
	var mid := Vector2(gap)+Vector2(d)*(cells-1)*0.5
	var span := float(cells)
	_box(shell,Vector3(span if along_x else T,over,T if along_x else span),Vector3(mid.x,floor_y+DOOR_H+over/2,mid.y),mat)
	var out := Vector2(0,signf(mid.y-centre.y)) if along_x else Vector2(signf(mid.x-centre.x),0)
	if out == Vector2.ZERO: out = Vector2(0,1) if along_x else Vector2(1,0)
	var door := Node3D.new()
	door.name = "Doorway"
	door.position = Vector3(mid.x,floor_y,mid.y)
	door.rotation.y = atan2(out.x,out.y)
	shell.add_child(door,true)
	var frame := oak()
	var half := span/2+0.02
	for x in [-half,half]: _box(door,Vector3(0.1,DOOR_H,T+0.08),Vector3(x,DOOR_H/2,0),frame)
	_box(door,Vector3(span+0.24,0.14,T+0.08),Vector3(0,DOOR_H+0.07,0),frame)
	_box(door,Vector3(span+0.2,0.06,T+0.3),Vector3(0,0.03,0.1),stone())
	# Pent canopy: two brackets and a short tiled slope over the door.
	var canopy_y := DOOR_H+0.45
	for x in [-half-0.1,half+0.1]: _box(door,Vector3(0.08,0.08,0.7),Vector3(x,canopy_y-0.2,T/2+0.3),frame,Vector3(-0.55,0,0))
	_box(door,Vector3(span+0.6,0.07,0.85),Vector3(0,canopy_y,T/2+0.38),covering,Vector3(0.38,0,0))

static func roof_tiles() -> StandardMaterial3D: return surface("grey_roof_tiles_02",Color("c0714c"),0.9,0.8)
static func shingles() -> StandardMaterial3D: return surface("roof_09",Color("b8a28a"),0.4,0.85)
static func roofing(kind: String) -> StandardMaterial3D: return shingles() if kind == "shingle" else roof_tiles()

# Oak frame over plaster: sole plate, mid rail, wall plate, posts at corners
# and trimmers either side of each opening, on both faces.
static func _framing(root: Node3D, walls: Dictionary, floor_y: float, top: float, centre: Vector2) -> void:
	var frame := Node3D.new()
	frame.name = "Framing"
	root.add_child(frame)
	var timber := oak()
	var depth := T+0.04
	for cell in walls:
		var along_x: bool = walls.has(cell+Vector2i(1,0)) or walls.has(cell+Vector2i(-1,0))
		var corner: bool = along_x and (walls.has(cell+Vector2i(0,1)) or walls.has(cell+Vector2i(0,-1)))
		var lx := 1.0 if along_x else depth
		var lz := depth if along_x else 1.0
		if not corner:
			for y in [floor_y+0.09,floor_y+2.75,top-0.1]:
				_box(frame,Vector3(lx,0.16,lz),Vector3(cell.x,y,cell.y),timber)
		if corner:
			_box(frame,Vector3(depth,top-floor_y,depth),Vector3(cell.x,floor_y+(top-floor_y)/2,cell.y),timber)
		elif bool(walls[cell].window):
			var ax := Vector3(1,0,0) if along_x else Vector3(0,0,1)
			for s in [-1.0,1.0]:
				_box(frame,Vector3(0.12 if along_x else depth,top-floor_y,depth if along_x else 0.12),Vector3(cell.x,floor_y+(top-floor_y)/2,cell.y)+ax*s*(WINDOW_W/2+0.08),timber)
		elif (cell.x+cell.y)%2 == 0:
			# A stud and a brace in the plain panels.
			_box(frame,Vector3(0.12 if along_x else depth,top-floor_y,depth if along_x else 0.12),Vector3(cell.x,floor_y+(top-floor_y)/2,cell.y),timber)
			_box(frame,Vector3(0.1 if along_x else depth,1.3,depth if along_x else 0.1),Vector3(cell.x,floor_y+3.4,cell.y),timber,Vector3(0,0,0.55) if along_x else Vector3(0.55,0,0))

# The building's corners: wall cells where exactly one wall runs along x and
# one along y (an L, not a T junction), so an L-shaped house gets its inner
# corner and never a post standing in its open patio.
static func _outer_corners(walls: Dictionary) -> Array:
	var result: Array = []
	for cell in walls:
		var x: int = int(walls.has(cell+Vector2i(1,0)))+int(walls.has(cell+Vector2i(-1,0)))
		var y: int = int(walls.has(cell+Vector2i(0,1)))+int(walls.has(cell+Vector2i(0,-1)))
		if x == 1 and y == 1: result.append(cell)
	return result

# Square oak posts at the corners (wood and timber-framed houses), each as
# tall as its corner's wall.
static func _corner_posts(root: Node3D, outer: Array, floor_y: float, walls: Dictionary) -> void:
	for corner in outer:
		var top := float(walls[corner].get("top",0))*SCALE
		if top-floor_y < 0.1: continue
		_box(root,Vector3(T+0.1,top-floor_y+0.05,T+0.1),Vector3(corner.x,floor_y+(top-floor_y)/2,corner.y),oak())

# Long-and-short dressed blocks at the outer corners.
static func _quoins(root: Node3D, outer: Array, floor_y: float, top: float, family: String, walls: Dictionary) -> void:
	if family in ["wood","log","marble","ashlar"]: return
	var mat := quoin()
	var y := floor_y
	var i := 0
	while y < top-0.05:
		var tall := minf(0.34,top-y)
		var long := i%2 == 0
		for corner in outer:
			# Only as high as this corner's own wall, and only on full walls.
			var corner_top := float(walls[corner].get("top",9999))*SCALE
			if corner_top-floor_y < DOOR_H or y >= corner_top-0.05: continue
			# Each block runs back along the wall that leaves the corner.
			var sx := -1.0 if walls.has(corner+Vector2i(1,0)) else 1.0
			var sz := -1.0 if walls.has(corner+Vector2i(0,1)) else 1.0
			_box(root,Vector3(T+0.06+(0.32 if long else 0.0),tall-0.02,T+0.06+(0.0 if long else 0.32)),Vector3(corner.x-sx*(0.16 if long else 0.0),y+tall/2,corner.y-sz*(0.0 if long else 0.16)),mat)
		y += tall
		i += 1

static func _ridge_of(roofs: Array) -> float:
	var top := 0.0
	for r in roofs: top = maxf(top,float(r[1]+3)*SCALE)
	return top

# Splits the roof cells into rectangles: the one covering the most cells not
# yet roofed first, then the next over what is left (it may overlap the
# first, as a cross gable does), until every roof cell is covered.
static func _roof_blocks(roofs: Array) -> Array:
	var cells := {}
	for r in roofs: cells[r[0]] = maxi(int(cells.get(r[0],-1000)),int(r[1]))
	var left := cells.duplicate()
	var blocks: Array = []
	while not left.is_empty() and blocks.size() < 6:
		var best := Rect2i()
		var best_new := 0
		for start in cells:
			var width := 0
			while cells.has(start+Vector2i(width,0)): width += 1
			var rows := 0
			while width >= 2:
				var row_w := 0
				while row_w < width and cells.has(start+Vector2i(row_w,rows)): row_w += 1
				if row_w < 2: break
				width = row_w
				rows += 1
				var rect := Rect2i(start,Vector2i(width,rows))
				var fresh := 0
				for y in rows:
					for x in width:
						if left.has(start+Vector2i(x,y)): fresh += 1
				if fresh > best_new or (fresh == best_new and rect.get_area() > best.get_area()):
					best_new = fresh
					best = rect
		if best_new == 0: break
		var block: Array = []
		for y in best.size.y:
			for x in best.size.x:
				var c := best.position+Vector2i(x,y)
				block.append([c,cells[c]])
				left.erase(c)
		blocks.append(block)
	return blocks

# Gable roof over the roof tiles' footprint: the ridge runs along the axis on
# which the topmost tiles line up; eaves at the lowest tiles.
static func _roof(root: Node3D, roofs: Array, low: Vector2i, high: Vector2i, eave_y: float, ridge_y: float, gable_family: String, covering: StandardMaterial3D) -> void:
	var rlow := Vector2i(100000,100000)
	var rhigh := Vector2i(-100000,-100000)
	var top_cells: Array = []
	for r in roofs:
		rlow = rlow.min(r[0])
		rhigh = rhigh.max(r[0])
	for r in roofs:
		if float(r[1]+3)*SCALE >= ridge_y-0.01: top_cells.append(r[0])
	var ridge_along_z := true
	if not top_cells.is_empty():
		var xs := {}
		for c in top_cells: xs[c.x] = true
		ridge_along_z = xs.size() == 1
	var roof := Node3D.new()
	roof.name = "Roof"
	root.add_child(roof,true)
	# Work in a frame where the ridge runs along local z.
	var a := Vector2(rlow)-Vector2(0.5,0.5)
	var b := Vector2(rhigh)+Vector2(0.5,0.5)
	var half_span := ((b.x-a.x) if ridge_along_z else (b.y-a.y))/2
	var length := (b.y-a.y) if ridge_along_z else (b.x-a.x)
	var mid := Vector3((a.x+b.x)/2,0,(a.y+b.y)/2)
	roof.position = mid
	if not ridge_along_z: roof.rotation.y = PI/2
	var overhang := 0.42
	var rise := ridge_y-eave_y
	var slope := atan2(rise,half_span)
	var run := (half_span+overhang)/cos(slope)
	var tiles := covering
	for side in [-1.0,1.0]:
		var plane := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var top_pt := Vector3(0,ridge_y+0.05,0)
		var low_pt := Vector3(side*(half_span+overhang),eave_y-overhang*tan(slope)+0.05,0)
		var zs := [-length/2-0.35,length/2+0.35]
		var quad := [top_pt+Vector3(0,0,zs[0]),top_pt+Vector3(0,0,zs[1]),low_pt+Vector3(0,0,zs[1]),low_pt+Vector3(0,0,zs[0])]
		var uvs := [Vector2(0,0),Vector2(length+0.7,0),Vector2(length+0.7,run),Vector2(0,run)]
		var order := [0,1,2,0,2,3] if side > 0 else [0,2,1,0,3,2]
		for k in order:
			st.set_uv(uvs[k]/1.6)
			st.add_vertex(quad[k])
		st.generate_normals()
		st.generate_tangents()
		plane.mesh = st.commit()
		var slab := StandardMaterial3D.new()
		slab.albedo_texture = tiles.albedo_texture
		slab.normal_enabled = tiles.normal_enabled
		slab.normal_texture = tiles.normal_texture
		slab.albedo_color = tiles.albedo_color
		slab.roughness = 0.8
		slab.cull_mode = BaseMaterial3D.CULL_DISABLED
		plane.material_override = slab
		roof.add_child(plane)
		# Fascia board along the eave and rafter tails under it.
		var eave := low_pt+Vector3(0,-0.06,0)
		_box(roof,Vector3(0.06,0.18,length+0.7),eave+Vector3(side*0.03,-0.04,0),oak())
	# Ridge cap: half-round clay tiles along the top.
	var cap := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.11; cyl.bottom_radius = 0.11; cyl.height = length+0.75; cyl.radial_segments = 10
	cap.mesh = cyl
	cap.rotation.x = PI/2
	cap.position = Vector3(0,ridge_y+0.08,0)
	# Clay ridge tiles on a tiled roof; a wooden ridge board on shingles.
	cap.material_override = surface("grey_roof_tiles_02",Color("a85a3c"),1.4,0.8) if covering == roof_tiles() else oak()
	roof.add_child(cap)
	# Gable ends: plaster triangles under the roof with an oak king post,
	# collar and bargeboards following the slopes.
	for end in [-1.0,1.0]:
		var z: float = end*length/2
		var tri := MeshInstance3D.new()
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts := [Vector3(-half_span+0.1,eave_y,z),Vector3(half_span-0.1,eave_y,z),Vector3(0,ridge_y-0.05,z)]
		for p in [pts[0],pts[1],pts[2]]: st.add_vertex(p+Vector3(0,0,end*T/2))
		for p in [pts[0],pts[2],pts[1]]: st.add_vertex(p-Vector3(0,0,end*T/2))
		st.generate_normals()
		tri.mesh = st.commit()
		tri.material_override = wall_material(gable_family)
		roof.add_child(tri)
		var depth: float = end*(T/2+0.03)
		_box(roof,Vector3(0.12,rise,0.06),Vector3(0,eave_y+rise/2,z+depth),oak())
		_box(roof,Vector3(half_span*1.1,0.12,0.06),Vector3(0,eave_y+rise*0.45,z+depth),oak())
		_box(roof,Vector3(half_span*2,0.14,0.06),Vector3(0,eave_y+0.07,z+depth),oak())
		for side in [-1.0,1.0]:
			_box(roof,Vector3(run,0.2,0.06),Vector3(side*(half_span+overhang)/2,(ridge_y+eave_y-overhang*tan(slope))/2+0.02,z+end*(0.35+0.03)),oak(),Vector3(0,0,-side*slope))
			_box(roof,Vector3(0.1,rise*0.55,0.05),Vector3(side*half_span*0.45,eave_y+rise*0.275,z+depth),oak(),Vector3(0,0,side*0.5))

# Stone steps from the ground to the floor in front of the door, across the
# width of the stair cells, rising toward the house.
static func _steps(root: Node3D, stairs: Array, floor_y: float, centre: Vector2) -> void:
	if stairs.is_empty(): return
	var low := Vector2i(100000,100000)
	var high := Vector2i(-100000,-100000)
	for s in stairs:
		low = low.min(s[0])
		high = high.max(s[0])
	var cells := Vector2(high-low)+Vector2.ONE
	var mid := Vector2(low+high)/2.0
	var out := mid-centre
	var along_x := absf(out.y) >= absf(out.x)
	var dir := Vector2(0,signf(out.y)) if along_x else Vector2(signf(out.x),0)
	var width := cells.x if along_x else cells.y
	var count := 4
	var tread := 0.95/count
	var mat := surface("castle_wall_varriation",Color("b4aea4"),1.1)
	for i in count:
		var h := floor_y*float(count-i)/count
		var at := Vector3(mid.x,h/2,mid.y)+Vector3(dir.x,0,dir.y)*(-0.45+tread*(i+0.5))
		_box(root,Vector3(width if along_x else tread,h,tread if along_x else width),at,mat)
		# A lighter dressed tread, just proud of the riser, marks each step.
		_box(root,Vector3((width if along_x else tread)+0.04,0.05,(tread if along_x else width)+0.04),Vector3(at.x,h-0.02,at.z),surface("castle_wall_varriation",Color("d2cdc4"),1.6))
	# Cheek walls either side.
	for s in [-1.0,1.0]:
		var side := Vector3(s*(width/2+0.1),0,0) if along_x else Vector3(0,0,s*(width/2+0.1))
		_box(root,Vector3(0.2 if along_x else 0.95,floor_y,0.95 if along_x else 0.2),Vector3(mid.x,floor_y/2,mid.y)+side,stone())

# Stone chimney stack through the roof near one gable, with pots and smoke.
static func _chimney(root: Node3D, block: Array, eave_y: float, ridge_y: float, rnd: RandomNumberGenerator) -> void:
	var stack := Node3D.new()
	stack.name = "Chimney"
	var lo := Vector2i(100000,100000)
	var hi := Vector2i(-100000,-100000)
	for r in block:
		lo = lo.min(r[0])
		hi = hi.max(r[0])
	# Near one end of the main roof, just off the ridge.
	var x := float(hi.x)-1.1 if hi.x-lo.x >= hi.y-lo.y else (lo.x+hi.x)/2.0+0.9
	var z := (lo.y+hi.y)/2.0+0.9 if hi.x-lo.x >= hi.y-lo.y else float(lo.y)+1.1
	var base := eave_y-0.3
	var top := ridge_y+0.9
	stack.position = Vector3(x,0,z)
	root.add_child(stack)
	_box(stack,Vector3(0.8,top-base,0.7),Vector3(0,(base+top)/2,0),stone())
	_box(stack,Vector3(0.95,0.14,0.85),Vector3(0,top+0.07,0),surface("castle_wall_varriation",Color("c4beb4"),0.9))
	for px in [-0.18,0.18]:
		var pot := MeshInstance3D.new()
		var cyl := CylinderMesh.new(); cyl.top_radius = 0.09; cyl.bottom_radius = 0.12; cyl.height = 0.32; cyl.radial_segments = 10
		pot.mesh = cyl
		pot.material_override = surface("medieval_red_brick",Color("a0644a"),2.0)
		pot.position = Vector3(px,top+0.3,0)
		stack.add_child(pot)
	var smoke := GPUParticles3D.new()
	smoke.amount = 30
	smoke.lifetime = 6.5
	smoke.preprocess = 6.0
	smoke.position = Vector3(0.18,top+0.5,0)
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0.25,1,0.1)
	process.spread = 12.0
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.55
	process.gravity = Vector3(0.12,0.05,0.05)
	var grow := Curve.new(); grow.add_point(Vector2(0,0.35)); grow.add_point(Vector2(1,2.6))
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
	stack.add_child(smoke)
