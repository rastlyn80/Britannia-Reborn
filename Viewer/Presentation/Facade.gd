extends RefCounted

# Author panels in metres rather than squeezing a whole kit façade into every
# one-metre source cell. Runs share structural rhythm, source openings stay put.
var geometry := preload("res://Presentation/GeometryLibrary.gd").new()
var materials := {}
var plans := {}
var runs := 0

func index(world: Dictionary, catalog: Dictionary) -> void:
	plans.clear()
	runs = 0
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
		m.set_shader_parameter("palette",Color("796044") if kind == "wood" else (Color("aaa79c") if kind == "stone" else (Color("ad9276") if kind == "brick" else Color("ded2b7"))))
		m.set_shader_parameter("wood",kind == "wood")
		materials[kind] = m
	return materials[kind]

func piece(parent: Node3D, size: Vector3, at: Vector3, kind: String) -> void:
	if size.y <= 0.001: return
	var mesh := geometry.box(parent,size,at,"ffffff")
	mesh.material_override = material(kind)

func panel(height: float, window: bool, plan: Dictionary, family: String) -> Node3D:
	var root := Node3D.new()
	var h := maxf(height,0.05)
	var sill := minf(1.05,h*0.28)
	var opening := minf(1.4,h*0.46)
	if window and h > 1.5:
		piece(root,Vector3(1,sill,0.18),Vector3(0,sill/2,0),family)
		piece(root,Vector3(1,h-sill-opening,0.18),Vector3(0,(h+sill+opening)/2,0),family)
		for x in [-0.43,0.43]: piece(root,Vector3(0.14,opening,0.18),Vector3(x,sill+opening/2,0),family)
		for y in [sill,sill+opening]: piece(root,Vector3(0.82,0.09,0.27),Vector3(0,y,0),"wood")
		for x in [-0.33,0.33]: piece(root,Vector3(0.07,opening,0.24),Vector3(x,sill+opening/2,0),"wood")
		piece(root,Vector3(0.035,opening,0.11),Vector3(0,sill+opening/2,0),"wood")
		piece(root,Vector3(0.78,0.035,0.11),Vector3(0,sill+opening*0.58,0),"wood")
	else:
		piece(root,Vector3(1,h,0.18),Vector3(0,h/2,0),family)
	if h > 0.6:
		piece(root,Vector3(1,0.22,0.22),Vector3(0,0.11,0),"stone")
		for y in [0.3,h-0.08]: piece(root,Vector3(1,0.13,0.23),Vector3(0,y,0),"wood")
		if plan.get("left_post",true): piece(root,Vector3(0.12,h,0.24),Vector3(-0.44,h/2,0),"wood")
		if plan.get("right_post",false): piece(root,Vector3(0.12,h,0.24),Vector3(0.44,h/2,0),"wood")
	return root
