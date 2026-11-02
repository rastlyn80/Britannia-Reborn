extends "res://Presentation/MeasuredCreatureSupport.gd"
## Six original two-joint legs. Historical bip01 arms are not stance limbs.
var stride:=4
var animator: AnimationPlayer
func configure(mesh: MeshInstance3D,_quadruped: bool) -> void:
	surface=mesh;arrays=mesh.mesh.surface_get_arrays(0);feet.clear();align_skinned_soles=true;iterations=8
	var rig:=get_skeleton();var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];stride=indices.size()/vertices.size();assert(stride in [4,8])
	for side in ["l","r"]:
		for segment in ["f","m","r"]:
			var upper:=rig.find_bone("legbone "+side+segment+"1");var lower:=rig.find_bone("legbone "+side+segment+"2");assert(upper>=0 and lower>=0 and rig.get_bone_parent(lower)==upper)
			var record:={"a":upper,"b":lower,"c":lower,"end":lower,"vertices":[],"label":side+segment,"plane_sole_index":feet.size()};var seen: Dictionary={}
			for vertex in vertices.size():
				var score:=0.
				for slot in stride:
					var bind:=indices[vertex*stride+slot];var bone:=surface.skin.get_bind_bone(bind)
					if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(bind))
					if bone==lower:score+=weights[vertex*stride+slot]
				if score>.6 and not seen.has(vertices[vertex]):record.vertices.append(vertex);seen[vertices[vertex]]=true
			assert(not record.vertices.is_empty(),"Original Solen leg has no measured distal surface");feet.append(record)
	assert(feet.size()==6)
func matrices() -> Array[Transform3D]:
	var rig:=get_skeleton();var result: Array[Transform3D]=[]
	for bind in surface.skin.get_bind_count():
		var bone:=surface.skin.get_bind_bone(bind)
		if bone<0:bone=rig.find_bone(surface.skin.get_bind_name(bind))
		result.append(rig.get_bone_global_pose(bone)*surface.skin.get_bind_pose(bind))
	return result
func skinned(vertex: int,poses: Array[Transform3D]) -> Vector3:
	var points: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX];var indices: PackedInt32Array=arrays[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS];var point:=Vector3.ZERO
	for slot in stride:point+=(poses[indices[vertex*stride+slot]]*points[vertex])*weights[vertex*stride+slot]
	return point
func source_lifts() -> Array[float]:
	var rig:=get_skeleton();var poses:=matrices();var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*rig.global_transform;var result: Array[float]=[]
	for foot: Dictionary in feet:
		var low:=INF
		for vertex: int in foot.vertices:low=minf(low,(reference*skinned(vertex,poses)).y)
		result.append(low)
	# Keep original torso/root bob, but adapt the six distal legs as a grounded
	# tripod gait. One fixed model anchor alone leaves all six soles hovering.
	# Relative source swing heights survive; no biped limbs or extra bones.
	if animator!=null and animator.assigned_animation in ["Walk","Run"]:
		var baseline: float=result.min()
		for i in result.size():result[i]-=baseline
	return result
func sole(record: Dictionary) -> Vector3:
	var index:=int(record.plane_sole_index);var rig:=get_skeleton();var poses:=matrices();var low:=INF;var result:=Vector3.ZERO;var normal: Vector3=contacts[index].normal if contacts.has(index) else Vector3.UP;var origin: Vector3=contacts[index].position if contacts.has(index) else Vector3.ZERO
	for vertex: int in record.vertices:
		var point:=rig.to_global(skinned(vertex,poses));var gap:=normal.dot(point-origin)
		if gap<low:low=gap;result=point
	assert(is_finite(low));return result
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null or model_root==null:return
	var rig:=get_skeleton();var lifts:=source_lifts()
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var hit: Dictionary=contacts[i];var normal: Vector3=hit.normal;var lift:=0. if lifts[i]<.015 else lifts[i]
		# Solve signed distance to the actual plane. A world-Y target computed
		# at the previous point drifts on these long, oblique insect feet.
		for iteration in 12:
			if absf(lift-normal.dot(sole(record)-hit.position))<.0015:break
			for joint: int in [record.b,record.a]:
				var point:=sole(record);var pose:=rig.get_bone_global_pose(joint);var arm:=point-rig.to_global(pose.origin);var axis:=arm.cross(normal);var lever:=axis.length()
				if lever<.0001:continue
				var angle:=clampf((lift-normal.dot(point-hit.position))/lever,-.045,.045);var local_axis: Vector3=(rig.global_basis.inverse()*axis.normalized()).normalized();pose.basis=Basis(Quaternion(local_axis,angle))*pose.basis;rig.set_bone_global_pose(joint,pose)
		if lifts[i]<.015:
			var gap: float=normal.dot(sole(record)-hit.position);errors.append(absf(gap));stance_gaps.append(gap)
