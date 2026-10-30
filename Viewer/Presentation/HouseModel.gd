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
# BakeHouses.gd saves the result per multi id into the ignored
# local-multis/houses folder; MultiPresenter uses the baked scene, or builds
# it on the fly for a supported id.
const SCALE := 0.2
const T := 0.32           # wall thickness (m)
const DOOR_H := 2.52      # door opening height (the server door's DoorwayPlan opening)
const SILL := 0.95        # window sill above the floor
const HEAD := 2.15        # window head above the floor
const WINDOW_W := 0.82
# House multis this builder has been reviewed for (classic small houses first).
const SUPPORTED := [0x64]
static var surfaces := {}

static func supported(id: int) -> bool:
	return id in SUPPORTED

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
		"stone": return surface("castle_wall_varriation",Color("cfc8bb"),0.45)
		"sandstone": return surface("medieval_blocks_03",Color("e2cfa8"),0.5)
		"brick": return surface("medieval_red_brick",Color("c09078"),0.6)
		"marble": return surface("medieval_blocks_02",Color("eeeae2"),0.5)
		"wood","log": return surface("brown_planks_03",Color("a88a6a"),0.7)
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
	var walls := {}        # Vector2i -> {z, top, family, window}
	var foundation := {}   # Vector2i -> top z
	var floors := {}       # Vector2i -> z
	var roofs: Array = []  # [cell (anchor-shifted), z]
	var stairs: Array = []
	var gable_family := ""
	for part in parts:
		var g := int(part[0])
		var info: Dictionary = tiles.get(str(g),{})
		var rule: Dictionary = Rules.resolve(g,info)
		var kind := str(rule.get("kind",""))
		var cell := Vector2i(int(part[1]),int(part[2]))
		var z := int(part[3])
		var h := int(info.get("height",0))
		var family := Facade.family_for(str(info.get("name","")))
		match kind:
			"wall","corner","window","trim","pillar":
				if h <= 6 and z <= 2: foundation[cell] = maxi(int(foundation.get(cell,0)),z+h)
				elif h >= 10:
					var known: Dictionary = walls.get(cell,{})
					walls[cell] = {"z":z,"top":z+h,"family":family if family != "" else str(known.get("family","plaster")),"window":kind == "window" or bool(known.get("window",false))}
				elif z > 10: gable_family = family
			"floor","landing": floors[cell] = z
			"roof":
				var anchor: Array = rule.get("anchorOffset",[-1,-1])
				roofs.append([cell+Vector2i(int(anchor[0]),int(anchor[1])),z])
			"stairs": stairs.append([cell,z,h])
	var root := Node3D.new()
	root.name = "HouseModel"
	if walls.is_empty(): return root
	# Storey: floor height and the walls' family (the most common).
	var floor_z := 1000
	for cell in walls: floor_z = mini(floor_z,int(walls[cell].z))
	var counts := {}
	for cell in walls: counts[walls[cell].family] = int(counts.get(walls[cell].family,0))+1
	var family: String = counts.keys()[0]
	for f in counts: if int(counts[f]) > int(counts[family]): family = f
	var floor_y := float(floor_z)*SCALE
	var low := Vector2i(100000,100000)
	var high := Vector2i(-100000,-100000)
	for cell in walls:
		low = low.min(cell)
		high = high.max(cell)
	var eave_y := 1000.0
	var ridge_y := 0.0
	for r in roofs:
		eave_y = minf(eave_y,float(r[1])*SCALE)
		ridge_y = maxf(ridge_y,float(r[1]+3)*SCALE)
	var wall_top := eave_y if not roofs.is_empty() else float(walls.values()[0].top)*SCALE
	var centre := Vector2(low+high)/2.0
	_plinth(root,foundation,low,high,floor_y)
	_floor(root,floors,walls,floor_y)
	var paint: Color = [Color("6e2a26"),Color("2f4a3a"),Color("2c3e5a"),Color("6a5428")][rnd.randi()%4]
	_walls(root,walls,floors,family,floor_y,wall_top,centre,paint)
	if family == "plaster": _framing(root,walls,floor_y,wall_top,centre)
	_quoins(root,low,high,floor_y,wall_top,family)
	if not roofs.is_empty(): _roof(root,roofs,low,high,eave_y,ridge_y,gable_family if gable_family != "" else family)
	_steps(root,stairs,floor_y,centre)
	if not roofs.is_empty(): _chimney(root,low,high,eave_y,ridge_y,rnd)
	for mesh in root.find_children("*","MeshInstance3D",true,false):
		(mesh as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return root

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

static func _floor(root: Node3D, floors: Dictionary, walls: Dictionary, floor_y: float) -> void:
	var boards := surface("brown_planks_03",Color("b49a7a"),0.55,0.8)
	for cell in floors:
		_box(root,Vector3(1.0,0.06,1.0),Vector3(cell.x,floor_y+0.03,cell.y),boards)

# Wall arms from each wall cell's centre towards its wall neighbours, with
# window and door openings; doors are gaps between two wall cells in a line.
static func _walls(root: Node3D, walls: Dictionary, floors: Dictionary, family: String, floor_y: float, top: float, centre: Vector2, paint: Color) -> void:
	var shell := Node3D.new()
	shell.name = "Walls"
	root.add_child(shell)
	var mat := wall_material(family)
	var height := top-floor_y
	var dirs := [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]
	var doors := {}
	for cell in walls:
		for d in [Vector2i(1,0),Vector2i(0,1)]:
			var gap: Vector2i = cell+d
			if not walls.has(gap) and walls.has(gap+d) and floors.has(gap): doors[gap] = d
	for cell in walls:
		var w: Dictionary = walls[cell]
		var arms: Array = []
		for d in dirs:
			if walls.has(cell+d) or doors.has(cell+d): arms.append(d)
		if arms.is_empty(): arms = [Vector2i(1,0),Vector2i(-1,0)]
		_box(shell,Vector3(T,height,T),Vector3(cell.x,floor_y+height/2,cell.y),mat)
		for d in arms:
			var along_x: bool = d.x != 0
			var mid := Vector3(cell.x+d.x*0.25+(0.0 if along_x else 0.0),floor_y+height/2,cell.y+d.y*0.25)
			if bool(w.window) and _straight(walls,cell):
				_window_arm(shell,cell,d,floor_y,top,mat)
			else:
				_box(shell,Vector3(0.5 if along_x else T,height,T if along_x else 0.5),mid,mat)
		if bool(w.window) and _straight(walls,cell): _window(shell,cell,walls,floor_y,centre,paint)
	for gap in doors: _doorway(shell,gap,doors[gap],floor_y,top,mat,centre)

static func _straight(walls: Dictionary, cell: Vector2i) -> bool:
	return (walls.has(cell+Vector2i(1,0)) or walls.has(cell+Vector2i(-1,0))) != (walls.has(cell+Vector2i(0,1)) or walls.has(cell+Vector2i(0,-1)))

# Half an arm of a window cell: solid below the sill and above the head, the
# opening (WINDOW_W wide, centred on the cell) left clear.
static func _window_arm(shell: Node3D, cell: Vector2i, d: Vector2i, floor_y: float, top: float, mat: Material) -> void:
	var along_x: bool = d.x != 0
	var half := WINDOW_W/2
	var edge := 0.5-half
	var mid_off := half+edge/2
	var side := Vector3(cell.x+d.x*mid_off,floor_y+(top-floor_y)/2,cell.y+d.y*mid_off)
	_box(shell,Vector3(edge if along_x else T,top-floor_y,T if along_x else edge),side,mat)
	var inner := Vector3(cell.x+d.x*half/2,0,cell.y+d.y*half/2)
	_box(shell,Vector3(half if along_x else T,SILL,T if along_x else half),inner+Vector3(0,floor_y+SILL/2,0),mat)
	_box(shell,Vector3(half if along_x else T,top-floor_y-HEAD,T if along_x else half),inner+Vector3(0,floor_y+HEAD+(top-floor_y-HEAD)/2,0),mat)

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
	shell.add_child(win)
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
static func _doorway(shell: Node3D, gap: Vector2i, d: Vector2i, floor_y: float, top: float, mat: Material, centre: Vector2) -> void:
	var along_x: bool = d.x != 0
	var over := top-floor_y-DOOR_H
	_box(shell,Vector3(1.0 if along_x else T,over,T if along_x else 1.0),Vector3(gap.x,floor_y+DOOR_H+over/2,gap.y),mat)
	var out := Vector2(0,signf(float(gap.y)-centre.y)) if along_x else Vector2(signf(float(gap.x)-centre.x),0)
	var door := Node3D.new()
	door.name = "Doorway"
	door.position = Vector3(gap.x,floor_y,gap.y)
	door.rotation.y = atan2(out.x,out.y)
	shell.add_child(door)
	var frame := oak()
	for x in [-0.52,0.52]: _box(door,Vector3(0.1,DOOR_H,T+0.08),Vector3(x,DOOR_H/2,0),frame)
	_box(door,Vector3(1.24,0.14,T+0.08),Vector3(0,DOOR_H+0.07,0),frame)
	_box(door,Vector3(1.2,0.06,T+0.3),Vector3(0,0.03,0.1),stone())
	# Pent canopy: two brackets and a short tiled slope over the door.
	var canopy_y := DOOR_H+0.45
	for x in [-0.62,0.62]: _box(door,Vector3(0.08,0.08,0.7),Vector3(x,canopy_y-0.2,T/2+0.3),frame,Vector3(-0.55,0,0))
	_box(door,Vector3(1.6,0.07,0.85),Vector3(0,canopy_y,T/2+0.38),roof_tiles(),Vector3(0.38,0,0))

static func roof_tiles() -> StandardMaterial3D: return surface("grey_roof_tiles_02",Color("c0714c"),0.9,0.8)

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

# Long-and-short dressed blocks at the outer corners.
static func _quoins(root: Node3D, low: Vector2i, high: Vector2i, floor_y: float, top: float, family: String) -> void:
	if family in ["wood","log"]: return
	var mat := quoin()
	var y := floor_y
	var i := 0
	while y < top-0.05:
		var tall := minf(0.34,top-y)
		var long := i%2 == 0
		for corner in [Vector2(low.x,low.y),Vector2(high.x,low.y),Vector2(low.x,high.y),Vector2(high.x,high.y)]:
			var sx := signf(corner.x-(low.x+high.x)/2.0)
			var sz := signf(corner.y-(low.y+high.y)/2.0)
			_box(root,Vector3(T+0.06+(0.32 if long else 0.0),tall-0.02,T+0.06+(0.0 if long else 0.32)),Vector3(corner.x-sx*(0.16 if long else 0.0),y+tall/2,corner.y-sz*(0.0 if long else 0.16)),mat)
		y += tall
		i += 1

# Gable roof over the roof tiles' footprint: the ridge runs along the axis on
# which the topmost tiles line up; eaves at the lowest tiles.
static func _roof(root: Node3D, roofs: Array, low: Vector2i, high: Vector2i, eave_y: float, ridge_y: float, gable_family: String) -> void:
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
	root.add_child(roof)
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
	var tiles := roof_tiles()
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
	cap.material_override = surface("grey_roof_tiles_02",Color("a85a3c"),1.4,0.8)
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
static func _chimney(root: Node3D, low: Vector2i, high: Vector2i, eave_y: float, ridge_y: float, rnd: RandomNumberGenerator) -> void:
	var stack := Node3D.new()
	stack.name = "Chimney"
	var x := float(high.x)-1.6
	var z := float(low.y)+1.0
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
