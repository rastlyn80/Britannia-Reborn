# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Mage := preload("bake-meer-mage-enhanced.gd")
const MageVisual := preload("res://Presentation/MeerMageFallVisual.gd")


func review_cast() -> Dictionary:
	return {Mage.Body: ["Death", "Death2", "Cast"] + Mage.Clips.values() + [Mage.WalkName]}


func review_folder() -> String:
	return Mage.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	return MageVisual.new()
