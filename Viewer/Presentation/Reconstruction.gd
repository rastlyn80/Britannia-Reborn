extends RefCounted

const Geometry = preload("res://Presentation/GeometryLibrary.gd")
var geometry := Geometry.new()
var facade := preload("res://Presentation/Facade.gd").new()
var roofs := preload("res://Presentation/RoofPlan.gd").new()
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/static-catalog.json")).rules
var scenes := {}
var bounds := {}
var roof_materials := {}
var architecture_materials := {}
var nature_materials := {}
var prop_materials := {}
var prop_mesh_variants := {}
var source_origin := Vector2.ZERO
var gable_material: ShaderMaterial
# Roof ends take the material of the walls actually under that roof; a brick
# or stone building must not grow plaster gable sails.
var gable_materials := {}
var roof_families := {}
# Generic "window" graphics take the material of the wall run they sit in.
var window_families := {}
# Wall-flagged pillars standing on a wall top: spire pinnacles, not towers.
var pinnacles := {}
# Carpet tiles by cell (source Zs), so each tile knows the rug's outer edges.
var carpet_cells := {}
# Wall ordinal -> metres of foundation course down to what really supports it.
var foundations := {}
# Arcades: cells with walkable arch openings and with solid arch pieces (by Z).
var passage_cells := {}
# Floor ordinal -> edges (0 N, 1 E, 2 S, 3 W) that drop into a stairwell.
var stairwell_rails := {}
# Topmost wall/post ordinal -> metres to raise it to the roof eave above it.
var eave_extensions := {}
var solid_arch_cells := {}
# Rendered terrain (TerrainSurface) and source supports under vegetation. UO
# stores one height per tile; the presented ground interpolates between tiles,
# so plants placed at raw tile height float or sink on slopes and planters.
var terrain_surface
var ground_supports := {}
const VEGETATION := ["tree","flower","grass","bush","mushroom","rock","log","fern","plant","reeds","cactus","stalagmite","crystal"]
var lava_materials := {}
# Optional local average colours of original art (scripts/build-item-catalog.ps1);
# graphics placed in Britain are excluded, so the reviewed city keeps its look.
static var art_colors: Variant = null
static func art_tint(id: int) -> String:
	if art_colors == null:
		art_colors = {}
		if FileAccess.file_exists("res://item-colors.local.json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://item-colors.local.json"))
			if parsed is Dictionary: art_colors = parsed
	return str(art_colors.get(str(id),""))
var water_material: ShaderMaterial
var shoreline
var show_boundary_fragments := false
var boundary_fragments := 0
var mapped := 0
var unresolved := 0
var grouped := 0
var report: Array = []
var groups := {}
# Chimney group owner -> source Z its stack descends to (roof or wall below).
var chimney_bases := {}
var wall_cells := {}
# Fence pieces (graphic id) by source cell and Z: stacked pieces continue the
# post below; neighbouring pieces join their rails at junctions.
var fence_cells := {}
var presentation_adjustments := {}
var contextual_suppressed := 0
var floors := preload("res://Presentation/FloorPlan.gd").new()
var supports := preload("res://Presentation/SupportPlan.gd").new()
var bridges := preload("res://Presentation/BridgePlan.gd").new()
var windows := preload("res://Presentation/WindowDressing.gd").new()

static func info(world: Dictionary, id: int, statics: bool) -> Dictionary:
	var data = world.get("staticData" if statics else "landData")
	return data.get(str(id),{}) if data is Dictionary else {}

static func terrain_color(name: String) -> Color:
	match name.to_lower():
		"grass": return Color("64884e")
		"forest": return Color("496940")
		"dirt": return Color("8c7658")
		"cobblestones", "stone": return Color("7e8787")
		"wooden floor": return Color("8b704c")
		"brick": return Color("9a7961")
		"sand": return Color("bba779")
		"water": return Color("346b80")
	return Color("807989")

func rule_for(id: int) -> Dictionary:
	return catalog.get(str(id),{})

func index(world: Dictionary) -> void:
	preload("res://Presentation/RegionalRules.gd").extend(world,catalog)
	preload("res://Presentation/ReviewedCatalog.gd").extend(catalog)
	if world.get("render_cells",false):print("REGIONAL RULES DONE")
	source_origin = Vector2(world.get("originX",0),world.get("originY",0))
	facade.index(world,catalog)
	windows.index(world,catalog)
	floors.index(world,catalog)
	roofs.index(world,catalog)
	if world.get("render_cells",false):print("REGIONAL ROOFS/FACADES DONE")
	groups.clear()
	# Co-located floor art records remain in coverage but share one surface.
	var floor_cells := {}
	for i in world.statics.size():
		var tile: Dictionary = world.statics[i]
		if rule_for(tile.id).get("kind") != "floor": continue
		var cell := Vector3i(tile.x,tile.y,tile.z)
		if not floor_cells.has(cell): floor_cells[cell] = []
		floor_cells[cell].append(i)
	for cell in floor_cells:
		if floor_cells[cell].size() > 1: _group(floor_cells[cell],world,"floor")
	presentation_adjustments.clear()
	wall_cells.clear()
	fence_cells.clear()
	var trees := {}
	var beds := {}
	var arches := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var kind := str(rule_for(s.id).get("kind","unknown"))
		var cell := Vector3i(s.x,s.y,s.z)
		if kind in ["wall","window","corner"]: wall_cells[cell] = true
		if kind == "fence": fence_cells[cell] = int(s.id)
		if kind == "tree": trees[cell] = i
		if kind == "bed": beds[cell] = i
		if kind == "arch": arches[cell] = i
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if rule_for(s.id).get("kind") != "canopy": continue
		var cell := Vector3i(s.x,s.y,s.z)
		if trees.has(cell): _group([trees[cell],i],world,"tree")
	var visited := {}
	for cell in beds:
		if visited.has(cell): continue
		var pending := [cell]
		var members := []
		while not pending.is_empty():
			var at: Vector3i = pending.pop_back()
			if visited.has(at): continue
			visited[at] = true
			members.append(beds[at])
			for offset in [Vector3i(1,0,0),Vector3i(-1,0,0),Vector3i(0,1,0),Vector3i(0,-1,0)]:
				if beds.has(at+offset) and not visited.has(at+offset): pending.append(at+offset)
		_group(members,world,"bed")
	# Source gables are stacked wedges; furniture IDs are component tiles.
	for assembled_kind in ["gable","bench","table","counter"]:
		var remaining := {}
		var nearby := {}
		for i in world.statics.size():
			var tile:Dictionary=world.statics[i]
			if rule_for(tile.id).get("kind")!=assembled_kind:continue
			remaining[i]=true
			var cell:=Vector2i(tile.x,tile.y)
			if not nearby.has(cell):nearby[cell]=[]
			nearby[cell].append(i)
		while not remaining.is_empty():
			var pending := [remaining.keys()[0]]
			var members := []
			while not pending.is_empty():
				var at: int = pending.pop_back()
				if not remaining.has(at): continue
				remaining.erase(at)
				members.append(at)
				var a: Dictionary = world.statics[at]
				for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					for other in nearby.get(Vector2i(a.x,a.y)+offset,[]):
						if not remaining.has(other):continue
						var b:Dictionary=world.statics[other]
						var same_axis:bool=rule_for(a.id).get("axis")==rule_for(b.id).get("axis")
						if (same_axis or assembled_kind!="gable") and absi(int(a.z)-int(b.z))<=(3 if assembled_kind=="gable" else 0):pending.append(other)
			_group(members,world,assembled_kind)
	# Multi-tile props are assemblies, not one complete model per sprite piece.
	var prop_cells := {}
	var prop_remaining := {}
	for i in world.statics.size():
		var source:Dictionary=world.statics[i]
		var rule:=rule_for(source.id)
		if rule.get("kind","")!="prop" or rule.get("model","") not in ["cannon","fountain","display_case","training","music","hearth"]:continue
		var cell:=Vector2i(source.x,source.y)
		if not prop_cells.has(cell):prop_cells[cell]=[]
		prop_cells[cell].append(i)
		prop_remaining[i]=true
	while not prop_remaining.is_empty():
		var pending: Array=[prop_remaining.keys()[0]]
		var members: Array=[]
		while not pending.is_empty():
			var current:int=pending.pop_back()
			if not prop_remaining.has(current):continue
			prop_remaining.erase(current)
			members.append(current)
			var a:Dictionary=world.statics[current]
			for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				for other in prop_cells.get(Vector2i(a.x,a.y)+offset,[]):
					var b:Dictionary=world.statics[other]
					if prop_remaining.has(other) and rule_for(a.id).model==rule_for(b.id).model and absi(int(a.z)-int(b.z))<=20:pending.append(other)
		_group(members,world,"prop")
	# A UO chimney is several stacked/adjacent sprite tiles; present each as one
	# masonry stack that descends into the roof or wall it stands on.
	var chimney_cells := {}
	var chimney_remaining := {}
	for i in world.statics.size():
		if rule_for(world.statics[i].id).get("kind","") != "chimney": continue
		var cell := Vector2i(world.statics[i].x,world.statics[i].y)
		if not chimney_cells.has(cell): chimney_cells[cell] = []
		chimney_cells[cell].append(i)
		chimney_remaining[i] = true
	if not chimney_cells.is_empty():
		var below := {}
		for i in world.statics.size():
			var other: Dictionary = world.statics[i]
			var cell := Vector2i(other.x,other.y)
			if chimney_cells.has(cell) and rule_for(other.id).get("kind","") != "chimney":
				if not below.has(cell): below[cell] = []
				below[cell].append(int(other.z))
		while not chimney_remaining.is_empty():
			var pending: Array = [chimney_remaining.keys()[0]]
			var members: Array = []
			while not pending.is_empty():
				var current: int = pending.pop_back()
				if not chimney_remaining.has(current): continue
				chimney_remaining.erase(current)
				members.append(current)
				var a: Dictionary = world.statics[current]
				for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					for other in chimney_cells.get(Vector2i(a.x,a.y)+offset,[]):
						if chimney_remaining.has(other) and absi(int(a.z)-int(world.statics[other].z)) <= 20: pending.append(other)
			_group(members,world,"chimney")
			var low_z := 1000
			for member in members: low_z = mini(low_z,int(world.statics[member].z))
			# Highest supporting record under the footprint, at most 30 Z below.
			var support := -1000
			for member in members:
				for z in below.get(Vector2i(world.statics[member].x,world.statics[member].y),[]):
					if z < low_z and low_z-z <= 30: support = maxi(support,z)
			chimney_bases[groups[members[0]].owner] = support if support > -1000 else low_z-6
	# The same graphic repeated in a cell within two Z (stacked duplicates in the
	# source) draws once; overlapping copies flicker against each other.
	var stacked := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var key := Vector3i(s.x,s.y,int(s.id))
		if not stacked.has(key): stacked[key] = []
		stacked[key].append(i)
	for key in stacked:
		var copies: Array = stacked[key]
		if copies.size() < 2: continue
		copies.sort_custom(func(a,b): return int(world.statics[a].z) < int(world.statics[b].z))
		var last := int(world.statics[copies[0]].z)
		for n in range(1,copies.size()):
			var z := int(world.statics[copies[n]].z)
			if z-last <= 2 and str(rule_for(int(key.z)).get("kind","")) in ["prop","asset"]:
				presentation_adjustments[copies[n]] = {"suppress":true,"reason":"stacked duplicate of the same graphic"}
			else: last = z
	# Walkable wall pieces (gateways, arch openings) run along their wall axis
	# into one archway each; solid arch pieces become the piers beside them.
	var passages := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if passage(world,s): passages[Vector3i(s.x,s.y,s.z)] = i
	# Cells holding wall-like records (any Z) and solid arch pieces, for
	# two-tile arch spans below.
	var arch_cells := {}
	passage_cells.clear()
	solid_arch_cells.clear()
	for i in world.statics.size():
		var tile: Dictionary = world.statics[i]
		var tile_kind := str(rule_for(int(tile.id)).get("kind",""))
		if tile_kind in ["wall","window","corner","arch","door","pillar","post"]:
			arch_cells[Vector3i(tile.x,tile.y,1)] = true
		if tile_kind == "arch" and not passage(world,tile):
			arch_cells[Vector3i(tile.x,tile.y,0)] = true
			if not solid_arch_cells.has(Vector2i(tile.x,tile.y)): solid_arch_cells[Vector2i(tile.x,tile.y)] = []
			solid_arch_cells[Vector2i(tile.x,tile.y)].append(int(tile.z))
	for cell in passages:
		if not passage_cells.has(Vector2i(cell.x,cell.y)): passage_cells[Vector2i(cell.x,cell.y)] = []
		passage_cells[Vector2i(cell.x,cell.y)].append(cell.z)
	var joined := {}
	for cell in passages:
		if joined.has(cell): continue
		var at: int = passages[cell]
		var step := Vector3i(0,1,0) if str(rule_for(int(world.statics[at].id)).get("axis","x")) == "y" else Vector3i(1,0,0)
		var start: Vector3i = cell
		while passages.has(start-step) and not joined.has(start-step): start -= step
		var members := []
		var walk: Vector3i = start
		while passages.has(walk) and not joined.has(walk):
			joined[walk] = true
			members.append(passages[walk])
			walk += step
		_group(members,world,"archway")
		# Wide arches: the source draws the arch over empty cells (up to five) to
		# the next solid arch piece (arcades such as the Chamber of Virtue).
		# The opening spans those cells instead of leaving a square hole.
		var group: Dictionary = groups[members[0]]
		for direction in [1,-1]:
			var edge: Vector3i = (walk if direction > 0 else start-step)
			var empty := 0
			while empty < 6 and not _wall_at(world,edge,arch_cells):
				empty += 1
				edge += step*direction
			if empty == 0 or empty > 5 or not arch_cells.has(Vector3i(edge.x,edge.y,0)): continue
			var extended := Vector2(edge.x-step.x*direction,edge.y-step.y*direction)
			var low: Vector2 = group.low.min(extended)
			var high: Vector2 = (group.low+group.size-Vector2.ONE).max(extended)
			group.low = low
			group.size = high-low+Vector2.ONE

	if world.get("render_cells",false):print("REGIONAL GROUPS DONE")
	_plan_context(world)
	_plan_mounts(world)
	_plan_roof_families(world)
	_plan_window_families(world)
	_plan_pinnacles(world)
	_plan_foundations(world)
	_plan_stairwells(world)
	_plan_stray_roofs(world)
	_plan_eaves(world)
	carpet_cells.clear()
	for tile in world.statics:
		if rule_for(int(tile.id)).get("kind","") != "carpet": continue
		# Several storeys can carry rugs over the same cell.
		var rug_cell := Vector2i(tile.x,tile.y)
		if not carpet_cells.has(rug_cell): carpet_cells[rug_cell] = []
		carpet_cells[rug_cell].append(int(tile.z))
	ground_supports.clear()
	for tile in world.statics:
		var support_kind := str(rule_for(int(tile.id)).get("kind",""))
		if support_kind not in ["floor","landing","planter","stairs"]: continue
		var detail := info(world,int(tile.id),true)
		var top := float(tile.z)+float(detail.get("height",0))*(0.5 if int(detail.get("flags",0)) & 0x400 else 1.0)
		var cell := Vector2i(tile.x,tile.y)
		if not ground_supports.has(cell): ground_supports[cell] = []
		ground_supports[cell].append(top)
	bridges.index(world,catalog)
	supports.catalog = catalog
	supports.index(world)

