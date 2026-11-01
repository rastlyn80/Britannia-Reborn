extends "res://Presentation/MeasuredCreatureSupport.gd"
## Original treant role names and eight-influence sole geometry.
var stride:=8
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	surface=mesh;arrays=mesh.mesh.surface_get_arrays(0);var rig:=get_skeleton()
	var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var joints: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
	stride=joints.size()/vertices.size();assert(stride==8 and weights.size()==vertices.size()*stride)
	feet.clear()
	for side in ["L","R"]:
		var record:={"a":rig.find_bone("thigh."+side),"b":rig.find_bone("shin."+side),"c":rig.find_bone("foot."+side),"end":rig.find_bone("foot."+side),"vertices":[]}
		assert(mini(record.a,mini(record.b,record.c))>=0)
		var used: Dictionary={record.end:true}
		for bone in rig.get_bone_count():
			var parent:=bone
			while parent>=0:
				if parent==int(record.end):used[bone]=true;break
				parent=rig.get_bone_parent(parent)
		var seen: Dictionary={}
		for vertex in vertices.size():
			var score:=0.
			for slot in stride:
				var bind:=joints[vertex*stride+slot];var bone:=mesh.skin.get_bind_bone(bind)
				if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
				if used.has(bone):score+=weights[vertex*stride+slot]
			if score>.6 and not seen.has(vertices[vertex]):record.vertices.append(vertex);seen[vertices[vertex]]=true
		assert(not record.vertices.is_empty());feet.append(record)
	align_skinned_soles=true;iterations=6
func lowest(record: Dictionary,reference: Transform3D) -> Vector3:
	var rig:=get_skeleton();var matrices: Array[Transform3D]=[]
	for bind in surface.skin.get_bind_count():
		var bone:=surface.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(bind))
		matrices.append(reference*rig.get_bone_global_pose(bone)*surface.skin.get_bind_pose(bind))
	var v: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var j: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var w: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var low:=Vector3(0,INF,0)
	for vertex: int in record.vertices:
		var point:=Vector3.ZERO
		for slot in stride:point+=(matrices[j[vertex*stride+slot]]*v[vertex])*w[vertex*stride+slot]
		if point.y<low.y:low=point
	return low
func sole(record: Dictionary) -> Vector3:return lowest(record,get_skeleton().global_transform)
func source_lifts() -> Array[float]:
	var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*get_skeleton().global_transform;var result: Array[float]=[]
	for foot: Dictionary in feet:result.append(lowest(foot,reference).y)
	return result
