extends "res://Presentation/SourceMountContact.gd"
## The Fan Dancer import retains eight influence slots.

const SLOTS := 8


func configure(mesh: MeshInstance3D, _quadruped: bool) -> void:
	surface = mesh
	arrays = mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	assert(bindings.size() == vertices.size() * SLOTS and weights.size() == bindings.size())
	var rig := get_skeleton()
	var joints: Array[int] = []
	for index in mesh.skin.get_bind_count():
		var joint := mesh.skin.get_bind_bone(index)
		joints.append(joint if joint >= 0 else rig.find_bone(mesh.skin.get_bind_name(index)))
	for side: String in ["l", "r"]:
		var thigh := bone(side + " thigh")
		var calf := bone(side + " calf")
		var foot := bone(side + " foot")
		assert(mini(thigh, mini(calf, foot)) >= 0)
		var sole_joints := {foot: true}
		for joint in rig.get_bone_count():
			var parent := joint
			while parent >= 0 and parent != foot:
				parent = rig.get_bone_parent(parent)
			if parent == foot:
				sole_joints[joint] = true
		var selected: Array[int] = []
		var seen := {}
		for vertex in vertices.size():
			var score := 0.0
			for slot in SLOTS:
				var index := vertex * SLOTS + slot
				if sole_joints.has(joints[bindings[index]]):
					score += weights[index]
			if score > 0.6 and not seen.has(vertices[vertex]):
				selected.append(vertex)
				seen[vertices[vertex]] = true
		assert(not selected.is_empty())
		feet.append({"a": thigh, "b": calf, "c": foot, "end": foot, "vertices": selected})


func sole(record: Dictionary) -> Vector3:
	var rig := get_skeleton()
	var matrices: Array[Transform3D] = []
	for index in surface.skin.get_bind_count():
		var joint := surface.skin.get_bind_bone(index)
		if joint < 0:
			joint = rig.find_bone(surface.skin.get_bind_name(index))
		matrices.append(rig.get_bone_global_pose(joint) * surface.skin.get_bind_pose(index))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var lowest := Vector3(0.0, INF, 0.0)
	for vertex: int in record.vertices:
		var point := Vector3.ZERO
		for slot in SLOTS:
			var index := vertex * SLOTS + slot
			point += (matrices[bindings[index]] * vertices[vertex]) * weights[index]
		point = rig.to_global(point)
		if point.y < lowest.y:
			lowest = point
	return lowest
