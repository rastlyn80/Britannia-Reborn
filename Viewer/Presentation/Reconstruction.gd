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
var source_origin := Vector2.ZERO
var gable_material: ShaderMaterial
var water_material: ShaderMaterial
var shoreline
var show_boundary_fragments := false
var boundary_fragments := 0
var mapped := 0
var unresolved := 0
var grouped := 0
var report: Array = []
var groups := {}
var wall_cells := {}
var presentation_adjustments := {}
var contextual_suppressed := 0
var floors := preload("res://Presentation/FloorPlan.gd").new()

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
	if world.get("render_cells",false):print("REGIONAL RULES DONE")
	source_origin = Vector2(world.get("originX",0),world.get("originY",0))
	facade.index(world,catalog)
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
		if rule.get("kind","")!="prop" or rule.get("model","") not in ["cannon","fountain","display_case","training","music"]:continue
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
	for cell in arches:
		var at: int = arches[cell]
		if int(world.statics[at].id) != 320: continue
		var step := Vector3i(0,1,0) if rule_for(int(world.statics[at].id)).get("axis") == "y" else Vector3i(1,0,0)
		for distance in range(1,5):
			var end: Vector3i = cell+step*distance
			if wall_cells.has(end): break
			if not arches.has(end): continue
			if int(world.statics[arches[end]].id) == 317: _group([at,arches[end]],world,"arch")
			break

	if world.get("render_cells",false):print("REGIONAL GROUPS DONE")
	_plan_context(world)

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
		if group.kind in ["bench","table","counter"]:
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
					mat.set_shader_parameter("amplitude",0.0 if show_boundary_fragments else minf(0.22,size.y*0.12))
					mat.set_shader_parameter("flutter",0.0 if show_boundary_fragments else (0.012 if "Leaves" in original.resource_name else 0.004))
					mat.set_shader_parameter("source_origin",source_origin)
					nature_materials[key] = mat
				mesh.set_surface_override_material(surface,nature_materials[key])
	if path.begins_with("Village/"):
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
		mat.set_shader_parameter("roof_color",Color("99988c") if kind == "stone" else Color("586573") if kind == "slate" else (Color("a06345") if kind == "clay" else (Color("b09355") if kind == "thatch" else Color("796344"))))
		mat.set_shader_parameter("wood",kind == "shingle")
		mat.set_shader_parameter("thatch",kind == "thatch")
		mat.set_shader_parameter("ceiling_color",Color("917454"))
		mat.set_shader_parameter("kit_texture",load("res://Art/Quaternius/Village/T_WoodTrim_BaseColor.png"))
		preload("res://Presentation/SurfaceLibrary.gd").bind(mat,"surface","brown_planks_03" if kind == "shingle" else ("rock_wall_04" if kind == "stone" else "grey_roof_tiles_02"))
		roof_materials[kind] = mat
	return roof_materials[kind]

