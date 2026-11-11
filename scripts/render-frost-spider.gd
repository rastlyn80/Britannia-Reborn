# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const SpiderFit := preload("bake-frost-spider-enhanced.gd")


func review_cast() -> Dictionary:
	return {20: SpiderFit.Clips.values()}


func review_folder() -> String:
	return SpiderFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = SpiderFit.Clips.values()
	return load("res://Presentation/SourceEnhancedFrostSpiderVisual.gd").new()
