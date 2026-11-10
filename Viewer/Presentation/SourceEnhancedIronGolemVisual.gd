# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceIronGolemVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed := Transform3D.IDENTITY
var supported := false


func _ready() -> void:
	super._ready()
	fall.skin = Ground.skin_points(model.find_child("Body", true, false), skeleton)
	animator.mixer_applied.connect(settle_fitted)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_support()
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fall.plane.is_empty():
		super._physics_process(delta)


func support_control_plane() -> void:
	if not is_fitted() and fall.plane.is_empty():
		super.support_control_plane()


func restore_support() -> void:
	if supported:
		model.transform = unposed
		supported = false


func settle_fitted() -> void:
	restore_support()
	if not fall.plane.is_empty():
		fall.settle(self)
	elif not dead and is_fitted():
		var plane := fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed = model.transform
		supported = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed.basis.get_scale())
		var gap := Ground.minimum_plane_gap(fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fall.begin_from_source(self, source, source.fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if not fall.plane.is_empty():
		return fall.snapshot_floor(self)
	return Ground.minimum_plane_gap(control_skin, skeleton, global_transform.affine_inverse() * skeleton.global_transform,
		Vector3.ZERO, Vector3.UP)
