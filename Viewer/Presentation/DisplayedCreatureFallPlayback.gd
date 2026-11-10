# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureFallPlayback.gd"
## Start a fall from the displayed clip when it differs from the requested action.

func begin_from_display(actor: Node3D, source: Node3D, previous: RefCounted,
		displayed_clip: String, in_flight: bool) -> float:
	var continuing: bool = source.dead and (displayed_clip in FALLS or displayed_clip == "AirDeath2")
	var airborne: bool = in_flight and actor.animator.has_animation("AirDeath")
	actor.model.position -= previous.shift
	actor.current_clip = displayed_clip if continuing else ("AirDeath" if airborne else "Death")
	remember_floor(actor, previous.plane if previous.plane.has("collider") else floor_under(source))
	var time: float = source.animator.current_animation_position if continuing else 0.0
	var speed: float = absf(source.animator.get_playing_speed()) if continuing else 1.0
	if is_zero_approx(speed):
		speed = 1.0
	actor.animator.play(actor.current_clip, 0.0, speed)
	actor.animator.advance(0.0)
	actor.animator.seek(time, true)
	if continuing or airborne:
		blend_start = time
		blend_length = minf((0.08 if continuing else 0.12) * speed, actor.animator.current_animation_length - time)
		if blend_length > 0.0:
			for bone in source.skeleton.get_bone_count():
				blend_pose.append(source.skeleton.get_bone_pose(bone))
			settle(actor)
	actor.action_remaining = maxf(0.0, actor.animator.current_animation_length - time) / speed
	return actor.action_remaining
