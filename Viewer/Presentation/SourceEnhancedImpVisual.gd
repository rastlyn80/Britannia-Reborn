# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedFieldVisual.gd"

var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		# The retained Imp has one fall clip, including when a hover is interrupted.
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
