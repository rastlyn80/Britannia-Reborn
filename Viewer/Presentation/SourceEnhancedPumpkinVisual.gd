# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/JackOLanternVisual.gd"

const Collapse := "EnhancedPumpkinCollapse"
const Timing := preload("res://Presentation/HumanActions.gd")


func receive_action(request: Dictionary) -> bool:
	if request.get("protocol") != "new" or request.get("type") != 3 or 			entry.get("enhanced_selected_fall", "") != Collapse:
		return super.receive_action(request)
	current_clip = Collapse
	dead = true
	contact.enabled = false
	floor_plane = read_floor(self)
	var length := animator.get_animation(Collapse).length
	action_remaining = Timing.duration(request, length)
	animator.speed_scale = 1.0
	animator.play(Collapse, .12, length / action_remaining)
	animator.seek(0.0, false)
	set_meta("native_action", request.duplicate(true))
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.dead or source.current_clip != Collapse:
		return super.begin_death_from(source)
	floor_plane = source.floor_plane if not source.floor_plane.is_empty() else read_floor(source)
	current_clip = Collapse
	var start: float = source.animator.current_animation_position
	var speed := maxf(.001, absf(source.animator.get_playing_speed()))
	animator.play(Collapse, 0.0, speed)
	animator.advance(0.0)
	animator.seek(start, true)
	place_visual()
	action_remaining = maxf(0.0, animator.current_animation_length - start) / speed
	return action_remaining
