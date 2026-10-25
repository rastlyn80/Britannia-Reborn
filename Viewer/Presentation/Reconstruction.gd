extends RefCounted

const Geometry = preload("res://Presentation/GeometryLibrary.gd")
var geometry := Geometry.new()
var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Presentation/static-catalog.json")).rules
var scenes := {}
var bounds := {}
var roof_materials := {}
var mapped := 0
var unresolved := 0
var grouped := 0
var report: Array = []
var groups := {}
var wall_cells := {}

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
	groups.clear()
	wall_cells.clear()
	var trees := {}
	var beds := {}
	var arches := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var kind := str(rule_for(s.id).get("kind","unknown"))
		var cell := Vector3i(s.x,s.y,s.z)
		if kind in ["wall","window","corner"]: wall_cells[cell] = true
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
	for cell in arches:
		var at: int = arches[cell]
		if int(world.statics[at].id) == 320 and arches.has(cell+Vector3i(0,1,0)):
			_group([at,arches[cell+Vector3i(0,1,0)]],world,"arch")

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
	var data := {"owner":owner,"indices":indices,"low":low,"size":high-low+Vector2.ONE,"kind":kind}
	for index in indices: groups[index] = data

func _collect_bounds(node: Node3D, transform: Transform3D, boxes: Array) -> void:
	var combined := transform*node.transform
	if node is MeshInstance3D: boxes.append(combined*node.get_aabb())
	for child in node.get_children():
		if child is Node3D: _collect_bounds(child,combined,boxes)

func fitted(path: String, size: Vector3) -> Node3D:
	var full := "res://Art/"+path if path.begins_with("Kenney/") else "res://Art/Quaternius/"+path
	if not scenes.has(path):
		scenes[path] = load(full)
		assert(scenes[path] != null,"Missing catalogue asset: "+path)
		var sample: Node3D = scenes[path].instantiate()
		var boxes: Array = []
		_collect_bounds(sample,Transform3D.IDENTITY,boxes)
		assert(not boxes.is_empty())
		var box: AABB = boxes[0]
		for other in boxes: box = box.merge(other)
		bounds[path] = box
		sample.free()
	var node := Node3D.new()
	var offset := Node3D.new()
	var model: Node3D = scenes[path].instantiate()
	if path.begins_with("Nature/"):
		# Keep wind-weight colours out of the ordinary material. The twisted
		# tree ships with red foliage; Britain uses the kit's green foliage palette.
		for mesh in model.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var mat: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
				mat.vertex_color_use_as_albedo = false
				if mat.resource_name == "Leaves_TwistedTree": mat.albedo_texture = load("res://Art/Quaternius/Nature/Leaves_NormalTree_C.png")
				mesh.set_surface_override_material(surface,mat)
	var box: AABB = bounds[path]
	offset.scale = size/box.size
	offset.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*offset.scale
	offset.add_child(model)
	node.add_child(offset)
	return node

func roof_material(kind: String) -> ShaderMaterial:
	if not roof_materials.has(kind):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://Presentation/Roof.gdshader")
		mat.set_shader_parameter("roof_color",Color("586573") if kind == "slate" else (Color("a06345") if kind == "clay" else Color("796344")))
		mat.set_shader_parameter("wood",kind == "shingle")
		mat.set_shader_parameter("kit_texture",load("res://Art/Quaternius/Village/T_WoodTrim_BaseColor.png"))
		roof_materials[kind] = mat
	return roof_materials[kind]

