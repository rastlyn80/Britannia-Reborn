extends RefCounted

var materials := {}
var timber_materials := {}

func material(color: String) -> StandardMaterial3D:
	if not materials.has(color):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(color)
		mat.roughness = 0.9
		materials[color] = mat
	return materials[color]

func box(parent: Node3D, size: Vector3, at: Vector3, color: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material(color)
	parent.add_child(mesh)
	return mesh

func cylinder(parent: Node3D, radius: float, height: float, at: Vector3, color: String) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	shape.radial_segments = 10
	mesh.mesh = shape
	mesh.position = at
	mesh.material_override = material(color)
	parent.add_child(mesh)
	return mesh

func stairs(height: float, rise: Vector2) -> Node3D:
	var node := Node3D.new()
	var steps := maxi(2,int(ceil(height/0.22)))
	for i in steps:
		var h := height*float(i+1)/steps
		box(node,Vector3(1,h,1.0/steps+0.005),Vector3(0,h/2,-0.5+(i+0.5)/steps),"796447")
	node.rotation.y = atan2(rise.x,rise.y)
	return node

func painting() -> Node3D:
	var node := Node3D.new()
	box(node,Vector3(0.65,0.8,0.06),Vector3(0,1.4,0),"674c2c")
	box(node,Vector3(0.53,0.67,0.02),Vector3(0,1.4,-0.04),"6e8e9b")
	box(node,Vector3(0.51,0.23,0.025),Vector3(0,1.2,-0.055),"4c6a42")
	return node

func sign() -> Node3D:
	var node := Node3D.new()
	box(node,Vector3(0.08,0.08,0.85),Vector3(0,0.8,0),"303b40")
	box(node,Vector3(0.07,0.7,0.07),Vector3(0,0.5,-0.35),"303b40")
	var ring := cylinder(node,0.05,0.35,Vector3(0,0.4,0.18),"303b40")
	ring.rotation_degrees.x = 25
	return node

const CARPET_LIFT := 0.025

func carpet(s: Dictionary) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1,1)
	mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Presentation/Carpet.gdshader")
	mat.set_shader_parameter("base_color",Color("243f61") if s.id <= 2777 else Color("77502d"))
	mesh.material_override = mat
	mesh.position.y = CARPET_LIFT
	return mesh

static func roof_height(u: float, v: float, rule: Dictionary) -> float:
	if rule.get("profile","")=="flat":return 0.0
	var rise: Array = rule.get("rise",[0,0])
	if int(rise[0]) != 0: return (u if int(rise[0]) > 0 else 1.0-u)*0.6
	if int(rise[1]) != 0: return (v if int(rise[1]) > 0 else 1.0-v)*0.6
	return (1.0-abs((v if rule.get("ridgeAxis","x") == "x" else u)-0.5)*2.0)*0.28

