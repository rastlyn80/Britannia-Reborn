extends "res://Presentation/SourceMageSupport.gd"
## Ice's original Run has real positive clearance; never balance it to zero.
var residual_height:=0.
const STANCE_CLEARANCE:=.002
func source_lifts() -> Array[float]:
	var result:=super.source_lifts()
	for index in result.size():result[index]=maxf(0.,result[index]+residual_height)
	return result
func _process_modification_with_delta(_delta: float) -> void:
	errors.clear();stance_gaps.clear()
	if not enabled or surface==null or model_root==null:return
	model_root.position.y=base_model_y
	var rig:=get_skeleton();var lifts:=source_lifts()
	var reference:=Transform3D(flat_basis,Vector3.ZERO)*model_root.global_transform.affine_inverse()*rig.global_transform
	var clearance:=maxf(0.,Ground.minimum_plane_gap(full_skin,rig,reference,Vector3.ZERO,Vector3.UP)+residual_height)
	for index in feet.size():
		if not contacts.has(index):continue
		var record: Dictionary=feet[index];var hit: Dictionary=contacts[index];var normal: Vector3=hit.normal
		var lift:=0. if lifts[index]<STANCE_CLEARANCE else lifts[index]
		for iteration in 12:
			if absf(lift-normal.dot(sole(record)-hit.position))<.0005:break
			for joint: int in [record.c,record.b,record.a]:
				var point:=sole(record);var pose:=rig.get_bone_global_pose(joint);var arm:=point-rig.to_global(pose.origin);var axis:=arm.cross(normal);var lever:=axis.length()
				if lever<.0001:continue
				var angle:=clampf((lift-normal.dot(point-hit.position))/lever,-.045,.045)
				var local_axis: Vector3=(rig.global_basis.inverse()*axis.normalized()).normalized()
				pose.basis=Basis(Quaternion(local_axis,angle))*pose.basis;rig.set_bone_global_pose(joint,pose)
	# On a shared finite plane balance source-relative body and sole errors.
	# Mixed ledges remain a separate scope; no common infinite-plane fiction.
	if contacts.size()==feet.size():
		var hit: Dictionary=contacts[0];var normal: Vector3=hit.normal;var origin: Vector3=hit.position;var shared:=true
		for other: Dictionary in contacts.values():
			if normal.dot(other.normal)<.999 or absf(normal.dot(other.position-origin))>.004:shared=false
		if shared:
			var minimum:=Ground.minimum_plane_gap(full_skin,rig,rig.global_transform,origin,normal)-clearance;var maximum:=minimum
			for index in feet.size():
				var wanted:=0. if lifts[index]<STANCE_CLEARANCE else lifts[index]
				var error: float=normal.dot(sole(feet[index])-origin)-wanted
				minimum=minf(minimum,error);maximum=maxf(maximum,error)
			var correction:=clampf(-(minimum+maximum)*.5,-.02,.02)
			var vertical: Vector3=model_root.get_parent_node_3d().global_basis.y
			model_root.position.y+=correction/maxf(.75,normal.dot(vertical))
	for index in feet.size():
		if contacts.has(index) and lifts[index]<STANCE_CLEARANCE:
			var gap: float=contacts[index].normal.dot(sole(feet[index])-contacts[index].position)
			errors.append(absf(gap));stance_gaps.append(gap)
