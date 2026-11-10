# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/StoneHarpyActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var unposed_model := Transform3D.IDENTITY
var posed_on_terrain := false
var native_flags := 0
var entry_air_gap := .003


func _ready() -> void:
	super._ready()
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(body, skeleton)
	animator.mixer_applied.connect(update_fitted_support)


func set_native_combat_flags(flags: int) -> void:
	native_flags = flags


func is_fitted(clip: String) -> bool:
	return clip in entry.get("archive_grounded_gestures", [])


func receive_action(request: Dictionary) -> bool:
	var entry_gap := .003
	if not dead and (native_flags & 4) != 0 and (is_fitted(current_clip) or current_clip in AIRBORNE):
		entry_gap = maxf(entry_gap, measured_gap(fitted_fall.floor_under(self)))
	restore_fitted_support()
	if not super.receive_action(request):
		return false
	if is_fitted(current_clip):
		entry_air_gap = entry_gap
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	restore_fitted_support()
	if not is_fitted(current_clip):
		super._physics_process(delta)
	elif not dead:
		update_fitted_support()


func restore_fitted_support() -> void:
	if posed_on_terrain:
		model.transform = unposed_model
		posed_on_terrain = false


func measured_gap(floor: Dictionary) -> float:
	skeleton.force_update_all_bone_transforms()
	return Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)


func update_fitted_support() -> void:
	restore_fitted_support()
	if dead and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		return
	if dead or not is_fitted(current_clip):
		return
	var floor := fitted_fall.floor_under(self)
	var normal: Vector3 = floor.normal
	var clearance := .003
	if (native_flags & 4) != 0:
		clearance = lerpf(entry_air_gap, maxf(entry_air_gap, .65),
			smoothstep(0.0, .18, animator.current_animation_position))
	unposed_model = model.transform
	posed_on_terrain = true
	var slope := Basis(Quaternion(Vector3.UP, (global_basis.inverse() * normal).normalized()))
	model.basis = (slope * source_model_basis).scaled_local(unposed_model.basis.get_scale())
	model.global_position.y += maxf(0.0, clearance - measured_gap(floor)) / normal.y


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted(source.current_clip) and source.fitted_fall.plane.is_empty():
		return super.begin_death_from(source)
	var airborne: bool = (source.native_flags & 4) != 0 or source.measured_gap(fitted_fall.floor_under(source)) > .18
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, airborne)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