# Legacy art can include unsupported decoration. Keep source XYZ immutable and
# record conservative presentation repairs rather than inventing supports.
func _plan_context(world: Dictionary) -> void:
	var terrain := {}
	var cells := {}
	for tile in world.get("terrain",[]): terrain[Vector2i(tile.x,tile.y)] = tile
	for tile in world.statics:
		var cell := Vector2i(tile.x,tile.y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(tile)
	for ordinal in groups:
		var group: Dictionary = groups[ordinal]
		if group.owner != ordinal: continue
		var source: Dictionary = world.statics[ordinal]
		if group.kind in ["bench","table","counter","bed"]:
			var unsupported_duplicates := true
			for member in group.indices:
				var tile: Dictionary = world.statics[member]
				var cell := Vector2i(tile.x,tile.y)
				var supported: bool = terrain.has(cell) and int(terrain[cell].z) == int(tile.z)
				var duplicate_below := false
				for other in cells[cell]:
					if int(other.id) == int(tile.id) and int(other.z) < int(tile.z): duplicate_below = true
					var data := info(world,int(other.id),true)
					var flags := int(data.get("flags",0))
					var top := float(other.z)+float(data.get("height",0))*(0.5 if flags & 0x400 else 1.0)
					if flags & 0x200 and not flags & 0x40 and absf(top-float(tile.z)) < 0.01: supported = true
				if supported or not duplicate_below: unsupported_duplicates = false
			if unsupported_duplicates:
				presentation_adjustments[ordinal] = {"suppress":true,"reason":"unsupported elevated duplicate of source furniture below; retained in source/map view"}
		if group.kind != "gable": continue
		var axis_y: bool = rule_for(int(source.id)).get("axis") == "y"
		var plane := float(group.low.x if axis_y else group.low.y)
		var start := int(group.low.y if axis_y else group.low.x)
		var length := int(group.size.y if axis_y else group.size.x)
		var candidates := {}
		for wall in world.statics:
			var rule := rule_for(int(wall.id))
			if rule.get("kind") not in ["wall","window","corner"]: continue
			if rule.get("kind") != "corner" and (rule.get("axis") == "y") != axis_y: continue
			var top := float(wall.z)+float(info(world,int(wall.id),true).get("height",0))
			if absf(top-float(group.min_z)) > 1: continue
			var along := int(wall.y if axis_y else wall.x)
			var at := int(wall.x if axis_y else wall.y)
			if along < start or along >= start+length or absf(at-plane) > 8: continue
			if not candidates.has(at): candidates[at] = {}
			candidates[at][along] = true
		var supported: bool = candidates.has(int(plane)) and candidates[int(plane)].size() >= ceili(length*0.8)
		var exterior := roofs.tiles.is_empty()
		for roof_ordinal in roofs.tiles:
			var tile: Dictionary = roofs.tiles[roof_ordinal]
			var roof_source: Dictionary = world.statics[roof_ordinal]
			var anchor: Array = rule_for(int(roof_source.id)).get("anchorOffset",[-1,-1])
			for edge in ([1,3] if axis_y else [0,2]):
				if not tile.exposed[edge]: continue
				var normal_at := float(roof_source.x)+float(anchor[0])+(1.0 if edge == 1 else 0.0) if axis_y else float(roof_source.y)+float(anchor[1])+(1.0 if edge == 2 else 0.0)
				var along_at := float(roof_source.y)+float(anchor[1]) if axis_y else float(roof_source.x)+float(anchor[0])
				if absf(normal_at-(plane+0.5)) <= 0.55 and along_at >= start-1 and along_at <= start+length and float(tile.heights.max()) >= float(group.min_z)*float(world.elevationScale): exterior = true
		if not roofs.tiles.is_empty() and exterior:
			presentation_adjustments[ordinal] = {"suppress":true,"reason":"exterior gable closure belongs to the continuous roof envelope; omit duplicate source-wedge mesh"}
		elif not supported or not exterior:
			presentation_adjustments[ordinal] = {"suppress":true,"reason":"source gable has no supporting wall on its own plane or matching exterior roof edge; no speculative relocation"}

# Wall-hung torches, sconces and maps occupy the cell in front of their wall
# (west or north, the faces legacy art shows). Hang them on that wall's face as a
# recorded presentation offset; source XYZ, serial and picking ownership remain.
func _plan_mounts(world: Dictionary) -> void:
	var cells := {}
	for i in world.statics.size():
		var cell := Vector2i(world.statics[i].x,world.statics[i].y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(i)
	var found := {}
	var votes := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if rule_for(int(s.id)).get("mount","") != "wall": continue
		var sides := {}
		for side in ["west","north"]:
			var offset := Vector2i.LEFT if side == "west" else Vector2i.UP
			for j in cells.get(Vector2i(s.x,s.y)+offset,[]):
				var wall: Dictionary = world.statics[j]
				var rule := rule_for(int(wall.id))
				if rule.get("kind") not in ["wall","window","corner"]: continue
				if int(s.z) < int(wall.z) or int(s.z) > int(wall.z)+int(info(world,int(wall.id),true).get("height",20)): continue
				# A parallel wall presents its face; a perpendicular one only its end.
				var face: bool = rule.get("kind") == "corner" or (rule.get("axis") == "y") == (side == "west")
				sides[side] = 0.91 if face or sides.get(side,0.0) == 0.91 else 0.5
		found[i] = sides
		if sides.size() == 1:
			var key := str(int(s.id))+"/"+str(sides.keys()[0])
			votes[key] = int(votes.get(key,0))+1
	for i in found:
		var sides: Dictionary = found[i]
		var id := str(int(world.statics[i].id))
		if sides.is_empty():
			presentation_adjustments[i] = {"reason":"wall attachment without adjacent source wall; left at its source cell"}
			continue
		var side: String = sides.keys()[0]
		if sides.size() > 1: side = "west" if int(votes.get(id+"/west",0)) >= int(votes.get(id+"/north",0)) else "north"
		var distance: float = sides[side]
		presentation_adjustments[i] = {"offset":Vector3(-distance,0,0) if side == "west" else Vector3(0,0,-distance),"yaw":-PI/2 if side == "west" else PI,"reason":"hung on adjacent %s source wall face" % side}

# A wall-flagged source piece the native client lets you walk through
# (gateway or arch opening), tall enough to stand under.
func passage(world: Dictionary, s: Dictionary) -> bool:
	if not str(rule_for(int(s.id)).get("kind","")) in ["wall","window","corner","arch","trim"]: return false
	var detail := info(world,int(s.id),true)
	var flags := int(detail.get("flags",0))
	return flags & 0x10 != 0 and flags & 0x40 == 0 and int(detail.get("height",0)) >= 10

static func wall_family(world: Dictionary, id: int) -> String:
	var name := str(info(world,id,true).get("name",""))
	var family := preload("res://Presentation/Facade.gd").family_for(name)
	return str(preload("res://Presentation/ReviewedCatalog.gd").entry(id).get("facadeFamily",family))

# A window named only "window" is plaster by name, yet sits in log, plank,
# brick or stone runs; the nearest wall along its own axis decides (reviewed
# per-graphic families still win in build()).
func _plan_window_families(world: Dictionary) -> void:
	window_families.clear()
	var walls := {}
	for i in world.statics.size():
		var tile: Dictionary = world.statics[i]
		if rule_for(int(tile.id)).get("kind","") not in ["wall","corner"]: continue
		var cell := Vector2i(tile.x,tile.y)
		if not walls.has(cell): walls[cell] = []
		walls[cell].append(tile)
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var rule := rule_for(int(s.id))
		if rule.get("kind","") not in ["window","arch"]: continue
		var step := Vector2i(0,1) if rule.get("axis","x") == "y" else Vector2i(1,0)
		var found := ""
		# Galleries and window bands can run several cells between plain walls.
		for distance in range(1,7):
			for direction in [-1,1]:
				if found != "": break
				for other in walls.get(Vector2i(s.x,s.y)+step*distance*direction,[]):
					if absi(int(other.z)-int(s.z)) > 1: continue
					found = wall_family(world,int(other.id))
					break
			if found != "": break
		if found != "": window_families[i] = found
	# An archway run is one opening: any member's finding stands for all.
	for i in window_families.keys():
		var group: Dictionary = groups.get(i,{})
		for member in group.get("indices",[]):
			if not window_families.has(member): window_families[member] = window_families[i]

# A "stone pillar" record on top of a wall is a corner pinnacle in the art
# (a slim spire just above the coping); its tiledata height (20) describes the
# sprite bounds, and drawn at full height it became a 4 m chimney-like pier.
func _plan_pinnacles(world: Dictionary) -> void:
	pinnacles.clear()
	var tops := {}
	for tile in world.statics:
		if rule_for(int(tile.id)).get("kind","") not in ["wall","corner","trim","arch","pillar","window"]: continue
		var cell := Vector2i(tile.x,tile.y)
		var top := int(tile.z)+int(info(world,int(tile.id),true).get("height",0))
		if not tops.has(Vector3i(cell.x,cell.y,0)): tops[Vector3i(cell.x,cell.y,0)] = []
		tops[Vector3i(cell.x,cell.y,0)].append(Vector2i(int(tile.z),top))
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if rule_for(int(s.id)).get("kind","") != "pillar" or int(info(world,int(s.id),true).get("flags",0)) & 0x10 == 0 or int(info(world,int(s.id),true).get("height",0)) < 10: continue
		# A column standing on the same graphic is its upper storey, not a spire.
		var stacked := false
		for other in world.statics:
			if int(other.x) == int(s.x) and int(other.y) == int(s.y) and int(other.id) == int(s.id) and int(other.z) < int(s.z) and int(other.z) >= int(s.z)-22: stacked = true
		if stacked: continue
		for span in tops.get(Vector3i(s.x,s.y,0),[]):
			if span.x < int(s.z) and span.y >= int(s.z)-4 and span.y <= int(s.z)+1: pinnacles[i] = true

# UO walls often start a few Z above the plinth, floor or ground under them;
# the 2D art overlaps, but in 3D a slot of daylight opened under the house
# (the storey seemed to float). Each storey-base wall gets a foundation course
# down to the highest support beneath it: a plinth/wall top, a floor, or the
# lowest terrain corner of its cell. Gaps over 3 m are left alone (bridges,
# galleries over passages).
func _plan_foundations(world: Dictionary) -> void:
	foundations.clear()
	var land := {}
	for tile in world.get("terrain",[])+world.get("terrainHalo",[]):
		land[Vector2i(tile.x,tile.y)] = int(tile.z)
	var tops := {}
	for tile in world.statics:
		var kind := str(rule_for(int(tile.id)).get("kind",""))
		if kind not in ["wall","window","corner","trim","floor","landing","stairs","pier","post","pillar"]: continue
		var detail := info(world,int(tile.id),true)
		var top := int(tile.z)+int(float(detail.get("height",0))*(0.5 if int(detail.get("flags",0)) & 0x400 else 1.0))
		var cell := Vector2i(tile.x,tile.y)
		if not tops.has(cell): tops[cell] = []
		tops[cell].append(top)
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if str(rule_for(int(s.id)).get("kind","")) not in ["wall","window","corner"]: continue
		if int(info(world,int(s.id),true).get("height",0)) < 10: continue
		var cell := Vector2i(s.x,s.y)
		var support := -1000
		for top in tops.get(cell,[]):
			if int(top) <= int(s.z): support = maxi(support,int(top))
		var lowest := 1000
		for corner in [Vector2i.ZERO,Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
			if land.has(cell+corner): lowest = mini(lowest,int(land[cell+corner]))
		if lowest < 1000 and lowest <= int(s.z): support = maxi(support,lowest)
		var gap := int(s.z)-support
		if support > -1000 and gap >= 1 and gap <= 15: foundations[i] = float(gap)*float(world.elevationScale)

func _arch_at(cells: Dictionary, cell: Vector2i, z: int) -> bool:
	for other in cells.get(cell,[]):
		if absi(int(other)-z) <= 2: return true
	return false

func _wall_at(_world: Dictionary, cell: Vector3i, arch_cells: Dictionary) -> bool:
	return arch_cells.has(Vector3i(cell.x,cell.y,1))

# A floor that ends at a stair opening gets a balustrade along that edge,
# except where the stairs themselves arrive: a bare hole in a floor read as
# a construction defect. The hole is a floorless cell with stairs below it
# (or beside it, for wide stairwells).
func _plan_stairwells(world: Dictionary) -> void:
	stairwell_rails.clear()
	var floors_at := {}
	var stairs_at := {}
	var walls_at := {}
	for tile in world.statics:
		var kind := str(rule_for(int(tile.id)).get("kind",""))
		var cell := Vector2i(tile.x,tile.y)
		if kind == "floor":
			if not floors_at.has(cell): floors_at[cell] = []
			floors_at[cell].append(int(tile.z))
		elif kind in ["stairs","landing"]:
			var detail := info(world,int(tile.id),true)
			if not stairs_at.has(cell): stairs_at[cell] = []
			# Bridge-flagged landings stand at half their tiledata height.
			var rise := int(float(detail.get("height",0))*(0.5 if int(detail.get("flags",0)) & 0x400 else 1.0))
			stairs_at[cell].append(Vector2i(int(tile.z),int(tile.z)+rise))
		elif kind in ["wall","window","corner","trim","fence","door","arch"]:
			if not walls_at.has(cell): walls_at[cell] = []
			walls_at[cell].append(int(tile.z))
	var steps := [Vector2i(0,-1),Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0)]
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		if str(rule_for(int(s.id)).get("kind","")) != "floor": continue
		var z := int(s.z)
		var cell := Vector2i(s.x,s.y)
		var blocked := false
		for wz in walls_at.get(cell,[]):
			if absi(int(wz)-z) <= 2: blocked = true
		if blocked: continue
		var edges: Array = []
		for d in 4:
			var next: Vector2i = cell+steps[d]
			var floored := false
			for fz in floors_at.get(next,[]):
				if absi(int(fz)-z) <= 2: floored = true
			var walled := false
			for wz in walls_at.get(next,[]):
				if absi(int(wz)-z) <= 2: walled = true
			if floored or walled: continue
			var below := false
			var arrival := false
			for probe in [next,next+steps[(d+1)%4],next+steps[(d+3)%4],next+steps[d]]:
				for span in stairs_at.get(probe,[]):
					if span.x < z-1 and span.x >= z-30: below = true
					# Stairs or a platform reaching this floor's level continue it.
					if probe == next and span.y >= z-3 and span.y <= z+3: arrival = true
			if below and not arrival: edges.append(d)
		if not edges.is_empty(): stairwell_rails[i] = edges

# One- or two-tile roof fragments with no wall, gable or roof under or beside
# them at their eave are source leftovers (a lone shingle eight Z above a
# ridge); drawn in 3D they float as loose planks, so they are not drawn.
func _plan_stray_roofs(world: Dictionary) -> void:
	var members := {}
	for ordinal in roofs.tiles:
		var component := int(roofs.tiles[ordinal].get("component",-1))
		if not members.has(component): members[component] = []
		members[component].append(ordinal)
	var roof_cells := {}
	for ordinal in roofs.tiles:
		var cell := Vector2i(world.statics[ordinal].x,world.statics[ordinal].y)
		if not roof_cells.has(cell): roof_cells[cell] = []
		roof_cells[cell].append(ordinal)
	var tops := {}
	for tile in world.statics:
		if str(rule_for(int(tile.id)).get("kind","")) not in ["wall","window","corner","gable","trim","pillar","post","chimney","beam","arch"]: continue
		var cell := Vector2i(tile.x,tile.y)
		if not tops.has(cell): tops[cell] = []
		tops[cell].append(Vector2i(int(tile.z),int(tile.z)+int(info(world,int(tile.id),true).get("height",0))))
	for component in members:
		var list: Array = members[component]
		if list.size() > 2: continue
		var supported := false
		for ordinal in list:
			var s: Dictionary = world.statics[ordinal]
			for dx in range(-1,2):
				for dy in range(-1,2):
					for span in tops.get(Vector2i(s.x+dx,s.y+dy),[]):
						if span.y >= int(s.z)-6 and span.x <= int(s.z)+1: supported = true
		# Ridge caps, dormers and material changes are small components too,
		# but they touch the rest of their roof; only isolated tiles are strays.
		for ordinal in list:
			var s: Dictionary = world.statics[ordinal]
			for dx in range(-1,2):
				for dy in range(-1,2):
					for other in roof_cells.get(Vector2i(s.x+dx,s.y+dy),[]):
						if not list.has(other) and absi(int(world.statics[other].z)-int(s.z)) <= 4: supported = true
		if supported: continue
		for ordinal in list:
			presentation_adjustments[ordinal] = {"suppress":true,"reason":"unsupported stray roof fragment"}

# UO roof sprites draw down over the band between a wall's top and a roof
# placed a few Z higher; in 3D that band was open sky and the roof hung in
# the air. The topmost wall, post or pillar under (or beside) a roof eave
# rises to meet it, up to 16 Z (3.2 m).
func _plan_eaves(world: Dictionary) -> void:
	eave_extensions.clear()
	var roof_bases := {}
	for ordinal in roofs.tiles:
		if presentation_adjustments.get(ordinal,{}).get("suppress",false): continue
		var tile: Dictionary = world.statics[ordinal]
		var cell := Vector2i(tile.x,tile.y)
		if not roof_bases.has(cell): roof_bases[cell] = []
		roof_bases[cell].append(int(tile.z))
	var stacks := {}
	for i in world.statics.size():
		var tile: Dictionary = world.statics[i]
		if str(rule_for(int(tile.id)).get("kind","")) not in ["wall","window","corner","pillar","post","trim","gable","beam"]: continue
		var cell := Vector2i(tile.x,tile.y)
		if not stacks.has(cell): stacks[cell] = []
		stacks[cell].append(i)
	for cell in stacks:
		for i in stacks[cell]:
			var tile: Dictionary = world.statics[i]
			var kind := str(rule_for(int(tile.id)).get("kind",""))
			if kind in ["trim","gable","beam"]: continue
			var top := int(tile.z)+int(info(world,int(tile.id),true).get("height",0))
			var covered := false
			for j in stacks[cell]:
				if j != i and int(world.statics[j].z) >= top-1 and int(world.statics[j].z) <= top+16: covered = true
			if covered: continue
			# The roof over the wall line itself decides; otherwise the lowest
			# eave tile beside it.
			var eave := 1000
			for z in roof_bases.get(cell,[]):
				if int(z) > top and int(z) <= top+16: eave = mini(eave,int(z))
			if eave == 1000:
				for dx in range(-1,2):
					for dy in range(-1,2):
						for z in roof_bases.get(cell+Vector2i(dx,dy),[]):
							if int(z) > top and int(z) <= top+16: eave = mini(eave,int(z))
			if eave < 1000: eave_extensions[i] = float(eave-top)*float(world.elevationScale)

# Wooden table runs: a photoscan-textured trestle table (Objaverse,
# CC-BY) repeated along the run, each piece at most about 1.9 m long.
# Another fence piece starts where this one ends (UO stacks pieces into tall
# railings and porch posts), so its post runs on without a cap.
func _fence_above(s: Dictionary, source_height: int) -> bool:
	for dz in [-1,0,1]:
		if fence_cells.has(Vector3i(s.x,s.y,int(s.z)+source_height+dz)): return true
	return false

# World directions (x, y as UO east/south) toward neighbouring fence pieces at
# about the same height whose rails can meet this piece's (post-only pieces,
# such as porch posts, join nothing).
func _fence_links(s: Dictionary) -> Array:
	var links := []
	if not preload("res://Presentation/FenceBuilder.gd").has_rails(int(s.id)): return links
	for direction in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		for dz in range(-3,4):
			var neighbour: Variant = fence_cells.get(Vector3i(s.x+direction.x,s.y+direction.y,int(s.z)+dz))
			if neighbour != null and preload("res://Presentation/FenceBuilder.gd").has_rails(int(neighbour)):
				links.append(direction)
				break
	return links

func trestle_run(size: Vector2, model := "Objaverse/table_wood_b/table_wood_b.glb", height := 0.8, piece_length := 1.9) -> Node3D:
	var root := Node3D.new()
	var length := maxf(size.x,size.y)
	var depth := minf(size.x,size.y)*0.9
	var count := maxi(1,roundi(length/piece_length))
	for i in count:
		var piece: Node3D = fitted(model,Vector3(length/count*0.96,height,depth))
		piece.position.x = -length/2+length/count*(i+0.5)
		root.add_child(piece)
	if size.y > size.x: root.rotation.y = PI/2
	return root

func stairwell_balustrade(edges: Array) -> Node3D:
	var root := Node3D.new()
	var wood := preload("res://Presentation/DoorLeaf.gd").surface("medieval_wood",Color(0.62,0.48,0.36))
	var box := preload("res://Presentation/DoorLeaf.gd")._box
	for d in edges:
		var along_x: bool = d in [0,2]
		var normal := [Vector3(0,0,-1),Vector3(1,0,0),Vector3(0,0,1),Vector3(-1,0,0)][d] as Vector3
		var centre: Vector3 = normal*0.46
		var length := Vector3(1.0,0,0) if along_x else Vector3(0,0,1.0)
		box.call(root,(Vector3(1.0,0.07,0.08) if along_x else Vector3(0.08,0.07,1.0)),centre+Vector3(0,0.93,0),wood)
		box.call(root,(Vector3(1.0,0.05,0.06) if along_x else Vector3(0.06,0.05,1.0)),centre+Vector3(0,0.1,0),wood)
		for end in [-0.46,0.46]: box.call(root,Vector3(0.09,0.97,0.09),centre+length*end+Vector3(0,0.485,0),wood)
		for k in 3: box.call(root,Vector3(0.035,0.8,0.035),centre+length*(-0.25+0.25*k)+Vector3(0,0.52,0),wood)
	return root

func _plan_roof_families(world: Dictionary) -> void:
	roof_families.clear()
	var walls := {}
	for tile in world.statics:
		# Storey walls only: low trims and plinths (often stone) do not decide the gable.
		if rule_for(int(tile.id)).get("kind","") not in ["wall","window","corner"]: continue
		var cell := Vector2i(tile.x,tile.y)
		if not walls.has(cell): walls[cell] = []
		walls[cell].append([int(tile.z),wall_family(world,int(tile.id))])
	for i in world.statics.size():
		var roof: Dictionary = world.statics[i]
		if rule_for(int(roof.id)).get("kind","") != "roof": continue
		var votes := {}
		for dy in range(-3,4):
			for dx in range(-3,4):
				# Only the highest wall under the roof in each column votes: the storey
				# directly below decides (stone ground floor + timber upper = timber).
				var storey_z: int = -1000000
				var storey_family: String = ""
				for entry in walls.get(Vector2i(roof.x+dx,roof.y+dy),[]):
					if int(entry[0]) < int(roof.z) and int(entry[0]) > storey_z:
						storey_z = int(entry[0])
						storey_family = str(entry[1])
				if storey_family != "": votes[storey_family] = int(votes.get(storey_family,0))+1
		# No walls beneath (open lookouts, porches): timber, not white plaster.
		var best := "wood"
		for family in votes:
			if int(votes[family]) > int(votes.get(best,0)): best = family
		roof_families[i] = best

# Height (metres) a plant should root at: the higher of the rendered terrain at
# the tile centre and any planter/floor top beneath its source Z. Returns NAN
# when nothing plausible is within 2.5 m, leaving the source height untouched.
func vegetation_ground(s: Dictionary, world: Dictionary) -> float:
	var scale := float(world.elevationScale)
	var ground := -INF
	if terrain_surface: ground = terrain_surface.height_at(Vector2(float(s.x)+0.5,float(s.y)+0.5))
	for top in ground_supports.get(Vector2i(s.x,s.y),[]):
		if float(top) <= float(s.z)+1.0: ground = maxf(ground,float(top)*scale)
	if ground == -INF or absf(ground-float(s.z)*scale) > 2.5: return NAN
	return ground

# Owner-licensed converted plants when present locally; CC0 library otherwise.
func plant(kind: String, s: Dictionary, detail: Dictionary, asset: String, size: Vector3) -> Node3D:
	var local: Node3D = preload("res://Presentation/LocalPlants.gd").build(kind,str(detail.get("name","")),int(s.x),int(s.y))
	return local if local else fitted(asset,size)

# One stone stack over the chimney group's footprint, from the record it stands
# on to a capped top two metres above its highest sprite tile.
func chimney_stack(s: Dictionary, group: Dictionary, world: Dictionary) -> Node3D:
	var scale := float(world.elevationScale)
	var size: Vector2 = group.get("size",Vector2.ONE)
	var low: Vector2 = group.get("low",Vector2(s.x,s.y))
	var base := float(chimney_bases.get(int(group.get("owner",-1)),int(s.z)-6))*scale
	var top := (float(group.get("max_z",float(s.z)+3.0))-3.0+10.0)*scale
	var width := Vector3(maxf(0.7,size.x*0.85),0,maxf(0.7,size.y*0.85))
	var root := Node3D.new()
	var centre := Vector3(low.x+size.x/2-float(s.x)-0.5,0,low.y+size.y/2-float(s.y)-0.5)
	var origin := float(s.z)*scale
	# The visible top is the MedievalKit (CC0) chimney with its clay pots, one
	# per footprint cell along the stack; masonry carries it down to the roof.
	const CROWN := 2.29
	var crown_base := maxf(base,top-CROWN)
	if crown_base > base: facade.piece(root,Vector3(width.x,crown_base-base,width.z),centre+Vector3(0,(base+crown_base)/2-origin,0),"stone")
	var along_x: bool = size.x >= size.y
	var count := maxi(1,int(round(maxf(size.x,size.y))))
	for i in count:
		var shift := (float(i)-float(count-1)/2.0)*(width.x if along_x else width.z)/float(count)
		var crown: Node3D = fitted("MedievalKit/Chimney.gltf",Vector3(width.x/float(count) if along_x else width.x,top-crown_base,width.z if along_x else width.z/float(count)))
		crown.position = centre+Vector3(shift if along_x else 0.0,crown_base-origin,0.0 if along_x else shift)
		root.add_child(crown)
	return root

# A shop's display cases are one cabinet per source cell, joined into a run:
# photoscanned timber carcass, felt bed at the native case height, a timber
# rim on the run's outer edges and thin glass panes. The glass never writes
# depth, so neighbouring panes and the goods inside cannot flicker.
var display_glass: StandardMaterial3D
func display_cases(s: Dictionary, group: Dictionary, world: Dictionary) -> Node3D:
	var scale := float(world.elevationScale)
	var root := Node3D.new()
	var cells := {}
	for index in group.indices: cells[Vector2i(world.statics[index].x,world.statics[index].y)] = true
	var wood := preload("res://Presentation/DoorLeaf.gd").surface("medieval_wood",Color(0.62,0.5,0.4))
	var felt := preload("res://Presentation/DoorLeaf.gd").surface("hessian_230",Color(0.42,0.12,0.1))
	if display_glass == null:
		display_glass = StandardMaterial3D.new()
		display_glass.albedo_color = Color(0.82,0.9,0.92,0.1)
		display_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		display_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		display_glass.roughness = 0.04
		display_glass.metallic_specular = 0.9
	var base := 0.6
	var top := 0.98
	var y := (float(group.min_z)-float(s.z))*scale
	var box := preload("res://Presentation/DoorLeaf.gd")._box
	for cell in cells:
		var at := Vector3(cell.x-int(s.x),y,cell.y-int(s.y))
		box.call(root,Vector3(1.0,base-0.06,1.0),at+Vector3(0,0.06+(base-0.06)/2,0),wood)
		box.call(root,Vector3(0.96,0.06,0.96),at+Vector3(0,0.03,0),wood)
		box.call(root,Vector3(0.98,0.012,0.98),at+Vector3(0,base+0.006,0),felt)
		box.call(root,Vector3(1.0,0.008,1.0),at+Vector3(0,top,0),display_glass)
		for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+side): continue
			var along_x: bool = side.y != 0
			var edge := at+Vector3(side.x*0.48,0,side.y*0.48)
			# Plinth lip, glass pane and timber rails along the outer edge.
			box.call(root,Vector3(1.0 if along_x else 0.04,0.05,0.04 if along_x else 1.0),edge+Vector3(0,base+0.025,0),wood)
			box.call(root,Vector3(1.0 if along_x else 0.008,top-base-0.05,0.008 if along_x else 1.0),edge+Vector3(0,(base+0.05+top)/2,0),display_glass)
			box.call(root,Vector3(1.0 if along_x else 0.04,0.035,0.04 if along_x else 1.0),edge+Vector3(0,top+0.012,0),wood)
		for corner in [Vector2i(-1,-1),Vector2i(1,-1),Vector2i(-1,1),Vector2i(1,1)]:
			if cells.has(cell+Vector2i(corner.x,0)) or cells.has(cell+Vector2i(0,corner.y)): continue
			box.call(root,Vector3(0.04,top-base,0.04),at+Vector3(corner.x*0.48,(base+top)/2,corner.y*0.48),wood)
	return root

# Shop counter: a panelled timber carcass on a plinth with an overhanging top,
# one module per source cell. Fronts and ends close only on the run's open
# sides, so L and U counters read as one piece of joinery.
func counter_run(s: Dictionary, group: Dictionary, world: Dictionary) -> Node3D:
	var scale := float(world.elevationScale)
	var root := Node3D.new()
	root.set_meta("cell_assembly",true)
	var cells := {}
	for index in group.indices: cells[Vector2i(world.statics[index].x,world.statics[index].y)] = true
	var leaf := preload("res://Presentation/DoorLeaf.gd")
	var carcass := leaf.surface("medieval_wood",Color(0.6,0.47,0.36))
	var top_wood := leaf.surface("medieval_wood",Color(0.78,0.62,0.46))
	var height := preload("res://Presentation/GeometryLibrary.gd").furniture_height("counter")
	var y := (float(group.get("min_z",s.z))-float(s.z))*scale
	for cell in cells:
		var at := Vector3(cell.x-int(s.x),y,cell.y-int(s.y))
		leaf._box(root,Vector3(0.9,height-0.16,0.9),at+Vector3(0,0.08+(height-0.16)/2,0),carcass)
		leaf._box(root,Vector3(0.86,0.08,0.86),at+Vector3(0,0.04,0),carcass)
		for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var joined := cells.has(cell+side)
			var along_x: bool = side.y != 0
			var edge := at+Vector3(side.x*0.45,0,side.y*0.45)
			if joined:
				# Close the gap to the neighbouring module (drawn once per pair).
				if side == Vector2i.LEFT or side == Vector2i.UP: continue
				leaf._box(root,Vector3(0.9 if along_x else 0.1,height-0.16,0.1 if along_x else 0.9),at+Vector3(side.x*0.5,0.08+(height-0.16)/2,side.y*0.5),carcass)
				continue
			# Raised-panel front: stiles, rails and a recessed panel.
			for rail_y in [0.16,height-0.14]: leaf._box(root,Vector3(0.9 if along_x else 0.03,0.07,0.03 if along_x else 0.9),edge+Vector3(side.x*0.015,rail_y,side.y*0.015),top_wood)
			for stile in [-0.41,0.41]: leaf._box(root,Vector3(0.07 if along_x else 0.03,height-0.3,0.03 if along_x else 0.07),edge+Vector3(side.x*0.015+(stile if along_x else 0.0),0.16+(height-0.3)/2,side.y*0.015+(0.0 if along_x else stile)),top_wood)
		var top_shift := Vector3.ZERO
		for side in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			if cells.has(cell+side): continue
			top_shift += Vector3(side.x*0.015,0,side.y*0.015)
		var top_size := Vector3(1.0+(0.03 if not cells.has(cell+Vector2i.LEFT) else 0.0)+(0.03 if not cells.has(cell+Vector2i.RIGHT) else 0.0),0.06,1.0+(0.03 if not cells.has(cell+Vector2i.UP) else 0.0)+(0.03 if not cells.has(cell+Vector2i.DOWN) else 0.0))
		leaf._box(root,top_size,at+top_shift+Vector3(0,height-0.03,0),top_wood)
	return root

# Open bay of a timber-framed house (galleries, carriage openings): oak posts,
# a heavy head beam with the infill above it and curved knee braces, left
# open to walk through. Masonry families keep the extruded stone arch.
func timber_archway(span: float, height: float, family: String) -> Node3D:
	var root := Node3D.new()
	var head := minf(2.6,height-0.3)
	var oak := "oak" if family == "plaster" else "wood"
	if height-head > 0.05: facade.piece(root,Vector3(span,height-head,0.18),Vector3(0,(height+head)/2,0),family)
	facade.piece(root,Vector3(span+0.04,0.26,0.32),Vector3(0,head+0.13,0),oak)
	facade.piece(root,Vector3(span+0.06,0.24,0.36),Vector3(0,height-0.12,0),oak)
	for side in [-1,1]:
		facade.piece(root,Vector3(0.2,head,0.3),Vector3(side*(span/2-0.1),head/2,0),oak)
		var brace := geometry.box(root,Vector3(0.62,0.12,0.26),Vector3(side*(span/2-0.38),head-0.2,0),"ffffff")
		brace.rotation.z = side*0.75
		brace.material_override = facade.material(oak)
	return root

func gable_for(family: String) -> ShaderMaterial:
	if not gable_materials.has(family):
		var material: ShaderMaterial = facade.material(family).duplicate()
		material.set_shader_parameter("double_sided",true)
		gable_materials[family] = material
	return gable_materials[family]

func _group(indices: Array, world: Dictionary, kind: String) -> void:
	var owner := int(indices[0])
	indices.sort()
	if kind != "tree": owner = int(indices[0])
	var low := Vector2(100000,100000)
	var high := Vector2(-100000,-100000)
	for index in indices:
		var s: Dictionary = world.statics[index]
		low = low.min(Vector2(s.x,s.y))
		high = high.max(Vector2(s.x,s.y))
	var min_z := 100000.0
	var max_z := -100000.0
	for index in indices:
		min_z = minf(min_z,float(world.statics[index].z))
		max_z = maxf(max_z,float(world.statics[index].z)+3.0)
	var data := {"min_z":min_z,"max_z":max_z,"owner":owner,"indices":indices,"low":low,"size":high-low+Vector2.ONE,"kind":kind}
	for index in indices: groups[index] = data

func _collect_bounds(node: Node3D, transform: Transform3D, boxes: Array) -> void:
	var combined := transform*node.transform
	if node is MeshInstance3D: boxes.append(combined*node.get_aabb())
	for child in node.get_children():
		if child is Node3D: _collect_bounds(child,combined,boxes)

func fitted(path: String, size: Vector3, orientation: Array = [0,0,0]) -> Node3D:
	var full := "res://Art/"+path if path.begins_with("Kenney/") or path.begins_with("PolyHaven/") or path.begins_with("MedievalKit/") or path.begins_with("Objaverse/") or path.begins_with("Reduced/") else "res://Art/Quaternius/"+path
	# Heavy Poly Haven scans placed hundreds of times use their game-budget copy
	# (scripts/reduce-polyhaven.py); the pinned original stays untouched.
	if path.begins_with("PolyHaven/"):
		var asset_id := path.get_slice("/",1)
		if ResourceLoader.exists("res://Art/Reduced/%s/%s.glb" % [asset_id,asset_id]): full = "res://Art/Reduced/%s/%s.glb" % [asset_id,asset_id]
	if not scenes.has(path):
		scenes[path] = load(full)
		assert(scenes[path] != null,"Missing catalogue asset: "+path)
	var bounds_key := path if orientation == [0,0,0] else path+str(orientation)
	if not bounds.has(bounds_key):
		var sample: Node3D = scenes[path].instantiate()
		sample.rotation_degrees = Vector3(orientation[0],orientation[1],orientation[2])
		var boxes: Array = []
		_collect_bounds(sample,Transform3D.IDENTITY,boxes)
		assert(not boxes.is_empty())
		var box: AABB = boxes[0]
		for other in boxes: box = box.merge(other)
		bounds[bounds_key] = box
		sample.free()
	var node := Node3D.new()
	var offset := Node3D.new()
	var model: Node3D = scenes[path].instantiate()
	model.rotation_degrees = Vector3(orientation[0],orientation[1],orientation[2])
	if path.begins_with("Props/") or path == "Village/Door_2_Flat.gltf":
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(surface)
				if not original is StandardMaterial3D: continue
				var key: int = original.get_instance_id()
				if not prop_materials.has(key):
					var material: StandardMaterial3D = original.duplicate()
					if path.begins_with("Props/"):material.vertex_color_use_as_albedo = true
					# Worn timber and iron should not reflect a bright outdoor sky
					# like polished chrome inside an unbaked room.
					material.metallic = minf(material.metallic,.25)
					material.roughness = maxf(material.roughness,.8)
					prop_materials[key] = material
				mesh.set_surface_override_material(surface,prop_materials[key])
	if path.begins_with("Nature/"):
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			# Reserve space for bounded shader deformation at frustum/shadow edges.
			var native_size: Vector3 = bounds[path].size
			mesh.extra_cull_margin = 0.2*maxf(1.0,(native_size/size).length())
			for surface in mesh.mesh.get_surface_count():
				var original: StandardMaterial3D = mesh.get_active_material(surface)
				var key := path+"/"+mesh.name+"/"+str(surface)
				if not nature_materials.has(key):
					var mat := ShaderMaterial.new()
					mat.resource_name = original.resource_name
					mat.shader = preload("res://Presentation/Nature.gdshader")
					var texture: Texture2D = original.albedo_texture
					if original.resource_name == "Leaves_TwistedTree": texture = load("res://Art/Quaternius/Nature/Leaves_NormalTree_C.png")
					mat.set_shader_parameter("source_texture",texture)
					mat.set_shader_parameter("source_normal",original.normal_texture)
					mat.set_shader_parameter("has_normal",original.normal_texture != null)
					mat.set_shader_parameter("camera_fade",not show_boundary_fragments and "Leaves" in original.resource_name)
					mat.set_shader_parameter("tint",Color("ced6b6") if "Leaves" in original.resource_name else Color("ded3bb"))
					mat.set_shader_parameter("base_y",mesh.get_aabb().position.y)
					mat.set_shader_parameter("plant_height",mesh.get_aabb().size.y)
					# Rocks, logs and stumps share the nature shader but never sway.
					var rigid := path.get_file().begins_with("Rock") or "Log" in path.get_file() or "Stump" in path.get_file() or "Pebble" in path.get_file()
					mat.set_shader_parameter("amplitude",0.0 if show_boundary_fragments or rigid else minf(0.22,size.y*0.12))
					mat.set_shader_parameter("flutter",0.0 if show_boundary_fragments or rigid else (0.012 if "Leaves" in original.resource_name else 0.004))
					mat.set_shader_parameter("source_origin",source_origin)
					nature_materials[key] = mat
				mesh.set_surface_override_material(surface,nature_materials[key])
	if path.begins_with("Village/") and path != "Village/Door_2_Flat.gltf":
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var original: Material = mesh.get_active_material(surface)
				if not original is StandardMaterial3D: continue
				var label := original.resource_name.to_lower()
				if not ("wood" in label or "plaster" in label or "brick" in label or "rock" in label): continue
				var key: int = original.get_instance_id()
				if not architecture_materials.has(key):
					var styled := ShaderMaterial.new()
					styled.shader = preload("res://Presentation/Architecture.gdshader")
					styled.set_shader_parameter("source_texture",original.albedo_texture)
					styled.set_shader_parameter("wood", "wood" in label)
					preload("res://Presentation/SurfaceLibrary.gd").bind(styled,"surface","brown_planks_03" if "wood" in label else ("plastered_wall_02" if "plaster" in label else "rock_wall_04"))
					styled.set_shader_parameter("palette",Color("66523d") if "wood" in label else (Color("c4b89b") if "plaster" in label else Color("85867b")))
					architecture_materials[key] = styled
				mesh.set_surface_override_material(surface,architecture_materials[key])
	var box: AABB = bounds[bounds_key]
	offset.scale = size/box.size
	offset.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*offset.scale
	offset.add_child(model)
	node.add_child(offset)
	return node

func tint_prop(node: Node3D, palette: String) -> void:
	# Preserve the cork/metal vertex colours; only the selected bottle-body
	# pigment changes. Original downloaded meshes and buffers stay immutable.
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var key := str(mesh.mesh.get_instance_id())+palette
		if not prop_mesh_variants.has(key):
			var variant := ArrayMesh.new()
			for surface in mesh.mesh.get_surface_count():
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] is PackedColorArray else PackedColorArray()
				for i in colors.size():
					if colors[i].r > colors[i].g*2.5:
						colors[i]=Color(.018,.065,.012,colors[i].a)
				if not colors.is_empty(): arrays[Mesh.ARRAY_COLOR]=colors
				variant.add_surface_from_arrays(mesh.mesh.surface_get_primitive_type(surface),arrays)
				variant.surface_set_material(surface,mesh.mesh.surface_get_material(surface))
			prop_mesh_variants[key]=variant
		mesh.mesh=prop_mesh_variants[key]

