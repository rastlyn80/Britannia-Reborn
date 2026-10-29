extends SkeletonModifier3D
## Bounded visual-only hoof fitting; never moves the network avatar root.
const CHAINS := [["upperarm_L","forearm_L","hand_L","finger_L"],["upperarm_R","forearm_R","hand_R","finger_R"],["thigh_L","calf_L","foot_L","toe_L"],["thigh_R","calf_R","foot_R","toe_R"]]
var contacts: Dictionary={}
var hoof_errors: Array[float]=[]
var support_tilt:=Vector2.ZERO
var enabled:=true
var support_origin_y:=0.
func sample(space: PhysicsDirectSpaceState3D,origin: Vector3) -> void:
	var rig:=get_skeleton()
	support_origin_y=origin.y
	if rig==null:return
	for chain: Array in CHAINS:
		var end:=rig.find_bone(chain[3])
		var hoof: Vector3=rig.global_transform*rig.get_bone_global_pose(end).origin-Vector3.UP*.17
		var from:=Vector3(hoof.x,origin.y+.65,hoof.z)
		var hit:=space.intersect_ray(PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*1.3,1))
		if enabled and not hit.is_empty() and hit.normal.y>.75 and absf(hit.position.y-origin.y)<.45:contacts[chain[3]]=hit
		else:contacts.erase(chain[3])
	var front:=0.;var rear:=0.;var left:=0.;var right:=0.
	if contacts.size()==4:
		front=(contacts.finger_L.position.y+contacts.finger_R.position.y)*.5
		rear=(contacts.toe_L.position.y+contacts.toe_R.position.y)*.5
		left=(contacts.finger_L.position.y+contacts.toe_L.position.y)*.5
		right=(contacts.finger_R.position.y+contacts.toe_R.position.y)*.5
		support_tilt=Vector2(clampf(atan2(front-rear,1.18),-.22,.22),clampf(atan2(left-right,.36),-.12,.12))
	else:support_tilt=Vector2.ZERO
func aim(rig: Skeleton3D,bone: int,child: int,target: Vector3) -> void:
	var pose:=rig.get_bone_global_pose(bone)
	var a:=rig.get_bone_global_pose(child).origin-pose.origin;var b:=target-pose.origin
	if a.length_squared()<.000001 or b.length_squared()<.000001:return
	pose.basis=Basis(Quaternion(a.normalized(),b.normalized()))*pose.basis;rig.set_bone_global_pose(bone,pose)
func _process_modification_with_delta(_delta: float) -> void:
	hoof_errors.clear()
	if not enabled:return
	var rig:=get_skeleton();var inverse:=rig.global_transform.affine_inverse()
	for chain: Array in CHAINS:
		if not contacts.has(chain[3]):continue
		var a:=rig.find_bone(chain[0]);var b:=rig.find_bone(chain[1]);var c:=rig.find_bone(chain[2]);var end:=rig.find_bone(chain[3])
		var ankle:=rig.get_bone_global_pose(c);var knee:=rig.get_bone_global_pose(b).origin;var hip:=rig.get_bone_global_pose(a).origin
		var hoof: Vector3=rig.global_transform*rig.get_bone_global_pose(end).origin-Vector3.UP*.17
		var hit: Dictionary=contacts[chain[3]]
		# Only stance feet follow support. Animated swing clearance is retained.
		var lift:=maxf(0.,hoof.y-support_origin_y)
		var strength:=1.-smoothstep(.035,.18,lift)
		var shift:=clampf(hit.position.y-hoof.y,-.24,.24)*strength
		var target: Vector3=inverse*(rig.global_transform*ankle.origin+Vector3.UP*shift)
		var bend:=preload("res://Presentation/FootContact.gd").knee_target(hip,knee,ankle.origin,target)
		aim(rig,a,b,bend);aim(rig,b,c,target)
		var pose:=rig.get_bone_global_pose(c)
		var up: Vector3=(rig.global_basis.inverse()*hit.normal).normalized()
		pose.basis=Basis(Quaternion.IDENTITY.slerp(Quaternion(Vector3.UP,up),strength*.5))*ankle.basis;rig.set_bone_global_pose(c,pose)
		var corrected: Vector3=rig.global_transform*rig.get_bone_global_pose(end).origin-Vector3.UP*.17
		if strength>.95:hoof_errors.append(absf(corrected.y-hit.position.y))
