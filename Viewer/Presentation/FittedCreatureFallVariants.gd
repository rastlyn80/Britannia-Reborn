# SPDX-License-Identifier: GPL-3.0-or-later
extends RefCounted

const Timing := preload("res://Presentation/HumanActions.gd")


static func consume(actor: Node3D, request: Dictionary) -> bool:
	if request.get("protocol") != "new" or request.get("type") != 3:
		return false
	var clip: String = actor.entry.get("enhanced_selected_fall", "")
	if clip.is_empty() or not actor.animator.has_animation(clip):
		return false
	actor.terrain.release_live()
	actor.current_clip = clip
	actor.dead = true
	actor.contact.enabled = false
	var length: float = actor.animator.get_animation(clip).length
	actor.action_remaining = Timing.duration(request, length)
	actor.animator.speed_scale = 1.0
	actor.animator.play(clip, .12, length / actor.action_remaining)
	actor.animator.seek(0.0, false)
	actor.terrain.prepare_collapse()
	actor.set_meta("native_action", request.duplicate(true))
	return true


static func handoff(actor: Node3D, source: Node3D) -> float:
	actor.global_transform = source.global_transform
	actor.terrain.split = source.terrain.split
	actor.model.position -= source.terrain.shift
	actor.current_clip = source.current_clip
	actor.terrain.remember_floor(actor, source.terrain.plane if not source.terrain.plane.is_empty()
		else actor.terrain.floor_under(source))
	var time: float = source.animator.current_animation_position
	var speed := maxf(.001, absf(source.animator.get_playing_speed()))
	actor.animator.play(actor.current_clip, 0.0, speed)
	actor.animator.advance(0.0)
	actor.animator.seek(time, true)
	var remaining: float = actor.animator.current_animation_length - time
	actor.terrain.blend_start = time
	actor.terrain.blend_length = minf(.08 * speed, remaining)
	if actor.terrain.blend_length > 0.0:
		for bone in source.skeleton.get_bone_count():
			actor.terrain.blend_pose.append(source.skeleton.get_bone_pose(bone))
		actor.terrain.settle(actor)
	actor.action_remaining = maxf(0.0, remaining) / speed
	return actor.action_remaining
