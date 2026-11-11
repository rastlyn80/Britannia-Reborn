# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fit := preload("bake-treefellow-enhanced.gd")
const TreeVisual := preload("res://Presentation/SourceEnhancedTreefellowVisual.gd")


func review_cast() -> Dictionary:
	return {Fit.Body: ["Death", "Walk", "Run", Fit.QuietWalk] + Fit.Clips.values()}


func review_folder() -> String:
	return Fit.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = Fit.Destination + "%d-original.scn" % body
	return TreeVisual.new()
