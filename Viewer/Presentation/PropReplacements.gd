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
	# Spell scrolls of every school share the scroll scans (spell_scroll()).
	if id >= 0 and not spell_scroll(id).is_empty(): return spell_scroll(id)
	var found := entry(name)
	if found.is_empty() and id >= 0: return wardrobe(id,name)
	if found.is_empty() or id < 0: return found
	var override: Dictionary = found.get("ids",{}).get(str(id),{})
	if override.get("skip",false): return {}
	# An entry that only lists graphics ("only_ids": unnamed records) needs one of them.
	if found.get("only_ids",false) and override.is_empty(): return {}
	return found.merged(override,true)

# Spell scrolls by graphic range: Magery, Necromancy, Spellweaving and
# Mysticism. One of three scroll scans, tinted by school with a small hue
# shift and size step per spell, so a shelf of scrolls is not identical.
const SCROLL_SCHOOLS := [[0x1F2D,0x1F6C,"f0c8a8"],[0x2260,0x2270,"78b098"],[0x2D51,0x2D60,"e8d0b0"],[0x2D9E,0x2DAD,"b0a078"]]
const SCROLL_MODELS := ["Objaverse/scroll_old","Objaverse/scroll_ancient","Objaverse/parchment_rolled"]
static func spell_scroll(id: int) -> Dictionary:
	for school in SCROLL_SCHOOLS:
		if id < int(school[0]) or id > int(school[1]): continue
		var tone := Color(str(school[2]))
		tone.h = fposmod(tone.h+float(id%7-3)*0.025,1.0)
		tone.v = clampf(tone.v*(0.92+float(id%5)*0.03),0.0,1.0)
		# A small tied bundle like the original art: two or three rolls.
		return {"models":[SCROLL_MODELS[id%SCROLL_MODELS.size()],SCROLL_MODELS[(id+1)%SCROLL_MODELS.size()]],"cluster":2+id%2,"spread":[0.03,0.05],"aligned":true,"length":0.26+float(id%4)*0.025,"lay":true,"tint":tone.to_html(false)}
	return {}

# Weapons, shields, helmets, gloves, footwear and jewellery lying loose draw
# the same local character-equipment mesh the avatars wear (HumanWardrobe), at
# its real size, when no curated entry, crafted build or library slot exists. Body garments keep their
# laid-out cloth builds (CraftedProps): a body-fitted shell reads wrong.
const LOOSE_SLOTS := ["weapon","shield","head","hands","feet","gorget","necklace","talisman","bracelet","earrings","ring","waist"]
const LAID_SLOTS := ["weapon","shield","hands","necklace","talisman","bracelet","earrings","ring","waist","gorget"]
const EQUIPMENT := "res://local-art/free-equipment-female/"
static func wardrobe(id: int, name := "") -> Dictionary:
	# Crafted builds and owner-library slots already give these a better look.
	if preload("res://Presentation/CraftedProps.gd").handles(name) or not preload("res://Presentation/RegionalRules.gd").slot_for(key(name)).is_empty(): return {}
	var piece: Array = preload("res://Presentation/HumanWardrobe.gd").extra(id)
	if piece.size() < 2 or not str(piece[0]) in LOOSE_SLOTS: return {}
	var file := str(piece[1]) if "/" in str(piece[1]) else "expansion/"+str(piece[1])
	if not ResourceLoader.exists(EQUIPMENT+file+".glb"): return {}
	return {"model":"Local/"+file,"native":true,"lay":str(piece[0]) in LAID_SLOTS}

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
		# "spread" [min, max] metres between copies (a tight bundle of scrolls).
		var spread: Array = found.get("spread",[0.12,0.3])
		var radius := 0.0 if i == 0 else random.randf_range(float(spread[0]),float(spread[1]))
		placed.position = Vector3(cos(angle)*radius,0,sin(angle)*radius)
		placed.rotation.y = random.randf_range(0,TAU)
		# "aligned": copies lie parallel side by side (a tied bundle), stacked a little.
		if found.get("aligned",false):
			var boxes: Array = []
			reconstruction._collect_bounds(placed,Transform3D.IDENTITY,boxes)
			var long_x := true
			if not boxes.is_empty():
				var box: AABB = boxes[0]
				for other in boxes: box = box.merge(other)
				long_x = box.size.x >= box.size.z
			var step := (float(i)-float(count-1)/2.0)*float(spread[1])
			placed.position = Vector3(random.randf_range(-0.02,0.02) if long_x else step,0.02*float(i%2),step if long_x else random.randf_range(-0.02,0.02))
			placed.rotation.y = random.randf_range(-0.12,0.12)
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

