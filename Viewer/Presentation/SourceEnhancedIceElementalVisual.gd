# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/IceElementalActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_transform := Transform3D.IDENTITY
var fitted_transform_active := false


func _ready() -> void:
	super._ready()
	var shell := model.find_child("IceCrystalShell", true, false) as MeshInstance3D
	assert(shell != null or not entry.has("enhanced_source_action_groups"))
	fitted_fall.skin = combined_skin(Ground.skin_points(shell, skeleton)) if shell != null else support_skin


func combined_skin(shell: Dictionary) -> Dictionary:
	var result := support_skin.duplicate(true)
	var offset: int = result.bones.size()
	result.bones.append_array(shell.bones)
	result.bind_poses.append_array(shell.bind_poses)
	for surface: Dictionary in shell.surfaces:
		var part := surface.duplicate()
		var bindings: PackedInt32Array = surface.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		part.bindings = bindings
		result.surfaces.append(part)
	return result


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
	if is_fitted():
		apply_ice_ground()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func release_fitted_pose() -> void:
	if fitted_transform_active:
		model.transform = fitted_transform
		fitted_transform_active = false


func apply_ice_ground() -> void:
	release_fitted_pose()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif not dead and is_fitted():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		fitted_transform = model.transform
		fitted_transform_active = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(fitted_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()
	else:
		super.apply_ice_ground()
		if dead and not fall.plane.is_empty():
			support_retained_fall()


func support_retained_fall() -> void:
	var normal: Vector3 = fall.plane.normal
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, fall.plane.position, normal)
	var before := model.position
	model.global_position.y += maxf(0.0, .002 - gap) / normal.y
	fall.shift += model.position - before


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	var relative := global_transform.affine_inverse() * skeleton.global_transform
	return Ground.minimum_plane_gap(fitted_fall.skin, skeleton, relative, Vector3.ZERO, Vector3.UP)
