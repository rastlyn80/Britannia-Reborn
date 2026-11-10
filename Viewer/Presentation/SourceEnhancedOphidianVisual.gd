# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OphidianActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	var combined := {"bones": body_skin.bones.duplicate(), "bind_poses": body_skin.bind_poses.duplicate(),
		"surfaces": body_skin.surfaces.duplicate()}
	var offset: int = combined.bones.size()
	combined.bones.append_array(bardiche_skin.bones)
	combined.bind_poses.append_array(bardiche_skin.bind_poses)
	for source: Dictionary in bardiche_skin.surfaces:
		var surface := source.duplicate()
		var bindings: PackedInt32Array = source.bindings.duplicate()
		for i in bindings.size():
			bindings[i] += offset
		surface.bindings = bindings
		combined.surfaces.append(surface)
	fitted_fall.skin = combined
	animator.mixer_applied.connect(apply_fitted_pose)
	contact.modification_processed.connect(support_fitted_pose)

func apply_fitted_pose() -> void:
	if dead:
		fitted_fall.settle(self)
	else:
		support_fitted_pose()

func support_fitted_pose() -> void:
	if dead or current_clip not in entry.get("archive_grounded_gestures", []):
		return
	restore_gesture()
	fit_grounded_gesture()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		return super.begin_death_from(source)
	# The copied model basis includes the displayed slope alignment.
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
