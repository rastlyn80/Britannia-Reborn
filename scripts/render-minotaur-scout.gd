# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const ScoutFit := preload("bake-minotaur-scout-enhanced.gd")


func review_cast() -> Dictionary:
	return {281: ScoutFit.Clips.values()}


func review_folder() -> String:
	return ScoutFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	return preload("res://Presentation/ArchiveGestureVisual.gd").new()