func roof(s: Dictionary, rule: Dictionary, shader: ShaderMaterial, plan: Dictionary = {}, gable_material: Material = null) -> Node3D:
	var node := Node3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Midpoints preserve ridge peaks; exact boundary samples join adjacent tiles.
	for y in 2:
		for x in 2:
			var points := [Vector2(x,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1)]
			for index in [0,2,1,2,3,1]:
				var uv: Vector2 = points[index]*0.5
				surface.set_uv(Vector2(s.x,s.y)+uv)
				if plan.has("normals"):surface.set_normal(plan.normals[int(uv.y*2)*3+int(uv.x*2)])
				surface.add_vertex(Vector3(uv.x-0.5,(float(plan.heights[int(uv.y*2)*3+int(uv.x*2)])-float(s.z)*0.2 if not plan.is_empty() else roof_height(uv.x,uv.y,rule)),uv.y-0.5))
	if not plan.has("normals"):surface.generate_normals()
	surface.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = shader
	node.add_child(mesh)
	if not plan.is_empty() and not plan.get("boundary_fragment",false):
		var edges := [[0,1,2],[2,5,8],[8,7,6],[6,3,0]]
		var bottom := float(plan.eave)-float(s.z)*0.2
		var gables := SurfaceTool.new()
		gables.begin(Mesh.PRIMITIVE_TRIANGLES)
		var has_gables := false
		for edge in 4:
			if not plan.exposed[edge]: continue
			for segment in 2:
				var a: int = edges[edge][segment]
				var b: int = edges[edge][segment+1]
				var p := Vector3(float(a%3)*0.5-0.5,float(plan.heights[a])-float(s.z)*0.2,float(a/3)*0.5-0.5)
				var q := Vector3(float(b%3)*0.5-0.5,float(plan.heights[b])-float(s.z)*0.2,float(b/3)*0.5-0.5)
				beam(node,p,q,0.09,"65523f")
				if maxf(p.y,q.y)-bottom < 0.08: continue
				has_gables = true
				for v in [p,Vector3(p.x,bottom,p.z),q,q,Vector3(p.x,bottom,p.z),Vector3(q.x,bottom,q.z)]:
					gables.set_uv(Vector2(v.x+v.z,v.y))
					gables.add_vertex(v)
		if has_gables:
			gables.generate_normals()
			gables.generate_tangents()
			var ends := MeshInstance3D.new()
			ends.mesh = gables.commit()
			ends.material_override = gable_material if gable_material != null else material("baa887")
			node.add_child(ends)
		if rule.get("rise",[0,0]) == [0,0]:
			var center := float(plan.heights[4])-float(s.z)*0.2+0.025
			if rule.get("ridgeAxis","x") == "x": beam(node,Vector3(-0.5,center,0),Vector3(0.5,center,0),0.085,"626260")
			else: beam(node,Vector3(0,center,-0.5),Vector3(0,center,0.5),0.085,"626260")
	# Interior rafters follow the same joined roof samples; no free-floating infill.
	if not plan.is_empty() and not plan.get("boundary_fragment",false):
		var rise: Array = rule.get("rise",[0,0])
		var along_x: bool = int(rise[0]) != 0 or (rise == [0,0] and rule.get("ridgeAxis","x") == "y")
		var line := int(s.y) if along_x else int(s.x)
		if posmod(line,3) == 0:
			var indices := [3,4,5] if along_x else [1,4,7]
			for segment in 2:
				var a: int = indices[segment]
				var b: int = indices[segment+1]
				var p := Vector3(float(a%3)*0.5-0.5,float(plan.heights[a])-float(s.z)*0.2-0.11,float(a/3)*0.5-0.5)
				var q := Vector3(float(b%3)*0.5-0.5,float(plan.heights[b])-float(s.z)*0.2-0.11,float(b/3)*0.5-0.5)
				beam(node,p,q,0.12,"59452e")
	return node

func beam(parent: Node3D, a: Vector3, b: Vector3, thickness: float, color: String) -> void:
	if a.distance_to(b) < 0.001: return
	var mesh := box(parent,Vector3(thickness,thickness,a.distance_to(b)),(a+b)/2,color)
	mesh.look_at_from_position((a+b)/2,b,Vector3.UP)

# One continuous infill replaces stacked isometric wedge records.
func gable(width: float, height: float, plaster: Material) -> Node3D:
	var node := Node3D.new()
	var mesh := MeshInstance3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for back in [false,true]:
		var points := [Vector3(-width/2,0,0),Vector3(0,height,0),Vector3(width/2,0,0)]
		if back: points.reverse()
		for point in points:
			surface.set_uv(Vector2(point.x,point.y))
			surface.add_vertex(point+Vector3(0,0,0.06 if back else -0.06))
	surface.generate_normals()
	mesh.mesh = surface.commit()
	mesh.material_override = plaster
	node.add_child(mesh)
	return node

