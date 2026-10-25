extends RefCounted

const ART := "res://Art/Quaternius/"
var scenes := {}
var bounds := {}
var mapped := 0
var unresolved := 0
var wall_cells := {}
var roof_cells := {}

static func info(world: Dictionary, id: int, statics: bool) -> Dictionary:
	var catalog = world.get("staticData" if statics else "landData")
	return catalog.get(str(id),{}) if catalog is Dictionary else {}

static func terrain_color(name: String) -> Color:
	name = name.to_lower()
	if name == "grass": return Color("6c9551")
	if name == "forest": return Color("527443")
	if name == "dirt": return Color("97805b")
	if name == "cobblestones" or name == "stone": return Color("949b99")
	if name == "wooden floor": return Color("94744c")
	if name == "brick": return Color("a28067")
	if name == "sand": return Color("c8b88a")
	if name.contains("water"): return Color("427d9b")
	return Color("887f91") # explicitly unknown, never silently classified as grass

func index(world: Dictionary) -> void:
	for s in world.statics:
		var data := info(world,s.id,true)
		if str(data.get("name","")).contains("roof") or data.get("name") == "wooden shingles": roof_cells[Vector2i(s.x,s.y)] = s.z
		if int(data.get("height",0)) >= 15 and (str(data.get("name","")).contains("wall") or data.get("name") == "window"):
			wall_cells[Vector3i(s.x,s.y,s.z)] = true

func fitted(path: String, size: Vector3) -> Node3D:
	if not scenes.has(path):
		scenes[path] = load(ART+path)
		var example: Node3D = scenes[path].instantiate()
		var box := AABB()
		var first := true
		for mesh in example.find_children("*","MeshInstance3D",true,false):
			var local: AABB = mesh.transform * mesh.get_aabb()
			box = local if first else box.merge(local)
			first = false
		bounds[path] = box
		example.free()
	var holder := Node3D.new()
	var model: Node3D = scenes[path].instantiate()
	var box: AABB = bounds[path]
	model.scale = size / box.size
	model.position = -Vector3(box.get_center().x,box.position.y,box.get_center().z)*model.scale
	holder.add_child(model)
	return holder

func build(s: Dictionary, world: Dictionary) -> Node3D:
	var data := info(world,s.id,true)
	var name := str(data.get("name","")).to_lower()
	var height := int(data.get("height",0))
	var node: Node3D
	if name.contains("wall") and height >= 15 or name == "window" and height >= 15:
		var cell := Vector3i(s.x,s.y,s.z)
		var horizontal := int(wall_cells.has(cell+Vector3i(1,0,0)))+int(wall_cells.has(cell-Vector3i(1,0,0)))
		var vertical := int(wall_cells.has(cell+Vector3i(0,1,0)))+int(wall_cells.has(cell-Vector3i(0,1,0)))
		if horizontal == vertical:
			unresolved += 1
			return null # ambiguous corners stay diagnostic until an explicit rule exists
		var file := "Wall_Plaster_Window_Wide_Flat" if name == "window" else ("Wall_Plaster_Straight" if name.contains("plaster") else "Wall_UnevenBrick_Straight")
		node = fitted("Village/"+file+".gltf",Vector3(1,height*float(world.elevationScale),0.18))
		node.rotation.y = 0 if horizontal > vertical else PI/2
	elif name == "wooden boards": node = fitted("Village/Floor_WoodDark.gltf",Vector3(1,0.025,1))
	elif name == "wooden shingles" or name == "slate roof":
		# Provisional slope from neighbouring canonical roof elevations; no full-house prefab.
		var cell := Vector2i(s.x,s.y)
		var rising := Vector2i.ZERO
		var rise := 0
		for step in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
			var difference := int(roof_cells.get(cell+step,s.z))-int(s.z)
			if difference > rise:
				rise = difference
				rising = step
		node = fitted("Village/Roof_Modular_RoundTiles.gltf",Vector3(1,maxi(3,mini(rise,5))*float(world.elevationScale),1))
		if rising != Vector2i.ZERO: node.rotation.y = atan2(float(rising.x),float(rising.y))
		for mesh in node.find_children("*","MeshInstance3D",true,false):
			for surface in mesh.mesh.get_surface_count():
				var mat: StandardMaterial3D = mesh.get_active_material(surface).duplicate()
				mat.albedo_color = Color("73869b") if name == "slate roof" else Color("ac895c")
				mesh.set_surface_override_material(surface,mat)
		# Source roof tiles form a continuous bed. Decorative kit geometry alone
		# has open edges and cannot serve as the whole roof surface.
		var bed := SurfaceTool.new()
		bed.begin(Mesh.PRIMITIVE_TRIANGLES)
		var lift := mini(rise,5)*float(world.elevationScale)
		var corners := [Vector3(-0.5,-0.015,-0.5),Vector3(0.5,-0.015,-0.5),Vector3(-0.5,lift-0.015,0.5),Vector3(0.5,lift-0.015,0.5)]
		for vertex in [0,2,1,1,2,3]: bed.add_vertex(corners[vertex])
		bed.generate_normals()
		var skin := MeshInstance3D.new()
		skin.mesh = bed.commit()
		var finish := StandardMaterial3D.new()
		finish.albedo_color = Color("586276") if name == "slate roof" else Color("7c5546")
		finish.roughness = 0.9
		finish.cull_mode = BaseMaterial3D.CULL_DISABLED
		skin.material_override = finish
		node.add_child(skin)
	elif name == "water":
		var mesh := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2.ONE
		mesh.mesh = plane
		var water := StandardMaterial3D.new()
		water.albedo_color = Color("44899e")
		water.roughness = 0.22
		water.metallic = 0.3
		mesh.material_override = water
		node = mesh
	elif name == "grasses" or name == "grass": node = fitted("Nature/Grass_Common_Short.gltf",Vector3(0.8,0.35,0.8))
	elif name.contains("bush"): node = fitted("Nature/Bush_Common.gltf",Vector3(1.1,0.8,1.1))
	elif name.contains("tree") and not name.contains("leaves"): node = fitted("Nature/CommonTree_1.gltf",Vector3(3,5,3))
	elif name.contains("rock") or name == "boulder": node = fitted("Nature/Rock_Medium_1.gltf",Vector3(1,0.7,1))
	elif name.contains("crate"): node = fitted("Village/Prop_Crate.gltf",Vector3(0.8,0.8,0.8))
	if node:
		mapped += 1
		node.set_meta("source_id",s.id)
		node.set_meta("source_xyz",Vector3i(s.x,s.y,s.z))
		# Canonical source anchor is unchanged; cell art is centred in its footprint.
		node.position = Vector3(s.x-int(world.originX)+0.5,s.z*float(world.elevationScale),s.y-int(world.originY)+0.5)
	else: unresolved += 1
	return node
