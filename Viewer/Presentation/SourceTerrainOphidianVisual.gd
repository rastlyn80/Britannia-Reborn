# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedOphidianVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(settle_armed_fall)
	animator.mixer_applied.disconnect(apply_fitted_pose)
	contact.modification_processed.disconnect(support_fitted_pose)
	terrain.bind(self, Vector2(2.3, 2.3))
	terrain.skin = fitted_fall.skin
	animator.mixer_applied.connect(terrain.settle.bind(self))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	terrain.sample()
	super._physics_process(delta)
	if not contact.enabled:
		settle_living()


func settle_living() -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	if current_clip in GROUNDED or current_clip in entry.get("archive_grounded_gestures", []):
		fit_grounded_gesture()
	terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
