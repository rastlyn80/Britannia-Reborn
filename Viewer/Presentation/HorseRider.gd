extends SkeletonModifier3D
## Presentation-only saddle contact and two-bone stirrup/rein fitting.
var rider: Node3D
var horse: Node3D
var seated_weight:=0.
var seat_error:=0.
var stirrup_errors: Array[float]=[]
var transition_foot_errors: Array[float]=[]
var seated_pelvis:=Basis.IDENTITY
var mode:="seated"
var progress:=1.
var transition_duration:=1.45
var finished:=false
var turn_balance:=0.
func begin_mount(animated: bool=true) -> void:
	mode="mount" if animated else "seated";progress=0. if animated else 1.;seated_weight=progress;finished=false
func begin_dismount() -> void:
	mode="dismount";progress=0.;finished=false
func hurry() -> void:transition_duration=.20
func climb_phase() -> float:return 1.-progress if mode=="dismount" else progress
func hip_path(t: float) -> Vector3:
	var keys: Array=[Vector3(.76,-.85,0),Vector3(.62,-.43,.02),Vector3(.43,.16,.02),Vector3(.04,.16,0),Vector3(0,.105,0)]
	var segment:=mini(3,int(t*4.));var u:=smoothstep(0.,1.,t*4.-float(segment))
	return keys[segment].lerp(keys[segment+1],u)
func foot_path(left: bool,t: float,saddle: Transform3D) -> Vector3:
	var stirrup: Vector3=horse.stirrup(left)
	if left:return (saddle*Vector3(.63,-1.58,.08)).lerp(stirrup,smoothstep(.04,.32,t))
	if t<.18:return saddle*Vector3(.84,maxf(-1.58,hip_path(t).y-.66),-.08)
	var u:=smoothstep(.18,.93,t)
	# A leg-over arc above and behind the saddle, not through the horse barrel.
	var a:=saddle*Vector3(.84,maxf(-1.58,hip_path(.18).y-.66),-.08);var b:=saddle*Vector3(.92,.62,-.45);var c:=saddle*Vector3(-.65,.62,-.45)
	return a.bezier_interpolate(b,c,stirrup,u)
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
	if mode!="seated":
		progress=minf(1.,progress+delta/transition_duration)
		if mode=="mount" and progress>=1.:mode="seated"
		elif mode=="dismount" and progress>=1.:finished=true
	seated_weight=1. if mode=="seated" else progress if mode=="mount" else 1.-progress
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
	var t:=climb_phase();var transition: bool=mode!="seated"
	var hip_offset:=hip_path(t) if transition else Vector3(0,.105,0)
	var target:=saddle*Transform3D(Basis.IDENTITY,hip_offset-native)
	rider.global_transform=target
	# The spine carries modest balance/forward reach while the pelvis stays fitted.
	var spine_now:=rig.get_bone_global_pose(spine)
	var lean: float=sin(PI*t)*.24 if transition else turn_balance
	spine_now.basis=Basis(Vector3.RIGHT if transition else Vector3.FORWARD,lean)*spine_now.basis;rig.set_bone_global_pose(spine,spine_now)
	var inverse:=rig.global_transform.affine_inverse();var hip:=rig.get_bone_global_pose(pelvis).origin
	var worn: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
	stirrup_errors.clear()
	transition_foot_errors.clear()
	for left in [true,false]:
		var side:="l" if left else "r";var sign:=1. if left else -1.
		var ankle: Vector3=inverse*(foot_path(left,t,saddle) if transition else horse.stirrup(left))
		var pole: Vector3=inverse*(saddle*Vector3(sign*.45,-.25,.72))
		solve(rig,"thigh_"+side,"calf_"+side,"foot_"+side,ankle,pole)
		var index:=rig.find_bone("foot_"+side);var foot:=rig.get_bone_global_pose(index)
		foot.basis=rig.get_bone_global_rest(index).basis;rig.set_bone_global_pose(index,foot)
		stirrup_errors.append((rig.global_transform*foot.origin).distance_to(horse.stirrup(left)))
		transition_foot_errors.append((rig.global_transform*foot.origin).distance_to(rig.global_transform*ankle))
		var asset: String=str(worn.pieces.get("weapon",{}).get("asset",""))
		var weapon_stance: String=preload("res://Presentation/HumanCoverageWardrobe.gd").STANCES.get(asset,"")
		var bow: bool=weapon_stance=="bow"
		var busy: bool=(worn.pieces.has("shield") or not weapon_stance.is_empty()) if left else (worn.pieces.has("weapon") and not bow)
		var ranged: bool=rider.action_clip in ["Rider_Bow","Rider_Crossbow"]
		var acting_hand: bool=not left and rider.action_clip in ["Rider_Attack","Rider_Slap"]
		if not ranged and not busy and not acting_hand:
			var grip:=Vector3(sign*.14,.30,.46)
			if transition:grip=Vector3(.24,.18,.31 if left else -.25).lerp(grip,smoothstep(.70,1.,t))
			var hand_target: Vector3=inverse*(saddle*grip)
			solve(rig,"upperarm_"+side,"lowerarm_"+side,"hand_"+side,hand_target,hip+Vector3(sign*.5,.1,.25))
	var left_hand:=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_l")).origin
	var right_hand:=rig.global_transform*rig.get_bone_global_pose(rig.find_bone("hand_r")).origin
	var outfit: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
	var weapon: String=str(outfit.pieces.get("weapon",{}).get("asset",""))
	if rider.action_clip in ["Rider_Bow","Rider_Crossbow"] or (outfit.pieces.has("weapon") and outfit.pieces.has("shield")) or weapon in ["coverage/crossbow","coverage/heavy_crossbow"]:
		left_hand=saddle*Vector3(.08,.14,.22);right_hand=left_hand
	elif weapon=="coverage/bow" or outfit.pieces.has("shield"):left_hand=right_hand
	elif outfit.pieces.has("weapon"):right_hand=left_hand
	horse.set_reins(left_hand,right_hand)
	seat_error=(rig.global_transform*rig.get_bone_global_pose(pelvis).origin).distance_to(saddle*Vector3(0,.105,0))
