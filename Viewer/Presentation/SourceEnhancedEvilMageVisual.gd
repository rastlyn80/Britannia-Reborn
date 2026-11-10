# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceMageVisual.gd"

const Ground := preload("res://Presentation/SourceGroundLookup.gd")
var growth := preload("CreatureGrowthRecovery.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	animator.mixer_applied.disconnect(apply_blend_ground)
	animator.mixer_applied.connect(update_fitted_pose)
	contact.modification_processed.connect(support_fit)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "EvilMageManifest":
		contact.enabled = false
	return true


func update_fitted_pose() -> void:
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	else:
		var recovering := not dead and growth.apply(self, "EvilMageManifest")
		if recovering or (not dead and current_clip in entry.get("archive_grounded_gestures", [])):
			support_fit(recovering)
		else:
			super.apply_blend_ground()


func support_fit(recovering := false) -> void:
	if dead or support_skin.is_empty() or (
		not recovering and current_clip not in entry.get("archive_grounded_gestures", [])
	):
		return
	var floor := fitted_fall.floor_under(self)
	model.position.y = source_model_position.y
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	model.global_position.y += maxf(0.0, .003 - gap) / float(floor.normal.y)
	contact.base_model_y = model.position.y
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if not source.growth.active and source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)