# Cannon fit in the model's own axes: its longest horizontal side is the barrel.
func cannon_size() -> Vector3:
	var sample: Node3D = fitted("PolyHaven/cannon_01/cannon_01_1k.gltf",Vector3.ONE)
	sample.free()
	var box: AABB = bounds["PolyHaven/cannon_01/cannon_01_1k.gltf"]
	return box.size*(2.1/maxf(box.size.x,box.size.z))

# Britain keeps its reviewed stone-or-timber steps; regional graphics (with an
# original colour) use their named material in that colour.
static func stair_surface(name: String, tint: String) -> String:
	if tint.is_empty(): return "stone" if "stone" in name else "wood"
	var surface := preload("res://Presentation/Facade.gd").surface_for(name)
	return surface+"#"+tint

# "material#rrggbb" keys tint a roof material with a graphic's original colour.
func roof_material(key: String) -> ShaderMaterial:
	if not roof_materials.has(key):
		var kind := key.get_slice("#",0)
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://Presentation/Roof.gdshader")
		# palm: dried frond thatch; tent: canvas; marble: pale dressed stone.
		var colors := {"stone":"99988c","slate":"586573","clay":"a06345","thatch":"b09355","palm":"8f8a55","tent":"cfc2a2","marble":"d8d3c8","shingle":"796344"}
		mat.set_shader_parameter("roof_color",Color(key.get_slice("#",1)) if "#" in key else Color(str(colors.get(kind,"796344"))))
		mat.set_shader_parameter("wood",kind == "shingle")
		mat.set_shader_parameter("thatch",kind in ["thatch","palm"])
		mat.set_shader_parameter("ceiling_color",Color("917454"))
		mat.set_shader_parameter("kit_texture",load("res://Art/Quaternius/Village/T_WoodTrim_BaseColor.png"))
		preload("res://Presentation/SurfaceLibrary.gd").bind(mat,"surface","brown_planks_03" if kind == "shingle" else ("rock_wall_04" if kind in ["stone","marble"] else ("plastered_wall_02" if kind == "tent" else "grey_roof_tiles_02")))
		roof_materials[key] = mat
	return roof_materials[key]

