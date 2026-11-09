# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

var fall := preload("res://Presentation/SourceSpaceFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	contact.align_skinned_soles = true
	contact.iterations = 8
	animator.mixer_applied.connect(fall.settle.bind(self))

func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted:
		fall.accept_action(self)
	return accepted

func begin_death_from(source: Node3D) -> float:
	var grounded_shift: Vector3 = Vector3.ZERO
	if source.ground_gesture.applied:
		grounded_shift = source.model.position - source.ground_gesture.restore_pose.origin
	return fall.begin_from_source(self, source, source.fall, grounded_shift)

func corpse_snapshot_floor() -> float:
	return INF if fall.plane.is_empty() else fall.snapshot_floor(self)
