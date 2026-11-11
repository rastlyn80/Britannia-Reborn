# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const CrystalFit := preload("bake-crystal-elemental-enhanced.gd")


func review_cast() -> Dictionary:
	return {300: CrystalFit.Clips.values()}


func review_folder() -> String:
	return CrystalFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = CrystalFit.Clips.values()
	return load("res://Presentation/SourceEnhancedCrystalElementalVisual.gd").new()
