extends RefCounted
# Data-driven replacements of stand-in props by pinned CC0 Poly Haven scans
# and museum scans (prop-replacements.json): keyed by the UO item name, scaled uniformly to a
# real height so the model keeps its own proportions. Used for map statics
# (Reconstruction) and server-placed items (WorldItems) alike.
static var table := {}

static func key(name: String) -> String:
	var plain := name.to_lower()
	var marker := RegEx.create_from_string("%[^%]*%")
	return marker.sub(plain,"",true).strip_edges()

static func entry(name: String) -> Dictionary:
	if table.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/prop-replacements.json"))
		table = data.items if data is Dictionary else {"": {}}
	return table.get(key(name),{})

# Per-graphic overrides under "ids": {"<id>": {...}} refine one entry (a
# pedestal height, "hide" for the extra tiles of a multi-tile piece, "skip"
# where the name's model does not fit that graphic).
static func entry_for(name: String, id := -1) -> Dictionary:
	var found := entry(name)
	if found.is_empty() or id < 0: return found
	var override: Dictionary = found.get("ids",{}).get(str(id),{})
	if override.get("skip",false): return {}
	# An entry that only lists graphics ("only_ids": unnamed records) needs one of them.
	if found.get("only_ids",false) and override.is_empty(): return {}
	return found.merged(override,true)

# Rule kinds built as architecture or by their own builders never take a
# name replacement (a wall-flagged "fireplace" is masonry, a "table" a trestle
# run); Reconstruction and the art catalogue both ask here.
const BUILT_KINDS := ["wall","window","corner","trim","beam","gable","floor","landing","stairs","roof","door","fence","water","lava","carpet","counter","bench","table","bed","decal","litter","invisible","sign","archway","pier","arch","pillar","chimney","palisade","planter","waterfall","tree","canopy","effect"]
static func applies(kind: String) -> bool:
	return not kind in BUILT_KINDS

static func has(name: String, id := -1) -> bool:
	return not entry_for(name,id).is_empty()

# reconstruction: Reconstruction.gd instance (its fitted() caches bounds).
# Optional keys: "models" (variants picked by seed), "cluster" (that many
# jittered copies, e.g. a patch of mushrooms), "rotation" (yaw degrees that
# turn the model's front to -Z), "anchor": "back" (its back face on z = 0,
# for wall mounts) and "elevation" (metres above the placement).
# overrides: caller-fitted keys (a multi-tile footprint sets "length").
static func build(reconstruction: RefCounted, name: String, seed := 0, id := -1, overrides: Dictionary = {}) -> Node3D:
	var found := entry_for(name,id)
	if found.is_empty(): return null
	if not overrides.is_empty():
		found = found.merged(overrides,true)
		if overrides.has("length"): found.erase("height")
	if found.get("hide",false):
		var part := Node3D.new()
		part.set_meta("replacement","part of a multi-tile piece")
		return part
	var models: Array = found.get("models",[found.get("model","")])
	var count := int(found.get("cluster",1))
	if count == 1:
		var single := _one(reconstruction,str(models[abs(seed)%models.size()]),found,1.0)
		if single: single.set_meta("replacement",str(models[abs(seed)%models.size()]))
		return single
	var random := RandomNumberGenerator.new()
	random.seed = hash([key(name),seed])
	var root := Node3D.new()
	for i in count:
		var model := str(models[(i+abs(seed))%models.size()])
		var placed := _one(reconstruction,model,found,random.randf_range(0.65,1.15))
		if placed == null: continue
		var angle := TAU*float(i)/count+random.randf_range(-0.5,0.5)
		var radius := 0.0 if i == 0 else random.randf_range(0.12,0.3)
		placed.position = Vector3(cos(angle)*radius,0,sin(angle)*radius)
		placed.rotation.y = random.randf_range(0,TAU)
		root.add_child(placed)
	if root.get_child_count() == 0:
		root.free()
		return null
	var first := str(models[0])
	root.set_meta("replacement",first)
	return root

# PBR repaint for metal variants of one model (an ingot in gold, silver,
# iron, copper): {"color": hex, "metallic": 0-1, "roughness": 0-1}.
static var repaints := {}
static func _repaint(node: Node3D, spec: Dictionary) -> void:
	var key := JSON.stringify(spec)
	if not repaints.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(str(spec.get("color","ffffff")))
		material.metallic = float(spec.get("metallic",0.0))
		material.roughness = float(spec.get("roughness",0.6))
		repaints[key] = material
	for mesh in node.find_children("*","MeshInstance3D",true,false): (mesh as MeshInstance3D).material_override = repaints[key]

