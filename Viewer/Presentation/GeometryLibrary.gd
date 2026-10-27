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
		var hips: SurfaceTool = null
		var open_edges: Array = plan.get("gable_edges",plan.exposed)
		for edge in 4:
			if not open_edges[edge]: continue
			for segment in 2:
				var a: int = edges[edge][segment]
				var b: int = edges[edge][segment+1]
				var p := Vector3(float(a%3)*0.5-0.5,float(plan.heights[a])-float(s.z)*0.2,float(a/3)*0.5-0.5)
				var q := Vector3(float(b%3)*0.5-0.5,float(plan.heights[b])-float(s.z)*0.2,float(b/3)*0.5-0.5)
				beam(node,p,q,0.09,"65523f")
				# Horizontal eave segments meet the wall (or its interior cap); only
				# sloped verge segments close a gable down to the eave.
				if absf(p.y-q.y) < 0.02: continue
				if maxf(p.y,q.y)-bottom < 0.08: continue
				var target: SurfaceTool = gables
				if plan.get("hip_edges",[false,false,false,false])[edge]:
					if hips == null:
						hips = SurfaceTool.new()
						hips.begin(Mesh.PRIMITIVE_TRIANGLES)
						# Flat normals: both windings share positions.
						hips.set_smooth_group(0xFFFFFFFF)
					target = hips
				else: has_gables = true
				var quad := [p,Vector3(p.x,bottom,p.z),q,q,Vector3(p.x,bottom,p.z),Vector3(q.x,bottom,q.z)]
				# The roof shader draws back faces as ceiling boards; a hip closure
				# shows shingles from either side, so it carries both windings.
				if target == hips:
					var back := quad.duplicate()
					back.reverse()
					quad.append_array(back)
				for v in quad:
					target.set_uv(Vector2(v.x+v.z,v.y)+(Vector2(s.x,s.y) if target == hips else Vector2.ZERO))
					target.add_vertex(v)
		if hips != null:
			hips.generate_normals()
			hips.generate_tangents()
			var hip_mesh := MeshInstance3D.new()
			hip_mesh.mesh = hips.commit()
			hip_mesh.material_override = shader
			node.add_child(hip_mesh)
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

# Stable pseudo-random value in [0,1) per source cell and salt.
func _hash(s: Dictionary, salt: int) -> float:
	return float(absi(int(s.x)*73856093^int(s.y)*19349663^salt*83492791)%1000)/1000.0

# Floating pads: a few flat discs with a notch-free rim, varied per cell.
func lilypads(s: Dictionary) -> Node3D:
	var root := Node3D.new()
	for i in 3:
		var pad := cylinder(root,0.12+0.08*_hash(s,i),0.012,Vector3(_hash(s,i+7)-0.5,0.02,_hash(s,i+13)-0.5)*0.7,"3f6a2c" if i != 1 else "557a33")
		pad.rotation.y = _hash(s,i+21)*TAU
	if _hash(s,40) > 0.6: cylinder(root,0.035,0.05,Vector3(0.1,0.045,-0.08),"e9d6e6")
	return root

# Tapering rock cones for cave stalagmites (and flowstone columns).
func stalagmites(s: Dictionary, height: float) -> Node3D:
	var root := Node3D.new()
	for i in 3:
		var tall := height*(1.0 if i == 0 else 0.35+0.4*_hash(s,i))
		var cone := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.02
		shape.bottom_radius = 0.12+0.1*_hash(s,i+3)
		shape.height = tall
		shape.radial_segments = 7
		cone.mesh = shape
		cone.position = Vector3((_hash(s,i+5)-0.5)*0.5*float(i > 0),tall/2,(_hash(s,i+9)-0.5)*0.5*float(i > 0))
		cone.material_override = material("7d7264")
		root.add_child(cone)
	return root

# Clusters of hexagonal crystal prisms that glow faintly.
# Scattered: broken shards lying on the ground. Colour from the original art
# when known, else pale blue or violet.
func crystals(s: Dictionary, height: float, scattered := false, color := "") -> Node3D:
	var root := Node3D.new()
	var tint := Color(color).lightened(0.2) if not color.is_empty() else (Color("8fc6ff") if _hash(s,1) < 0.6 else Color("c79bff"))
	if not materials.has("crystal"+tint.to_html()):
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(tint,0.82)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = 0.15
		glass.metallic_specular = 0.9
		glass.emission_enabled = true
		glass.emission = tint
		glass.emission_energy_multiplier = 0.6
		materials["crystal"+tint.to_html()] = glass
	for i in (9 if scattered else 5):
		var tall := minf(height,1.2)*(0.45+0.55*_hash(s,i+2))
		if scattered: tall = 0.08+0.08*_hash(s,i+2)
		var prism := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.015
		shape.bottom_radius = 0.05+0.04*_hash(s,i+4)
		shape.height = tall
		shape.radial_segments = 6
		shape.rings = 1
		prism.mesh = shape
		prism.position = Vector3((_hash(s,i+6)-0.5)*(0.8 if scattered else 0.4),0.03 if scattered else tall*0.45,(_hash(s,i+8)-0.5)*(0.8 if scattered else 0.4))
		prism.rotation = Vector3(PI/2,_hash(s,i+10)*TAU,0) if scattered else Vector3((_hash(s,i+10)-0.5)*0.7,0,(_hash(s,i+12)-0.5)*0.7)
		prism.material_override = materials["crystal"+tint.to_html()]
		root.add_child(prism)
	return root

# Columnar cactus: a ribbed trunk with one or two upturned arms.
func cactus(s: Dictionary, height: float) -> Node3D:
	var root := Node3D.new()
	var green := "5d7a3a"
	cylinder(root,0.13,height,Vector3(0,height/2,0),green)
	cylinder(root,0.12,0.02,Vector3(0,height,0),"6f8c48")
	for side in ([-1,1] if _hash(s,3) > 0.4 else [1]):
		var at := height*(0.35+0.2*_hash(s,side+5))
		var reach := 0.22+0.06*_hash(s,side+9)
		var arm := cylinder(root,0.08,reach,Vector3(side*(0.13+reach/2),at,0),green)
		arm.rotation.z = PI/2
		var up := height*(0.25+0.15*_hash(s,side+11))
		cylinder(root,0.08,up,Vector3(side*(0.13+reach),at+up/2,0),green)
	root.rotation.y = _hash(s,17)*TAU
	return root

# Fallen leaf litter: small flat flakes scattered over the cell.
func litter(s: Dictionary, color: String) -> Node3D:
	var root := Node3D.new()
	for i in 10:
		var flake := box(root,Vector3(0.09,0.006,0.06),Vector3((_hash(s,i)-0.5)*0.9,0.004,(_hash(s,i+20)-0.5)*0.9),color)
		flake.rotation.y = _hash(s,i+40)*TAU
	return root

# Palisade: a row of sharpened stakes along the cell's x axis.
func palisade(s: Dictionary, height: float, wood: Material) -> Node3D:
	var root := Node3D.new()
	for i in 4:
		var x := -0.375+i*0.25
		var tall := height*(0.92+0.08*_hash(s,i))
		var stake := cylinder(root,0.12,tall-0.25,Vector3(x,(tall-0.25)/2,0),"6b5139")
		stake.material_override = wood
		var tip := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.12
		cone.height = 0.25
		cone.radial_segments = 8
		tip.mesh = cone
		tip.position = Vector3(x,tall-0.125,0)
		tip.material_override = wood
		root.add_child(tip)
	return root
