# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/RottingCorpseActionsVisual.gd"

var gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	entry = entry.duplicate(true)
	entry["archive_align_gesture_slope"] = true
	super._ready()
	gesture.bind(self)
	fitted_fall.skin = gesture.skin


func _physics_process(delta: float) -> void:
	gesture.release(self)
	super._physics_process(delta)


func settle_collapse() -> void:
	if fitted_fall.plane.is_empty():
		super.settle_collapse()
	else:
		fitted_fall.settle(self)
		update_landmarks()


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in source.entry.get("archive_grounded_gestures", []) or not source.fitted_fall.plane.is_empty():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
