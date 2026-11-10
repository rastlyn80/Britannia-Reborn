# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Palm := .11
var shaft: Vector2
var rig: Skeleton3D
var vertices: PackedVector3Array
var joints: PackedInt32Array
var weights: PackedFloat32Array
var indices: PackedInt32Array
var bones := PackedInt32Array()
var binds: Array[Transform3D] = []
var stride: int
var deformed := PackedVector3Array()
var bounds: Array[AABB] = []


func _init(body: MeshInstance3D, skeleton: Skeleton3D) -> void:
	rig = skeleton
	assert(body.mesh.get_surface_count() == 1)
	var arrays := body.mesh.surface_get_arrays(0)
	vertices = arrays[Mesh.ARRAY_VERTEX]
	joints = arrays[Mesh.ARRAY_BONES]
	weights = arrays[Mesh.ARRAY_WEIGHTS]
	indices = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for vertex in vertices.size():
			indices.append(vertex)
	stride = joints.size() / vertices.size()
	for slot in body.skin.get_bind_count():
		var bone := body.skin.get_bind_bone(slot)
		if bone < 0:
			bone = rig.find_bone(body.skin.get_bind_name(slot))
		assert(bone >= 0)
		bones.append(bone)
		binds.append(body.skin.get_bind_pose(slot))
	deformed.resize(vertices.size())
	bounds.resize(indices.size() / 3)


func update_pose() -> void:
	var transforms: Array[Transform3D] = []
	for slot in bones.size():
		transforms.append(rig.global_transform * rig.get_bone_global_pose(bones[slot]) * binds[slot])
	for vertex in vertices.size():
		var point := Vector3.ZERO
		for slot in stride:
			var influence := vertex * stride + slot
			if weights[influence] > 0.0:
				point += (transforms[joints[influence]] * vertices[vertex]) * weights[influence]
		deformed[vertex] = point
	for triangle in bounds.size():
		var corner := triangle * 3
		bounds[triangle] = AABB(deformed[indices[corner]], Vector3.ZERO).expand(
			deformed[indices[corner + 1]]).expand(deformed[indices[corner + 2]])


func crosses_sceptre(pose: Transform3D, margin: float) -> bool:
	var offsets := [Vector3.ZERO, pose.basis.x * margin, -pose.basis.x * margin,
		pose.basis.z * margin, -pose.basis.z * margin]
	for section: Vector2 in [Vector2(shaft.x, -Palm), Vector2(Palm, shaft.y)]:
		var start := pose * Vector3(0.0, section.x, 0.0)
		var finish := pose * Vector3(0.0, section.y, 0.0)
		var limits := AABB(start, Vector3.ZERO).expand(finish).grow(margin * 2.0 + .0001)
		for triangle in bounds.size():
			if not limits.intersects(bounds[triangle]):
				continue
			var index := triangle * 3
			for offset: Vector3 in offsets:
				if Geometry3D.segment_intersects_triangle(start + offset, finish + offset,
						deformed[indices[index]], deformed[indices[index + 1]], deformed[indices[index + 2]]) != null:
					return true
	return false
