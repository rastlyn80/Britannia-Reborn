extends RefCounted
# Outdoor dressing for house windows: open shutter pairs and some flower boxes.
# UO walls carry no inside/outside information, so the outdoor face is read
# from the source: indoor cells have a roof or upper floor overhead, outdoor
# cells beside the wall are open to the sky. Ambiguous windows (both sides
# covered or both open, crop edges) stay undressed, so nothing appears indoors.
# Shutter leaves fold back onto the wall beside the opening, so both
# neighbouring cells along the wall must be solid wall at the same level.
const COVER_KINDS := ["roof","floor","landing","gable"]
const SOLID_KINDS := ["wall","corner"]
# A covering record must sit at least this far (source Z) above the window base.
const COVER_RISE := 12
var plans: Dictionary = {}
var undecided := 0

func index(world: Dictionary, catalog: Dictionary) -> void:
	plans.clear()
	undecided = 0
	var cells := {}
	for i in world.statics.size():
		var cell := Vector2i(world.statics[i].x,world.statics[i].y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(i)
	var kind_of := func(i: int) -> String: return str(catalog.get(str(int(world.statics[i].id)),{}).get("kind",""))
	var covered := func(cell: Vector2i, z: int, kinds: Array) -> bool:
		for i in cells.get(cell,[]):
			if int(world.statics[i].z) >= z+COVER_RISE and kind_of.call(i) in kinds: return true
		return false
	var walled := func(cell: Vector2i, z: int, kinds: Array) -> bool:
		for i in cells.get(cell,[]):
			if absf(float(world.statics[i].z)-float(z)) <= 1 and kind_of.call(i) in kinds: return true
		return false
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var rule: Dictionary = catalog.get(str(int(s.id)),{})
		if rule.get("kind","") != "window": continue
		var cell := Vector2i(s.x,s.y)
		var axis_y: bool = rule.get("axis","x") == "y"
		var along := Vector2i(0,1) if axis_y else Vector2i(1,0)
		var normal := Vector2i(1,0) if axis_y else Vector2i(0,1)
		# Outdoors: nothing overhead two cells out, and only a roof eave (no
		# upper floor or landing) right beside the wall. Indoors: a roof or
		# floor above within three cells.
		var open_side := {}
		var roofed_side := {}
		for side in [-1,1]:
			open_side[side] = not covered.call(cell+normal*side*2,int(s.z),COVER_KINDS) and not covered.call(cell+normal*side,int(s.z),["floor","landing"])
			roofed_side[side] = false
			for k in range(1,4):
				if covered.call(cell+normal*side*k,int(s.z),COVER_KINDS): roofed_side[side] = true
		var outward := 0
		for side in [-1,1]:
			if open_side[side] and roofed_side[-side] and not (open_side[-side] and roofed_side[side]): outward = side
		# Another wall right outside means a gap too narrow to dress.
		if outward != 0 and walled.call(cell+normal*outward,int(s.z),["wall","window","corner","door"]): outward = 0
		if outward == 0:
			undecided += 1
			continue
		var shutters: bool = walled.call(cell-along,int(s.z),SOLID_KINDS) and walled.call(cell+along,int(s.z),SOLID_KINDS)
		# Flower boxes on about half of the shuttered windows, stable per cell.
		var box: bool = shutters and absi(int(s.x)*73856093^int(s.y)*19349663)%2 == 0
		plans[i] = {"side":outward,"shutters":shutters,"flower_box":box}

# Shutters and flower box for one window panel, in the panel's local frame
# (x along the wall, +z the wall normal before the record's axis rotation).
func dress(reconstruction: RefCounted, plan: Dictionary, sill: float, opening: float, family: String) -> Node3D:
	if plan.is_empty() or not (plan.get("shutters",false) or plan.get("flower_box",false)): return null
	var root := Node3D.new()
	root.set_meta("kind","dressing")
	var side := float(plan.side)
	# Outer face of the framing: Tudor oak stands 0.15 m proud, plain walls 0.09.
	var face := 0.15 if family in ["plaster","wood"] else 0.09
	if plan.get("shutters",false):
		# The kit pair leaves a 0.96 m gap between 0.43 m leaves; open them
		# just outside the 0.9 m window frame.
		var leaves: Node3D = reconstruction.fitted("MedievalKit/FShutter_Pair_Red.gltf" if plan.get("flower_box",false) else "MedievalKit/FShutter_Pair.gltf",Vector3(1.71,opening,0.08))
		leaves.position = Vector3(0,sill,side*(face+0.04))
		if side < 0: leaves.rotation.y = PI
		root.add_child(leaves)
	if plan.get("flower_box",false):
		var box: Node3D = reconstruction.fitted("MedievalKit/FlowerBox.gltf",Vector3(0.86,0.44,0.26))
		box.position = Vector3(0,sill-0.12,side*(face+0.12))
		if side < 0: box.rotation.y = PI
		root.add_child(box)
	return root
