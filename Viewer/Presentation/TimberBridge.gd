extends RefCounted
# Wooden footbridges (Trinsic's canal crossings and their kind): UO builds them
# from loose tiles (deck boards, ramp wedges at both ends, "wood" cribbing
# blocks and short rail pieces), which drawn one by one read as a box on
# stilts. A deck of boards over water with a ramp is recognised as one bridge
# and drawn once, by its first record, as a timber footbridge fitted to its
# own footprint: individual weathered boards on stringers following the walking
# surface (ramps included, gently rounded), trestle bents with cap beams and
# cross bracing down to the bank or riverbed, and post-and-rail handrails on
# both sides. Photoscanned CC0 Poly Haven surfaces (rough_wood, medieval_wood).
# Source records keep their XYZ; the members are accounted as components.
const SURFACE := 0x200
const IMPASSABLE := 0x40
const DECK_NAMES := ["wooden boards","wooden planks","wooden plank","wooden bridge"]
# ordinal -> anchor ordinal of its bridge
var members := {}
# anchor ordinal -> plan
var plans := {}

static func _name(world: Dictionary, id: int) -> String:
	var data: Variant = world.get("staticData",{})
	return str((data as Dictionary).get(str(id),{}).get("name","")).to_lower() if data is Dictionary else ""

static func _flags(world: Dictionary, id: int) -> int:
	var data: Variant = world.get("staticData",{})
	return int((data as Dictionary).get(str(id),{}).get("flags",0)) if data is Dictionary else 0

static func _height(world: Dictionary, id: int) -> int:
	var data: Variant = world.get("staticData",{})
	return int((data as Dictionary).get(str(id),{}).get("height",0)) if data is Dictionary else 0

func index(world: Dictionary, catalog: Dictionary) -> void:
	members.clear()
	plans.clear()
	var land_data: Variant = world.get("landData",{})
	var ground := {}
	var water := {}
	for tile in world.get("terrain",[]):
		var at := Vector2i(tile.x,tile.y)
		ground[at] = int(tile.z)
		if land_data is Dictionary and str(land_data.get(str(int(tile.id)),{}).get("name","")).to_lower() == "water": water[at] = int(tile.z)
	# Candidate pieces by cell: decks, ramps, cribbing, rails and loose "wood".
	var decks := {}
	var parts := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var name := _name(world,int(s.id))
		var at := Vector2i(s.x,s.y)
		if name == "water":
			water[at] = int(s.z)
			continue
		var kind := str(catalog.get(str(int(s.id)),{}).get("kind",""))
		var role := ""
		if name in DECK_NAMES and _flags(world,int(s.id)) & SURFACE and not _flags(world,int(s.id)) & IMPASSABLE: role = "deck"
		elif name == "wooden ramp": role = "ramp"
		elif name == "wood" and kind in ["landing","prop"]: role = "crib"
		elif name == "wooden rail": role = "rail"
		if role.is_empty(): continue
		if not parts.has(at): parts[at] = []
		parts[at].append([i,role])
		if role == "deck":
			if not decks.has(at): decks[at] = []
			decks[at].append(i)
	# Each deck over water grows over neighbouring boards, ramps and cribbing
	# at about its own level; a cluster with a ramp is a footbridge (piers and
	# jetties have none).
	var taken := {}
	for at in decks:
		if not water.has(at): continue
		for first in decks[at]:
			if taken.has(first) or int(world.statics[first].z) <= int(water[at]): continue
			var cluster := {first:true}
			var queue := [first]
			while not queue.is_empty():
				var current: int = queue.pop_back()
				var c: Dictionary = world.statics[current]
				for dx in range(-1,2):
					for dy in range(-1,2):
						for part in parts.get(Vector2i(c.x+dx,c.y+dy),[]):
							var other: int = part[0]
							if cluster.has(other) or taken.has(other): continue
							var o: Dictionary = world.statics[other]
							var diagonal := dx != 0 and dy != 0
							var step := absi(int(o.z)-int(c.z))
							# Rails and cribbing join from any side; walkable parts edge to edge.
							if part[1] in ["rail","crib"] and step <= 12 or not diagonal and step <= 6:
								cluster[other] = true
								if part[1] != "rail": queue.append(other)
			var ramps := 0
			var deck_count := 0
			# The first deck board draws the bridge (a solid floor record).
			var anchor := 1 << 30
			for i in cluster:
				var role := _role(parts,world.statics[i],i)
				if role == "ramp": ramps += 1
				elif role == "deck":
					deck_count += 1
					anchor = mini(anchor,i)
			if ramps == 0 or deck_count < 4: continue
			var plan := _plan(cluster.keys(),parts,world,ground,water)
			if plan.is_empty(): continue
			plans[anchor] = plan
			for i in cluster:
				members[i] = anchor
				taken[i] = true

