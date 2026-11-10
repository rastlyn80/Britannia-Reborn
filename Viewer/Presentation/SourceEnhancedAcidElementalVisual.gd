# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFluidElementalVisual.gd"

const Growth := "AcidElementalCondense"
const FitGround := preload("res://Presentation/SourceGroundLookup.gd")
var growth := preload("res://Presentation/CreatureGrowthRecovery.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_lift := Vector3.ZERO


func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	animator.mixer_applied.disconnect(support_death_blend)
	animator.mixer_applied.connect(update_fitted_pose)
	contact.modification_processed.connect(support_fit)


func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == Growth:
		contact.enabled = false
	return true


func _physics_process(delta: float) -> void:
	release_fit()
	super._physics_process(delta)


func release_fit() -> void:
	model.position -= fitted_lift
	fitted_lift = Vector3.ZERO


func update_fitted_pose() -> void:
	release_fit()
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
		update_landmarks()
	else:
		super.support_death_blend()
		support_fit(not dead and growth.apply(self, Growth))


func support_fit(recovering := false) -> void:
	if dead or support_skin.is_empty() or (
		not recovering and current_clip not in entry.get("archive_grounded_gestures", [])
	):
		return
	release_fit()
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := FitGround.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	if gap < .003:
		var before := model.position
		model.global_position.y += (.003 - gap) / float(floor.normal.y)
		fitted_lift = model.position - before
	update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if not source.growth.active and source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	model.position -= source.fitted_lift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
