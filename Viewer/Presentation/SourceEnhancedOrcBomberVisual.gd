# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OrcBomberActionsVisual.gd"

const Floor := preload("res://Presentation/SourceGroundLookup.gd")
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false


func _ready() -> void:
	super._ready()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = Floor.skin_points(body, skeleton)
	animator.mixer_applied.connect(settle_fitted)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_fitted()
	if is_fitted():
		contact.enabled = false
	return true


func begin_bomb_effect(effect: Dictionary) -> Variant:
	var origin: Variant = super.begin_bomb_effect(effect)
	if origin != null:
		release_fitted()
	return origin


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func support_control_plane() -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		super.support_control_plane()


func release_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func settle_fitted() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif not dead and is_fitted():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Floor.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	return Floor.minimum_plane_gap(control_skin, skeleton, global_transform.affine_inverse() * skeleton.global_transform,
		Vector3.ZERO, Vector3.UP)

