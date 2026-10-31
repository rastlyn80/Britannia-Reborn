extends RefCounted

var chunks := {}
var triangles := 0
var trunks: Array[Vector3] = []
# Detailed solids (scanned props, carved architecture) collide as an oriented
# box around their shape: client collision only serves the camera and mouse
# picking (movement is the server's and the tile data's), and per-triangle
# collision of every model was most of a district's size
# (docs/COMPACT_STREAMING.md).
const EXACT_TRIANGLE_LIMIT := 300
# Everything more detailed than a box collides as its box (walls with carved
# frames, roofs, furniture); only pieces the camera passes through or climbs
# keep their triangles, up to EXACT_TRIANGLE_LIMIT.
const BOX_TRIANGLE_LIMIT := 12
const EXACT_KINDS := ["arch","door","stairs","landing","bridge","fence"]
var boxes: Array = []   # [Transform3D, Vector3 size]

func add_visual(node: Node3D) -> void:
	if node.get_meta("kind","") == "tree" and node.get_child_count() > 0: trunks.append(node.position)
	if not bool(node.get_meta("solid",false)): return
	var key := Vector2i(int(floor(node.position.x/16)),int(floor(node.position.z/16)))
	var faces := PackedVector3Array()
	_collect(node,Transform3D.IDENTITY,faces)
	if faces.size()/3 > (EXACT_TRIANGLE_LIMIT if str(node.get_meta("kind","")) in EXACT_KINDS else BOX_TRIANGLE_LIMIT):
		# Bounds in the node's own frame, so the box turns with it.
		var inverse := node.transform.affine_inverse()
		var box := AABB(inverse*faces[0],Vector3.ZERO)
		for vertex in faces: box = box.expand(inverse*vertex)
		if box.size.length() > 0.01:
			boxes.append([node.transform*Transform3D(Basis.IDENTITY,box.get_center()),box.size.max(Vector3.ONE*0.05)])
			return
	if not chunks.has(key): chunks[key] = PackedVector3Array()
	var combined: PackedVector3Array = chunks[key]
	combined.append_array(faces)
	chunks[key] = combined

func _collect(node: Node3D, parent: Transform3D, output: PackedVector3Array) -> void:
	var transform := parent*node.transform
	if node is MeshInstance3D:
		var faces: PackedVector3Array = node.mesh.get_faces()
		for vertex in faces: output.append(transform*vertex)
	for child in node.get_children():
		# Window shutters and flower boxes are decoration, not walls to bump into.
		if child is Node3D and child.get_meta("kind","") != "dressing": _collect(child,transform,output)

func finish(parent: Node3D, terrain: MeshInstance3D) -> void:
	for at in trunks:
		var body := StaticBody3D.new()
		body.collision_layer = 2
		body.collision_mask = 0
		body.position = at+Vector3.UP*1.5
		var collider := CollisionShape3D.new()
		var trunk := CylinderShape3D.new()
		trunk.radius = 0.18
		trunk.height = 3.0
		collider.shape = trunk
		body.add_child(collider)
		parent.add_child(body)
	for entry in boxes:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = entry[0]
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = entry[1]
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body)
		triangles += 12
	_terrain_heightmap(parent,terrain)
	for key in chunks:
		var faces: PackedVector3Array = chunks[key]
		if faces.is_empty(): continue
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.name = "SolidChunk_%d_%d" % [key.x,key.y]
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		parent.add_child(body)
		triangles += faces.size()/3

# Ground collision as a heightmap of the terrain's heights at each whole-tile
# corner (65 x 65 per district, about 17 KB) rather than the subdivided
# render triangles stored again as collision (tens of thousands per district).
func _terrain_heightmap(parent: Node3D, terrain: MeshInstance3D) -> void:
	var heights := {}
	var low := Vector2i(1 << 30,1 << 30)
	var high := Vector2i(-(1 << 30),-(1 << 30))
	for vertex in terrain.mesh.get_faces():
		var at: Vector3 = terrain.transform*vertex
		var corner := Vector2i(roundi(at.x),roundi(at.z))
		if absf(at.x-corner.x) > 0.01 or absf(at.z-corner.y) > 0.01: continue
		heights[corner] = maxf(float(heights.get(corner,-1e9)),at.y)
		low = low.min(corner)
		high = high.max(corner)
	if heights.is_empty(): return
	var width := high.x-low.x+1
	var depth := high.y-low.y+1
	var data := PackedFloat32Array()
	data.resize(width*depth)
	var last := 0.0
	for z in depth:
		for x in width:
			var key := Vector2i(low.x+x,low.y+z)
			if heights.has(key): last = heights[key]
			data[z*width+x] = last
	var shape := HeightMapShape3D.new()
	shape.map_width = width
	shape.map_depth = depth
	shape.map_data = data
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.name = "TerrainHeights"
	# A heightmap is centred on its node.
	body.position = Vector3(low.x+(width-1)/2.0,0,low.y+(depth-1)/2.0)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
	triangles += (width-1)*(depth-1)*2
