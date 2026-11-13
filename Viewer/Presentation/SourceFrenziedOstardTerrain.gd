# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceCreatureTreadTerrain.gd"


func prepare(visual: Node3D) -> void:
	bind(visual, Vector2(1.25, 1.8))
	visual.contact.modification_processed.connect(ground_pose)
	visual.animator.mixer_applied.connect(ground_pose)


func ground_pose() -> void:
	if actor.dead and not plane.is_empty():
		if actor.animator.current_animation_position > 0.0 or not blend_pose.is_empty():
			settle(actor)
	elif not actor.dead:
		settle_live(.0005)


func begin_fall(source: Node3D) -> float:
	actor.dead = true
	actor.reins.hide()
	actor.contact.enabled = false
	actor.contact.active = false
	actor.model.transform = source.model.transform
	split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return begin_from_source(actor, source, previous, false)
