# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/OphidianMageActionsVisual.gd"


func begin_death_from(source: Node3D) -> float:
	if source.current_clip in entry.get("archive_grounded_gestures", []):
		global_transform = source.global_transform
	return super.begin_death_from(source)
