# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RuneBeetleActionsVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const CombatIdle := "RuneBeetleQuietGuard"
const PeaceIdle := "RuneBeetlePeaceWatch"
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_transform := Transform3D.IDENTITY
var fitted_support := false
var native_flags := -1


func _ready() -> void:
	super._ready()
	fitted_fall.skin = gesture.skin
	animator.mixer_applied.connect(settle_fitted)


func set_native_combat_flags(flags: int) -> void:
	native_flags = flags


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	restore_fitted()
	if is_fitted():
		contact.enabled = false
	return true


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	if moving or native_flags < 0:
		restore_fitted()
		super.play_gait(moving, speed)
		return
	var idle := CombatIdle if (native_flags & 0x40) != 0 else PeaceIdle
	contact.enabled = false
	animator.speed_scale = 1.0
	if current_clip != idle or not animator.is_playing():
		current_clip = idle
		play(idle, .18)
	elif animator.current_animation_position >= animator.current_animation_length - .015:
		animator.seek(0.0, true)


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func restore_fitted() -> void:
	if fitted_support:
		model.transform = unposed_transform
		fitted_support = false


func settle_fitted() -> void:
	restore_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	elif is_fitted() and not dead:
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		unposed_transform = model.transform
		fitted_support = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(unposed_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

