# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/IceSerpentVisual.gd"

const EMERGE := "IceSerpentEmerge"
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_lift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	fitted_fall.skin = support_skin
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))
	contact.modification_processed.connect(update_fitted_ground)

func apply_ground() -> void:
	if dead and not fitted_fall.plane.is_empty():
		return
	if not update_fitted_ground():
		fitted_lift = Vector3.ZERO
		super.apply_ground()

func update_fitted_ground() -> bool:
	var clip := animator.assigned_animation
	if dead or clip not in entry.get("archive_grounded_gestures", []):
		return false
	model.position.y = source_position.y
	fitted_lift = Vector3.ZERO
	var floor := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, floor.position, floor.normal)
	var phase := animator.current_animation_position / animator.current_animation_length
	var allowed_depth := .39 * (1.0 - smoothstep(.04, .82, phase)) if clip == EMERGE else 0.0
	var target := .004 - allowed_depth
	if gap < target:
		var before := model.position
		model.global_position.y += (target - gap) / float(floor.normal.y)
		fitted_lift = model.position - before
	update_landmarks()
	return true

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	model.position -= source.fitted_lift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false, source.current_clip == EMERGE)

func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
