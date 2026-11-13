# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBlackSolenWorkerVisual.gd"

var terrain := preload("res://Presentation/SourceSolenWorkerTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(settle_worker_fall)
	terrain.bind(self, Vector2(1.6, 1.5))
	animator.mixer_applied.connect(settle_collapse)
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		settle_living()


func settle_fitted_pose() -> void:
	terrain.release_live()
	super.settle_fitted_pose()
	if not contact.enabled:
		settle_living()


func settle_living() -> void:
	if dead or terrain.plane.is_empty():
		return
	var normal: Vector3 = terrain.plane.normal
	if terrain.split or (current_clip in ["Attack2", "LieDown"] and normal.y < .999):
		terrain.settle_live(.0035)
		update_landmarks()


func settle_collapse() -> void:
	if dead and not terrain.plane.is_empty():
		terrain.settle(self)
		update_landmarks()


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	blend_remaining = 0.0
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
