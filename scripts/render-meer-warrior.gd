# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const MeerFit := preload("bake-meer-warrior-enhanced.gd")


func review_cast() -> Dictionary:
	return {771: MeerFit.Clips.values()}


func review_folder() -> String:
	return MeerFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = MeerFit.Clips.values()
	return load("res://Presentation/SourceEnhancedMeerWarriorVisual.gd").new()
