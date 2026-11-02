extends "res://Presentation/HumanVisual.gd"
## A native human-NPC death snapshot owns its materials, wardrobe and clip state.
var native_body:=0
var native_hue:=0
var dead:=true
var intro_seconds:=.08
func begin_from(source: Node3D) -> float:
	var original: Animation=animator.get_animation("Death")
	var animation:=original.duplicate(true) as Animation
	animation.length=original.length+intro_seconds
	var source_rig: Skeleton3D=source.skeleton
	for track in animation.get_track_count():
		for key in range(animation.track_get_key_count(track)-1,-1,-1):
			animation.track_set_key_time(track,key,animation.track_get_key_time(track,key)+intro_seconds)
		var path:=animation.track_get_path(track)
		if path.get_subname_count()==0:continue
		var bone:=source_rig.find_bone(str(path.get_subname(0)))
		if bone<0:continue
		if animation.track_get_type(track)==Animation.TYPE_POSITION_3D:
			animation.position_track_insert_key(track,0.,source_rig.get_bone_pose_position(bone))
		elif animation.track_get_type(track)==Animation.TYPE_ROTATION_3D:
			animation.rotation_track_insert_key(track,0.,source_rig.get_bone_pose_rotation(bone))
		elif animation.track_get_type(track)==Animation.TYPE_SCALE_3D:
			animation.scale_track_insert_key(track,0.,source_rig.get_bone_pose_scale(bone))
	var library:=animator.get_animation_library("").duplicate()
	animator.stop(true);animator.remove_animation_library("");animator.add_animation_library("",library)
	library.remove_animation("Death");library.add_animation("Death",animation)
	current_clip="Death";action_clip="Death";action_duration=animation.length;action_cycles=1
	animator.play("Death",0.);animator.seek(0.,true)
	return animation.length