# Colours by source material name for scans that carry none ({"Leaves":
# "2f5a24", "Petal": "6a2a8c"}: a surface whose material name contains a key).
static func _palette(node: Node3D, palette: Dictionary) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var instance := mesh as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface)
			var label := source.resource_name if source else ""
			for part in palette:
				if part.to_lower() in label.to_lower():
					var key := "palette/"+str(palette[part])
					if not repaints.has(key):
						var material := StandardMaterial3D.new()
						material.albedo_color = Color(str(palette[part]))
						material.roughness = 0.75
						repaints[key] = material
					instance.set_surface_override_material(surface,repaints[key])

# One hue of an atlas texture repainted ({"from": hex, "to": hex, "reach":
# chroma distance}): the petals of a flower scan in another colour.
static func _recolor(node: Node3D, spec: Dictionary) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var instance := mesh as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null or source.albedo_texture == null: continue
			var key := "recolor/%s/%s" % [JSON.stringify(spec),source.get_instance_id()]
			if not repaints.has(key):
				var material := ShaderMaterial.new()
				material.shader = preload("res://Presentation/Recolor.gdshader")
				material.set_shader_parameter("albedo_tex",source.albedo_texture)
				material.set_shader_parameter("has_normal",source.normal_enabled and source.normal_texture != null)
				material.set_shader_parameter("normal_tex",source.normal_texture)
				material.set_shader_parameter("from_color",Color(str(spec.get("from","f0d020"))))
				material.set_shader_parameter("to_color",Color(str(spec.get("to","f4f1e8"))))
				material.set_shader_parameter("reach",float(spec.get("reach",0.2)))
				repaints[key] = material
			instance.set_surface_override_material(surface,repaints[key])

# Multiplies a scan's own colours by a tint, keeping its texture (a dyed
# variant of one model).
static func _tint(node: Node3D, tone: Color) -> void:
	for mesh in node.find_children("*","MeshInstance3D",true,false):
		var instance := mesh as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var source := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if source == null: continue
			var key := "tint/%s/%s" % [tone.to_html(false),source.get_instance_id()]
			if not repaints.has(key):
				var dyed := source.duplicate() as BaseMaterial3D
				dyed.albedo_color = source.albedo_color*tone
				repaints[key] = dyed
			instance.set_surface_override_material(surface,repaints[key])

static func _one(reconstruction: RefCounted, model: String, found: Dictionary, scale: float) -> Node3D:
	if found.get("aligned",false): scale = lerpf(1.0,scale,0.3)
	# "Objaverse/name" entries are reduced museum/Sketchfab scans (Art/Objaverse);
	# "Reduced/set/set_N" one variant split out of a Poly Haven nature set;
	# "Objaverse/set/split/part_N" one variant split out of a pinned scan set.
	var path := ("Objaverse/%s.gltf" % model.trim_prefix("Objaverse/") if "/" in model.trim_prefix("Objaverse/") else "Objaverse/%s/%s.glb" % [model.trim_prefix("Objaverse/"),model.trim_prefix("Objaverse/")]) if model.begins_with("Objaverse/") else (("%s.gltf" % model if ResourceLoader.exists("res://Art/%s.gltf" % model) else "%s.glb" % model) if model.begins_with("Reduced/") else "PolyHaven/%s/%s_1k.gltf" % [model,model])
	if model.begins_with("Local/"): path = model+".glb"
	if not ResourceLoader.exists(EQUIPMENT+model.trim_prefix("Local/")+".glb" if model.begins_with("Local/") else "res://Art/"+path): return null
	var probe: Node3D = reconstruction.fitted(path,Vector3.ONE)
	probe.free()
	var box: AABB = reconstruction.bounds[path]
	# Flat goods (cutlery, trays, bread, ore) scale by their length instead;
	# "lay" items (weapons, shields) lie flat: scaled by their longest side and
	# turned so their thinnest side is vertical.
	var lay: bool = found.get("lay",false)
	var longest := maxf(box.size.x,maxf(box.size.y,box.size.z)) if lay else maxf(box.size.x,box.size.z)
	var factor := (1.0 if found.get("native",false) else (float(found.length)/maxf(longest,0.001) if found.has("length") else float(found.height)/maxf(box.size.y,0.001)))*scale
	# "size" [x, y, z] fits a block-like scan to exact proportions (a clipped hedge).
	var placed: Node3D = reconstruction.fitted(path,Vector3(found.size[0],found.size[1],found.size[2])*scale if found.has("size") else box.size*factor)
	if found.has("material"): _repaint(placed,found.material)
	if found.has("palette"): _palette(placed,found.palette)
	if found.has("recolor"): _recolor(placed,found.recolor)
	if found.has("tint"): _tint(placed,Color(str(found.tint)))
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
