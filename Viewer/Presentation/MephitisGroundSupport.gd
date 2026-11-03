extends "res://Presentation/SourceMountContact.gd"

const LEG_ROOTS := [4, 8, 12, 16, 20, 24, 28, 32]


func configure(mesh: MeshInstance3D, _quadruped: bool) -> void:
	surface = mesh
	arrays = mesh.mesh.surface_get_arrays(0)
	feet.clear()
	var rig := get_skeleton()
	var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	assert(bindings.size() == positions.size() * 4)
	var bind_bones := PackedInt32Array()
	for bind in mesh.skin.get_bind_count():
		var joint := mesh.skin.get_bind_bone(bind)
		if joint < 0:
			joint = rig.find_bone(mesh.skin.get_bind_name(bind))
		bind_bones.append(joint)
	for start: int in LEG_ROOTS:
		var base := rig.find_bone("bone%02d" % start)
		var middle := rig.find_bone("bone%02d" % (start + 1))
		var tip := rig.find_bone("bone%02d" % (start + 2))
		assert(mini(base, mini(middle, tip)) >= 0)
		assert(rig.get_bone_parent(middle) == base and rig.get_bone_parent(tip) == middle)
		var vertices: Array[int] = []
		var seen := {}
		for vertex in positions.size():
			var weight := 0.0
			for influence in 4:
				var index := vertex * 4 + influence
				if bind_bones[bindings[index]] == tip:
					weight += weights[index]
			if weight > 0.6 and not seen.has(positions[vertex]):
				seen[positions[vertex]] = true
				vertices.append(vertex)
		assert(not vertices.is_empty(), "Mephitis leg is missing weighted tip vertices")
		feet.append({"a": base, "b": middle, "c": tip, "end": tip, "vertices": vertices})
