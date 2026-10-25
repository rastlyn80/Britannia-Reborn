extends RefCounted

# Derived presentation only. Source records and open stairwells remain intact.
var edges := {}
var repairs: Array[Vector3i] = []
var stair_rise := {}
var scale := 0.2

func index(world: Dictionary, catalog: Dictionary) -> void:
	edges.clear()
	repairs.clear()
	stair_rise.clear()
	scale = float(world.get("elevationScale",0.2))
	var cells := {}
	var floor_cells := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var at := Vector2i(s.x,s.y)
		if not cells.has(at): cells[at] = []
		cells[at].append(i)
		if catalog.get(str(int(s.id)),{}).get("kind") == "floor": floor_cells[Vector3i(s.x,s.y,s.z)] = i
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var kind: String = catalog.get(str(int(s.id)),{}).get("kind","")
		var at := Vector2i(s.x,s.y)
		if kind == "stairs":
			var rise := Vector2.ZERO
			for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				for j in cells.get(at+offset,[]):
					var other: Dictionary = world.statics[j]
					if other.id == s.id and other.z > s.z and other.z-s.z <= 5: rise += Vector2(offset)
			if rise.length_squared() == 1: stair_rise[i] = rise
		if kind != "floor": continue
		var extra := Vector4.ZERO # left, right, north, south
		var offsets := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
		for side in 4:
			for j in cells.get(at+offsets[side],[]):
				var wall: Dictionary = world.statics[j]
				var rule: Dictionary = catalog.get(str(int(wall.id)),{})
				if rule.get("kind") not in ["wall","window","corner"]: continue
				if absf(float(wall.z)-float(s.z)) <= 1: extra[side] = 0.51
		edges[i] = extra
	# Terrain-encoded wooden rooms need the same ceiling-to-wall extensions.
	for i in world.get("terrain",[]).size():
		var tile: Dictionary = world.terrain[i]
		var data = world.get("landData",{})
		if not data is Dictionary or data.get(str(int(tile.get("id",-1))),{}).get("name","").to_lower() != "wooden floor": continue
		var extra := Vector4.ZERO
		var offsets := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
		for side in 4:
			for j in cells.get(Vector2i(tile.x,tile.y)+offsets[side],[]):
				var wall: Dictionary = world.statics[j]
				if catalog.get(str(int(wall.id)),{}).get("kind") in ["wall","window","corner"] and absf(float(wall.z)-float(tile.z)) <= 1: extra[side] = 0.51
		edges[-i-1] = extra
	# Repair only isolated missing floor cells surrounded on all four sides by
	# the same floor or its base walls. Never bridge a stairwell/lower floor/door.
	var candidates := {}
	for at in floor_cells:
		for offset in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i(0,1,0),Vector3i(0,-1,0)]:
			if not floor_cells.has(at+offset): candidates[at+offset] = true
	for at in candidates:
		var occupied := false
		for j in cells.get(Vector2i(at.x,at.y),[]):
			var kind: String = catalog.get(str(int(world.statics[j].id)),{}).get("kind","")
			if kind in ["floor","stairs","landing","door","wall","corner","window"]: occupied = true
		if occupied: continue
		var neighbors := 0
		var floors := 0
		for offset in [Vector3i.LEFT,Vector3i.RIGHT,Vector3i(0,1,0),Vector3i(0,-1,0)]:
			var other: Vector3i = at+offset
			if floor_cells.has(other):
				neighbors += 1
				floors += 1
				continue
			for j in cells.get(Vector2i(other.x,other.y),[]):
				var s: Dictionary = world.statics[j]
				if catalog.get(str(int(s.id)),{}).get("kind") in ["wall","corner"] and absf(float(s.z)-at.z) <= 1:
					neighbors += 1
					break
		if neighbors == 4 and floors >= 3:
			repairs.append(at)
			var extra := Vector4.ZERO
			var offsets := [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]
			for side in 4:
				for j in cells.get(Vector2i(at.x,at.y)+offsets[side],[]):
					var wall: Dictionary = world.statics[j]
					if catalog.get(str(int(wall.id)),{}).get("kind") in ["wall","corner"] and absf(float(wall.z)-at.z) <= 1: extra[side] = 0.51
			edges[at] = extra

func slab(ordinal: Variant, material: Material) -> Node3D:
	var extra: Vector4 = edges.get(ordinal,Vector4.ZERO)
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.002+extra.x+extra.y,0.12,1.002+extra.z+extra.w)
	node.mesh = mesh
	# Exact source top, thickness below it; continuous world-space timber UVs.
	node.position = Vector3((extra.y-extra.x)/2,-0.06,(extra.w-extra.z)/2)
	node.material_override = material
	return node
