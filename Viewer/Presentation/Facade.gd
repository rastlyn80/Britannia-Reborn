extends RefCounted

# Author panels in metres rather than squeezing a whole kit façade into every
# one-metre source cell. Runs share structural rhythm, source openings stay put.
var geometry := preload("res://Presentation/GeometryLibrary.gd").new()
var materials := {}
var plans := {}
var runs := 0
var corners := {}
var diagonal_joins := 0
var cap_extensions := {}
var capless_materials := {}
var glass_material: StandardMaterial3D
var iron_material: StandardMaterial3D

func index(world: Dictionary, catalog: Dictionary) -> void:
	plans.clear()
	corners.clear()
	runs = 0
	diagonal_joins = 0
	cap_extensions.clear()
	var lines := {}
	for i in world.statics.size():
		var s: Dictionary = world.statics[i]
		var rule: Dictionary = catalog.get(str(int(s.id)),{})
		if rule.get("kind") not in ["wall","window"]: continue
		var axis := str(rule.get("axis","x"))
		var detail: Dictionary = world.staticData.get(str(int(s.id)),{})
		var key := "%s/%d/%d/%d/%s" % [axis,s.y if axis == "x" else s.x,s.z,int(detail.get("height",20)),"brick" if "Brick" in str(rule.get("asset")) else "plaster"]
		if not lines.has(key): lines[key] = []
		lines[key].append({"ordinal":i,"at":int(s.x if axis == "x" else s.y)})
	for key in lines:
		var cells: Array = lines[key]
		cells.sort_custom(func(a: Dictionary,b: Dictionary): return a.at < b.at)
		var run: Array = []
		for cell in cells:
			if not run.is_empty() and cell.at != run.back().at+1:
				finish_run(run)
				run.clear()
			run.append(cell)
		finish_run(run)

	# Explicit corner records connect to the same centre planes as neighboring
	# walls. Previous full panels at -0.42m left disconnected parallel faces.
	var cells := {}
	for i in world.statics.size():
		var source: Dictionary = world.statics[i]
		var cell := Vector2i(source.x,source.y)
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(i)
	# Close only one-Z legacy storey seams, never open door/window cells.
	for i in plans:
		var source: Dictionary = world.statics[i]
		var top := float(source.z)+float(world.staticData.get(str(int(source.id)),{}).get("height",20))
		var extension := 0.0
		for other_index in cells.get(Vector2i(source.x,source.y),[]):
			var other: Dictionary = world.statics[other_index]
			var rule: Dictionary = catalog.get(str(int(other.id)),{})
			if rule.get("kind") not in ["wall","window","corner"]: continue
			if rule.get("axis") != catalog[str(int(source.id))].get("axis"): continue
			var gap := float(other.z)-top
			if gap > 0 and gap <= 1: extension = maxf(extension,gap*float(world.get("elevationScale",0.2)))
		plans[i].height_extension = extension
		var axis_y: bool = catalog[str(int(source.id))].get("axis") == "y"
		for direction in [-1,1]:
			var offset := Vector2i(0,direction) if axis_y else Vector2i(direction,0)
			for other_index in cells.get(Vector2i(source.x,source.y)+offset,[]):
				var other: Dictionary = world.statics[other_index]
				var rule: Dictionary = catalog.get(str(int(other.id)),{})
				if rule.get("kind") != "wall" or (rule.get("axis") == "y") == axis_y: continue
				if absf(float(other.z)-float(source.z)) > 1: continue
				var local_direction: int = -direction if axis_y else direction
				plans[i]["extend_left" if local_direction < 0 else "extend_right"] = true

	# Diagonally adjacent perpendicular end tiles meet at their shared axis
	# intersection. Legacy art draws that half-cell return inside the sprite.
	for i in plans:
		var a: Dictionary = world.statics[i]
		var axis_y: bool = catalog[str(int(a.id))].get("axis") == "y"
		for dx in [-1,1]:
			for dy in [-1,1]:
				for j in cells.get(Vector2i(a.x+dx,a.y+dy),[]):
					if j <= i or not plans.has(j): continue
					var b: Dictionary = world.statics[j]
					if (catalog[str(int(b.id))].get("axis") == "y") == axis_y or absf(float(a.z)-float(b.z)) > 1: continue
					var intersection := Vector2i(a.x,b.y) if axis_y else Vector2i(b.x,a.y)
					var occupied := false
					for k in cells.get(intersection,[]):
						var c: Dictionary = world.statics[k]
						if absf(float(c.z)-float(a.z)) <= 1 and catalog.get(str(int(c.id)),{}).get("kind") in ["wall","window","corner","door","arch"]: occupied = true
					if occupied: continue
					var side_a: int = -dy if axis_y else dx
					var side_b: int = -dx if axis_y else dy
					plans[i]["extend_left" if side_a < 0 else "extend_right"] = true
					plans[j]["extend_left" if side_b < 0 else "extend_right"] = true
					diagonal_joins += 1

	# Close one-Z wall/corner-to-floor seams at the ceiling, including map.mul
	# wooden floors. Source bottoms stay unchanged and door heights are untouched.
	var land := {}
	for tile in world.get("terrain",[]): land[Vector2i(tile.x,tile.y)] = tile
	for i in world.statics.size():
		var source: Dictionary = world.statics[i]
		if catalog.get(str(int(source.id)),{}).get("kind") not in ["wall","window","corner"]: continue
		var data = world.get("staticData",{})
		if not data is Dictionary: continue
		var top := float(source.z)+float(data.get(str(int(source.id)),{}).get("height",20))
		var levels: Array[float] = []
		for j in cells.get(Vector2i(source.x,source.y),[]):
			var floor: Dictionary = world.statics[j]
			if catalog.get(str(int(floor.id)),{}).get("kind") == "floor": levels.append(float(floor.z))
		var land_data = world.get("landData",{})
		for offset in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var terrain: Dictionary = land.get(Vector2i(source.x,source.y)+offset,{})
			if not terrain.is_empty() and land_data is Dictionary and land_data.get(str(int(terrain.get("id",-1))),{}).get("name") == "wooden floor": levels.append(float(terrain.z))
		for level in levels:
			if level > top and level-top <= 1: cap_extensions[i] = (level-top)*float(world.get("elevationScale",0.2))

	for i in world.statics.size():
		var source: Dictionary = world.statics[i]
		if catalog.get(str(int(source.id)),{}).get("kind") != "corner": continue
		var directions: Array[Vector2i] = []
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			for neighbor in cells.get(Vector2i(source.x,source.y)+offset,[]):
				var other: Dictionary = world.statics[neighbor]
				var rule: Dictionary = catalog.get(str(int(other.id)),{})
				if rule.get("kind") not in ["wall","window","corner","door","arch"]: continue
				if absf(float(other.z)-float(source.z)) > 1: continue
				if rule.get("kind") != "corner" and (rule.get("axis") == "y") != (offset.y != 0): continue
				if not directions.has(offset): directions.append(offset)
		corners[i] = {"directions":directions}

