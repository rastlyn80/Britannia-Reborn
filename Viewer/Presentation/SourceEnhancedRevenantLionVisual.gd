# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveOccurrenceGestureVisual.gd"

const Floor := preload("res://Presentation/SourceGroundLookup.gd")
const Quiet := "RevenantLionQuietStand"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_transform := Transform3D.IDENTITY
var supported := false
var quiet_mode := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = ground_gesture.skin
	contact.modification_processed.disconnect(ground_gesture.support.bind(self))
	contact.modification_processed.connect(support_retained_gesture)
	animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR
	animator.mixer_applied.connect(settle_fitted)


func set_native_combat_flags(flags: int) -> void:
	quiet_mode = flags >= 0 and (flags & 0x40) == 0


func play_gait(moving: bool, speed: float) -> void:
	if moving or not quiet_mode:
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0 and current_clip != Quiet:
		current_clip = Quiet
		animator.speed_scale = 1.0
		play(Quiet, .16)
	if is_fitted():
		contact.enabled = false


func receive_action(request: Dictionary) -> bool:
	release_fitted()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func support_retained_gesture() -> void:
	if not is_fitted():
		ground_gesture.support(self)


func release_fitted() -> void:
	if supported:
		model.transform = fitted_transform
		supported = false


func settle_fitted() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif is_fitted():
		var floor := fitted_fall.floor_under(self)
		var normal: Vector3 = floor.normal
		fitted_transform = model.transform
		supported = true
		var tilt := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (tilt * source_model_basis).scaled_local(fitted_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Floor.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, normal)
		model.global_position.y += (.003 - gap) / normal.y


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
