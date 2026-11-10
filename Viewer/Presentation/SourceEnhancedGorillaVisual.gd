# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MeasuredCreatureVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unplanted_model := Transform3D.IDENTITY
var planted := false

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func _physics_process(delta: float) -> void:
	restore_measured_ground()
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		super._physics_process(delta)
		return
	var support := fitted_fall.floor_under(self)
	if not support.has("collider"):
		return
	var local_normal: Vector3 = (global_basis.inverse() * support.normal).normalized()
	var slope := Basis(Quaternion(Vector3.UP, local_normal))
	unplanted_model = model.transform
	planted = true
	model.transform = Transform3D((slope * source_model_basis).scaled_local(model.scale),
		slope * unplanted_model.origin + to_local(support.position))
	update_landmarks()

func receive_action(request: Dictionary) -> bool:
	restore_measured_ground()
	if not super.receive_action(request):
		return false
	fitted_fall.accept_action(self)
	if current_clip in entry.get("archive_grounded_gestures", []):
		contact.enabled = false
	return true

func restore_measured_ground() -> void:
	if planted:
		model.transform = unplanted_model
		planted = false

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return fitted_fall.begin_from(self, source, source.fitted_fall)

func corpse_snapshot_floor() -> float:
	return fitted_fall.snapshot_floor(self)
