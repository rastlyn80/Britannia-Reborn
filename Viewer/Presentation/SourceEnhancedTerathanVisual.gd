# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/TerathanActionsVisual.gd"

func _ready() -> void:
	entry = entry.duplicate()
	entry["grounded_gestures"] = entry.get("grounded_gestures", []) + entry.get("archive_grounded_gestures", [])
	super._ready()

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in source.entry.get("archive_grounded_gestures", []):
		global_transform = source.global_transform
	return super.begin_death_from(source)
