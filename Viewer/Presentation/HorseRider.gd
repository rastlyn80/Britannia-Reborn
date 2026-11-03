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
var rendered_pose:=preload("res://Presentation/SourceRenderedPose.gd").new()
var displayed_global:=Transform3D.IDENTITY
var displayed_model:=Transform3D.IDENTITY
var displayed_frame:=-10
func _ready() -> void:
	modification_processed.connect(_capture_submitted_pose)
	RenderingServer.frame_post_draw.connect(_capture_displayed_frame)
func _capture_submitted_pose() -> void:
	if not is_instance_valid(rider):return
	rendered_pose.capture(rider.skeleton)
	if DisplayServer.get_name()=="headless":
		displayed_global=rider.global_transform;displayed_model=rider.model.transform
func _capture_displayed_frame() -> void:
	if not is_instance_valid(rider) or not rider.is_visible_in_tree():return
	displayed_frame=Engine.get_process_frames();displayed_global=rider.global_transform;displayed_model=rider.model.transform
func displayed_state() -> Dictionary:
	if not is_instance_valid(rider) or rendered_pose.rig_id!=rider.skeleton.get_instance_id():return {}
	if DisplayServer.get_name()!="headless" and Engine.get_process_frames()-displayed_frame>1:return {}
	var held:=preload("res://Presentation/SourceVariantPoseEntry.gd").new();held.rendered_pose=rendered_pose
	return {"rig":held.displayed_rig(rider.skeleton),"global_transform":displayed_global,"model_transform":displayed_model}
func begin_mount(animated: bool=true) -> void:
	mode="mount" if animated else "seated";progress=0. if animated else 1.;seated_weight=progress;finished=false
func begin_dismount() -> void:
	mode="dismount";progress=0.;finished=false
func hurry() -> void:transition_duration=.20
func climb_phase() -> float:return 1.-progress if mode=="dismount" else progress
func hip_path(t: float) -> Vector3:
	var keys: Array=[Vector3(.76,-.85,0),Vector3(.62,-.43,.02),Vector3(.43,.16,.02),Vector3(.04,.16,0),Vector3(0,.105,0)]
	var segment:=mini(3,int(t*4.));var u:=smoothstep(0.,1.,t*4.-float(segment))
	var result: Vector3=keys[segment].lerp(keys[segment+1],u)
	result.y+=(1.58-float(horse.get_meta("rider_ground_drop",1.58)))*(1.-smoothstep(0.,.7,t))
	return result
func foot_path(left: bool,t: float,saddle: Transform3D) -> Vector3:
	var stirrup: Vector3=horse.stirrup(left)
	var drop: float=float(horse.get_meta("rider_ground_drop",1.58))
	if left:return (saddle*Vector3(.63,-drop,.08)).lerp(stirrup,smoothstep(.04,.32,t))
	if t<.18:return saddle*Vector3(.84,maxf(-drop,hip_path(t).y-.66),-.08)
	var u:=smoothstep(.18,.93,t)
	# A leg-over arc above and behind the saddle, not through the horse barrel.
	var a:=saddle*Vector3(.84,maxf(-drop,hip_path(.18).y-.66),-.08);var b:=saddle*Vector3(.92,.62,-.45);var c:=saddle*Vector3(-.65,.62,-.45)
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
func fit_rein_wrist(rig: Skeleton3D,side: String,weight: float) -> void:
	var arm:=rig.find_bone("lowerarm_"+side);var hand:=rig.find_bone("hand_"+side)
	var forearm:=rig.get_bone_global_pose(arm);var wrist:=rig.get_bone_global_pose(hand)
	# Calibrate neutral from this gender's actual rig, not a fixed wrist Euler.
	var neutral:=forearm.basis*rig.get_bone_global_rest(arm).basis.inverse()*rig.get_bone_global_rest(hand).basis
	wrist.basis=wrist.basis.slerp(neutral,weight);rig.set_bone_global_pose(hand,wrist)
	var axis: Vector3=(wrist.origin-forearm.origin).normalized()
	var index:=rig.get_bone_global_pose(rig.find_bone("index_01_"+side)).origin
	var pinky:=rig.get_bone_global_pose(rig.find_bone("pinky_01_"+side)).origin
	var thumb: Vector3=(index-pinky).slide(axis).normalized()
	var up: Vector3=(rig.global_basis.inverse()*Vector3.UP).slide(axis).normalized()
	if thumb.length_squared()<.5 or up.length_squared()<.5:return
	# Pronation belongs in the forearm. Keep the wrist straight while the
	# thumb edge comes upward; do not fold the hand back to reach the reins.
	var twist:=clampf(atan2(axis.dot(thumb.cross(up)),thumb.dot(up)),-PI/2.,PI/2.)*weight
	forearm.basis=Basis(axis,twist)*forearm.basis;rig.set_bone_global_pose(arm,forearm)
func rein_socket(rig: Skeleton3D,side: String) -> Vector3:
	var wrist:=rig.get_bone_global_pose(rig.find_bone("hand_"+side)).origin
	var middle:=rig.get_bone_global_pose(rig.find_bone("middle_01_"+side)).origin
	var ring:=rig.get_bone_global_pose(rig.find_bone("ring_01_"+side)).origin
	return rig.global_transform*wrist.lerp((middle+ring)*.5,.72)
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
	var inverse:=rig.global_transform.affine_inverse()
	var worn: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
	stirrup_errors.clear()
	transition_foot_errors.clear()
	rider.grip.reins_holding=false;rider.grip.left_reins_holding=false
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
			var elbow_pole: Vector3=inverse*(saddle*Vector3(sign*.34,.34,0.))
			solve(rig,"upperarm_"+side,"lowerarm_"+side,"hand_"+side,hand_target,elbow_pole)
			fit_rein_wrist(rig,side,smoothstep(.7,1.,t) if transition else 1.)
			if left:rider.grip.left_reins_holding=true
			else:rider.grip.reins_holding=true
	var left_hand:=rein_socket(rig,"l")
	var right_hand:=rein_socket(rig,"r")
	var outfit: Dictionary=preload("res://Presentation/HumanWardrobe.gd").resolve(rider.server_equipment)
	var weapon: String=str(outfit.pieces.get("weapon",{}).get("asset",""))
	if rider.action_clip in ["Rider_Bow","Rider_Crossbow"] or (outfit.pieces.has("weapon") and outfit.pieces.has("shield")) or weapon in ["coverage/crossbow","coverage/heavy_crossbow"]:
		left_hand=saddle*Vector3(.08,.14,.22);right_hand=left_hand
	elif weapon=="coverage/bow" or outfit.pieces.has("shield"):left_hand=right_hand
	elif outfit.pieces.has("weapon"):right_hand=left_hand
	horse.set_reins(left_hand,right_hand)
	seat_error=(rig.global_transform*rig.get_bone_global_pose(pelvis).origin).distance_to(saddle*Vector3(0,.105,0))
