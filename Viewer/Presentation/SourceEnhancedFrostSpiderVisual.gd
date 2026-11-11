# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/BlackWidowActionsVisual.gd"

const Quiet := "FrostSpiderQuietRest"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var quiet_mode := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = gesture_skin


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
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func _physics_process(delta: float) -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		super._physics_process(delta)


func support_gesture() -> void:
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		return
	if not is_fitted():
		super.support_gesture()
		return
	restore_gesture_model()
	var plane := fitted_fall.floor_under(self)
	var normal: Vector3 = plane.normal
	gesture_model = model.transform
	gesture_adjusted = true
	var tilt := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (tilt * source_model_basis).scaled_local(gesture_model.basis.get_scale())
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(gesture_skin, skeleton, skeleton.global_transform, plane.position, normal)
	model.global_position.y += (.003 - gap) / normal.y


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if fitted_fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	return fitted_fall.snapshot_floor(self)
