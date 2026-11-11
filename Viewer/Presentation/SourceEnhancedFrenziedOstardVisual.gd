# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceRigMountVisual.gd"

const Floor := preload("res://Presentation/SourceGroundLookup.gd")
const Seated := ["FrenziedOstardSeatedIdle", "FrenziedOstardSeatedWalk", "FrenziedOstardSeatedRun"]
const Quiet := ["FrenziedOstardQuietIdle", "FrenziedOstardPeaceWalk", "Run"]
const MountedItem := 0x3ea4

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var base_transform := Transform3D.IDENTITY
var supported := false
var quiet_mode := false


func mount_fittings() -> Dictionary:
	return {"proportions": Vector3.ONE, "saddle": Vector3(0, 1.24, -.05), "mouth": Vector3(0, 1.85, .70),
		"seat_bone": "spine1", "mouth_bone": "head", "stirrup": Vector3(.29, -.62, .12)}


func _ready() -> void:
	super._ready()
	fitted_fall.skin = control_skin
	animator.mixer_applied.connect(settle_fitted)


func apply_identity(body: int, value: int, item: int = 0) -> void:
	super.apply_identity(body, value, item)
	set_meta("equine_profile", {"style": "frenzied", "ethereal": false})
	reins.visible = item == MountedItem and not dead


func set_native_combat_flags(flags: int) -> void:
	quiet_mode = flags >= 0 and (flags & 0x40) == 0


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip == "LieDown":
		action_remaining = 0.0
	if dead or action_remaining > 0.0:
		return
	var mounted := native_mount_item == MountedItem
	if not mounted and not quiet_mode:
		super.play_gait(moving, speed)
		return
	var stage := 0 if not moving else 2 if speed > 3.6 else 1
	var clip: String = Seated[stage] if mounted else Quiet[stage]
	if current_clip == "LieDown" and not moving:
		return
	contact.enabled = clip not in entry.get("archive_grounded_gestures", [])
	if current_clip != clip:
		current_clip = clip
		play(clip, .18)
	animator.speed_scale = clampf(speed / (5.5 if stage == 2 else 1.8), .65, 1.65) if moving else 1.0


func receive_action(request: Dictionary) -> bool:
	release_fitted()
	if not super.receive_action(request):
		return false
	if is_fitted():
		contact.enabled = false
	return true


func is_fitted() -> bool:
	return not dead and current_clip in entry.get("archive_grounded_gestures", [])


func _physics_process(delta: float) -> void:
	if is_fitted():
		settle_fitted()
	elif fitted_fall.plane.is_empty():
		super._physics_process(delta)


func support_control_plane() -> void:
	if not is_fitted() and fitted_fall.plane.is_empty():
		super.support_control_plane()


func release_fitted() -> void:
	if supported:
		model.transform = base_transform
		supported = false


func settle_fitted() -> void:
	release_fitted()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	elif is_fitted():
		var plane := fitted_fall.floor_under(self)
		var normal: Vector3 = plane.normal
		base_transform = model.transform
		supported = true
		var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
		model.basis = (slope * source_model_basis).scaled_local(base_transform.basis.get_scale())
		skeleton.force_update_all_bone_transforms()
		var gap := Floor.minimum_plane_gap(control_skin, skeleton, skeleton.global_transform, plane.position, normal)
		model.global_position.y += (.003 - gap) / normal.y
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	reins.hide()
	if source.is_fitted():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	if not fitted_fall.plane.is_empty():
		return fitted_fall.snapshot_floor(self)
	var relative := global_transform.affine_inverse() * skeleton.global_transform
	return Floor.minimum_plane_gap(control_skin, skeleton, relative, Vector3.ZERO, Vector3.UP)
