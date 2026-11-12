# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedGhoulVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")


func _ready() -> void:
	super._ready()
	Footing.attach(self)
	contact.modification_processed.connect(update_landmarks)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in ["Fidget", "Fidget2"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	fitted_fall.plane = {}
	if dead:
		contact.prepare_death()
	return true


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)
