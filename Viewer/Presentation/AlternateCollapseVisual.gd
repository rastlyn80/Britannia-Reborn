extends "res://Presentation/GiantSpiderActionsVisual.gd"
## Carry the displayed alternate collapse through the native corpse handoff.

var entry_pose: Array[Transform3D] = []
var entry_start := 0.0
var entry_span := 0.0

func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != "Death2":
		return super.begin_death_from(source)
	model.position -= source.collapse_shift
	collapse_plane = source.collapse_plane
	if not collapse_plane.has("collider"):
		sample_collapse_ground()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	collapse_skin = Ground.skin_points(mesh, skeleton)
	current_clip = "Death2"
	var elapsed: float = source.animator.current_animation_position
	var speed := absf(source.animator.get_playing_speed())
	if is_zero_approx(speed):
		speed = 1.0
	animator.play(current_clip, 0.0, speed)
	animator.advance(0.0)
	animator.seek(elapsed, true)
	entry_start = elapsed
	entry_span = minf(0.08 * speed, animator.current_animation_length - elapsed)
	if entry_span > 0.0:
		var needs_blend := false
		for bone in source.skeleton.get_bone_count():
			var displayed: Transform3D = source.skeleton.get_bone_pose(bone)
			entry_pose.append(displayed)
			needs_blend = needs_blend or not displayed.is_equal_approx(skeleton.get_bone_pose(bone))
		if needs_blend:
			settle_collapse()
		else:
			entry_pose.clear()
	action_remaining = maxf(0.0, animator.current_animation_length - elapsed) / speed
	return action_remaining

func settle_collapse() -> void:
	if not entry_pose.is_empty():
		var weight := clampf((animator.current_animation_position - entry_start) / entry_span, 0.0, 1.0)
		if weight >= 1.0:
			entry_pose.clear()
		else:
			for bone in entry_pose.size():
				var pose := entry_pose[bone].interpolate_with(skeleton.get_bone_pose(bone), weight)
				skeleton.set_bone_pose(bone, pose)
	super.settle_collapse()