static func _role(parts: Dictionary, s: Dictionary, i: int) -> String:
	for part in parts.get(Vector2i(s.x,s.y),[]):
		if part[0] == i: return part[1]
	return ""

func _plan(cluster: Array, parts: Dictionary, world: Dictionary, ground: Dictionary, water: Dictionary) -> Dictionary:
	var lo := Vector2i(1 << 20,1 << 20)
	var hi := -lo
	var walk_lo := Vector2i(1 << 20,1 << 20)
	var walk_hi := -walk_lo
	var ramp_lo := Vector2i(1 << 20,1 << 20)
	var ramp_hi := -ramp_lo
	var deck_z := -1000
	for i in cluster:
		var s: Dictionary = world.statics[i]
		var at := Vector2i(s.x,s.y)
		lo = lo.min(at)
		hi = hi.max(at)
		var role := _role(parts,s,i)
		if role in ["deck","ramp"]:
			walk_lo = walk_lo.min(at)
			walk_hi = walk_hi.max(at)
		if role == "ramp":
			ramp_lo = ramp_lo.min(at)
			ramp_hi = ramp_hi.max(at)
		if role == "deck": deck_z = maxi(deck_z,int(s.z))
	# The span runs between the ramps (or along the longer side).
	var axis_x := ramp_hi.x-ramp_lo.x > ramp_hi.y-ramp_lo.y if ramp_hi != ramp_lo else walk_hi.x-walk_lo.x >= walk_hi.y-walk_lo.y
	var u0 := walk_lo.x if axis_x else walk_lo.y
	var u1 := walk_hi.x if axis_x else walk_hi.y
	var v0 := walk_lo.y if axis_x else walk_lo.x
	var v1 := walk_hi.y if axis_x else walk_hi.x
	# Walking surface per column (its two ends): decks flat, ramps rising
	# toward the deck's middle.
	var middle := 0.0
	var deck_columns := 0
	var left := {}
	var right := {}
	for i in cluster:
		var s: Dictionary = world.statics[i]
		if _role(parts,s,i) == "deck":
			middle += float(s.x if axis_x else s.y)
			deck_columns += 1
	middle /= maxf(1.0,float(deck_columns))
	for i in cluster:
		var s: Dictionary = world.statics[i]
		var role := _role(parts,s,i)
		if role not in ["deck","ramp"]: continue
		var u := int(s.x if axis_x else s.y)
		var a := int(s.z)
		var b := int(s.z)
		if role == "ramp":
			var rise := maxi(1,_height(world,int(s.id)))
			if float(u) > middle: a += rise
			else: b += rise
		left[u] = maxi(int(left.get(u,-1000)),a)
		right[u] = maxi(int(right.get(u,-1000)),b)
	var profile: Array[Vector2] = []
	for b in range(u0,u1+2):
		var z := -1000
		if right.has(b-1): z = maxi(z,int(right[b-1]))
		if left.has(b): z = maxi(z,int(left[b]))
		if z > -1000: profile.append(Vector2(float(b),float(z)*float(world.elevationScale)))
	if profile.size() < 3: return {}
	# Ground under each column: bank height, or a riverbed under water.
	var beds := {}
	for u in range(u0,u1+1):
		var bed := 1000.0
		for v in range(v0,v1+1):
			var cell := Vector2i(u,v) if axis_x else Vector2i(v,u)
			if water.has(cell): bed = minf(bed,float(water[cell])*float(world.elevationScale)-1.5)
			elif ground.has(cell): bed = minf(bed,float(ground[cell])*float(world.elevationScale))
		beds[u] = bed if bed < 999 else float(deck_z)*float(world.elevationScale)-2.0
	return {"axis_x":axis_x,"u0":u0,"u1":u1,"v0":v0,"v1":v1,"profile":_rounded(profile),"beds":beds,"deck_z":deck_z,"members":cluster.size()}

# Two Chaikin passes keep the ends and soften the ramp-to-deck kinks.
static func _rounded(points: Array[Vector2]) -> Array[Vector2]:
	var result := points
	for pass_index in 2:
		var next: Array[Vector2] = [result[0]]
		for i in result.size()-1:
			next.append(result[i].lerp(result[i+1],0.25))
			next.append(result[i].lerp(result[i+1],0.75))
		next.append(result[-1])
		result = next
	return result

static func _height_at(profile: Array, u: float) -> float:
	for i in profile.size()-1:
		if u <= profile[i+1].x:
			var t := clampf((u-profile[i].x)/maxf(0.0001,profile[i+1].x-profile[i].x),0,1)
			return lerpf(profile[i].y,profile[i+1].y,t)
	return profile[-1].y

