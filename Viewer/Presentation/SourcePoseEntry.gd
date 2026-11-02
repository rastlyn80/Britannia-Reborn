extends RefCounted
## Build from a target already sampled at source time zero. No shared edits.
static func insert(animation: Animation,track: int,time: float,pose: Transform3D) -> void:
	match animation.track_get_type(track):
		Animation.TYPE_POSITION_3D:animation.position_track_insert_key(track,time,pose.origin)
		Animation.TYPE_ROTATION_3D:animation.rotation_track_insert_key(track,time,pose.basis.get_rotation_quaternion())
		Animation.TYPE_SCALE_3D:animation.scale_track_insert_key(track,time,pose.basis.get_scale())
static func channel(animation: Animation,path: NodePath,kind: int,source: Transform3D,target: Transform3D,seconds: float) -> void:
	var track:=animation.find_track(path,kind)
	if track<0:
		track=animation.add_track(kind);animation.track_set_path(track,path)
	var boundary:=false
	for key in animation.track_get_key_count(track):boundary=boundary or is_equal_approx(animation.track_get_key_time(track,key),seconds)
	if not boundary:insert(animation,track,seconds,target)
	insert(animation,track,0.,source)
static func build(player: AnimationPlayer,rig: Skeleton3D,source_rig: Skeleton3D,node_poses: Dictionary,seconds: float=.08,label: String="Death") -> Animation:
	assert(seconds>0. and player.assigned_animation==label and is_zero_approx(player.current_animation_position))
	var original:=player.get_animation(label);var result:=original.duplicate(true) as Animation
	result.length=original.length+seconds;result.loop_mode=Animation.LOOP_NONE
	for track in result.get_track_count():
		for key in range(result.track_get_key_count(track)-1,-1,-1):result.track_set_key_time(track,key,result.track_get_key_time(track,key)+seconds)
	var animation_root:=player.get_node(player.root_node);var rig_path:=str(animation_root.get_path_to(rig))
	for bone in rig.get_bone_count():
		var name:=rig.get_bone_name(bone);var source_bone:=source_rig.find_bone(name);assert(source_bone>=0)
		var path:=NodePath(rig_path+":"+name);var source:=source_rig.get_bone_pose(source_bone);var target:=rig.get_bone_pose(bone)
		for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:channel(result,path,kind,source,target,seconds)
	for path: NodePath in node_poses:
		var node:=animation_root.get_node(path) as Node3D;assert(node!=null)
		for kind in [Animation.TYPE_POSITION_3D,Animation.TYPE_ROTATION_3D,Animation.TYPE_SCALE_3D]:channel(result,path,kind,node_poses[path],node.transform,seconds)
	return result
