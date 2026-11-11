# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fire := preload("bake-fire-gargoyle-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedFireGargoyleVisual.gd")


func review_cast() -> Dictionary:
	return {Fire.Body: Fire.Clips.values()}


func review_folder() -> String:
	return Fire.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.archive_grounded_gestures = Fire.Clips.values()
	return Visual.new()
