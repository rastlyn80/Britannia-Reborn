# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CyclopsActionsVisual.gd"

func is_fitted_gesture() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if is_fitted_gesture():
		contact.enabled = false
	return true

func _physics_process(delta: float) -> void:
	if dead or not is_fitted_gesture():
		super._physics_process(delta)

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in source.entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	global_transform = source.global_transform
	var remaining := fall.begin_from_source(self, source, source.fall, source.mallet_shift)
	support_fall()
	return remaining

func settle() -> void:
	super.settle()
	if dead or not is_fitted_gesture():
		return
	var plane := fall.floor_under(self)
	if not plane.has("collider"):
		return
	gesture_model = model.transform
	gesture_adjusted = true
	var normal: Vector3 = plane.normal
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(gesture_model.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := minf(Ground.minimum_plane_gap(body_skin, skeleton, skeleton.global_transform, plane.position, normal),
		Ground.minimum_plane_gap(mallet_skin, skeleton, skeleton.global_transform, plane.position, normal))
	model.global_position.y += (0.003 - gap) / normal.y
	raise_over_steps(plane)
