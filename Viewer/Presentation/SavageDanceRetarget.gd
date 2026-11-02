extends RefCounted
## Retarget original tribal choreography to the modern human proportions.
## Rig/UV inputs and generated clips remain private and separately gated.
const Geometry=preload("res://Presentation/SkinGeometry.gd")
const AXIAL={"bip01 pelvis":"pelvis","bip01 spine":"spine_01","bip01 spine1":"spine_02","bip01 spine2":"spine_03","bip01 neck":"neck_01","bip01 head":"head"}

static func targets(name: String) -> Array[String]:
	if AXIAL.has(name):return [AXIAL[name]]
	for side: String in ["l","r"]:
		var prefix:="bip01 "+side+" "
		if not name.begins_with(prefix):continue
		var suffix:=name.trim_prefix(prefix)
		var fingers:={"finger1":"01","finger11":"02","finger1nub":"03"}
		if fingers.has(suffix):
			var result: Array[String]=[]
			# The original mitten's four fingers share two joints and a tip.
			for finger: String in ["index","middle","ring","pinky"]:result.append(finger+"_"+str(fingers[suffix])+"_"+side)
			return result
		var target:=str({"clavicle":"clavicle","upperarm":"upperarm","forearm":"lowerarm","hand":"hand","thigh":"thigh","calf":"calf","foot":"foot","toe0":"ball","finger0":"thumb_01","finger01":"thumb_02","finger0nub":"thumb_03"}.get(suffix,""))
		if not target.is_empty():return [target+"_"+side]
	return []

static func body(human: Node3D) -> MeshInstance3D:
	return human.model.find_children("Body*","MeshInstance3D",true,false)[0]

