# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MatriarchActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	fitted_fall.skin = skin


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)


func settle() -> void:
	if fitted_fall.plane.is_empty():
		super.settle()
	else:
		fitted_fall.settle(self)


func corpse_snapshot_floor() -> float:
	if fitted_fall.plane.is_empty():
		return super.corpse_snapshot_floor()
	return fitted_fall.snapshot_floor(self)

