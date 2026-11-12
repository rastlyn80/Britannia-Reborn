# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CougarTerrainFall.gd"

var allowed_depth := 0.0


func begin_grave(actor: Node3D, source: Node3D) -> float:
	split = source.contact.use_local_planes
	if split:
		remember_floor(source, source.contact.ground)
		initial_depth = maxf(0.0, .002 - super.step_gap(source.skeleton))
	var duration := begin_from_source(actor, source, source.grave_fall, false, not split)
	blend_length = minf(.48, duration)
	settle(actor)
	return duration


func settle(actor: Node3D) -> void:
	if split:
		var progress := smoothstep(0.0, blend_length, actor.animator.current_animation_position) if blend_length > 0.0 else 0.0
		allowed_depth = initial_depth * (1.0 - progress)
	super.settle(actor)
	allowed_depth = 0.0


func step_gap(rig: Skeleton3D) -> float:
	return super.step_gap(rig) + allowed_depth
