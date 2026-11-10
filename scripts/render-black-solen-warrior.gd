# SPDX-License-Identifier: GPL-3.0-or-later
extends "render-golem-sand.gd"

const Solen := preload("bake-black-solen-warrior-enhanced.gd")
const Renderer := preload("res://Presentation/SourceEnhancedBlackSolenWarriorVisual.gd")


func review_cast() -> Dictionary:
	return {806: Solen.Clips.values()}


func review_folder() -> String:
	return Solen.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	Registry.entry(body).archive_grounded_gestures = Solen.Clips.values()
	return Renderer.new()
