extends Node3D
# Houses and boats (multis). A multi with a full model in multi-models.json is
# drawn as that one model; any other is built tile by tile from the install's
# component list (scripts/prepare-multis.py) with the same rules as the
# converted city, so classic houses look like Britain's own. Custom houses
# replace the component list with their server design (0xD8, requested when
# 0xBF 0x1D announces a newer revision). The components always feed local
# movement, so floors, decks and stairs carry the player. Boats glide to each
# 0xF6 position with their passengers.
const INDEX_PATH := "res://local-multis/index.json"
const MODELS_PATH := "res://Presentation/multi-models.json"
const WorldSystems = preload("res://Network/Packets/WorldSystems.gd")
const Ships = preload("res://Presentation/ShipBuilder.gd")
static var data := {}
static var registry := {}
var scene: Node3D
var game: Node
var systems: RefCounted
# serial -> {root, id, anchor (Vector3i the root was built at), cells, design}
var built := {}
var queue: Array = []
var building := false

static func index() -> Dictionary:
	if data.is_empty() and FileAccess.file_exists(INDEX_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(INDEX_PATH))
		if parsed is Dictionary: data = parsed
	return data

static func models() -> Dictionary:
	if registry.is_empty() and FileAccess.file_exists(MODELS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MODELS_PATH))
		if parsed is Dictionary: registry = parsed
	return registry

static func components(id: int) -> Array:
	return index().get("multis",{}).get(str(id),[])

static func tile(graphic: int) -> Dictionary:
	return index().get("tiles",{}).get(str(graphic),{})

# Component bounds as ClassicUO's MultiInfo: min x/y and max x/y.
static func bounds(id: int) -> Rect2i:
	var parts := components(id)
	if parts.is_empty(): return Rect2i()
	var low := Vector2i(int(parts[0][1]),int(parts[0][2]))
	var high := low
	for part in parts:
		low = Vector2i(mini(low.x,int(part[1])),mini(low.y,int(part[2])))
		high = Vector2i(maxi(high.x,int(part[1])),maxi(high.y,int(part[2])))
	return Rect2i(low,high-low)

# A custom house design as component rows [graphic, dx, dy, dz] (ClassicUO
# ReadUnsafeCustomHouseData: mode 2 planes are rows over the multi's bounds).
static func design_parts(design: Dictionary, id: int) -> Array:
	var box := bounds(id)
	var min_x := box.position.x
	var min_y := box.position.y
	var max_y := box.end.y
	var parts: Array = []
	for plane in design.get("planes",[]):
		for t in plane.tiles: parts.append([int(t.id),int(t.x),int(t.y),int(t.z)])
		if plane.ids.is_empty(): continue
		var plane_z := int(plane.plane)
		var offset := Vector2i(min_x,min_y)
		var rows := max_y-min_y+2
		if plane_z > 0 and plane_z <= 4:
			offset = Vector2i(min_x+1,min_y+1)
			rows = max_y-min_y
		elif plane_z > 4: rows = max_y-min_y+1
		if rows <= 0: continue
		for i in plane.ids.size():
			var graphic := int(plane.ids[i])
			if graphic: parts.append([graphic,i/rows+offset.x,i%rows+offset.y,int(plane.z)])
	return parts

func configure(world_scene: Node3D) -> void:
	scene = world_scene
	game = scene.game
	systems = game.module("world")
	index()
	game.multi_changed.connect(_changed)
	game.multi_removed.connect(remove)
	game.ended.connect(clear)
	systems.house_revision.connect(func(serial: int, revision: int):
		if int(systems.designs.get(serial,{}).get("revision",-1)) != revision: game.send(WorldSystems.design_query(serial)))
	systems.house_design.connect(func(serial: int): if game.multis.has(serial): _request(serial))
	systems.boat_moved.connect(_boat)

