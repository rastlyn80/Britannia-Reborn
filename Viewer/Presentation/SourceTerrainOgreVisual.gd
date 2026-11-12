# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedFieldVisual.gd"

const Footing := preload("res://Presentation/SourceSkeletonGround.gd")
const Resting := ["Fidget", "ShoulderScratch", "OgreLookDown", "OgreBrowGuard", "OgreReadyLean"]
var moving_for_gait := false


func _ready() -> void:
	super._ready()
	Footing.attach(self)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	moving_for_gait = moving
	if moving and current_clip in Resting:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func receive_action(request: Dictionary) -> bool:
	if not dead and moving_for_gait and request.get("protocol") == "classic" and request.get("action") in [1, 17, 18]:
		return true
	var accepted := super.receive_action(request)
	if accepted and dead:
		contact.prepare_death()
	return accepted


func settle_collapse() -> void:
	pass


func begin_death_from(source: Node3D) -> float:
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	return contact.death.snapshot_floor(self)