func build(s: Dictionary, world: Dictionary, ordinal: int = -1) -> Node3D:
	var rule := rule_for(s.id)
	if rule.is_empty() and info(world,s.id,true).get("name") == "wooden boards": rule = {"kind":"floor","asset":"Village/Floor_WoodDark.gltf","axis":"x","confidence":"fixture"}
	var kind := str(rule.get("kind","unknown"))
	var node := Node3D.new()
	var detail := info(world,s.id,true)
	var height := maxf(0.04,float(detail.get("height",0))*float(world.elevationScale))
	height += maxf(maxf(float(facade.plans.get(ordinal,{}).get("height_extension",0.0)),float(facade.cap_extensions.get(ordinal,0.0))),float(eave_extensions.get(ordinal,0.0)))
	var asset := str(rule.get("asset",""))
	var family := preload("res://Presentation/Facade.gd").family_for(str(detail.get("name","")))
	var tint := art_tint(int(s.id)) if rule.get("regional",false) else ""
	# Generic tiledata names ("window", "arrow loop") hide the material their
	# art shows; reviewed per-graphic facts and bridge context take precedence.
	var review: Dictionary = preload("res://Presentation/ReviewedCatalog.gd").entry(int(s.id))
	if kind in ["window","arch"] and window_families.has(ordinal): family = str(window_families[ordinal])
	family = str(review.get("facadeFamily",rule.get("facadeFamily",family)))
	var opening := str(review.get("opening",""))
	var bridge: Dictionary = bridges.parapets.get(ordinal,{})
	if not bridge.is_empty():
		family = str(review.get("facadeFamily",bridge.family))
		if opening.is_empty(): opening = str(bridge.opening)
	if not tint.is_empty() and kind in ["wall","window","corner","trim","arch"]:
		# Outside Britain, unnamed walls are plain masonry or render in their own
		# colour; close-studded timber framing is Britain's reviewed house style.
		if family == "plaster": family = "clay" if "plaster" in str(detail.get("name","")) else "stone"
		if family in preload("res://Presentation/Facade.gd").TINTED: family += "#"+tint
	if groups.get(ordinal,{}).get("kind","") == "archway": kind = "archway"
	elif kind == "arch": kind = "pier"
	var visual: Node3D
	var state := "replacement"
	if groups.has(ordinal) and groups[ordinal].owner != ordinal:
		state = "group-component"
		grouped += 1
	elif presentation_adjustments.get(ordinal,{}).get("suppress",false) and not show_boundary_fragments:
		state = "context-suppressed"
		contextual_suppressed += 1
	elif kind == "roof" and roofs.tiles.get(ordinal,{}).get("boundary_fragment",false) and not show_boundary_fragments:
		state = "boundary-fragment"
		boundary_fragments += 1
	else:
		# Modern Britain: library models replace the reviewed stand-ins for loose
		# objects too (multi-cell furniture keeps its fitted assemblies).
		var modern := preload("res://Presentation/GraphicsMode.gd").modern() and tint.is_empty() and kind in ["prop","asset"] and not groups.has(ordinal)
		if modern and not rule.has("slot") and not preload("res://Presentation/PropReplacements.gd").has(str(detail.get("name","")),int(s.id)):
			var found: Array = preload("res://Presentation/RegionalRules.gd").slot_for(str(detail.get("name","")).strip_edges().to_lower())
			if not found.is_empty(): rule = rule.merged({"slot":found[0],"slotSize":found[1]}.merged({"slotCount":found[2]} if int(found[2]) > 1 else {}))
		# Modern Britain: table and bench runs become library pieces along the run.
		var furniture_slot: String = {"table":"table","bench":"bench"}.get(kind,"") if preload("res://Presentation/GraphicsMode.gd").modern() and tint.is_empty() else ""
		if furniture_slot != "" and preload("res://Presentation/LocalLibrary.gd").has(furniture_slot):
			var span: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
			var long_x := span.x >= span.y
			visual = preload("res://Presentation/LocalLibrary.gd").run(furniture_slot,int(s.x),int(s.y),maxf(span.x,span.y),0.8 if kind == "table" else 0.48,minf(span.x,span.y)*(0.9 if kind == "table" else 0.5))
			if visual and not long_x: visual.rotation.y = PI/2
		# Photoscanned CC0 replacements by item name (prop-replacements.json).
		if visual == null and kind in ["prop","asset","rock","log","mushroom","post","flower","plant","fern"] and not groups.has(ordinal): visual = preload("res://Presentation/PropReplacements.gd").build(self,str(detail.get("name","")),int(s.x)*7919+int(s.y)*104729,int(s.id))
		# Counters follow their real footprint (L and U shapes) cell by cell.
		if visual == null and kind == "counter" and tint.is_empty(): visual = counter_run(s,groups.get(ordinal,{"indices":[ordinal],"min_z":float(s.z)}),world)
		# Wooden benches are runs of the scanned bench whatever their review says.
		var scanned_bench := kind == "bench" and tint.is_empty() and not ("stone" in str(detail.get("name","")).to_lower() or "marble" in str(detail.get("name","")).to_lower()) and ResourceLoader.exists("res://Art/Objaverse/bench_scan/bench_scan.glb")
		if visual == null and not scanned_bench and (preload("res://Presentation/ReviewedCatalog.gd").scanned(int(s.id)) or not (modern and rule.has("slot") and preload("res://Presentation/LocalLibrary.gd").has(str(rule.slot)))):
			visual = preload("res://Presentation/ReviewedCatalog.gd").build(self,int(s.id),groups.get(ordinal,{}))
		# Owner-library model for graphics outside the reviewed city (local only),
		# and in Britain when modern graphics are selected.
		if visual == null and rule.has("slot") and (not tint.is_empty() or modern):
			var fit: Array = rule.get("slotSize",[0.8,0.8,0.8])
			var library := preload("res://Presentation/LocalLibrary.gd")
			visual = library.pile(str(rule.slot),int(s.x),int(s.y),Vector3(fit[0],fit[1],fit[2]),int(rule.slotCount)) if rule.has("slotCount") else library.build(str(rule.slot),int(s.x),int(s.y),Vector3(fit[0],fit[1],fit[2]))
			if visual: node.set_meta("library",str(rule.slot))
		if visual == null:
			match kind:
				"wall", "window":
					var frame: Node3D = null
					visual = facade.panel(height,kind == "window",facade.plans.get(ordinal,{}),family,frame,opening)
					# Outdoor shutters/flower boxes on house windows (never bridges or slits).
					if kind == "window" and height > 1.5 and opening.is_empty() and bridge.is_empty():
						var dressing: Node3D = windows.dress(self,windows.plans.get(ordinal,{}),minf(1.05,height*0.28),minf(1.4,height*0.46),family)
						if dressing: visual.add_child(dressing)
				"corner": visual = facade.corner(height,facade.corners.get(ordinal,{}),family)
				"post": visual = fitted(asset,Vector3(0.15,height,0.15))
				"pillar" when pinnacles.has(ordinal):
					visual = Node3D.new()
					var spire_family := "stone" if family.get_slice("#",0) in ["plaster","wood"] else family
					facade.piece(visual,Vector3(0.36,0.5,0.36),Vector3(0,0.25,0),spire_family)
					facade.piece(visual,Vector3(0.42,0.08,0.42),Vector3(0,0.54,0),spire_family)
					var spire := MeshInstance3D.new()
					var cone := CylinderMesh.new()
					cone.top_radius = 0.0
					cone.bottom_radius = 0.2
					cone.height = 0.75
					cone.radial_segments = 4
					cone.rings = 1
					spire.mesh = cone
					spire.position.y = 0.58+0.375
					spire.rotation.y = PI/4
					spire.material_override = facade.material(spire_family)
					visual.add_child(spire)
				"pillar" when int(detail.get("flags",0)) & 0x10 != 0:
					# Wall-flagged posts/pillars are square wall piers (corners and
					# battlement posts), not free-standing round columns.
					visual = Node3D.new()
					var pier_family := "stone" if family.get_slice("#",0) in ["plaster","wood"] else family
					facade.piece(visual,Vector3(0.46,maxf(0.05,height-0.1),0.46),Vector3(0,(height-0.1)/2,0),pier_family)
					facade.piece(visual,Vector3(0.54,0.1,0.54),Vector3(0,height-0.05,0),pier_family)
				"pillar":
					visual=Node3D.new()
					for y in [0.06,height-0.06]:
						var base_mesh:MeshInstance3D=geometry.crafted_box(visual,Vector3(0.40,0.12,0.40),Vector3(0,y,0),"ffffff")
						base_mesh.material_override=facade.material("stone")
					var shaft:MeshInstance3D=geometry.cylinder(visual,0.15,maxf(0.05,height-0.24),Vector3(0,height/2,0),"ffffff")
					shaft.material_override=facade.material("stone")
				"gable":
					var group: Dictionary = groups[ordinal]
					var span: float = maxf(group.size.x,group.size.y)+1.0
					visual = geometry.gable(span,(group.max_z-group.min_z)*float(world.elevationScale),facade.material(family))
					visual.position.y = (group.min_z-float(s.z))*float(world.elevationScale)
					if rule.get("axis") == "y": visual.rotation.y = PI/2
				"trim", "beam":
					if kind == "trim" and (not bridge.is_empty() or family.get_slice("#",0) in preload("res://Presentation/Facade.gd").MASONRY):
						# Masonry parapets and merlons: solid dressed stone (or
						# brick) with a projecting coping, not a plaster/timber kit wall.
						visual = Node3D.new()
						facade.piece(visual,Vector3(1.01,maxf(0.05,height-0.08),0.3),Vector3(0,(height-0.08)/2,0),family)
						facade.piece(visual,Vector3(1.01,0.08,0.38),Vector3(0,height-0.04,0),family)
						# Edge parapets sit flush on the deck edge rather than mid-tile
						# over the water (presentation offset; source XYZ unchanged).
						var toward: Vector2i = bridge.get("toward",Vector2i.ZERO)
						visual.position += Vector3(toward.x,0,toward.y)*0.35
					else: visual = fitted(asset,Vector3(1,height,0.14))
				"archway":
					var run: Dictionary = groups[ordinal]
					# Gateways and arcades in masonry stay stone; openings in timber-framed
					# runs (galleries, carriage bays) are framed in oak.
					if family in ["plaster","wood"] and window_families.has(ordinal): visual = timber_archway(maxf(run.size.x,run.size.y),height,family)
					else:
						# In an arcade the arch springs from the slim columns either side,
						# so the opening reaches into the neighbouring column cells.
						var along := Vector2i(0,1) if rule.get("axis") == "y" else Vector2i(1,0)
						var first := Vector2i(run.low)
						var last := Vector2i(run.low+run.size-Vector2.ONE)
						var reach_low := 0.32 if _arch_at(solid_arch_cells,first-along,int(s.z)) else 0.0
						var reach_high := 0.32 if _arch_at(solid_arch_cells,last+along,int(s.z)) else 0.0
						visual = facade.archway(maxf(run.size.x,run.size.y)+reach_low+reach_high,height,"stone" if family.get_slice("#",0) == "plaster" else family)
						var inner: Node3D = visual
						visual = Node3D.new()
						inner.position.x = (reach_high-reach_low)/2
						visual.add_child(inner)
				"pier":
					# Solid arch pieces are the masonry beside an opening.
					# Timber houses keep framed panels beside their openings.
					var pier_along := Vector2i(0,1) if rule.get("axis") == "y" else Vector2i(1,0)
					var arcade := _arch_at(passage_cells,Vector2i(s.x,s.y)+pier_along,int(s.z)) or _arch_at(passage_cells,Vector2i(s.x,s.y)-pier_along,int(s.z))
					if family in ["plaster","wood"] and window_families.has(ordinal): visual = facade.panel(height,false,{"offset":0,"length":1},family)
					elif arcade and height > 2.0:
						# Slim arcade column with a moulded base and capital.
						visual = Node3D.new()
						var column_family := family if family.get_slice("#",0) != "plaster" else "stone"
						facade.piece(visual,Vector3(0.36,height,0.36),Vector3(0,height/2,0),column_family)
						facade.piece(visual,Vector3(0.5,0.22,0.5),Vector3(0,0.11,0),column_family)
						facade.piece(visual,Vector3(0.48,0.16,0.44),Vector3(0,minf(2.4,height-0.6),0),column_family)
					else:
						visual = Node3D.new()
						facade.piece(visual,Vector3(1.0,height,0.26),Vector3(0,height/2,0),family if family.get_slice("#",0) != "plaster" else "stone")
				"arch":
					visual = Node3D.new()
					var span: float = maxf(groups[ordinal].size.x,groups[ordinal].size.y) if groups.has(ordinal) else 1.0
					var opening_height := minf(height,2.7)
					visual.add_child(fitted(asset,Vector3(span,opening_height,0.2)))
					# Masonry over the opening matches the arch's own material.
					var arch_name := str(detail.get("name",""))
					var arch_family := family if preload("res://Presentation/Facade.gd").family_for(arch_name) == "plaster" else preload("res://Presentation/Facade.gd").family_for(arch_name)
					if height > opening_height: facade.piece(visual,Vector3(span,height-opening_height,0.18),Vector3(0,(height+opening_height)/2,0),arch_family)
				"floor":
					var surface := str(rule.get("surface","wood"))
					if surface == "": surface = "wood"
					visual = floors.slab(ordinal,floors.material() if surface == "wood" and tint.is_empty() else facade.material(surface+("#"+tint if not tint.is_empty() else "")))
					if stairwell_rails.has(ordinal):
						var slab: Node3D = visual
						visual = Node3D.new()
						visual.add_child(slab)
						visual.add_child(stairwell_balustrade(stairwell_rails[ordinal]))
				"asset": visual = fitted(asset,Vector3(rule.dimensions[0],rule.dimensions[1],rule.dimensions[2]))
				"prop":
					# Pinned CC0 Poly Haven cannon (smugglers' cove), real proportions:
					# 1.23 m wide, 0.79 m tall, 2.3 m long; procedural gun otherwise.
					if str(rule.model) == "cannon" and ResourceLoader.exists("res://Art/PolyHaven/cannon_01/cannon_01_1k.gltf"):
						visual = fitted("PolyHaven/cannon_01/cannon_01_1k.gltf",cannon_size())
					elif str(rule.model) == "display_case" and groups.has(ordinal): visual = display_cases(s,groups[ordinal],world)
					else: visual = preload("res://Presentation/CityProps.gd").build(str(rule.model),s,detail,geometry)
				"invisible": state="source-nodraw"
				"landing":
					visual = Node3D.new()
					# Bridge tiledata heights describe the art bounds; support is halfway up.
					if int(detail.get("flags",0)) & 0x400: height *= 0.5
					var stair_material := facade.material(stair_surface(str(detail.get("name","")),tint))
					var support := geometry.box(visual,Vector3(1,height,1),Vector3(0,height/2,0),"ffffff")
					support.material_override = stair_material
					var deck := floors.slab("landing",stair_material)
					deck.position.y += height
					visual.add_child(deck)
				"stairs":
					visual = geometry.stairs(height,floors.stair_rise.get(ordinal,Vector2(rule.rise[0],rule.rise[1])))
					for step in visual.get_children(): step.material_override = facade.material(stair_surface(str(detail.get("name","")),tint))
				"roof":
					visual = geometry.roof(s,rule,roof_material(str(rule.material)+("#"+tint if not tint.is_empty() and rule.material in ["clay","stone","slate","marble","tent"] else "")),roofs.tiles.get(ordinal,{}),gable_for(str(roof_families.get(ordinal,"plaster"))),facade.material("oak") if str(roof_families.get(ordinal,"plaster")) == "plaster" else null)
				"door":
					visual = fitted(asset,Vector3(0.86,height,0.12))
					for side in [-1,1]: facade.piece(visual,Vector3(0.08,height,0.2),Vector3(side*0.46,height/2,0),"wood")
					facade.piece(visual,Vector3(1,0.12,0.2),Vector3(0,height-0.06,0),"wood")
				"fence":
					# Wooden, iron and stone-pier fences are built in photoscanned materials.
					if preload("res://Presentation/FenceBuilder.gd").handles(str(detail.get("name",""))): visual = preload("res://Presentation/FenceBuilder.gd").build(str(detail.get("name","")),int(s.id),geometry,facade,height,_fence_above(s,int(detail.get("height",6))),_fence_links(s))
					else: visual = fitted(asset,Vector3(1,1.2,0.10))
				"bed":
					var size: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
					# Photoscanned carved bed with linen (CC0 Poly Haven); a double bed
					# is the same frame at the double footprint.
					asset = "PolyHaven/GothicBed_01/GothicBed_01_1k.gltf"
					visual = fitted(asset,Vector3(minf(size.x,size.y),1.3,maxf(size.x,size.y)))
					if size.x > size.y: visual.rotation.y = PI/2
				"carpet":
					var edges := 0
					for side in [[Vector2i.LEFT,1],[Vector2i.RIGHT,2],[Vector2i.UP,4],[Vector2i.DOWN,8]]:
						var joined := false
						for z in carpet_cells.get(Vector2i(s.x,s.y)+side[0],[]):
							if absi(int(z)-int(s.z)) <= 2: joined = true
						if not joined: edges |= int(side[1])
					visual = geometry.carpet(s,edges)
				"table", "bench", "counter":
					var size: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
					if kind == "bench":
						if size.y > size.x: size.x = 0.5
						else: size.y = 0.5
					var bench_name := str(detail.get("name","")).to_lower()
					var table_name := str(detail.get("name","")).to_lower()
					if kind == "table" and not ("stone" in table_name or "marble" in table_name or "sandstone" in table_name) and ResourceLoader.exists("res://Art/Objaverse/table_wood_b/table_wood_b.glb"):
						visual = trestle_run(size)
					elif kind == "bench" and not ("stone" in bench_name or "marble" in bench_name) and ResourceLoader.exists("res://Art/Objaverse/bench_scan/bench_scan.glb"):
						visual = trestle_run(size,"Objaverse/bench_scan/bench_scan.glb",0.47,1.1)
					else: visual = geometry.furniture(size,kind)
					# Stone and marble tables keep their material, not timber.
					var table_surface := preload("res://Presentation/Facade.gd").surface_for(str(detail.get("name","")))
					if not tint.is_empty() and table_surface != "wood" and ("stone" in str(detail.get("name","")) or "marble" in str(detail.get("name",""))):
						for mesh in visual.find_children("*","MeshInstance3D",true,false): mesh.material_override = facade.material(table_surface)
				# Signposts are drawn by the server sign they carry (board, arm and
				# wall bracket); the source stub alone read as bent iron remnants.
				"sign": state = "source-nodraw"
				"painting": visual = geometry.painting()
				"tree", "canopy":
					var name := str(detail.get("name",""))
					var size := Vector3(3.2,5.8,3.2)
					if name.contains("sapling"): size = Vector3(1,1.9,1)
					if name.contains("cedar"): size = Vector3(2.6,6.2,2.6)
					if kind == "canopy": asset = "Nature/CommonTree_1.gltf"
					# Owner-licensed converted trees when present locally; CC0 library otherwise.
					# A crown without a trunk in its cell is a whole tree of its species.
					var species := name if kind == "tree" else ("oak tree" if "oak" in name else ("walnut tree" if "walnut" in name else ("cedar tree" if "cedar" in name or "needles" in name else ("willow tree" if "willow" in name else "tree"))))
					var local_tree: Node3D = preload("res://Presentation/LocalTrees.gd").build(species,int(s.x),int(s.y)) if preload("res://Presentation/LocalTrees.gd").available() else null
					if local_tree: visual = local_tree
					else:
						visual = fitted(asset,size)
						visual.rotation.y = fmod(float(int(s.x)*17+int(s.y)*31),TAU)
				"grass": visual = plant(kind,s,detail,asset,Vector3(0.65,0.25+0.1*(int(s.id)%3),0.65))
				"flower": visual = plant(kind,s,detail,asset,Vector3(0.55,0.28,0.55))
				"planter":
					# Stone-curbed raised bed at its source height with a soil top.
					visual = Node3D.new()
					facade.piece(visual,Vector3(1.0,maxf(0.05,height-0.03),1.0),Vector3(0,(height-0.03)/2,0),"stone")
					var soil := geometry.box(visual,Vector3(0.9,0.04,0.9),Vector3(0,height-0.01,0),"3b2c20")
					soil.material_override = geometry.material("3b2c20")
				"bush": visual = plant(kind,s,detail,asset,Vector3(1.1,0.65,1.1))
				"fern": visual = plant(kind,s,detail,asset,Vector3(0.9,0.6,0.9))
				"reeds": visual = fitted(asset,Vector3(0.8,1.25,0.8))
				"cactus": visual = geometry.cactus(s,maxf(0.7,minf(height,2.4)))
				"litter": visual = geometry.litter(s,tint if not tint.is_empty() else "7a5a2e")
				"palisade": visual = geometry.palisade(s,maxf(1.6,height),facade.material("log"))
				"waterfall":
					# A falling sheet across the cell diagonal, facing the classic viewpoint.
					var sheet := QuadMesh.new()
					sheet.size = Vector2(1.3,maxf(1.0,height))
					visual = MeshInstance3D.new()
					visual.mesh = sheet
					visual.position.y = maxf(1.0,height)/2
					visual.rotation.y = PI/4
					var fall := ShaderMaterial.new()
					fall.shader = preload("res://Presentation/Waterfall.gdshader")
					visual.material_override = fall
				"plant": visual = plant(kind,s,detail,asset,Vector3(1.0,maxf(0.8,minf(height,2.2)),1.0))
				"lilypad": visual = geometry.lilypads(s)
				"vine":
					# Creepers hang on the wall face they share a cell with.
					visual = fitted(asset,Vector3(1.0,maxf(1.6,height),0.35))
					visual.position.z = -0.42
				"stalagmite": visual = geometry.stalagmites(s,maxf(0.6,height))
				"crystal": visual = geometry.crystals(s,maxf(0.4,height),bool(rule.get("scatter",false)),tint)
				"lava":
					var plane := PlaneMesh.new()
					plane.size = Vector2.ONE
					visual = MeshInstance3D.new()
					visual.mesh = plane
					visual.material_override = lava_surface(str(rule.get("tint","lava")))
				"chimney": visual = chimney_stack(s,groups.get(ordinal,{}),world)
				"mushroom": visual = fitted(asset,Vector3(0.32,0.22,0.32))
				"rock": visual = fitted(asset,Vector3(0.55,0.38,0.55))
				"log": visual = fitted(asset,Vector3(0.9,0.35,0.4))
				"water":
					var plane := PlaneMesh.new()
					plane.size = Vector2.ONE
					plane.subdivide_width = 3
					plane.subdivide_depth = 3
					visual = MeshInstance3D.new()
					visual.mesh = plane
					visual.material_override = water_surface()
				_:
					unresolved += 1
					node.free()
					report.append({"ordinal":ordinal,"id":s.id,"xyz":[s.x,s.y,s.z],"status":"unmapped"})
					return null
		if visual and not bridge.is_empty() and kind in ["wall","window","corner"]:
			# Bridge parapet walls sit on the deck edge like the trims beside them.
			var deck_side: Vector2i = bridge.get("toward",Vector2i.ZERO)
			visual.position += Vector3(deck_side.x,0,deck_side.y)*0.35
		if visual and foundations.has(ordinal) and kind in ["wall","window","corner"]:
			# Foundation course under a wall standing above its support.
			var depth: float = foundations[ordinal]
			var course := "stone" if family.get_slice("#",0) in ["plaster","wood","log","clay","cloth","hide"] else family
			facade.piece(visual,Vector3(1.0 if kind != "corner" else 0.34,depth,0.26 if kind != "corner" else 0.34),Vector3(0,-depth/2,0),course)
		if visual:
			if kind == "roof":
				var anchor: Array = rule.get("anchorOffset",[-1,-1])
				visual.position += Vector3(float(anchor[0]),0,float(anchor[1]))
			if kind in ["wall","window","trim","beam","arch","archway","pier","door","fence","sign","painting"] and rule.get("axis") == "y" and not visual.has_meta("world_aligned"): visual.rotation.y = PI/2
			if kind=="prop" and groups.has(ordinal) and str(rule.get("model","")) == "cannon":
				# A cannon keeps its proportions and points along its footprint.
				if groups[ordinal].size.x > groups[ordinal].size.y: visual.rotation.y = PI/2
				visual.position.y+=(groups[ordinal].min_z-float(s.z))*float(world.elevationScale)
			elif kind=="prop" and groups.has(ordinal) and str(rule.get("model","")) != "display_case":
				visual.scale=Vector3(groups[ordinal].size.x,1.0,groups[ordinal].size.y)
				visual.position.y+=(groups[ordinal].min_z-float(s.z))*float(world.elevationScale)
			if groups.has(ordinal) and kind in ["bed","arch","archway","gable","bench","table","counter","prop"] and str(rule.get("model","")) != "display_case" and not visual.has_meta("cell_assembly"):
				var group: Dictionary = groups[ordinal]
				visual.position += Vector3(group.low.x+group.size.x/2-float(s.x)-0.5,0,group.low.y+group.size.y/2-float(s.y)-0.5)
			if not show_boundary_fragments and kind in VEGETATION:
				var rooted := vegetation_ground(s,world)
				if not is_nan(rooted):
					visual.position.y += rooted-float(s.z)*float(world.elevationScale)
					node.set_meta("ground_offset",rooted-float(s.z)*float(world.elevationScale))
			if not show_boundary_fragments:
				visual.position += presentation_adjustments.get(ordinal,{}).get("offset",Vector3.ZERO)
				visual.rotation.y += float(presentation_adjustments.get(ordinal,{}).get("yaw",0.0))
			if not show_boundary_fragments:
				var contact: Dictionary = supports.placement(s)
				visual.position += contact.offset
				node.set_meta("contact",contact)
			node.add_child(visual)
	mapped += 1
	node.set_meta("source_id",s.id)
	node.set_meta("source_xyz",Vector3i(s.x,s.y,s.z))
	node.set_meta("source_ordinal",ordinal)
	node.set_meta("kind",kind)
	node.set_meta("solid",kind in ["archway","pier","wall","window","corner","post","trim","gable","beam","arch","floor","landing","stairs","roof","door","fence","bed","table","bench","counter","rock","log","planter","stalagmite","crystal","palisade"] and state not in ["group-component","boundary-fragment","context-suppressed"])
	node.position = Vector3(s.x-int(world.originX)+0.5,s.z*float(world.elevationScale),s.y-int(world.originY)+0.5)
	if facade.plans.has(ordinal): node.set_meta("facade_run",facade.plans[ordinal].run)
	var entry := {"ordinal":ordinal,"id":s.id,"xyz":[s.x,s.y,s.z],"status":state,"kind":kind,"asset":asset,"axis":rule.get("axis","x"),"confidence":rule.get("confidence","semantic")}
	if state == "boundary-fragment": entry.reason = "isolated roof row clipped by crop; retained in source and map view, suppressed in perspective"
	if facade.plans.has(ordinal):
		entry.facade_run = facade.plans[ordinal].run
		entry.seam_height_extension = facade.plans[ordinal].get("height_extension",0.0)
	if facade.corners.has(ordinal): entry.corner_connections = facade.corners[ordinal].directions.size()
	if roofs.tiles.has(ordinal):
		entry.roof_joined = true
		entry.visual_anchor_offset = rule.get("anchorOffset",[-1,-1])
	if presentation_adjustments.has(ordinal):
		entry.presentation_reason = presentation_adjustments[ordinal].reason
		var adjustment: Vector3 = presentation_adjustments[ordinal].get("offset",Vector3.ZERO)
		entry.presentation_offset = [adjustment.x,adjustment.y,adjustment.z] if not show_boundary_fragments else [0,0,0]
	if groups.has(ordinal): entry.group_owner = groups[ordinal].owner
	if not bridge.is_empty(): entry.bridge_context = bridge.reason
	report.append(entry)
	return node