# One building piece at the origin, for the designer palette's icons.
func tile_model(graphic: int) -> Node3D:
	if scene.world.is_empty() or not scene.world.get("staticData") is Dictionary: return null
	_know(graphic)
	var node: Node3D = scene.reconstruction.build({"x":int(scene.world.originX),"y":int(scene.world.originY),"z":0,"id":graphic,"hue":0},scene.world,-1)
	if node == null: return null
	node.position = Vector3.ZERO
	for body in node.find_children("*","CollisionObject3D",true,false): body.free()
	return node

func clear() -> void:
	for serial in built.keys(): remove(serial)
	queue.clear()

func _changed(serial: int, multi: Dictionary) -> void:
	var entry: Dictionary = built.get(serial,{})
	# A boat's or house's new position with the same shape moves what is built.
	if not entry.is_empty() and int(entry.id) == int(multi.id):
		_move(serial,Vector3i(int(multi.x),int(multi.y),int(multi.z)),0.0)
		return
	_request(serial)

func _request(serial: int) -> void:
	if not serial in queue: queue.append(serial)
	if not building: _drain()

func _drain() -> void:
	building = true
	while not queue.is_empty():
		var serial: int = queue.pop_front()
		if game.multis.has(serial): await _build(serial,game.multis[serial])
	building = false

func remove(serial: int) -> void:
	var entry: Dictionary = built.get(serial,{})
	built.erase(serial)
	if entry.is_empty(): return
	_forget_cells(serial,entry)
	if is_instance_valid(entry.root): entry.root.queue_free()

func in_view(multi: Dictionary) -> bool:
	if scene.world.is_empty() or not scene.world.get("staticData") is Dictionary or int(multi.get("facet",1)) != 1: return false
	var area := Rect2i(int(scene.world.originX),int(scene.world.originY),int(scene.world.width),int(scene.world.height))
	return area.has_point(Vector2i(int(multi.x),int(multi.y)))

func parts_of(serial: int, id: int) -> Array:
	if systems.designs.has(serial): return design_parts(systems.designs[serial],id)
	return components(id)

func _build(serial: int, multi: Dictionary) -> void:
	remove(serial)
	if not in_view(multi): return
	var id := int(multi.id)
	var parts := parts_of(serial,id)
	if parts.is_empty(): return
	var root := Node3D.new()
	root.name = "Multi_%08X" % serial
	root.set_meta("serial",serial)
	root.set_meta("multi_id",id)
	add_child(root)
	var anchor := Vector3i(int(multi.x),int(multi.y),int(multi.z))
	var entry := {"root":root,"id":id,"anchor":anchor,"cells":{},"design":systems.designs.has(serial),"unmapped":0}
	built[serial] = entry
	var model: Dictionary = models().get(str(id),{})
	if not model.is_empty() and not entry.design:
		_full_model(root,model,anchor)
	elif Ships.handles(id):
		# Boats are drawn whole; their components only carry movement.
		var ship: Node3D = Ships.build(id,bounds(id))
		var box := bounds(id)
		ship.position = Vector3(box.position.x+box.size.x/2.0+0.5-float(scene.world.originX),0,box.position.y+box.size.y/2.0+0.5-float(scene.world.originY))
		root.add_child(ship)
		model = {"ship":true}
	for i in parts.size():
		var part: Array = parts[i]
		var record := {"x":anchor.x+int(part[1]),"y":anchor.y+int(part[2]),"z":anchor.z+int(part[3]),"id":int(part[0]),"hue":int(multi.get("hue",0)),"multi":serial}
		_know(int(part[0]))
		_add_cell(entry,record)
		if not model.is_empty() and not entry.design: continue
		var node: Node3D = scene.reconstruction.build(record,scene.world,-1)
		if node == null:
			entry.unmapped += 1
			continue
		node.position -= _offset(anchor)
		root.add_child(node)
		if i%48 == 47:
			await get_tree().process_frame
			if not built.has(serial) or built[serial].root != root: return
	# Houses built from their layout get chimneys, window boxes, lanterns,
	# a garden and ivy around the authentic shell (HouseDressing).
	if model.is_empty() or entry.design: preload("res://Presentation/HouseDressing.gd").dress(root,parts,scene.reconstruction,scene.world,serial)
	root.position = _offset(anchor)

