extends RefCounted

var chunks := {}
var triangles := 0

func add_visual(node: Node3D) -> void:
	if not bool(node.get_meta("solid",false)): return
	var key := Vector2i(int(floor(node.position.x/16)),int(floor(node.position.z/16)))
	var faces := PackedVector3Array()
	_collect(node,Transform3D.IDENTITY,faces)
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
		if child is Node3D: _collect(child,transform,output)

func finish(parent: Node3D, terrain: MeshInstance3D) -> void:
	var terrain_faces := PackedVector3Array()
	for vertex in terrain.mesh.get_faces(): terrain_faces.append(terrain.transform*vertex)
	chunks[Vector2i(-1,-1)] = terrain_faces
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
