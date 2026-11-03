extends "res://Presentation/SourceGazerLarvaVisual.gd"
## The exact affine death entry is shared with the Gazer Larva.

var base_mesh: MeshInstance3D
var footprint := PackedInt32Array()
var neutral_model: Transform3D

func _ready() -> void:
	super._ready()
	base_mesh = model.find_children("*", "MeshInstance3D", true, false)[0]
	neutral_model = model.transform
	var path := str(entry.get("footprint", ""))
	if path.is_empty():
		return
	var indices: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not indices is Array:
		return
	var count: int = base_mesh.mesh.surface_get_array_len(0)
	for index in indices:
		if index != int(index) or int(index) < 0 or int(index) >= count:
			footprint.clear()
			return
		footprint.append(int(index))

func _physics_process(_delta: float) -> void:
	if dead or footprint.is_empty():
		return
	var center := ground_hit(global_position)
	if center.is_empty():
		model.transform = neutral_model
		return
	var normal := (global_basis.inverse() * Vector3(center.normal)).normalized()
	if normal.dot(Vector3.UP) < .8:
		model.transform = neutral_model
		return
	var tilt := Basis(Quaternion(Vector3.UP, normal))
	var sample_from_rig := Transform3D(tilt, Vector3.ZERO) * neutral_model * model.transform.affine_inverse() * global_transform.affine_inverse() * skeleton.global_transform
	var transforms := skin_transforms(base_mesh, sample_from_rig)
	var arrays := base_mesh.mesh.surface_get_arrays(0)
	var correction := -INF
	for index in footprint:
		var point := to_global(weighted_point(arrays, transforms, index))
		var hit := ground_hit(point)
		if hit.is_empty():
			model.transform = neutral_model
			return
		correction = maxf(correction, float(hit.position.y) - point.y)
	var offset := global_basis.inverse() * (Vector3.UP * correction)
	model.transform = Transform3D(tilt * neutral_model.basis, tilt * neutral_model.origin + offset)

func ground_hit(point: Vector3) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 2.0, 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func skin_transforms(mesh: MeshInstance3D, target_from_rig: Transform3D) -> Array[Transform3D]:
	var transforms: Array[Transform3D] = []
	for binding in mesh.skin.get_bind_count():
		var bone := mesh.skin.get_bind_bone(binding)
		if bone < 0:
			bone = skeleton.find_bone(mesh.skin.get_bind_name(binding))
		transforms.append(target_from_rig * skeleton.get_bone_global_pose(bone) * mesh.skin.get_bind_pose(binding))
	return transforms

func weighted_point(arrays: Array, transforms: Array[Transform3D], vertex: int) -> Vector3:
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var bindings: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
	var stride := bindings.size() / points.size()
	var point := Vector3.ZERO
	for offset in stride:
		var index := vertex * stride + offset
		point += (transforms[bindings[index]] * points[vertex]) * weights[index]
	return point

func corpse_snapshot_floor() -> float:
	var actor_from_rig := global_transform.affine_inverse() * skeleton.global_transform
	var transforms := skin_transforms(base_mesh, actor_from_rig)
	var floor_y := INF
	for surface in base_mesh.mesh.get_surface_count():
		var arrays := base_mesh.mesh.surface_get_arrays(surface)
		for vertex in base_mesh.mesh.surface_get_array_len(surface):
			floor_y = minf(floor_y, weighted_point(arrays, transforms, vertex).y)
	return floor_y