# Tiles the converted region never had get their tiledata and the shared
# rule for their name, as the converter would have given them.
func _know(graphic: int) -> void:
	var key := str(graphic)
	if not scene.world.staticData.has(key):
		var info := tile(graphic)
		if info.is_empty(): return
		scene.world.staticData[key] = info
	if not scene.reconstruction.catalog.has(key):
		var rule: Dictionary = preload("res://Presentation/RegionalRules.gd").resolve(graphic,scene.world.staticData[key])
		if not rule.is_empty(): scene.reconstruction.catalog[key] = rule

func _offset(anchor: Vector3i) -> Vector3:
	return Vector3(anchor.x,anchor.z*float(scene.world.elevationScale),anchor.y)

# A full model, fitted to the multi's footprint in tiles (size [w, h, d]),
# turned by yaw degrees and centred on the footprint.
func _full_model(root: Node3D, model: Dictionary, anchor: Vector3i) -> void:
	var size: Array = model.get("size",[1,1,1])
	var visual: Node3D = scene.reconstruction.fitted(str(model.asset),Vector3(float(size[0]),float(size[1]),float(size[2])))
	if visual == null: return
	var box := bounds(int(root.get_meta("multi_id")))
	var center := Vector2(box.position.x+box.size.x/2.0+0.5,box.position.y+box.size.y/2.0+0.5)
	# The root sits at the anchor; tiles are built relative to the world origin.
	visual.position = Vector3(center.x-float(scene.world.originX),float(model.get("lift",0.0)),center.y-float(scene.world.originY))
	visual.rotation.y = deg_to_rad(float(model.get("yaw",0.0)))
	visual.name = "FullModel"
	root.add_child(visual)

func _add_cell(entry: Dictionary, record: Dictionary) -> void:
	var surface = scene.movement_surface
	if surface == null: return
	var cell := Vector2i(int(record.x),int(record.y))
	if not surface.statics.has(cell): surface.statics[cell] = []
	surface.statics[cell].append(record)
	entry.cells[cell] = true

func _forget_cells(serial: int, entry: Dictionary) -> void:
	var surface = scene.movement_surface
	if surface == null: return
	for cell in entry.cells:
		var kept: Array = surface.statics.get(cell,[]).filter(func(t): return int(t.get("multi",0)) != serial)
		if kept.is_empty(): surface.statics.erase(cell)
		else: surface.statics[cell] = kept

# Moving keeps the built tiles and shifts the root; the movement cells follow.
func _move(serial: int, to: Vector3i, seconds: float) -> void:
	var entry: Dictionary = built.get(serial,{})
	if entry.is_empty(): return
	var delta: Vector3i = to-entry.anchor
	if delta == Vector3i.ZERO: return
	_forget_cells(serial,entry)
	entry.cells = {}
	entry.anchor = to
	for part in parts_of(serial,int(entry.id)):
		_add_cell(entry,{"x":to.x+int(part[1]),"y":to.y+int(part[2]),"z":to.z+int(part[3]),"id":int(part[0]),"multi":serial})
	var root: Node3D = entry.root
	var target := _offset(to)
	if seconds <= 0.0 or root.position.distance_to(target) > 4.0:
		root.position = target
		return
	var glide := create_tween()
	glide.tween_property(root,"position",target,seconds)

# 0xF6: speed 1 is slow, 2 fast; one step per glide (ClassicUO BoatMovingManager).
func _boat(boat: Dictionary) -> void:
	_move(int(boat.serial),Vector3i(int(boat.x),int(boat.y),int(boat.z)),0.5 if int(boat.speed) <= 1 else 0.25)
