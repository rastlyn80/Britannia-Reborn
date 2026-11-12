# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedZombieVisual.gd"

const Footing := preload("res://Presentation/SourceZombieGround.gd")
const GraveFall := preload("res://Presentation/SourceZombieGraveFall.gd")
var zombie_grave := GraveFall.new()
var moving_for_gait := false


func _init() -> void:
	grave_fall = zombie_grave


func _ready() -> void:
	super._ready()
	Footing.attach_zombie(self)


func _physics_process(_delta: float) -> void:
	if not dead:
		contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	moving_for_gait = moving
	contact.resume_gait(moving)
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
	if source.current_clip == GraveRise:
		return zombie_grave.begin_grave(self, source)
	return contact.death.enter(self, source)


func corpse_snapshot_floor() -> float:
	if not grave_fall.plane.is_empty():
		return grave_fall.snapshot_floor(self)
	return contact.death.snapshot_floor(self)
