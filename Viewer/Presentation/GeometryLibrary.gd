extends RefCounted

var materials := {}

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

func carpet(s: Dictionary) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1,1)
	mesh.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://Presentation/Carpet.gdshader")
	mat.set_shader_parameter("base_color",Color("243f61") if s.id <= 2777 else Color("77502d"))
	mesh.material_override = mat
	mesh.position.y = 0.025
	return mesh

static func roof_height(u: float, v: float, rule: Dictionary) -> float:
	var rise: Array = rule.get("rise",[0,0])
	if int(rise[0]) != 0: return (u if int(rise[0]) > 0 else 1.0-u)*0.6
	if int(rise[1]) != 0: return (v if int(rise[1]) > 0 else 1.0-v)*0.6
	return (1.0-abs((v if rule.get("ridgeAxis","x") == "x" else u)-0.5)*2.0)*0.28

func roof(s: Dictionary, rule: Dictionary, shader: ShaderMaterial) -> Node3D:
	var node := Node3D.new()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Midpoints preserve ridge peaks; exact boundary samples join adjacent tiles.
	for y in 2:
		for x in 2:
			var points := [Vector2(x,y),Vector2(x,y+1),Vector2(x+1,y),Vector2(x+1,y+1)]
			for index in [0,1,2,2,1,3]:
				var uv: Vector2 = points[index]*0.5
				surface.set_uv(Vector2(s.x,s.y)+uv)
				surface.add_vertex(Vector3(uv.x-0.5,roof_height(uv.x,uv.y,rule),uv.y-0.5))
	surface.generate_normals()
	surface.generate_tangents()
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = shader
	node.add_child(mesh)
	return node
