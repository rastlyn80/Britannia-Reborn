# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SolenWorkerActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_model := Transform3D.IDENTITY
var fitted_supported := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	animator.mixer_applied.connect(settle_fitted_pose)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	restore_fitted_model()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		restore_fitted_model()
		super._physics_process(delta)


func restore_fitted_model() -> void:
	if fitted_supported:
		model.transform = unposed_model
		fitted_supported = false


func settle_fitted_pose() -> void:
	restore_fitted_model()
	if dead and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif not dead and is_fitted():
		var floor := fitted_fall.floor_under(self)
		var normal: Vector3 = floor.normal
		unposed_model = model.transform
		fitted_supported = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_model.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted() or not source.fitted_fall.plane.is_empty():
		blend_remaining = 0.0
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	global_transform = source.global_transform
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
