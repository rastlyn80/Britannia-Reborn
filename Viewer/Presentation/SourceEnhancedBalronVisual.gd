# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/VampireBatFallVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
const AirClearance := .65
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var native_flags := 0
var fitted_lift := Vector3.ZERO
var airborne_fit := false
var starting_clearance := .003


func _ready() -> void:
	super._ready()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(body, skeleton)
	animator.mixer_applied.connect(update_fit)
	contact.modification_processed.connect(update_fit)


func is_fitted(clip: String) -> bool:
	return clip in entry.get("archive_grounded_gestures", [])


func set_native_combat_flags(flags: int) -> void:
	native_flags = flags


func receive_action(request: Dictionary) -> bool:
	var was_airborne := current_clip in fall.FLIGHT or (is_fitted(current_clip) and airborne_fit)
	var airborne := (native_flags & 4) != 0
	var clearance := .003
	if not dead and airborne and was_airborne:
		clearance = maxf(clearance, measured_gap(fitted_fall.floor_under(self)))
	if not super.receive_action(request):
		return false
	if is_fitted(current_clip):
		airborne_fit = airborne
		starting_clearance = clearance
		contact.enabled = not airborne
	return true


func _physics_process(delta: float) -> void:
	release_fit()
	super._physics_process(delta)
	update_fit()


func release_fit() -> void:
	model.position -= fitted_lift
	fitted_lift = Vector3.ZERO


func measured_gap(floor: Dictionary) -> float:
	skeleton.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)


func update_fit() -> void:
	release_fit()
	if dead:
		fitted_fall.settle(self)
		return
	if not is_fitted(current_clip):
		return
	var floor := fitted_fall.floor_under(self)
	var clearance := .003
	if airborne_fit:
		clearance = lerpf(starting_clearance, maxf(starting_clearance, AirClearance),
			smoothstep(0.0, .16, animator.current_animation_position))
	var gap := measured_gap(floor)
	if gap < clearance:
		var before := model.position
		model.global_position.y += (clearance - gap) / float(floor.normal.y)
		fitted_lift = model.position - before


func begin_death_from(source: Node3D) -> float:
	if not is_fitted(source.current_clip):
		return super.begin_death_from(source)
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, source.airborne_fit)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
