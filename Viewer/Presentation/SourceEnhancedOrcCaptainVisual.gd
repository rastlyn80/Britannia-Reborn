# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OrcCaptainActionsVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	entry = entry.merged({"grounded_gestures": entry.grounded_gestures + entry.get("archive_grounded_gestures", [])}, true)
	super._ready()
	fitted_fall.skin = skin


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []) or not source.fitted_fall.plane.is_empty():
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	global_transform = source.global_transform
	return super.begin_death_from(source)


func settle() -> void:
	if dead and not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)
	else:
		super.settle()


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
