# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceJukaMageActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_fitted()
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		super._physics_process(delta)


func apply_blend_ground() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif not dead and is_fitted() and not support_skin.is_empty():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		contact.base_model_y = model.position.y
		update_landmarks()
	else:
		super.apply_blend_ground()


func release_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

