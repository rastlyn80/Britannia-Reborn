extends "res://Presentation/MeasuredCreatureSupport.gd"
## The lowest world-Y point is not necessarily the lowest point against a slope.
func configure(mesh: MeshInstance3D,quadruped: bool) -> void:
	super.configure(mesh,quadruped)
	for i in feet.size():feet[i]["plane_sole_index"]=i
func sole(record: Dictionary) -> Vector3:
	var index:=int(record.get("plane_sole_index",-1))
	if not contacts.has(index):return super.sole(record)
	var hit: Dictionary=contacts[index];var rig:=get_skeleton();var matrices: Array[Transform3D]=[]
	for i in surface.skin.get_bind_count():
		var bone:=surface.skin.get_bind_bone(i)
		if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(i))
		matrices.append(rig.get_bone_global_pose(bone)*surface.skin.get_bind_pose(i))
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var lowest:=INF;var result:=Vector3.ZERO
	for vertex: int in record.vertices:
		var point:=Vector3.ZERO
		for slot in 4:point+=(matrices[indices[vertex*4+slot]]*vertices[vertex])*weights[vertex*4+slot]
		point=rig.to_global(point);var gap: float=hit.normal.dot(point-hit.position)
		if gap<lowest:lowest=gap;result=point
	return result if is_finite(lowest) else super.sole(record)
