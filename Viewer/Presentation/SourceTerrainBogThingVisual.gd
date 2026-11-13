# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedClockBogThingVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()
var complete_footprint := false
var beginning_fall := false


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.4, 2.1))


func ground_hit(point: Vector3) -> Dictionary:
	var hit := super.ground_hit(point)
	if hit.is_empty():
		complete_footprint = false
	return hit


func _physics_process(delta: float) -> void:
	if not dead:
		terrain.release_live()
		terrain.sample()
		complete_footprint = not footprint.is_empty()
	super._physics_process(delta)
	if not dead and complete_footprint:
		terrain.settle_live(.002)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	terrain.sample()
	terrain.prepare_collapse()
	beginning_fall = true
	var duration := super.begin_death_from(source)
	beginning_fall = false
	settle_fall()
	return duration


func settle_fall() -> void:
	if not beginning_fall and animator.assigned_animation == "Death" and animator.current_animation_position > 0.0:
		terrain.settle(self)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
