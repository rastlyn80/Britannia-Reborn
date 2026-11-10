# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedCorpserVisual.gd"

const GraveRise := "ZombieGraveRise"
var grave_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()

func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(grave_fall.settle.bind(self))

func begin_death_from(source: Node3D) -> float:
	if source.current_clip != GraveRise:
		return super.begin_death_from(source)
	var duration := grave_fall.begin_from_source(self, source, source.grave_fall, false, true)
	# The grave rise starts deeper than the serpent's surface motion.
	grave_fall.blend_length = minf(.48, duration)
	return duration

func corpse_snapshot_floor() -> float:
	if not grave_fall.plane.is_empty():
		return grave_fall.snapshot_floor(self)
	return super.corpse_snapshot_floor()