# Procedural furniture top heights; support contact uses the same values.
static func furniture_height(kind: String) -> float:
	return 0.5 if kind == "bench" else (1.0 if kind == "counter" else 0.82)

func furniture(size: Vector2, kind: String) -> Node3D:
	var node := Node3D.new()
	var height := furniture_height(kind)
	crafted_box(node,Vector3(size.x-0.06,0.12,size.y-0.06),Vector3(0,height-0.06,0),"a17b4e")
	var count_x := maxi(2,int(ceil(size.x/1.5))+1)
	var count_y := maxi(2,int(ceil(size.y/1.5))+1)
	for x in count_x:
		for y in count_y:
			var at := Vector3(lerpf(-size.x/2+0.13,size.x/2-0.13,float(x)/(count_x-1)),(height-0.12)/2,lerpf(-size.y/2+0.13,size.y/2-0.13,float(y)/(count_y-1)))
			crafted_box(node,Vector3(0.12,height-0.12,0.12),at,"73563b")
	if kind == "counter": crafted_box(node,Vector3(size.x-0.12,height-0.15,0.1),Vector3(0,(height-0.15)/2,size.y/2-0.1),"6b4c31")
	return node

# Small chamfers catch light without relying on oversized texture highlights.
func crafted_box(parent: Node3D, size: Vector3, at: Vector3, color: String) -> MeshInstance3D:
	var half := size/2
	var bevel := minf(0.022,minf(size.x,minf(size.y,size.z))*0.16)
	var inner := half-Vector3.ONE*bevel
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for axis in 3:
		var b := (axis+1)%3
		var c := (axis+2)%3
		for sign_value in [-1.0,1.0]:
			var normal := Vector3.ZERO
			normal[axis] = sign_value
			var points: Array[Vector3] = []
			for pair in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]:
				var point := Vector3.ZERO
				point[axis] = half[axis]*sign_value
				point[b] = inner[b]*pair.x
				point[c] = inner[c]*pair.y
				points.append(point)
			_face(surface,points,normal)
	for axis_a in 3:
		for axis_b in range(axis_a+1,3):
			var along := 3-axis_a-axis_b
			for sign_a in [-1.0,1.0]:
				for sign_b in [-1.0,1.0]:
					var points: Array[Vector3] = []
					for pair in [Vector2(-1,0),Vector2(1,0),Vector2(1,1),Vector2(-1,1)]:
						var point := Vector3.ZERO
						point[along] = inner[along]*pair.x
						point[axis_a] = (half[axis_a] if pair.y == 0 else inner[axis_a])*sign_a
						point[axis_b] = (inner[axis_b] if pair.y == 0 else half[axis_b])*sign_b
						points.append(point)
					var normal := Vector3.ZERO
					normal[axis_a] = sign_a
					normal[axis_b] = sign_b
					_face(surface,points,normal.normalized())
	for x in [-1.0,1.0]:
		for y in [-1.0,1.0]:
			for z in [-1.0,1.0]:
				var direction := Vector3(x,y,z)
				var points: Array[Vector3] = []
				for axis in 3:
					var point := inner*direction
					point[axis] = half[axis]*direction[axis]
					points.append(point)
				_face(surface,points,direction.normalized())
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	if not timber_materials.has(color):
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://Presentation/Timber.gdshader")
		mat.set_shader_parameter("tint",Color(color))
		preload("res://Presentation/SurfaceLibrary.gd").bind(mat,"surface","brown_planks_03")
		timber_materials[color] = mat
	mesh.material_override = timber_materials[color]
	mesh.position = at
	parent.add_child(mesh)
	return mesh

func _face(surface: SurfaceTool, points: Array[Vector3], normal: Vector3) -> void:
	if (points[1]-points[0]).cross(points[2]-points[0]).dot(normal) < 0: points.reverse()
	var indices := [0,1,2] if points.size() == 3 else [0,1,2,0,2,3]
	for index in indices:
		surface.set_normal(normal)
		surface.add_vertex(points[index])