func corner(height: float, plan: Dictionary, family: String) -> Node3D:
	var root := Node3D.new()
	var directions: Array = plan.get("directions",[])
	# Isolated/crop-edge corners keep a closed central pier; never speculate
	# across absent source cells or fill an intentional door/window opening.
	piece(root,Vector3(0.22,height,0.22),Vector3(0,height/2,0),family)
	for direction in directions:
		var size := Vector3(0.61,height,0.18) if direction.x != 0 else Vector3(0.18,height,0.61)
		piece(root,size,Vector3(direction.x*0.25,height/2,direction.y*0.25),family)
	piece(root,Vector3(0.14,height,0.14),Vector3(0,height/2,0),"wood" if family in ["wood","plaster"] else family)
	return root

func finish_run(cells: Array) -> void:
	if cells.is_empty(): return
	runs += 1
	for i in cells.size():
		plans[cells[i].ordinal] = {"run":runs,"length":cells.size(),"offset":i,"left_post":i == 0 or i % 3 == 0,"right_post":i == cells.size()-1}

func material(kind: String) -> ShaderMaterial:
	if not materials.has(kind):
		var m := ShaderMaterial.new()
		m.shader = preload("res://Presentation/Facade.gdshader")
		var family := "WoodTrim" if kind == "wood" else ("UnevenBrick" if kind == "brick" else ("RockTrim" if kind == "stone" else "Plaster"))
		m.set_shader_parameter("source_texture",load("res://Art/Quaternius/Village/T_"+family+"_BaseColor.png"))
		m.set_shader_parameter("surface_normal",load("res://Art/Quaternius/Village/T_"+family+"_Normal.png"))
		m.set_shader_parameter("palette",Color("5e4631") if kind == "wood" else (Color("aaa79c") if kind == "stone" else (Color("ad9276") if kind == "brick" else Color("ded2b7"))))
		m.set_shader_parameter("wood",kind == "wood")
		m.set_shader_parameter("masonry",kind in ["stone","brick"])
		preload("res://Presentation/SurfaceLibrary.gd").bind(m,"surface","brown_planks_03" if kind == "wood" else (("medieval_blocks_03" if kind=="stone" else "medieval_red_brick") if kind in ["stone","brick"] else "plastered_wall_02"))
		materials[kind] = m
	return materials[kind]

