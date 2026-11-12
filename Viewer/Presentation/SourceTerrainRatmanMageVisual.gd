# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RatmanMageActionsVisual.gd"

const Footing := preload("res://Presentation/SourceRatmanStepContact.gd")


func _ready() -> void:
	super._ready()
	Footing.attach(self)
	contact.modification_processed.connect(update_landmarks)


func play_gait(moving: bool, speed: float) -> void:
	contact.resume_gait(moving)
	super.play_gait(moving, speed)

func receive_action(request: Dictionary) -> bool:
	var accepted := super.receive_action(request)
	if accepted and dead:
		contact.prepare_death()
	return accepted


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self) if not contact.death.plane.is_empty() else super.corpse_snapshot_floor()