func build(s: Dictionary, world: Dictionary, ordinal: int = -1) -> Node3D:
	var rule := rule_for(s.id)
	if rule.is_empty() and info(world,s.id,true).get("name") == "wooden boards": rule = {"kind":"floor","asset":"Village/Floor_WoodDark.gltf","axis":"x","confidence":"fixture"}
	var kind := str(rule.get("kind","unknown"))
	var node := Node3D.new()
	var detail := info(world,s.id,true)
	var height := maxf(0.04,float(detail.get("height",0))*float(world.elevationScale))
	var asset := str(rule.get("asset",""))
	var visual: Node3D
	var state := "replacement"
	if groups.has(ordinal) and groups[ordinal].owner != ordinal:
		state = "group-component"
		grouped += 1
	else:
		match kind:
			"wall", "window": visual = fitted(asset,Vector3(1,height,0.16))
			"corner":
				visual = Node3D.new()
				var first := fitted(asset,Vector3(1,height,0.16))
				var second := fitted(asset,Vector3(1,height,0.16))
				first.position.z = -0.42
				second.position.x = -0.42
				second.rotation.y = PI/2
				visual.add_child(first)
				visual.add_child(second)
			"post": visual = fitted(asset,Vector3(0.15,height,0.15))
			"trim", "beam": visual = fitted(asset,Vector3(1,height,0.14))
			"arch": visual = fitted(asset,Vector3(2 if groups.has(ordinal) else 1,height,0.18))
			"floor": visual = fitted(asset,Vector3(1,0.035,1))
			"landing":
				visual = Node3D.new()
				geometry.box(visual,Vector3(1,height,1),Vector3(0,height/2,0),"76634d" if int(s.id) != 1872 else "888b87")
				var deck := fitted(asset,Vector3(1,0.035,1))
				deck.position.y = height
				visual.add_child(deck)
			"stairs": visual = geometry.stairs(height,Vector2(rule.rise[0],rule.rise[1]))
			"roof": visual = geometry.roof(s,rule,roof_material(rule.material))
			"door": visual = fitted(asset,Vector3(0.86,height,0.12))
			"fence": visual = fitted(asset,Vector3(1,1.2,0.10))
			"bed":
				var size: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
				var double_bed := minf(size.x,size.y) > 1
				asset = "Kenney/bedDouble.glb" if double_bed else asset
				visual = fitted(asset,Vector3(minf(size.x,size.y),0.72,maxf(size.x,size.y)))
				if size.x > size.y: visual.rotation.y = PI/2
			"carpet": visual = geometry.carpet(s)
			"table": visual = fitted(asset,Vector3(0.98,0.95,0.98))
			"bench": visual = fitted(asset,Vector3(1,0.5,0.52))
			"counter":
				visual = fitted(asset,Vector3(1,1.0,0.8))
				for mesh in visual.find_children("*","MeshInstance3D",true,false):
					for surface in mesh.mesh.get_surface_count():
						var mat: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
						mat.albedo_color *= Color("9b744e")
						mat.roughness = 0.9
						mesh.set_surface_override_material(surface,mat)
			"sign": visual = geometry.sign()
			"painting": visual = geometry.painting()
			"tree", "canopy":
				var name := str(detail.get("name",""))
				var size := Vector3(3.2,5.8,3.2)
				if name.contains("sapling"): size = Vector3(1,1.9,1)
				if name.contains("cedar"): size = Vector3(2.6,6.2,2.6)
				if kind == "canopy": asset = "Nature/CommonTree_1.gltf"
				visual = fitted(asset,size)
				visual.rotation.y = fmod(float(int(s.x)*17+int(s.y)*31),TAU)
			"grass": visual = fitted(asset,Vector3(0.65,0.25+0.1*(int(s.id)%3),0.65))
			"flower": visual = fitted(asset,Vector3(0.55,0.28,0.55))
			"bush": visual = fitted(asset,Vector3(1.1,0.65,1.1))
			"mushroom": visual = fitted(asset,Vector3(0.32,0.22,0.32))
			"rock": visual = fitted(asset,Vector3(0.55,0.38,0.55))
			"log": visual = fitted(asset,Vector3(0.9,0.35,0.4))
			"water":
				var plane := PlaneMesh.new()
				plane.size = Vector2.ONE
				visual = MeshInstance3D.new()
				visual.mesh = plane
				var mat := ShaderMaterial.new()
				mat.shader = preload("res://Presentation/Water.gdshader")
				visual.material_override = mat
			_:
				unresolved += 1
				node.free()
				report.append({"ordinal":ordinal,"id":s.id,"xyz":[s.x,s.y,s.z],"status":"unmapped"})
				return null
		if visual:
			if kind in ["wall","window","trim","beam","arch","door","fence","bench","sign","painting"] and rule.get("axis") == "y": visual.rotation.y = PI/2
			if groups.has(ordinal) and kind in ["bed","arch"]:
				var group: Dictionary = groups[ordinal]
				visual.position += Vector3(group.low.x+group.size.x/2-float(s.x)-0.5,0,group.low.y+group.size.y/2-float(s.y)-0.5)
			node.add_child(visual)
	mapped += 1
	node.set_meta("source_id",s.id)
	node.set_meta("source_xyz",Vector3i(s.x,s.y,s.z))
	node.set_meta("source_ordinal",ordinal)
	node.set_meta("kind",kind)
	node.set_meta("solid",kind in ["wall","window","corner","post","trim","beam","arch","floor","landing","stairs","roof","door","fence","bed","table","bench","counter","rock","log"] and state != "group-component")
	node.position = Vector3(s.x-int(world.originX)+0.5,s.z*float(world.elevationScale),s.y-int(world.originY)+0.5)
	var entry := {"ordinal":ordinal,"id":s.id,"xyz":[s.x,s.y,s.z],"status":state,"kind":kind,"asset":asset,"axis":rule.get("axis","x"),"confidence":rule.get("confidence","semantic")}
	if groups.has(ordinal): entry.group_owner = groups[ordinal].owner
	report.append(entry)
	return node

func save_report(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"total":report.size(),"accounted":mapped,"group_components":grouped,"unmapped":unresolved,"exact_original_art_matches":0,"placements":report},"\t"))
