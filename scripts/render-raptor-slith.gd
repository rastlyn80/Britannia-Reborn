# SPDX-License-Identifier: GPL-3.0-or-later
extends "render-golem-sand.gd"

const Pair := preload("bake-raptor-slith-enhanced.gd")


func review_cast() -> Dictionary:
	return {730: Pair.Raptor.values(), 734: Pair.Slith.values() + [Pair.Breath]}


func review_folder() -> String:
	return Pair.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	return Registry.create(body)
