# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourcePreservingDistinctActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_model := Transform3D.IDENTITY
var posed_on_terrain := false


func _ready() -> void:
	super._ready()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(body, skeleton)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	restore_fitted_support()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	restore_fitted_support()
	if not is_fitted():
		super._physics_process(delta)
	elif not dead:
		place_fitted_pose()


func support_control_plane() -> void:
	if not is_fitted():
		super.support_control_plane()


func restore_fitted_support() -> void:
	if posed_on_terrain:
		model.transform = unposed_model
		posed_on_terrain = false


func settle_action() -> void:
	restore_fitted_support()
	if dead and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
		return
	super.settle_action()
	if not dead and is_fitted() and not fitted_fall.skin.is_empty():
		place_fitted_pose()


func place_fitted_pose() -> void:
	var plane := fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	var hover: bool = entry.kind == "changling"
	unposed_model = model.transform
	posed_on_terrain = true
	if not hover:
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_model.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
	var correction := .003 - gap
	model.global_position.y += (maxf(0.0, correction) if hover else correction) / normal.y
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted() or not source.fitted_fall.plane.is_empty():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
