# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedCorpserVisual.gd"

var surface_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(func(): surface_fall.settle(self))

func begin_death_from(source: Node3D) -> float:
	if source.current_clip == "SerpentSurface":
		return surface_fall.begin_from_source(self, source, source.surface_fall, false, true)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	if not surface_fall.plane.is_empty():
		return surface_fall.snapshot_floor(self)
	return super.corpse_snapshot_floor()
