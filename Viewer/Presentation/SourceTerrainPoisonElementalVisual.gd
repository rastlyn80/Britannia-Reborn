# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedPoisonElementalVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(support_death_blend)
	animator.mixer_applied.disconnect(gesture.release.bind(self))
	animator.mixer_applied.disconnect(fitted_fall.settle.bind(self))
	contact.modification_processed.disconnect(gesture.support.bind(self))
	terrain.bind(self, Vector2(1.3, 1.55))
	animator.mixer_applied.connect(terrain.settle.bind(self))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		settle_living()


func settle_living() -> void:
	if dead or terrain.plane.is_empty():
		return
	if entry.get("archive_align_gesture_slope", false) and current_clip in entry.get("archive_grounded_gestures", []):
		var normal := (global_basis.inverse() * Vector3(terrain.plane.normal)).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, normal)) * source_model_basis).scaled_local(model.scale)
	terrain.settle_live(.0005)
	update_landmarks()


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
