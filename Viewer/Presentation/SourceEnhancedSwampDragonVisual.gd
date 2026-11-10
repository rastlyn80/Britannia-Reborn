# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSwampDragonVisual.gd"

const SwampGround := preload("res://Presentation/SourceGroundLookup.gd")

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = control_skin
	animator.mixer_applied.connect(settle_fitted)
	var mounted_idle := str(entry.get("enhanced_mounted_idle", ""))
	if animator.has_animation(mounted_idle):
		animator.get_animation(mounted_idle).loop_mode = Animation.LOOP_LINEAR


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	release_fitted()
	if is_fitted():
		contact.enabled = false
	return true


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	release_fitted()
	var mounted_idle := str(entry.get("enhanced_mounted_idle", ""))
	if moving or native_mount_item == 0 or not animator.has_animation(mounted_idle):
		super.play_gait(moving, speed)
		return
	contact.enabled = true
	animator.speed_scale = 1.0
	if current_clip != mounted_idle:
		current_clip = mounted_idle
		play(mounted_idle, .18)


func _physics_process(delta: float) -> void:
	if fitted_fall.plane.is_empty():
		if is_fitted():
			settle_fitted()
		else:
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
	elif is_fitted() and not dead:
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := SwampGround.minimum_plane_gap(control_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	var relative := global_transform.affine_inverse() * skeleton.global_transform
	return SwampGround.minimum_plane_gap(control_skin, skeleton, relative, Vector3.ZERO, Vector3.UP)
