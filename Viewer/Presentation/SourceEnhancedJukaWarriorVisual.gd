# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceJukaVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin


func is_fitted(clip: String) -> bool:
	return clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if is_fitted(current_clip):
		# Keep the kick foot airborne and support the pose using its planted foot.
		contact.enabled = false
	return true


func apply_blend_ground() -> void:
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
		return
	if not is_fitted(animator.assigned_animation):
		super.apply_blend_ground()
		return
	if support_skin.is_empty():
		return
	var floor := fitted_fall.floor_under(self)
	var normal: Vector3 = floor.normal
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(model.scale)
	model.position.y = source_model_position.y
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, normal)
	model.global_position.y += (.003 - gap) / normal.y
	contact.base_model_y = model.position.y
	update_landmarks()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if is_fitted(current_clip):
		apply_blend_ground()


func begin_death_from(source: Node3D) -> float:
	if not is_fitted(source.current_clip):
		play("Death", .08)
		return animator.get_animation("Death").length
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
