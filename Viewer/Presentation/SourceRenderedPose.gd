extends RefCounted
## Skeleton modifiers restore CPU poses after submitting the displayed skin.
var poses: Array[Transform3D]=[]
var rig_id:=0
var frame:=-10
func capture(rig: Skeleton3D) -> void:
	rig_id=rig.get_instance_id();frame=Engine.get_process_frames()
	poses.resize(rig.get_bone_count())
	for bone in poses.size():poses[bone]=rig.get_bone_pose(bone)
func source(rig: Skeleton3D) -> Skeleton3D:
	if rig_id!=rig.get_instance_id() or poses.size()!=rig.get_bone_count() or Engine.get_process_frames()-frame>1:return rig
	# SourcePoseEntry reads names/local channels only; no second render rig runs.
	var snapshot:=Skeleton3D.new()
	for bone in poses.size():snapshot.add_bone(rig.get_bone_name(bone))
	for bone in poses.size():
		snapshot.set_bone_parent(bone,rig.get_bone_parent(bone))
		snapshot.set_bone_pose_position(bone,poses[bone].origin);snapshot.set_bone_pose_rotation(bone,poses[bone].basis.get_rotation_quaternion());snapshot.set_bone_pose_scale(bone,poses[bone].basis.get_scale())
	return snapshot
