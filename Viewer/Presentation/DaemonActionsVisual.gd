extends "res://Presentation/MongbatActionsVisual.gd"
## Carry the displayed flying creature into the matching ground or airborne fall.

var entry_pose: Array[Transform3D] = []
var entry_start := 0.0
var entry_span := 0.0

func begin_death_from(source: Node3D) -> float:
	var continuing: bool = source.dead and source.current_clip in ["Death", "Death2", AIR_COLLAPSE]
	var airborne: bool = source.current_clip in AIRBORNE
	var clip: String = source.current_clip if continuing else (AIR_COLLAPSE if airborne else "Death")
	model.position -= source.collapse_shift
	model.global_position.y -= source.gesture_lift
	start_collapse(clip, support_plane(source))
	var elapsed: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	animator.play(clip, 0.0, speed)
	animator.advance(0.0)
	animator.seek(elapsed, true)
	if continuing or airborne:
		entry_start = elapsed
		entry_span = minf((0.08 if continuing else 0.12) * speed, animator.current_animation_length - elapsed)
		if entry_span > 0.0:
			for bone in source.skeleton.get_bone_count():
				entry_pose.append(source.skeleton.get_bone_pose(bone))
			settle_collapse()
	action_remaining = maxf(0.0, animator.current_animation_length - elapsed) / speed
	return action_remaining

func settle_collapse() -> void:
	if not entry_pose.is_empty():
		var weight := clampf((animator.current_animation_position - entry_start) / entry_span, 0.0, 1.0)
		if weight < 1.0:
			for bone in entry_pose.size():
				skeleton.set_bone_pose(bone, entry_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), weight))
		else:
			entry_pose.clear()
	super.settle_collapse()
