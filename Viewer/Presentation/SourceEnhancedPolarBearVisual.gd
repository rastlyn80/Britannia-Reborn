# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/AlternateCollapseVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var fitted_shift := Vector3.ZERO

func _ready() -> void:
	super._ready()
	var mesh := model.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
	collapse_skin = Ground.skin_points(mesh, skeleton)
	fitted_fall.skin = collapse_skin
	animator.mixer_applied.connect(release_fitted_lift)
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))
	contact.modification_processed.connect(support_fitted_gesture)

func _physics_process(delta: float) -> void:
	release_fitted_lift()
	super._physics_process(delta)

func release_fitted_lift() -> void:
	model.position -= fitted_shift
	fitted_shift = Vector3.ZERO

func support_fitted_gesture() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	release_fitted_lift()
	var plane := fitted_fall.floor_under(self)
	skeleton.force_update_all_bone_transforms()
	var gap := Ground.minimum_plane_gap(collapse_skin, skeleton, skeleton.global_transform, plane.position, plane.normal)
	if gap < .003:
		var before := model.position
		model.global_position.y += (.003 - gap) / float(plane.normal.y)
		fitted_shift = model.position - before

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	model.position -= source.fitted_shift
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