func lava_surface(tint: String) -> ShaderMaterial:
	if not lava_materials.has(tint):
		var material := ShaderMaterial.new()
		material.shader = preload("res://Presentation/Lava.gdshader")
		material.set_shader_parameter("source_origin",source_origin)
		if tint == "acid":
			material.set_shader_parameter("hot",Color("8fe03a"))
			material.set_shader_parameter("crust",Color("1d2a12"))
			material.set_shader_parameter("glow",1.6)
		lava_materials[tint] = material
	return lava_materials[tint]

func water_surface() -> ShaderMaterial:
	if water_material == null:
		water_material = ShaderMaterial.new()
		water_material.shader = preload("res://Presentation/Water.gdshader")
		water_material.set_shader_parameter("source_origin",source_origin)
		water_material.set_shader_parameter("wave_strength",0.0 if show_boundary_fragments else 1.0)
		if shoreline: shoreline.apply(water_material)
		# Owner-licensed water normal/foam (scripts/import-unity-water.py), local only.
		if FileAccess.file_exists("res://local-art/water/normal.png.import"):
			water_material.set_shader_parameter("detail_normal",load("res://local-art/water/normal.png"))
			water_material.set_shader_parameter("foam_mask",load("res://local-art/water/foam.png"))
			water_material.set_shader_parameter("has_detail",true)
	return water_material

func save_report(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"total":report.size(),"accounted":mapped,"group_components":grouped,"boundary_fragments":boundary_fragments,"contextual_suppressed":contextual_suppressed,"unmapped":unresolved,"exact_original_art_matches":0,"architecture":facade.audit(),"bridges":bridges.audit(),"derived_floor_repairs":floors.repairs.map(func(at): return [at.x,at.y,at.z]),"stair_directions_inferred":floors.stair_rise.size(),"placements":report},"\t"))
