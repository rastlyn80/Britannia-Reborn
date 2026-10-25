extends SkeletonModifier3D

# Runs after animation; never changes the network-controlled character root.
var grounded := true
var root_height := 0.0
var contacts := {}
var weights := {}
var body_offset := 0.0

static func knee_target(hip: Vector3, knee: Vector3, ankle: Vector3, target: Vector3) -> Vector3:
	var a := hip.distance_to(knee)
	var b := knee.distance_to(ankle)
	var axis := (target-hip).normalized()
	var length := clampf(hip.distance_to(target),absf(a-b)+0.001,a+b-0.001)
	var along := (a*a-b*b+length*length)/(2*length)
	var bend := knee-hip-axis*(knee-hip).dot(axis)
	if bend.length_squared() < 0.00001: bend = Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)
	return hip+axis*along+bend.normalized()*sqrt(maxf(0,a*a-along*along))

func sample(space: PhysicsDirectSpaceState3D, root_y: float) -> void:
	root_height = root_y
	var rig := get_skeleton()
	if rig == null: return
	for side in ["l","r"]:
		var bone := rig.find_bone("foot_"+side)
		if bone < 0: continue
		var foot := rig.global_transform*rig.get_bone_global_pose(bone).origin
		var from := Vector3(foot.x,root_y+0.65,foot.z)
		var query := PhysicsRayQueryParameters3D.create(from,from-Vector3.UP*1.3,1)
		var hit := space.intersect_ray(query)
		if not hit.is_empty() and hit.normal.y >= 0.65: contacts[side] = hit
		else: contacts.erase(side)

func _aim(rig: Skeleton3D, bone: int, child: int, target: Vector3) -> void:
	var pose := rig.get_bone_global_pose(bone)
	var from := rig.get_bone_global_pose(child).origin-pose.origin
	var to := target-pose.origin
	if minf(from.length(),to.length()) < 0.0001: return
	pose.basis = Basis(Quaternion(from.normalized(),to.normalized()))*pose.basis
	rig.set_bone_global_pose(bone,pose)

func _process_modification_with_delta(delta: float) -> void:
	var rig := get_skeleton()
	if rig == null: return
	for side in ["l","r"]:
		var thigh := rig.find_bone("thigh_"+side)
		var calf := rig.find_bone("calf_"+side)
		var foot := rig.find_bone("foot_"+side)
		if mini(thigh,mini(calf,foot)) < 0: continue
		var ankle := rig.get_bone_global_pose(foot)
		var contact: Dictionary = contacts.get(side,{})
		var weight := 1.0 if grounded and not contact.is_empty() else 0.0
		weights[side] = lerpf(float(weights.get(side,0.0)),weight,1.0-exp(-22.0*delta))
		if weights[side] < 0.001: continue
		var world_ankle := rig.global_transform*ankle.origin
		# Preserve the animated swing above the stance height instead of pinning
		# both feet to the ground throughout a walking cycle.
		var lift := maxf(0.0,world_ankle.y-root_height-body_offset-0.085)
		# Add a little swing clearance when the two feet see different treads.
		var clearance := 0.0
		if contacts.has("l") and contacts.has("r"):
			clearance = minf(0.18,absf(float(contacts.l.position.y)-float(contacts.r.position.y)))
		lift += clearance*smoothstep(0.01,0.12,lift)
		var target := world_ankle
		if not contact.is_empty(): target.y = float(contact.position.y)+0.085+lift
		target.y = world_ankle.y+clampf(target.y-world_ankle.y,-0.42,0.42)*float(weights[side])
		var local := rig.global_transform.affine_inverse()*target
		var hip := rig.get_bone_global_pose(thigh).origin
		var knee := rig.get_bone_global_pose(calf).origin
		_aim(rig,thigh,calf,knee_target(hip,knee,ankle.origin,local))
		_aim(rig,calf,foot,local)
		# Sole pitch follows gentle support normals, with a bounded tilt.
		if not contact.is_empty():
			var pose := rig.get_bone_global_pose(foot)
			var up: Vector3 = rig.global_basis.inverse()*contact.normal
			var tilt := Quaternion(Vector3.UP,up.normalized())
			pose.basis = Basis(Quaternion.IDENTITY.slerp(tilt,minf(0.65,float(weights[side]))))*ankle.basis
			rig.set_bone_global_pose(foot,pose)
