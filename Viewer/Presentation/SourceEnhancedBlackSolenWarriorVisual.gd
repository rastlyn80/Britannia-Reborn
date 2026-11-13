# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SolenWarriorActionsVisual.gd"

const Quiet := "BlackSolenWarriorQuietIdle"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var baseline := Transform3D.IDENTITY
var supported := false
var known_warmode := false
var in_combat := false


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	if animator.has_animation(Quiet):
		animator.get_animation(Quiet).loop_mode = Animation.LOOP_LINEAR


func set_native_combat_flags(flags: int) -> void:
	known_warmode = flags >= 0
	in_combat = (flags & 0x40) != 0


func play_gait(moving: bool, speed: float) -> void:
	if moving or not known_warmode or in_combat or not animator.has_animation(Quiet):
		super.play_gait(moving, speed)
	elif not dead and action_remaining <= 0.0 and current_clip != Quiet:
		current_clip = Quiet
		animator.speed_scale = 1.0
		play(Quiet, .16)
	if is_fitted():
		contact.enabled = false


func receive_action(request: Dictionary) -> bool:
	release_support()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	if is_fitted():
		apply_warrior_ground()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func release_support() -> void:
	if supported:
		model.transform = baseline
		supported = false


func apply_warrior_ground() -> void:
	release_support()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif is_fitted() and not support_skin.is_empty():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		baseline = model.transform
		supported = true
		var tilt := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (tilt * source_model_basis).scaled_local(baseline.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()
	else:
		super.apply_warrior_ground()


func begin_death_from(source: Node3D) -> float:
	if source.is_fitted():
		blend_remaining = 0.0
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
