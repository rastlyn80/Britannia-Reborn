# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")


func _ready() -> void:
	super._ready()
	Footing.attach(self)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


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
	return contact.death.snapshot_floor(self)