static func _slope_at(profile: Array, u: float) -> float:
	for i in profile.size()-1:
		if u <= profile[i+1].x: return (profile[i+1].y-profile[i].y)/maxf(0.0001,profile[i+1].x-profile[i].x)
	return 0.0

static var materials := {}
static func _material(id: String, tint: Color) -> StandardMaterial3D:
	var key := id+tint.to_html()
	if not materials.has(key):
		var material: StandardMaterial3D = preload("res://Presentation/DoorLeaf.gd").surface(id,tint).duplicate()
		material.uv1_world_triplanar = true
		materials[key] = material
	return materials[key]

# Oriented box into a SurfaceTool: centre, basis (columns are the box axes)
# and full size; faces wound clockwise from outside (Godot front faces).
static func _box(st: SurfaceTool, centre: Vector3, basis: Basis, size: Vector3) -> void:
	var h := size/2
	var corners := []
	for k in 8: corners.append(centre+basis*Vector3(h.x*(1 if k & 1 else -1),h.y*(1 if k & 2 else -1),h.z*(1 if k & 4 else -1)))
	for face in [[0,2,6,4],[1,5,7,3],[0,4,5,1],[2,3,7,6],[0,1,3,2],[4,6,7,5]]:
		var a: Vector3 = corners[face[0]]
		var b: Vector3 = corners[face[1]]
		var c: Vector3 = corners[face[2]]
		var d: Vector3 = corners[face[3]]
		var normal := (b-a).cross(c-a).normalized()
		if normal.dot((a+c)/2-centre) < 0:
			normal = -normal
			var swap := b
			b = d
			d = swap
		st.set_normal(normal)
		for v in [a,c,b,a,d,c]: st.add_vertex(v)

# A beam from a to b (centre line), w wide (across) and h deep (up-ish).
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, w: float, h: float, across: Vector3) -> void:
	var along := (b-a)
	if along.length() < 0.01: return
	var x := along.normalized()
	var z := across.normalized()
	var y := z.cross(x).normalized()
	z = x.cross(y).normalized()
	_box(st,(a+b)/2,Basis(x,y,z),Vector3(along.length(),h,w))

