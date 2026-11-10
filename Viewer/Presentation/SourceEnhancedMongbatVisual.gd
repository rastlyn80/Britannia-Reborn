# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MongbatActionsVisual.gd"

const Ascent := "MongbatUnfoldAndRise"
var enhanced_ground := preload("res://Presentation/ArchiveGestureGround.gd").new()

func _ready() -> void:
	super._ready()
	enhanced_ground.bind(self)

func _physics_process(delta: float) -> void:
	enhanced_ground.release(self)
	super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	var optional: Array = source.entry.get("archive_grounded_gestures", [])
	if not source.dead and source.current_clip in optional:
		var left_ground: bool = source.current_clip != Ascent or source.animator.current_animation_position > .36
		if left_ground:
			start_collapse(AIR_COLLAPSE, support_plane(source))
			var duration := animator.get_animation(AIR_COLLAPSE).length
			action_remaining = duration
			play(AIR_COLLAPSE, .08)
			return duration
	return super.begin_death_from(source)
