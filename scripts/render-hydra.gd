# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const HydraFit := preload("bake-hydra-enhanced.gd")


func review_cast() -> Dictionary:
	return {265: HydraFit.Clips.values()}


func review_folder() -> String:
	return HydraFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = HydraFit.Clips.values()
	return load("res://Presentation/SourceEnhancedHydraVisual.gd").new()