func piece(parent: Node3D, size: Vector3, at: Vector3, kind: String) -> void:
	if size.y <= 0.001: return
	var mesh := geometry.box(parent,size,at,"ffffff")
	mesh.material_override = material(kind)
	# Wall tops meet the upper floor at the same plane. Their pale cap faces
	# must not draw through that floor; lintels/sills retain their visible tops.
	if size.y > 0.6:
		if not capless_materials.has(kind):
			capless_materials[kind] = material(kind).duplicate()
			capless_materials[kind].set_shader_parameter("open_caps",true)
		mesh.material_override = capless_materials[kind]

func panel(height: float, window: bool, plan: Dictionary, family: String, frame: Node3D = null, masonry_opening: String = "") -> Node3D:
	var root := Node3D.new()
	var h := maxf(height,0.05)
	var sill := minf(1.05,h*0.28)
	var opening := minf(1.4,h*0.46)
	if window and h > 1.5 and masonry_opening in ["slit","arched"]:
		masonry_window(root,h,family,masonry_opening)
	elif window and h > 1.5:
		piece(root,Vector3(1,sill,0.18),Vector3(0,sill/2,0),family)
		piece(root,Vector3(1,h-sill-opening,0.18),Vector3(0,(h+sill+opening)/2,0),family)
		for x in [-0.43,0.43]: piece(root,Vector3(0.14,opening,0.18),Vector3(x,sill+opening/2,0),family)
		if frame:
			frame.position=Vector3(0,sill-.08,0)
			root.add_child(frame)
		else:
			for y in [sill,sill+opening]: piece(root,Vector3(0.82,0.09,0.27),Vector3(0,y,0),"wood")
			for x in [-0.33,0.33]: piece(root,Vector3(0.07,opening,0.24),Vector3(x,sill+opening/2,0),"wood")
			piece(root,Vector3(0.035,opening,0.11),Vector3(0,sill+opening/2,0),"wood")
			piece(root,Vector3(0.78,0.035,0.11),Vector3(0,sill+opening*0.58,0),"wood")
			piece(root,Vector3(0.98,0.10,0.40),Vector3(0,sill-0.03,0),"stone")
			if glass_material == null:
				glass_material = StandardMaterial3D.new()
				glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				glass_material.albedo_color = Color(0.48,0.62,0.64,0.19)
				glass_material.roughness = 0.18
				glass_material.metallic = 0.12
				glass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
			var glass := geometry.box(root,Vector3(0.74,opening-0.06,0.018),Vector3(0,sill+opening/2,0),"ffffff")
			glass.material_override = glass_material
	else:
		piece(root,Vector3(1.01,h,0.18),Vector3(0,h/2,0),family)
	if h > 0.6 and family in ["wood","plaster"]:
		piece(root,Vector3(1,0.22,0.22),Vector3(0,0.11,0),"stone")
		# Framing stands proud of the lime infill so it reads in raking light.
		for y in [0.3,h-0.08]: piece(root,Vector3(1,0.15,0.29),Vector3(0,y,0),"wood")
		if plan.get("left_post",true): piece(root,Vector3(0.15,h,0.30),Vector3(-0.43,h/2,0),"wood")
		if plan.get("right_post",false): piece(root,Vector3(0.15,h,0.30),Vector3(0.43,h/2,0),"wood")
	for side in [-1,1]:
		if not plan.get("extend_left" if side < 0 else "extend_right",false): continue
		piece(root,Vector3(0.51,h,0.18),Vector3(side*0.75,h/2,0),family)
		if h > 0.6 and family in ["wood","plaster"]:
			for y in [0.3,h-0.08]: piece(root,Vector3(0.51,0.15,0.29),Vector3(side*0.75,y,0),"wood")
	return root