# Builds the bridge in the anchor record's local frame.
func build(anchor: Dictionary, world: Dictionary, ordinal: int) -> Node3D:
	var plan: Dictionary = plans.get(ordinal,{})
	var root := Node3D.new()
	root.set_meta("replacement","timber footbridge")
	root.set_meta("world_aligned",true)
	if plan.is_empty(): return root
	var scale := float(world.elevationScale)
	var axis_x: bool = plan.axis_x
	var origin := Vector3(float(anchor.x)+0.5,float(anchor.z)*scale,float(anchor.y)+0.5)
	# (u along the span, v across, height in metres) -> local position.
	var at := func(u: float, v: float, height: float) -> Vector3:
		return (Vector3(u,height,v) if axis_x else Vector3(v,height,u))-origin
	var across := Vector3(0,0,1) if axis_x else Vector3(1,0,0)
	var profile: Array = plan.profile
	var u0 := float(plan.u0)
	var u1 := float(plan.u1)+1.0
	var v0 := float(plan.v0)
	var v1 := float(plan.v1)+1.0
	var width := v1-v0
	var boards := SurfaceTool.new()
	boards.begin(Mesh.PRIMITIVE_TRIANGLES)
	var timber := SurfaceTool.new()
	timber.begin(Mesh.PRIMITIVE_TRIANGLES)
	var random := RandomNumberGenerator.new()
	random.seed = int(anchor.x)*7919+int(anchor.y)*104729
	# Deck boards laid across the span, 22 cm wide with small gaps.
	var u := u0+0.02
	while u < u1-0.1:
		var slope := _slope_at(profile,u+0.11)
		var x := (Vector3(1,slope,0) if axis_x else Vector3(0,slope,1)).normalized()
		var y := across.cross(x).normalized() if axis_x else x.cross(across).normalized()
		if y.y < 0: y = -y
		var z := x.cross(y).normalized()
		var length := width+0.16+random.randf_range(-0.05,0.05)
		var thick := 0.06+random.randf_range(-0.008,0.008)
		var centre: Vector3 = at.call(u+0.11,v0+width/2+random.randf_range(-0.03,0.03),_height_at(profile,u+0.11)-thick/2)
		_box(boards,centre,Basis(x,y,z).rotated(y,random.randf_range(-0.012,0.012)),Vector3(0.22,thick,length))
		# Boards keep their spacing along the slope of the ramps.
		u += (0.235+random.randf_range(0,0.01))/sqrt(1.0+slope*slope)
	# Stringers under the boards and an outer fascia beam on each side, all
	# following the rounded profile.
	for line in [[v0+0.35,0.16,0.24,0.18],[v0+width/2,0.16,0.24,0.18],[v1-0.35,0.16,0.24,0.18],[v0+0.03,0.07,0.32,0.12],[v1-0.03,0.07,0.32,0.12]]:
		for i in profile.size()-1:
			var a: Vector3 = at.call(profile[i].x,line[0],profile[i].y-0.06-line[3])
			var b: Vector3 = at.call(profile[i+1].x,line[0],profile[i+1].y-0.06-line[3])
			_beam(timber,a,b,line[1],line[2],across)
	# Trestle bents: at both ends of the raised deck and every 3 m between.
	var stations: Array[float] = []
	var flat_lo := u1
	var flat_hi := u0
	var top := -1000.0
	for p in profile: top = maxf(top,p.y)
	for p in profile:
		if p.y >= top-0.05:
			flat_lo = minf(flat_lo,p.x)
			flat_hi = maxf(flat_hi,p.x)
	flat_lo = clampf(flat_lo,u0+0.5,u1-0.5)
	flat_hi = clampf(flat_hi,u0+0.5,u1-0.5)
	var bays := maxi(1,ceili((flat_hi-flat_lo)/3.0))
	for k in bays+1: stations.append(lerpf(flat_lo,flat_hi,float(k)/bays))
	# Ramps longer than a metre get a bent halfway down too.
	if flat_lo-u0 > 1.2: stations.append((u0+flat_lo)/2)
	if u1-flat_hi > 1.2: stations.append((u1+flat_hi)/2)
	var post_vs := [v0+0.35,v0+width/2,v1-0.35] if width > 3.5 else [v0+0.35,v1-0.35]
	for station in stations:
		var deck := _height_at(profile,station)-0.06-0.24
		var bed := 1000.0
		for column in [floori(station-0.5),floori(station)]:
			bed = minf(bed,float(plan.beds.get(column,plan.beds.get(floori(station),deck-2.0))))
		if deck-bed < 0.3: continue
		_beam(timber,at.call(station,v0-0.1,deck-0.12),at.call(station,v1+0.1,deck-0.12),0.22,0.24,Vector3.UP.cross(across).normalized())
		for v in post_vs: _beam(timber,at.call(station,v,bed),at.call(station,v,deck-0.24),0.2,0.2,across)
		if deck-bed > 1.0:
			var low := bed+0.25
			var high := deck-0.35
			_beam(timber,at.call(station,v0+0.35,low),at.call(station,v1-0.35,high),0.08,0.14,Vector3.UP.cross(across).normalized())
			_beam(timber,at.call(station,v1-0.35,low),at.call(station,v0+0.35,high),0.08,0.14,Vector3.UP.cross(across).normalized())
	# Sills where the ramps meet the banks.
	for end in [u0+0.15,u1-0.15]:
		var h := _height_at(profile,end)
		_beam(timber,at.call(end,v0-0.05,h-0.3),at.call(end,v1+0.05,h-0.3),0.3,0.3,Vector3.UP.cross(across).normalized())
	# Handrails: posts every ~1.3 m, top and middle rails along the profile.
	for side in [v0+0.06,v1-0.06]:
		var count := maxi(2,roundi((u1-u0-0.3)/1.3))
		for k in count+1:
			var pu := lerpf(u0+0.15,u1-0.15,float(k)/count)
			var base := _height_at(profile,pu)
			_beam(timber,at.call(pu,side,base-0.25),at.call(pu,side,base+1.02),0.11,0.11,across)
		for i in profile.size()-1:
			for rail in [[1.0,0.1],[0.52,0.07]]:
				var a: Vector3 = at.call(clampf(profile[i].x,u0+0.15,u1-0.15),side,_height_at(profile,clampf(profile[i].x,u0+0.15,u1-0.15))+rail[0])
				var b: Vector3 = at.call(clampf(profile[i+1].x,u0+0.15,u1-0.15),side,_height_at(profile,clampf(profile[i+1].x,u0+0.15,u1-0.15))+rail[0])
				_beam(timber,a,b,rail[1],rail[1]*0.8,across)
	for part in [[boards,_material("rough_wood",Color(0.92,0.86,0.78))],[timber,_material("medieval_wood",Color(0.85,0.8,0.74))]]:
		var mesh := MeshInstance3D.new()
		mesh.mesh = part[0].commit()
		mesh.material_override = part[1]
		root.add_child(mesh)
	return root

func audit() -> Dictionary:
	return {"bridges":plans.size(),"members":members.size()}
