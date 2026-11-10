# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceAmorphousVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func _physics_process(delta: float) -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		super._physics_process(delta)
		return
	var support := fitted_fall.floor_under(self)
	var normal := (global_basis.inverse() * Vector3(support.normal)).normalized()
	var slope := Basis(Quaternion(Vector3.UP, normal))
	model.transform = Transform3D((slope * source_model_basis).scaled_local(model.scale), to_local(support.position))
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(support_skin, skeleton, skeleton.global_transform, support.position, support.normal)
	if gap < .002:
		model.global_position += Vector3.UP * (.002 - gap) / float(support.normal.y)
	update_landmarks()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		blend_remaining = 0.0
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	play("Death", .08)
	return animator.get_animation("Death").length

func corpse_snapshot_floor() -> float:
	return INF if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
