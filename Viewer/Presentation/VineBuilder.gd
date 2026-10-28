extends RefCounted
# Climbing vines (UO "vines", "decorative vines", "morning glories") built as
# twisting woody stems in photoscanned bark (CC0 Poly Haven dead_tree_trunk)
# climbing the wall face behind the tile, with clusters of photoscanned ivy
# leaves (Objaverse ivy_hanging, CC-BY) on the leafy graphics. The bare-stem
# graphics of the original stay bare. Built in local space: the wall is the
# tile's back edge (-Z), the vine climbs from the ground.
const LEAFY := [3307,3308,3309,3310,3311,3312,3313,3314,3166,3167,3168,11513,11514,11515,11516,3380]
static var bark: StandardMaterial3D

static func handles(name: String) -> bool:
	return name.to_lower() in ["vines","decorative vines","morning glories"]

static func _bark() -> StandardMaterial3D:
	if bark == null:
		bark = StandardMaterial3D.new()
		bark.albedo_texture = load("res://Art/PolyHaven/dead_tree_trunk/textures/dead_tree_trunk_diff_1k.jpg")
		bark.normal_enabled = true
		bark.normal_texture = load("res://Art/PolyHaven/dead_tree_trunk/textures/dead_tree_trunk_nor_gl_1k.jpg")
		bark.roughness = 0.9
		bark.uv1_triplanar = true
		bark.uv1_scale = Vector3.ONE*3.0
	return bark

# A tube along a polyline (few sides; a vine is thin).
static func _tube(points: PackedVector3Array, radius: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 5
	for i in points.size()-1:
		var a := points[i]
		var b := points[i+1]
		var axis := (b-a).normalized()
		var side := axis.cross(Vector3.FORWARD if absf(axis.z) < 0.9 else Vector3.RIGHT).normalized()
		var up := axis.cross(side).normalized()
		var ra := radius*(1.0-0.5*float(i)/points.size())
		var rb := radius*(1.0-0.5*float(i+1)/points.size())
		for k in sides:
			var t0 := TAU*k/sides
			var t1 := TAU*(k+1)/sides
			var p0 := a+(side*cos(t0)+up*sin(t0))*ra
			var p1 := a+(side*cos(t1)+up*sin(t1))*ra
			var q0 := b+(side*cos(t0)+up*sin(t0))*rb
			var q1 := b+(side*cos(t1)+up*sin(t1))*rb
			for v in [p0,q0,p1,p1,q0,q1]: st.add_vertex(v)
	st.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh = st.commit()
	mesh.material_override = _bark()
	return mesh

static func build(name: String, id: int, height: float, seed: int, reconstruction: RefCounted) -> Node3D:
	var root := Node3D.new()
	root.set_meta("model","vine")
	var random := RandomNumberGenerator.new()
	random.seed = hash([id,seed])
	var top := clampf(height,1.2,3.4) if height > 0.5 else random.randf_range(1.6,2.8)
	var leafy := id in LEAFY or name.to_lower() != "vines"
	var stems := 2 if leafy else random.randi_range(1,2)
	for s in stems:
		var points := PackedVector3Array()
		var x := random.randf_range(-0.3,0.3)
		var steps := 9
		for i in steps+1:
			var y := top*float(i)/steps
			x += random.randf_range(-0.12,0.12)
			points.append(Vector3(clampf(x,-0.45,0.45),y,-0.46+random.randf_range(0.0,0.03)))
		root.add_child(_tube(points,0.022 if s == 0 else 0.015))
		# Side shoots.
		for b in 2:
			var from := points[random.randi_range(2,steps-1)]
			var dir := Vector3(random.randf_range(-0.35,0.35),random.randf_range(0.15,0.35),0.0)
			root.add_child(_tube(PackedVector3Array([from,from+dir*0.6,from+dir+Vector3(random.randf_range(-0.1,0.1),0.05,0)]),0.01))
		if leafy:
			# Small leaf sprigs along the upper stem, flat against the wall.
			for k in 4:
				var leaves: Node3D = preload("res://Presentation/PropReplacements.gd").build(reconstruction,"__vine leaves",seed+s*7+k)
				if leaves == null: break
				var at := points[clampi(3+k*2,0,steps)]
				leaves.position = Vector3(at.x,at.y-0.25,-0.47)
				leaves.scale = Vector3(0.28,random.randf_range(0.3,0.45),0.15)
				leaves.rotation.z = random.randf_range(-0.9,0.9)
				root.add_child(leaves)
	return root
