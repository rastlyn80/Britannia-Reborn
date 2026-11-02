extends "res://Presentation/SourceSolenSupport.gd"
## Preserve actual source clearance, including all-six-feet-airborne run poses.
var residual_height:=0.
const STANCE_CLEARANCE:=.002
func source_lifts() -> Array[float]:
	var rig:=get_skeleton();var poses:=matrices();var result: Array[float]=[]
	var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*rig.global_transform
	for foot: Dictionary in feet:
		var low:=INF
		for vertex: int in foot.vertices:low=minf(low,(reference*skinned(vertex,poses)).y)
		# The whole-clip gait anchor and measured action residual belong to
		# the model. Subtracting the lowest foot here would invent a stance
		# during source flight and ask fixed-length legs to reach too far.
		result.append(maxf(0.,low+residual_height))
	return result
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null or model_root==null:return
	var rig:=get_skeleton();var lifts:=source_lifts()
	for i in feet.size():
		if not contacts.has(i):continue
		var record: Dictionary=feet[i];var hit: Dictionary=contacts[i];var normal: Vector3=hit.normal
		var lift:=0. if lifts[i]<STANCE_CLEARANCE else lifts[i]
		# Keep the established exact-length signed-plane solve. A 15mm stance
		# snap erases small source flight; this candidate plants only within2mm.
		for iteration in 12:
			if absf(lift-normal.dot(sole(record)-hit.position))<.0015:break
			for joint: int in [record.b,record.a]:
				var point:=sole(record);var pose:=rig.get_bone_global_pose(joint);var arm:=point-rig.to_global(pose.origin);var axis:=arm.cross(normal);var lever:=axis.length()
				if lever<.0001:continue
				var angle:=clampf((lift-normal.dot(point-hit.position))/lever,-.045,.045);var local_axis: Vector3=(rig.global_basis.inverse()*axis.normalized()).normalized()
				pose.basis=Basis(Quaternion(local_axis,angle))*pose.basis;rig.set_bone_global_pose(joint,pose)
		if lifts[i]<STANCE_CLEARANCE:
			var gap: float=normal.dot(sole(record)-hit.position);errors.append(absf(gap));stance_gaps.append(gap)
