extends "res://Presentation/HumanVisual.gd"
## A native human-NPC death snapshot owns its materials, wardrobe and clip state.
var native_body:=0
var native_hue:=0
var dead:=true
var intro_seconds:=.08
var landing_active:=false
var landing_from:=Transform3D.IDENTITY
var landing_to:=Transform3D.IDENTITY
func apply_landing() -> void:
	if not landing_active:return
	# Preserve the displayed saddle pose at time0, then reach the native ground
	# anchor during the collapse instead of hovering until corpse replacement.
	var blend:=smoothstep(intro_seconds,.45,animator.current_animation_position)
	global_transform=landing_from.interpolate_with(landing_to,blend)
func begin_from(source: Node3D,displayed: Dictionary={},landing: Transform3D=Transform3D.IDENTITY) -> float:
	var original: Animation=animator.get_animation("Death")
	var animation:=original.duplicate(true) as Animation
	animation.length=original.length+intro_seconds
	var source_rig: Skeleton3D=displayed.get("rig",source.skeleton)
	if not displayed.is_empty():
		global_transform=displayed.global_transform;model.transform=displayed.model_transform
		landing_from=global_transform;landing_to=landing;landing_active=true
		animator.mixer_applied.connect(apply_landing)
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
	if source_rig!=source.skeleton:source_rig.free()
	var library:=animator.get_animation_library("").duplicate()
	animator.stop(true);animator.remove_animation_library("");animator.add_animation_library("",library)
	library.remove_animation("Death");library.add_animation("Death",animation)
	current_clip="Death";action_clip="Death";action_duration=animation.length;action_cycles=1
	animator.play("Death",0.);animator.seek(0.,true)
	return animation.length
