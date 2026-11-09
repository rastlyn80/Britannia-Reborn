extends "res://Presentation/SourceGazerLarvaVisual.gd"
## An explicit Classic fall may already be playing when the death packet arrives.

var displayed_pose: Array[Transform3D] = []
var entry_clock := 0.0
var entry_span := 0.0

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != "Death":
		return super.begin_death_from(source)

	var previous: AnimationPlayer = source.animator
	var death := animator.get_animation("Death")
	var speed := absf(previous.get_playing_speed())
	if is_zero_approx(speed):
		speed = 1.0
	entry_clock = clampf(previous.current_animation_position, 0.0, death.length)
	entry_span = minf(DEATH_ENTRY_SECONDS * speed, death.length - entry_clock)
	animator.stop()
	animator.speed_scale = 1.0
	animator.play("Death", 0.0, speed)
	animator.advance(0.0)
	animator.seek(entry_clock, true)
	if entry_span > 0.0:
		for bone in skeleton.get_bone_count():
			displayed_pose.append(source.skeleton.get_bone_pose(bone))
		animator.mixer_applied.connect(blend_displayed_pose)
		blend_displayed_pose()
	current_clip = "Death"
	action_remaining = (death.length - entry_clock) / speed
	return action_remaining

func blend_displayed_pose() -> void:
	var weight := clampf((animator.current_animation_position - entry_clock) / entry_span, 0.0, 1.0)
	if weight >= 1.0:
		animator.mixer_applied.disconnect(blend_displayed_pose)
		displayed_pose.clear()
		return
	for bone in displayed_pose.size():
		var pose := displayed_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), weight)
		skeleton.set_bone_pose(bone, pose)
	skeleton.force_update_all_bone_transforms()
