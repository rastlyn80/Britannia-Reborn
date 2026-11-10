# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BlackWidowActionsVisual.gd"

const Unfold := "GiantBlackWidowUnfold"
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var recovering_clip := ""


func _ready() -> void:
	super._ready()
	fitted_fall.skin = gesture_skin


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	var interrupted := growth.active and current_clip == Unfold
	if not super.receive_action(request):
		return false
	recovering_clip = current_clip if interrupted and current_clip != Unfold else ""
	if is_fitted() or not recovering_clip.is_empty():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if not is_fitted() and not is_recovering() and fitted_fall.plane.is_empty():
		super._physics_process(delta)


func support_gesture() -> void:
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		return
	var recovering := not dead and growth.apply(self, Unfold)
	if dead or (not is_fitted() and not recovering and not is_recovering()):
		super.support_gesture()
		return
	restore_gesture_model()
	var plane := fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	gesture_model = model.transform
	gesture_adjusted = true
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(gesture_model.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (.003 - gap) / normal.y


func is_recovering() -> bool:
	return not recovering_clip.is_empty() and recovering_clip == current_clip and action_remaining > 0.0


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted() or source.growth.active or source.is_recovering():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if fitted_fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	return fitted_fall.snapshot_floor(self)