static func _one(reconstruction: RefCounted, model: String, found: Dictionary, scale: float) -> Node3D:
	# "Objaverse/name" entries are reduced museum/Sketchfab scans (Art/Objaverse);
	# "Reduced/set/set_N" one variant split out of a Poly Haven nature set.
	var path := "Objaverse/%s/%s.glb" % [model.trim_prefix("Objaverse/"),model.trim_prefix("Objaverse/")] if model.begins_with("Objaverse/") else (("%s.gltf" % model if ResourceLoader.exists("res://Art/%s.gltf" % model) else "%s.glb" % model) if model.begins_with("Reduced/") else "PolyHaven/%s/%s_1k.gltf" % [model,model])
	if not ResourceLoader.exists("res://Art/"+path): return null
	var probe: Node3D = reconstruction.fitted(path,Vector3.ONE)
	probe.free()
	var box: AABB = reconstruction.bounds[path]
	# Flat goods (cutlery, trays, bread, ore) scale by their length instead;
	# "lay" items (weapons, shields) lie flat: scaled by their longest side and
	# turned so their thinnest side is vertical.
	var lay: bool = found.get("lay",false)
	var longest := maxf(box.size.x,maxf(box.size.y,box.size.z)) if lay else maxf(box.size.x,box.size.z)
	var factor := (float(found.length)/maxf(longest,0.001) if found.has("length") else float(found.height)/maxf(box.size.y,0.001))*scale
	var placed: Node3D = reconstruction.fitted(path,box.size*factor)
	if found.has("material"): _repaint(placed,found.material)
	if lay:
		# fitted() stands the model on y = 0, centred in x and z.
		var size := box.size*factor
		var pivot := Node3D.new()
		pivot.add_child(placed)
		# "flip": the model's front (shield face) lies upward instead of down.
		var flip: bool = found.get("flip",false)
		if size.z < size.y and size.z <= size.x:
			# About X: z becomes up (y' = -z), y runs along z' (0..size.y).
			placed.rotation.x = -PI/2 if flip else PI/2
			placed.position = Vector3(0,size.z/2,size.y/2 if flip else -size.y/2)
		elif size.x < size.y and size.x < size.z:
			# About Z: x becomes up (y' = x), y runs along -x' (-size.y..0).
			placed.rotation.z = PI/2
			placed.position = Vector3(size.y/2,size.x/2,0)
		return pivot
	if not (found.has("rotation") or found.has("anchor") or found.has("elevation") or found.has("flame") or found.has("pedestal") or found.has("pitch")): return placed
	var pivot := Node3D.new()
	pivot.add_child(placed)
	placed.rotation.y = deg_to_rad(float(found.get("rotation",0.0)))
	placed.position.y = float(found.get("elevation",0.0))
	# "pitch": tip an upright scan over (degrees about X) to lie on the ground.
	if found.has("pitch"):
		placed.rotation.x = deg_to_rad(float(found.pitch))
		placed.position.y += box.size.z*factor/2
	# "pedestal": [width, height] stone column the model stands on.
	if found.has("pedestal"):
		var column: Array = found.pedestal
		reconstruction.geometry.crafted_box(pivot,Vector3(float(column[0]),float(column[1]),float(column[0])),Vector3(0,float(column[1])/2,0),"9e9a87")
		placed.position.y += float(column[1])
	var turned := Basis(Vector3.UP,placed.rotation.y)*(box.size*factor)
	if str(found.get("anchor","")) == "back": placed.position.z = -absf(turned.z)/2
	# "flame": a glowing tip on top (a wall torch's head leans away from the wall).
	if found.get("flame",false):
		var flame := MeshInstance3D.new()
		var tip := SphereMesh.new()
		# true: a torch tip; a number: that flame radius (a brazier's fire).
		var radius := 0.05 if found.flame is bool else float(found.flame)
		tip.radius = radius
		tip.height = radius*3.2
		tip.radial_segments = 8
		tip.rings = 4
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("ffb347")
		glow.emission_enabled = true
		glow.emission = Color("ff9a2e")
		glow.emission_energy_multiplier = 2.5
		flame.mesh = tip
		flame.material_override = glow
		flame.position = Vector3(0,placed.position.y+absf(turned.y)+0.07-radius,placed.position.z-absf(turned.z)/2+0.07 if str(found.get("anchor","")) == "back" else 0.0)
		pivot.add_child(flame)
	return pivot
