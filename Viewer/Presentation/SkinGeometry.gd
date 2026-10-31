extends RefCounted
## Exact CPU skin bounds, also available with the headless renderer.
static func deformed_bounds(mesh: MeshInstance3D,rig: Skeleton3D) -> AABB:
	var arrays:=mesh.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	var matrices: Array[Transform3D]=[]
	for i in mesh.skin.get_bind_count():
		var bone:=mesh.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*mesh.skin.get_bind_pose(i))
	var box:=AABB()
	for i in vertices.size():
		var point:=Vector3.ZERO
		for j in 4:point+=(matrices[indices[i*4+j]]*vertices[i])*weights[i*4+j]
		point=rig.to_global(point)
		if not point.is_finite():return AABB(Vector3(INF,INF,INF),Vector3.ZERO)
		box=AABB(point,Vector3.ZERO) if i==0 else box.expand(point)
	return box