# Source-art masonry openings: a barred arrow slit or a narrow leaded arch cut
# through the wall itself. No timber frame, plaster or glazed casement is added.
func masonry_window(root: Node3D, h: float, family: String, style: String) -> void:
	var width := 0.2 if style == "slit" else 0.46
	var sill := minf(1.1,h*0.3)
	var opening := minf(1.25 if style == "slit" else 1.5,h*0.45)
	var jamb := (1.0-width)/2
	piece(root,Vector3(1,sill,0.18),Vector3(0,sill/2,0),family)
	piece(root,Vector3(1,h-sill-opening,0.18),Vector3(0,(h+sill+opening)/2,0),family)
	for side in [-1,1]: piece(root,Vector3(jamb,opening,0.18),Vector3(side*(width+jamb)/2,sill+opening/2,0),family)
	# Stepped voussoirs close the head of an arched opening.
	if style == "arched":
		for side in [-1,1]: piece(root,Vector3(width*0.3,0.14,0.18),Vector3(side*width*0.35,sill+opening-0.07,0),family)
	piece(root,Vector3(width+0.16,0.07,0.26),Vector3(0,sill-0.035,0),family)
	if iron_material == null:
		iron_material = StandardMaterial3D.new()
		iron_material.albedo_color = Color("2f3130")
		iron_material.metallic = 0.3
		iron_material.roughness = 0.75
	var bars := [-width*0.22,width*0.22] if style == "slit" else [0.0]
	for x in bars:
		var bar := geometry.box(root,Vector3(0.025,opening,0.025),Vector3(x,sill+opening/2,0),"ffffff")
		bar.material_override = iron_material
	var rail := geometry.box(root,Vector3(width,0.025,0.025),Vector3(0,sill+opening*0.55,0),"ffffff")
	rail.material_override = iron_material

func audit() -> Dictionary:
	var branches := 0
	var unconnected: Array[int] = []
	for ordinal in corners:
		branches += corners[ordinal].directions.size()
		if corners[ordinal].directions.is_empty(): unconnected.append(ordinal)
	var implicit := 0
	var storeys := 0
	for plan in plans.values():
		implicit += int(plan.get("extend_left",false))+int(plan.get("extend_right",false))
		if float(plan.get("height_extension",0)) > 0: storeys += 1
	return {"corner_records":corners.size(),"joined_corner_branches":branches,"implicit_wall_joins":implicit,"diagonal_corner_joins":diagonal_joins,"ceiling_seams":cap_extensions.size(),"storey_seams":storeys,"unconnected_corner_ordinals":unconnected}
