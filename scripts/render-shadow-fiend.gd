# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const ShadowFit := preload("bake-shadow-fiend-enhanced.gd")


func review_cast() -> Dictionary:
	return {168: ShadowFit.Clips.values()}


func review_folder() -> String:
	return ShadowFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = ShadowFit.Clips.values()
	return load("res://Presentation/SourceEnhancedShadowFiendVisual.gd").new()
