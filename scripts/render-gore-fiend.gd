# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const GoreFit := preload("bake-gore-fiend-enhanced.gd")


func review_cast() -> Dictionary:
	return {305: GoreFit.Clips.values()}


func review_folder() -> String:
	return GoreFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = GoreFit.Clips.values()
	return load("res://Presentation/SourceEnhancedGoreFiendVisual.gd").new()
