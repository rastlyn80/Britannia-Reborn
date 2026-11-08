extends "res://Presentation/HarpyActionsVisual.gd"
## Preserve the displayed pose and timing when a native death takes over.

var entry_pose: Array[Transform3D] = []
var entry_time := 0.0
var entry_length := 0.0

func receive_action(request: Dictionary) -> bool:
	release_gesture_lift()
	return super.receive_action(request)

func begin_death_from(source: Node3D) -> float:
	model.global_position.y -= source.gesture_lift
	var duration := super.begin_death_from(source)
	var continuing: bool = source.dead and source.current_clip == current_clip
	var speed := absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	animator.speed_scale = speed
	action_remaining = duration / speed
	if not continuing:
		animator.advance(0.0)
		animator.seek(0.0, true)
	entry_time = animator.current_animation_position
	entry_length = minf(0.08 * speed, duration)
	if entry_length <= 0.0:
		return action_remaining
	for bone in source.skeleton.get_bone_count():
		entry_pose.append(source.skeleton.get_bone_pose(bone))
	# The scene animates its SourceSpace parent as well as the rig.
	var root := skeleton.find_bone("__root")
	assert(root >= 0 and skeleton.get_bone_parent(root) < 0)
	var root_pose := entry_pose[root]
	var target_space := skeleton.global_position - global_basis * collapse_shift
	var source_space: Vector3 = source.skeleton.global_position - source.global_basis * source.collapse_shift
	root_pose.origin += skeleton.global_basis.inverse() * (source_space - target_space)
	entry_pose[root] = root_pose
	settle_collapse()
	return action_remaining

func settle_collapse() -> void:
	if not entry_pose.is_empty():
		var weight := clampf((animator.current_animation_position - entry_time) / entry_length, 0.0, 1.0)
		if weight >= 1.0:
			entry_pose.clear()
		else:
			for bone in entry_pose.size():
				var pose := entry_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), weight)
				skeleton.set_bone_pose(bone, pose)
	super.settle_collapse()