static func build(source: Node3D,human: Node3D,floor_source: Node3D,fps: int=60) -> Dictionary:
	assert(fps in [30,60,120],"Bounded dance sample rate required")
	var source_rig: Skeleton3D=source.find_children("*","Skeleton3D",true,false)[0]
	var player: AnimationPlayer=source.find_children("*","AnimationPlayer",true,false)[0]
	var source_mesh: MeshInstance3D=floor_source.find_children("Body*","MeshInstance3D",true,false)[0]
	var floor_rig: Skeleton3D=floor_source.find_children("*","Skeleton3D",true,false)[0]
	var floor_player: AnimationPlayer=floor_source.find_children("*","AnimationPlayer",true,false)[0]
	assert(source_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size()>100,"A full original Savage skin is required; the hue-chip rig helper is not a body")
	var rig: Skeleton3D=human.skeleton
	assert(player.has_animation("TribalDance"),"Original source dance required")
	var duration:=player.get_animation("TribalDance").length
	assert(is_equal_approx(duration,floor_player.get_animation("TribalDance").length),"Choreography and full-body clearance must share original timing")
	var steps:=ceili(duration*fps);var pairs: Dictionary={};var mapping: Array=[];var omitted: Array[String]=[]
	for bone in source_rig.get_bone_count():
		var name:=source_rig.get_bone_name(bone);var names:=targets(name)
		if names.is_empty():omitted.append(name)
		for target_name: String in names:
			var target:=rig.find_bone(target_name)
			assert(target>=0 and not pairs.has(target),"Missing or multiply mapped modern dance bone")
			pairs[target]=bone;mapping.append({"source":name,"target":target_name})
	assert(pairs.size()==52,"All modern body/finger joints must be mapped; root and eight garment controls stay separate")
	var animation:=Animation.new();animation.length=duration;animation.loop_mode=Animation.LOOP_NONE
	var destination:=str(human.animator.get_node(human.animator.root_node).get_path_to(rig))
	var positions: Dictionary={};var rotations: Dictionary={}
	for bone in rig.get_bone_count():
		var track:=animation.add_track(Animation.TYPE_POSITION_3D)
		animation.track_set_path(track,NodePath(destination+":"+rig.get_bone_name(bone)));positions[bone]=track
		track=animation.add_track(Animation.TYPE_ROTATION_3D)
		animation.track_set_path(track,NodePath(destination+":"+rig.get_bone_name(bone)));rotations[bone]=track
	var source_basis:=source_rig.global_basis.orthonormalized();var target_basis:=rig.global_basis.orthonormalized()
	var maximum_basis_error:=0.;var maximum_offset_error:=0.;var maximum_floor_error:=0.;var maximum_source_lift:=0.
	var samples: Array=[];var pelvis:=rig.find_bone("pelvis");var source_pelvis: int=pairs[pelvis]
	human.animator.stop();player.play("TribalDance");floor_player.play("TribalDance")
	for frame in steps+1:
		var time:=minf(duration,float(frame)/fps)
		player.seek(time,true);source_rig.force_update_all_bone_transforms();rig.reset_bone_poses()
		floor_player.seek(time,true);floor_rig.force_update_all_bone_transforms()
		var raw_source_min:=Geometry.deformed_bounds(source_mesh,floor_rig).position.y
		# Correct source foot penetration, retaining every positive rise.
		var source_min:=maxf(0.,raw_source_min)
		maximum_source_lift=maxf(maximum_source_lift,source_min)
		var expected: Dictionary={}
		for bone in rig.get_bone_count():
			if not pairs.has(bone):continue
			var from: int=pairs[bone]
			var reference: Quaternion=(source_basis*source_rig.get_bone_global_rest(from).basis).get_rotation_quaternion()
			var posed: Quaternion=(source_basis*source_rig.get_bone_global_pose(from).basis).get_rotation_quaternion()
			var delta:=Basis(posed*reference.inverse())
			var desired:=target_basis.inverse()*delta*target_basis*rig.get_bone_global_rest(bone).basis
			var parent:=rig.get_bone_parent(bone)
			var parent_basis:=rig.get_bone_global_pose(parent).basis if parent>=0 else Basis.IDENTITY
			rig.set_bone_pose_rotation(bone,(parent_basis.inverse()*desired).get_rotation_quaternion().normalized())
			expected[bone]=delta
		var source_rest: Vector3=source_rig.global_transform*source_rig.get_bone_global_rest(source_pelvis).origin
		var source_pose: Vector3=source_rig.global_transform*source_rig.get_bone_global_pose(source_pelvis).origin
		var desired_world:=rig.global_transform*rig.get_bone_global_rest(pelvis).origin+Vector3.UP*(source_pose.y-source_rest.y)
		var desired_position:=rig.global_transform.affine_inverse()*desired_world
		var parent:=rig.get_bone_parent(pelvis)
		var parent_pose:=rig.get_bone_global_pose(parent) if parent>=0 else Transform3D.IDENTITY
		rig.set_bone_pose_position(pelvis,parent_pose.affine_inverse()*desired_position);rig.force_update_all_bone_transforms()
		var actual_min:=Geometry.deformed_bounds(body(human),rig).position.y
		# Preserve the source's complete-skin clearance, including its airborne
		# phase. World metres differ from rig units on both current human models.
		for correction in 6:
			if absf(source_min-actual_min)<.000001:break
			desired_position+=rig.global_basis.inverse()*Vector3.UP*(source_min-actual_min)
			rig.set_bone_pose_position(pelvis,parent_pose.affine_inverse()*desired_position);rig.force_update_all_bone_transforms()
			actual_min=Geometry.deformed_bounds(body(human),rig).position.y
		maximum_floor_error=maxf(maximum_floor_error,absf(actual_min-source_min))
		for bone in rig.get_bone_count():
			animation.position_track_insert_key(positions[bone],time,rig.get_bone_pose_position(bone))
			animation.rotation_track_insert_key(rotations[bone],time,rig.get_bone_pose_rotation(bone))
			if bone!=pelvis:maximum_offset_error=maxf(maximum_offset_error,rig.get_bone_pose_position(bone).distance_to(rig.get_bone_rest(bone).origin))
			if not pairs.has(bone):continue
			var observed:=target_basis*rig.get_bone_global_pose(bone).basis*rig.get_bone_global_rest(bone).basis.inverse()*target_basis.inverse()
			var wanted: Basis=expected[bone]
			maximum_basis_error=maxf(maximum_basis_error,maxf(observed.x.distance_to(wanted.x),maxf(observed.y.distance_to(wanted.y),observed.z.distance_to(wanted.z))))
		samples.append({"time":time,"raw_source_body_clearance_m":raw_source_min,"source_lift_m":source_min,"retargeted_lift_m":actual_min})
	assert(maximum_basis_error<.00001 and maximum_offset_error<.000001 and maximum_floor_error<.00001,"Dance retarget changed source rotation deltas, limb offsets or measured clearance")
	var floor_curve:=PackedVector2Array()
	for sample: Dictionary in samples:floor_curve.append(Vector2(float(sample.time),float(sample.source_lift_m)))
	animation.set_meta("npc_full_body_clearance",floor_curve)
	return {"animation":animation,"report":{"fps":fps,"source_bones":source_rig.get_bone_count(),"target_bones":rig.get_bone_count(),"mapped_bones":pairs.size(),"mapping":mapping,"unmapped_source_helpers":omitted,"samples":samples,"maximum_global_rotation_basis_error":maximum_basis_error,"maximum_nonpelvis_local_position_error_m":maximum_offset_error,"maximum_floor_reference_error_m":maximum_floor_error,"source_lift_m":maximum_source_lift,"scope":"Authored modern retarget of original tribal choreography. Source global rotation changes and measured complete-skin lift retained, fixed limb offsets. Root/eight garment controls held at rest. Native111, clothing dynamics, slopes, transitions and acceptance remain separate."}}
