# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RatmanMageActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_shift := Vector3.ZERO
var crook_in_fall := false
var sword: MeshInstance3D
var crook: MeshInstance3D


func _ready() -> void:
	super._ready()
	sword = model.find_child("RatmanSword", true, false)
	crook = model.find_child("RatmanCrook", true, false)
	assert(sword != null and crook != null)
	sword.set_meta("optional_corpse_visual_prop", true)
	crook.set_meta("corpse_prop_keeps_material", true)
	var body := model.find_child("Body", true, false) as MeshInstance3D
	fitted_fall.skin = skin_with_crook(Ground.skin_points(body, skeleton), Ground.skin_points(crook, skeleton))
	animator.mixer_applied.connect(apply_fitted_frame)
	contact.modification_processed.connect(support_fitted_pose)
	update_props()


func set_hue(value: int) -> void:
	super.set_hue(value)
	if model == null:
		return
	var prop := model.find_child("RatmanCrook", true, false) as MeshInstance3D
	if prop != null:
		# The crook is authored model geometry without a native item hue.
		prop.set_surface_override_material(0, null)


func skin_with_crook(body: Dictionary, staff: Dictionary) -> Dictionary:
	var result := body.duplicate(true)
	var offset: int = result.bones.size()
	result.bones.append_array(staff.bones)
	result.bind_poses.append_array(staff.bind_poses)
	for surface: Dictionary in staff.surfaces:
		var adjusted := surface.duplicate()
		var bindings: PackedInt32Array = surface.bindings.duplicate()
		for index in bindings.size():
			bindings[index] += offset
		adjusted.bindings = bindings
		result.surfaces.append(adjusted)
	return result


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func update_props() -> void:
	var using_crook := crook_in_fall or is_fitted()
	crook.visible = using_crook
	sword.visible = not using_crook


func apply_fitted_frame() -> void:
	release_fitted_shift()
	update_props()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)


func _physics_process(delta: float) -> void:
	release_fitted_shift()
	if fitted_fall.plane.is_empty():
		super._physics_process(delta)


func release_fitted_shift() -> void:
	model.position -= fitted_shift
	fitted_shift = Vector3.ZERO


func support_fitted_pose() -> void:
	if dead or not is_fitted():
		return
	release_fitted_shift()
	release_clearance()
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	var before := model.position
	model.global_position.y += maxf(0.0, .002 - gap) / float(floor.normal.y)
	fitted_shift = model.position - before
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted():
		return super.begin_death_from(source)
	crook_in_fall = true
	update_props()
	model.position -= source.fitted_shift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
