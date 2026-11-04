extends RefCounted
## Test the shaft and blade centerlines against the posed body outside the grasp.

const SEGMENTS := [
	[Vector3(0, -0.38, 0), Vector3(0, -0.14, 0)],
	[Vector3(0, 0.14, 0), Vector3(0, 0.98, 0)],
	[Vector3(0, 0.69, 0.07), Vector3(0, 0.97, 0.07)],
]

var mesh: MeshInstance3D
var rig: Skeleton3D
var positions: PackedVector3Array
var joints: PackedInt32Array
var weights: PackedFloat32Array
var indices: PackedInt32Array
var bones: Array[int] = []
var binds: Array[Transform3D] = []
var stride: int
var deformed := PackedVector3Array()
var bounds: Array[AABB] = []

func _init(body: MeshInstance3D, skeleton: Skeleton3D) -> void:
	mesh = body
	rig = skeleton
	assert(mesh.mesh.get_surface_count() == 1)
	var arrays := mesh.mesh.surface_get_arrays(0)
	positions = arrays[Mesh.ARRAY_VERTEX]
	joints = arrays[Mesh.ARRAY_BONES]
	weights = arrays[Mesh.ARRAY_WEIGHTS]
	indices = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
	if indices.is_empty():
		for i in positions.size():
			indices.append(i)
	stride = joints.size() / positions.size()
	for slot in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(slot)
		if bone < 0:
			bone = rig.find_bone(mesh.skin.get_bind_name(slot))
		assert(bone >= 0)
		bones.append(bone)
		binds.append(mesh.skin.get_bind_pose(slot))
	deformed.resize(positions.size())
	bounds.resize(indices.size() / 3)

func update_pose() -> void:
	var transforms: Array[Transform3D] = []
	for i in bones.size():
		transforms.append(rig.global_transform * rig.get_bone_global_pose(bones[i]) * binds[i])
	for i in positions.size():
		var point := Vector3.ZERO
		for slot in stride:
			var influence := i * stride + slot
			if weights[influence] > 0.0:
				point += (transforms[joints[influence]] * positions[i]) * weights[influence]
		deformed[i] = point
	for i in bounds.size():
		var first := i * 3
		bounds[i] = AABB(deformed[indices[first]], Vector3.ZERO).expand(
			deformed[indices[first + 1]]).expand(deformed[indices[first + 2]])

func intersects(pose: Transform3D, margin := 0.0) -> bool:
	var offsets := [Vector3.ZERO]
	if margin > 0.0:
		for axis in [Vector3.RIGHT, Vector3.LEFT, Vector3.FORWARD, Vector3.BACK]:
			offsets.append(axis * margin)
	for segment in SEGMENTS:
		var from: Vector3 = pose * segment[0]
		var to: Vector3 = pose * segment[1]
		var line := AABB(from, Vector3.ZERO).expand(to).grow(margin * 1.5 + 0.0001)
		for i in bounds.size():
			if not line.intersects(bounds[i]):
				continue
			var first := i * 3
			for offset: Vector3 in offsets:
				var shift := pose.basis * offset
				if Geometry3D.segment_intersects_triangle(from + shift, to + shift, deformed[indices[first]],
						deformed[indices[first + 1]], deformed[indices[first + 2]]) != null:
					return true
	return false
