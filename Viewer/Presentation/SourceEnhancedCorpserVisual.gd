# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/GiantSpiderActionsVisual.gd"

var resting_model := Transform3D.IDENTITY
var prior_contact := false
var planted := false

func _physics_process(delta: float) -> void:
	restore_contact()
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		super._physics_process(delta)
		return
	var origin := global_position
	var ray := PhysicsRayQueryParameters3D.create(origin + Vector3.UP * .7, origin - Vector3.UP * 1.6, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or hit.normal.y < .75:
		return
	var local_up: Vector3 = (global_basis.inverse() * hit.normal).normalized()
	var alignment := Basis(Quaternion(Vector3.UP, local_up))
	resting_model = model.transform
	prior_contact = contact.enabled
	contact.enabled = false
	planted = true
	model.transform = Transform3D(alignment * source_model_basis.scaled_local(model.scale),
		alignment * resting_model.origin + to_local(hit.position))

func receive_action(request: Dictionary) -> bool:
	restore_contact()
	return super.receive_action(request)

func restore_contact() -> void:
	if planted:
		model.transform = resting_model
		contact.enabled = prior_contact
		planted = false
