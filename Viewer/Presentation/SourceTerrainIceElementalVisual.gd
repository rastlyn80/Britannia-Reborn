# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedIceElementalVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var continuing_fall := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.2, 2.1))
	terrain.skin = fitted_fall.skin
	contact.modification_processed.connect(settle_contact)


func _physics_process(delta: float) -> void:
	if not dead:
		terrain.release_live()
		terrain.sample()
	super._physics_process(delta)


func apply_ice_ground() -> void:
	if terrain.actor == null:
		super.apply_ice_ground()
		return
	if continuing_fall:
		settle_fall()
		return
	terrain.release_live()
	model.position -= terrain.shift
	terrain.shift = Vector3.ZERO
	super.apply_ice_ground()
	if dead:
		settle_fall()
	elif not contact.enabled:
		settle_living()


func settle_contact() -> void:
	if contact.enabled:
		terrain.live_lift = 0.0
		settle_living()


func settle_living() -> void:
	terrain.settle_live(.0005)
	update_landmarks()


func settle_fall() -> void:
	if animator.current_animation_position > 0.0:
		terrain.settle(self)
		update_landmarks()


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	terrain.split = source.terrain.split
	terrain.remember_floor(self, source.terrain.plane if not source.terrain.plane.is_empty() else terrain.floor_under(self))
	continuing_fall = source.dead
	if continuing_fall:
		return terrain.begin_from_source(self, source, source.terrain, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
