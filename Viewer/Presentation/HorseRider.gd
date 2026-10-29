extends SkeletonModifier3D
## Presentation-only saddle contact and two-bone stirrup/rein fitting.
var rider: Node3D
var horse: Node3D
var seated_weight:=0.
var seat_error:=0.
var stirrup_errors: Array[float]=[]
var seated_pelvis:=Basis.IDENTITY
func aim(rig: Skeleton3D,bone: int,child: int,target: Vector3) -> void:
	var pose:=rig.get_bone_global_pose(bone)
	var direction:=rig.get_bone_global_pose(child).origin-pose.origin
	var rotation:=Quaternion(direction.normalized(),(target-pose.origin).normalized())
	pose.basis=Basis(rotation)*pose.basis;rig.set_bone_global_pose(bone,pose)
func solve(rig: Skeleton3D,a: String,b: String,c: String,target: Vector3,pole: Vector3) -> void:
	var ia:=rig.find_bone(a);var ib:=rig.find_bone(b);var ic:=rig.find_bone(c)
	var pa:=rig.get_bone_global_pose(ia).origin;var pb:=rig.get_bone_global_pose(ib).origin;var pc:=rig.get_bone_global_pose(ic).origin
	var first:=pa.distance_to(pb);var second:=pb.distance_to(pc);var offset:=target-pa
	var distance:=clampf(offset.length(),absf(first-second)+.001,first+second-.001);var axis:=offset.normalized()
	var bend:=(pole-pa)-axis*(pole-pa).dot(axis);bend=bend.normalized()
	var along:=(first*first-second*second+distance*distance)/(2.*distance)
	var knee:=pa+axis*along+bend*sqrt(maxf(0.,first*first-along*along))
	aim(rig,ia,ib,knee);aim(rig,ib,ic,pa+axis*distance)
func _process_modification_with_delta(delta: float) -> void:
	if not is_instance_valid(horse) or not is_instance_valid(rider):return
	seated_weight=minf(1.,seated_weight+delta/.35)
	var rig:=get_skeleton();var pelvis:=rig.find_bone("pelvis")
	# Keep the pelvis seated while the upper body performs a weapon action.
	# The old on-foot-derived attack otherwise twists the shorter rider's hip
	# far enough away that its stirrup is outside the leg's physical reach.
	var hip_pose:=rig.get_bone_global_pose(pelvis)
	if seated_pelvis==Basis.IDENTITY:seated_pelvis=hip_pose.basis
	var spine:=rig.find_bone("spine_01");var spine_basis:=rig.get_bone_global_pose(spine).basis
	hip_pose.basis=seated_pelvis;rig.set_bone_global_pose(pelvis,hip_pose)
	var spine_pose:=rig.get_bone_global_pose(spine);spine_pose.basis=spine_basis;rig.set_bone_global_pose(spine,spine_pose)
	var native: Vector3=(rider.global_transform.affine_inverse()*rig.global_transform)*rig.get_bone_global_pose(pelvis).origin
	var saddle: Transform3D=horse.seat()
	var target:=saddle*Transform3D(Basis.IDENTITY,Vector3(0,.105,0)-native)
	rider.global_transform=rider.global_transform.interpolate_with(target,minf(1.,delta*18.) if seated_weight<1. else 1.)
	var inverse:=rig.global_transform.affine_inverse();var hip:=rig.get_bone_global_pose(pelvis).origin
	stirrup_errors.clear()
	for left in [true,false]:
		var side:="l" if left else "r";var sign:=1. if left else -1.
		var ankle: Vector3=inverse*horse.stirrup(left)
		var pole: Vector3=inverse*(saddle*Vector3(sign*.45,-.25,.72))
		solve(rig,"thigh_"+side,"calf_"+side,"foot_"+side,ankle,pole)
		var index:=rig.find_bone("foot_"+side);var foot:=rig.get_bone_global_pose(index)
		foot.basis=rig.get_bone_global_rest(index).basis;rig.set_bone_global_pose(index,foot)
		stirrup_errors.append((rig.global_transform*foot.origin).distance_to(horse.stirrup(left)))
		var worn: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
		var bow: bool=str(worn.pieces.get("weapon",{}).get("asset",""))=="coverage/bow"
		var busy: bool=(worn.pieces.has("shield") or bow) if left else (worn.pieces.has("weapon") and not bow)
		var ranged: bool=rider.action_clip in ["Rider_Bow","Rider_Crossbow"]
		var acting_hand: bool=not left and rider.action_clip in ["Rider_Attack","Rider_Slap"]
		if not ranged and not busy and not acting_hand:
			var hand_target: Vector3=inverse*(saddle*Vector3(sign*.14,.30,.46))
			solve(rig,"upperarm_"+side,"lowerarm_"+side,"hand_"+side,hand_target,hip+Vector3(sign*.5,.1,.25))
	var left_hand:=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
	var right_hand:=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
	var outfit: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
	if outfit.pieces.has("weapon") and not outfit.pieces.has("shield") and rider.action_clip not in ["Rider_Bow","Rider_Crossbow"]:right_hand=left_hand
	horse.set_reins(left_hand,right_hand)
	seat_error=(rig.global_transform*rig.get_bone_global_pose(pelvis).origin).distance_to(saddle*Vector3(0,.105,0))
