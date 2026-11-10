# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/DaemonActionsVisual.gd"

const AirClearance := .65
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var native_flags := 0
var fitted_plane: Dictionary = {}
var gesture_shift := Vector3.ZERO
var airborne_fit := false
var starting_clearance := .003

func _ready() -> void:
	super._ready()
	remember_plane({})
	fitted_fall.skin = collapse_skin
	animator.mixer_applied.connect(apply_fitted_pose)
	contact.modification_processed.connect(apply_gesture_support)

func set_native_combat_flags(flags: int) -> void:
	native_flags = flags

func is_fitted(clip: String) -> bool:
	return clip in entry.get("archive_grounded_gestures", [])

func receive_action(request: Dictionary) -> bool:
	var was_airborne := current_clip in AIRBORNE or (is_fitted(current_clip) and airborne_fit)
	var clearance := .003
	if not dead and was_airborne and (native_flags & 4) != 0:
		var plane := fitted_fall.floor_under(self)
		skeleton.force_update_all_bone_transforms()
		clearance = maxf(clearance, Ground.minimum_plane_gap(collapse_skin, skeleton,
			skeleton.global_transform, plane.position, plane.normal))
	if not super.receive_action(request):
		return false
	if not dead and is_fitted(current_clip):
		airborne_fit = (native_flags & 4) != 0
		starting_clearance = clearance
		contact.enabled = not airborne_fit
	return true

func _physics_process(delta: float) -> void:
	release_gesture_shift()
	super._physics_process(delta)
	if not dead and is_fitted(current_clip):
		fitted_plane = fitted_fall.floor_under(self)
		if airborne_fit:
			apply_gesture_support()

func release_gesture_shift() -> void:
	model.position -= gesture_shift
	gesture_shift = Vector3.ZERO

func apply_fitted_pose() -> void:
	release_gesture_shift()
	if dead:
		fitted_fall.settle(self)
	elif airborne_fit:
		apply_gesture_support()

func apply_gesture_support() -> void:
	if dead or not is_fitted(current_clip) or fitted_plane.is_empty():
		return
	release_gesture_shift()
	skeleton.force_update_all_bone_transforms()
	var normal: Vector3 = fitted_plane.normal
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform, fitted_plane.position, normal)
	var lift := .003
	if airborne_fit:
		lift = lerpf(starting_clearance, maxf(starting_clearance, AirClearance),
			smoothstep(0.0, .16, animator.current_animation_position))
	if gap >= lift:
		return
	var before := model.position
	model.global_position.y += (lift - gap) / normal.y
	gesture_shift = model.position - before

func begin_death_from(source: Node3D) -> float:
	if not is_fitted(source.current_clip):
		return super.begin_death_from(source)
	model.position -= source.gesture_shift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, source.airborne_fit)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
