extends RefCounted
## Two measured finger chains close around the source staff's actual shaft.
static func aim(rig: Skeleton3D,bone: int,from: Vector3,target: Vector3) -> void:
	var pose:=rig.get_bone_global_pose(bone);var a:=from-pose.origin;var b:=target-pose.origin
	if a.length_squared()<.00000001 or b.length_squared()<.00000001:return
	pose.basis=Basis(Quaternion(a.normalized(),b.normalized()))*pose.basis;rig.set_bone_global_pose(bone,pose);rig.force_update_all_bone_transforms()
static func knee(a: Vector3,b: Vector3,c: Vector3,target: Vector3) -> Vector3:
	var first:=a.distance_to(b);var second:=b.distance_to(c);var axis:=(target-a).normalized();var distance:=clampf(a.distance_to(target),absf(first-second)+.0001,first+second-.0001);var along:=(first*first-second*second+distance*distance)/(2.*distance);var bend:=(b-a).slide(axis)
	if bend.length_squared()<.00000001:bend=Vector3.FORWARD.slide(axis)
	return a+axis*along+bend.normalized()*sqrt(maxf(0.,first*first-along*along))
static func calibrate(mesh: MeshInstance3D,rig: Skeleton3D,staff: Node3D) -> Dictionary:
	var saved: Dictionary={}
	for name in ["bip01 r finger0","bip01 r finger01","bip01 r finger1","bip01 r finger11"]:
		var bone:=rig.find_bone(name);assert(bone>=0);saved[bone]=rig.get_bone_pose_rotation(bone)
	var center:=rig.to_local(staff.global_position);var axis: Vector3=(rig.global_basis.inverse()*staff.global_basis.y).normalized();var rotations: Dictionary={};var measured: Array=[]
	for pair in [["bip01 r finger0","bip01 r finger01"],["bip01 r finger1","bip01 r finger11"]]:
		var upper:=rig.find_bone(pair[0]);var lower:=rig.find_bone(pair[1]);var reach:=0.
		for surface in mesh.mesh.get_surface_count():
			var a:=mesh.mesh.surface_get_arrays(surface);var vertices: PackedVector3Array=a[Mesh.ARRAY_VERTEX];var bindings: PackedInt32Array=a[Mesh.ARRAY_BONES];var weights: PackedFloat32Array=a[Mesh.ARRAY_WEIGHTS];var stride:=weights.size()/vertices.size()
			for i in vertices.size():
				for slot in stride:
					var bind:=bindings[i*stride+slot];var bone:=mesh.skin.get_bind_bone(bind)
					if bone<0:bone=rig.find_bone(mesh.skin.get_bind_name(bind))
					if bone==lower and weights[i*stride+slot]>.6:reach=maxf(reach,(mesh.skin.get_bind_pose(bind)*vertices[i]).x)
		assert(reach>.001,"Source distal finger has measurable weighted tip geometry")
		var a:=rig.get_bone_global_pose(upper).origin;var b:=rig.get_bone_global_pose(lower).origin;var tip:=rig.get_bone_global_pose(lower)*Vector3(reach,0.,0.);var radial:=(a-center).slide(axis).normalized();var target:=center+axis*clampf((tip-center).dot(axis),-.05,.05)-radial*.009
		var first:=a.distance_to(b);var second:=b.distance_to(tip);var direction:=(target-a).normalized();target=a+direction*clampf(a.distance_to(target),absf(first-second)+.0001,first+second-.0001)
		var joint:=knee(a,b,tip,target);aim(rig,upper,b,joint);aim(rig,lower,rig.get_bone_global_pose(lower)*Vector3(reach,0.,0.),target)
		rotations[upper]=rig.get_bone_pose_rotation(upper);rotations[lower]=rig.get_bone_pose_rotation(lower);var actual:=rig.get_bone_global_pose(lower)*Vector3(reach,0.,0.);measured.append({"chain":pair,"tip_length":reach,"first_length":first,"second_length":second,"target_error":actual.distance_to(target),"tip_shaft_radius":(actual-center).slide(axis).length()})
	for bone: int in saved:rig.set_bone_pose_rotation(bone,saved[bone])
	rig.force_update_all_bone_transforms();return {"rotations":rotations,"source_rotations":saved,"chains":measured}
static func apply(rig: Skeleton3D,fit: Dictionary) -> void:
	for bone: int in fit.rotations:rig.set_bone_pose_rotation(bone,fit.rotations[bone])
	rig.force_update_all_bone_transforms()