func build(s: Dictionary, world: Dictionary, ordinal: int = -1) -> Node3D:
	var rule := rule_for(s.id)
	if rule.is_empty() and info(world,s.id,true).get("name") == "wooden boards": rule = {"kind":"floor","asset":"Village/Floor_WoodDark.gltf","axis":"x","confidence":"fixture"}
	var kind := str(rule.get("kind","unknown"))
	var node := Node3D.new()
	var detail := info(world,s.id,true)
	var height := maxf(0.04,float(detail.get("height",0))*float(world.elevationScale))
	height += maxf(float(facade.plans.get(ordinal,{}).get("height_extension",0.0)),float(facade.cap_extensions.get(ordinal,0.0)))
	var asset := str(rule.get("asset",""))
	var family := "brick" if "brick wall" in str(detail.get("name","")) else "wood" if "wooden wall" in str(detail.get("name","")) else ("stone" if "stone wall" in str(detail.get("name","")) else "plaster")
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
		match kind:
			"wall", "window": visual = facade.panel(height,kind == "window",facade.plans.get(ordinal,{}),family)
			"corner": visual = facade.corner(height,facade.corners.get(ordinal,{}),family)
			"post": visual = fitted(asset,Vector3(0.15,height,0.15))
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
				visual = geometry.gable(span,(group.max_z-group.min_z)*float(world.elevationScale),facade.material("plaster"))
				visual.position.y = (group.min_z-float(s.z))*float(world.elevationScale)
				if rule.get("axis") == "y": visual.rotation.y = PI/2
			"trim", "beam": visual = fitted(asset,Vector3(1,height,0.14))
			"arch":
				visual = Node3D.new()
				var span: float = maxf(groups[ordinal].size.x,groups[ordinal].size.y) if groups.has(ordinal) else 1.0
				var opening_height := minf(height,2.7)
				visual.add_child(fitted(asset,Vector3(span,opening_height,0.2)))
				if height > opening_height: facade.piece(visual,Vector3(span,height-opening_height,0.18),Vector3(0,(height+opening_height)/2,0),"plaster")
			"floor": visual = floors.slab(ordinal,facade.material("stone") if rule.get("surface","")=="stone" else floors.material())
			"asset": visual = fitted(asset,Vector3(rule.dimensions[0],rule.dimensions[1],rule.dimensions[2]))
			"prop": visual = preload("res://Presentation/CityProps.gd").build(str(rule.model),s,detail,geometry)
			"invisible": state="source-nodraw"
			"landing":
				visual = Node3D.new()
				# Bridge tiledata heights describe the art bounds; support is halfway up.
				if int(detail.get("flags",0)) & 0x400: height *= 0.5
				var stair_material := facade.material("stone" if "stone" in str(detail.get("name","")) else "wood")
				var support := geometry.box(visual,Vector3(1,height,1),Vector3(0,height/2,0),"ffffff")
				support.material_override = stair_material
				var deck := floors.slab("landing",stair_material)
				deck.position.y += height
				visual.add_child(deck)
			"stairs":
				visual = geometry.stairs(height,floors.stair_rise.get(ordinal,Vector2(rule.rise[0],rule.rise[1])))
				for step in visual.get_children(): step.material_override = facade.material("stone" if "stone" in str(detail.get("name","")) else "wood")
			"roof":
				if gable_material == null:
					gable_material = facade.material("plaster").duplicate()
					gable_material.set_shader_parameter("double_sided",true)
				visual = geometry.roof(s,rule,roof_material(rule.material),roofs.tiles.get(ordinal,{}),gable_material)
			"door":
				visual = fitted(asset,Vector3(0.86,height,0.12))
				for side in [-1,1]: facade.piece(visual,Vector3(0.08,height,0.2),Vector3(side*0.46,height/2,0),"wood")
				facade.piece(visual,Vector3(1,0.12,0.2),Vector3(0,height-0.06,0),"wood")
			"fence": visual = fitted(asset,Vector3(1,1.2,0.10))
			"bed":
				var size: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
				var double_bed := minf(size.x,size.y) > 1
				asset = "Kenney/bedDouble.glb" if double_bed else asset
				visual = fitted(asset,Vector3(minf(size.x,size.y),0.72,maxf(size.x,size.y)))
				if size.x > size.y: visual.rotation.y = PI/2
			"carpet": visual = geometry.carpet(s)
			"table", "bench", "counter":
				var size: Vector2 = groups[ordinal].size if groups.has(ordinal) else Vector2.ONE
				if kind == "bench":
					if size.y > size.x: size.x = 0.5
					else: size.y = 0.5
				visual = geometry.furniture(size,kind)
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
				plane.subdivide_width = 3
				plane.subdivide_depth = 3
				visual = MeshInstance3D.new()
				visual.mesh = plane
				if water_material == null:
					water_material = ShaderMaterial.new()
					water_material.shader = preload("res://Presentation/Water.gdshader")
					water_material.set_shader_parameter("source_origin",source_origin)
					water_material.set_shader_parameter("wave_strength",0.0 if show_boundary_fragments else 1.0)
					if shoreline: shoreline.apply(water_material)
				visual.material_override = water_material
			_:
				unresolved += 1
				node.free()
				report.append({"ordinal":ordinal,"id":s.id,"xyz":[s.x,s.y,s.z],"status":"unmapped"})
				return null
		if visual:
			if kind == "roof":
				var anchor: Array = rule.get("anchorOffset",[-1,-1])
				visual.position += Vector3(float(anchor[0]),0,float(anchor[1]))
			if kind in ["wall","window","trim","beam","arch","door","fence","sign","painting"] and rule.get("axis") == "y": visual.rotation.y = PI/2
			if kind=="prop" and groups.has(ordinal):
				visual.scale=Vector3(groups[ordinal].size.x,1.0,groups[ordinal].size.y)
				visual.position.y+=(groups[ordinal].min_z-float(s.z))*float(world.elevationScale)
			if groups.has(ordinal) and kind in ["bed","arch","gable","bench","table","counter","prop"]:
				var group: Dictionary = groups[ordinal]
				visual.position += Vector3(group.low.x+group.size.x/2-float(s.x)-0.5,0,group.low.y+group.size.y/2-float(s.y)-0.5)
			if not show_boundary_fragments: visual.position += presentation_adjustments.get(ordinal,{}).get("offset",Vector3.ZERO)
			node.add_child(visual)
	mapped += 1
	node.set_meta("source_id",s.id)
	node.set_meta("source_xyz",Vector3i(s.x,s.y,s.z))
	node.set_meta("source_ordinal",ordinal)
	node.set_meta("kind",kind)
	node.set_meta("solid",kind in ["wall","window","corner","post","trim","gable","beam","arch","floor","landing","stairs","roof","door","fence","bed","table","bench","counter","rock","log"] and state not in ["group-component","boundary-fragment","context-suppressed"])
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
	report.append(entry)
	return node

func save_report(path: String) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"total":report.size(),"accounted":mapped,"group_components":grouped,"boundary_fragments":boundary_fragments,"contextual_suppressed":contextual_suppressed,"unmapped":unresolved,"exact_original_art_matches":0,"architecture":facade.audit(),"derived_floor_repairs":floors.repairs.map(func(at): return [at.x,at.y,at.z]),"stair_directions_inferred":floors.stair_rise.size(),"placements":report},"\t"))
