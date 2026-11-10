# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_lift := Vector3.ZERO


func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	fitted_fall.skin = Ground.skin_points(mesh, skeleton)
	animator.mixer_applied.connect(update_fitted_pose)
	contact.modification_processed.connect(support_fit)


func _physics_process(delta: float) -> void:
	release_fit()
	super._physics_process(delta)


func release_fit() -> void:
	model.position -= fitted_lift
	fitted_lift = Vector3.ZERO


func update_fitted_pose() -> void:
	release_fit()
	if dead:
		fitted_fall.settle(self)


func support_fit() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	release_fit()
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(fitted_fall.skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	if gap < .003:
		var before := model.position
		model.global_position.y += (.003 - gap) / float(floor.normal.y)
		fitted_lift = model.position - before


func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	model.position -= source.fitted_lift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

