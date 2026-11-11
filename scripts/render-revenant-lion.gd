# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const LionFit := preload("bake-revenant-lion-enhanced.gd")


func review_cast() -> Dictionary:
	return {251: LionFit.Clips.values()}


func review_folder() -> String:
	return LionFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = LionFit.Clips.values()
	return load("res://Presentation/SourceEnhancedRevenantLionVisual.gd").new()
