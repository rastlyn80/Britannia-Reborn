# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/TitanActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_transform := Transform3D.IDENTITY
var fitted_transform_active := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = reference_skin
	animator.mixer_applied.connect(settle_fitted)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_fitted_pose()
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		release_fitted_pose()
		super._physics_process(delta)


func release_fitted_pose() -> void:
	if fitted_transform_active:
		model.transform = fitted_transform
		fitted_transform_active = false


func settle_fitted() -> void:
	release_fitted_pose()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif not dead and is_fitted():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		fitted_transform = model.transform
		fitted_transform_active = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(fitted_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(reference_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (0.003 - gap) / normal.y


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted():
		return super.begin_death_from(source)
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
