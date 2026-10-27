extends RefCounted
# Optional owner-licensed prop library (Dexsoft and Arteria3d packs) converted by
# scripts/import-owner-library.py into the ignored res://local-art/library folder.
# Slots name what a model depicts ("skull", "palm", "chair"); callers fall back to
# CC0 or procedural looks when a slot is absent, so the public build never needs it.
const ROOT := "res://local-art/library"
static var catalog: Dictionary = {}
static var loaded := false
static var scenes: Dictionary = {}
static var boxes: Dictionary = {}
static var excluded: Dictionary = {}

static func slots() -> Dictionary:
	if not loaded:
		loaded = true
		if FileAccess.file_exists(ROOT+"/catalog.json"):
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"/catalog.json"))
			if parsed is Dictionary: catalog = parsed.get("slots",{})
		# Variants rejected in review (Presentation/library-review.json).
		if FileAccess.file_exists("res://Presentation/library-review.json"):
			var review: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/library-review.json"))
			if review is Dictionary:
				for name in review.get("rejected",{}): excluded[name] = true
	return catalog

static func has(slot: String) -> bool:
	return not choices(slot).is_empty()

static func choices(slot: String) -> Array:
	var names: Array = []
	for entry in slots().get(slot,[]):
		if not excluded.has(entry.name) and FileAccess.file_exists(ROOT+"/"+str(entry.file)): names.append(entry)
	return names

static func signature() -> String:
	var text := FileAccess.get_sha256(ROOT+"/catalog.json") if FileAccess.file_exists(ROOT+"/catalog.json") else "none"
	if FileAccess.file_exists("res://Presentation/library-review.json"): text += FileAccess.get_sha256("res://Presentation/library-review.json")
	return text

# A stable variant per cell, uniformly scaled so it fits inside size (x, height, z),
# resting on the ground and centred on the cell, with a stable quarter-turn yaw.
# Piles: count smaller copies scattered over the footprint.
static func pile(slot: String, x: int, y: int, size: Vector3, count: int) -> Node3D:
	var root := Node3D.new()
	var piece := Vector3(size.x,size.y,size.z)*clampf(1.6/sqrt(float(count)),0.35,1.0)
	for i in count:
		var part := build(slot,x*7+i,y*13+i*3,piece)
		if part == null: continue
		var h := absi((x*92821+i*68917)^(y*31337))
		part.position = Vector3(float(h%100)/100.0-0.5,0,float((h/100)%100)/100.0-0.5)*Vector3(size.x,0,size.z)*0.75
		part.rotation.y = float(h%628)/100.0
		root.add_child(part)
	return root if root.get_child_count() > 0 else null

static func build(slot: String, x: int, y: int, size: Vector3, turn := true, variant := "") -> Node3D:
	var options := choices(slot)
	if not variant.is_empty(): options = options.filter(func(e: Dictionary) -> bool: return e.name == variant)
	if options.is_empty(): return null
	var entry: Dictionary = options[absi(x*73856093^y*19349663)%options.size()]
	var path: String = ROOT+"/"+str(entry.file)
	if not scenes.has(path):
		scenes[path] = load(path)
		if scenes[path]:
			var sample: Node3D = scenes[path].instantiate()
			var box := AABB()
			var first := true
			for mesh in sample.find_children("*","MeshInstance3D",true,false):
				var part: AABB = (mesh as MeshInstance3D).get_aabb()
				var at := Transform3D.IDENTITY
				var node: Node = mesh
				while node and node != sample:
					at = (node as Node3D).transform*at
					node = node.get_parent()
				part = at*part
				box = part if first else box.merge(part)
				first = false
			boxes[path] = box
			sample.free()
	if scenes[path] == null: return null
	var box: AABB = boxes[path]
	var model: Node3D = scenes[path].instantiate()
	for mesh in model.find_children("*","MeshInstance3D",true,false):
		for surface in (mesh as MeshInstance3D).mesh.get_surface_count():
			var material: Material = (mesh as MeshInstance3D).mesh.surface_get_material(surface)
			if material is BaseMaterial3D and (material as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				# Foliage and cut-out cards: alpha scissor sorts and shadows correctly.
				var cut: BaseMaterial3D = material.duplicate()
				cut.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				cut.alpha_scissor_threshold = 0.45
				cut.cull_mode = BaseMaterial3D.CULL_DISABLED
				(mesh as MeshInstance3D).set_surface_override_material(surface,cut)
	# Height and widest horizontal side bound the fit, so flat or thin models
	# (shields, swords, coins) keep a sensible size whatever their orientation.
	var scale := minf(size.y/maxf(box.size.y,0.0001),maxf(size.x,size.z)/maxf(maxf(box.size.x,box.size.z),0.0001))
	var root := Node3D.new()
	root.set_meta("library",str(entry.name))
	model.scale = Vector3.ONE*scale
	model.position = Vector3(-box.get_center().x*scale,-box.position.y*scale,-box.get_center().z*scale)
	var holder := Node3D.new()
	holder.add_child(model)
	if turn: holder.rotation.y = float(absi(x*31+y*17)%4)*PI/2
	root.add_child(holder)
	return root
