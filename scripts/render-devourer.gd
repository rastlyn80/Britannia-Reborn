# SPDX-License-Identifier: GPL-3.0-or-later
extends "render-golem-sand.gd"

const Devourer := preload("bake-devourer-enhanced.gd")


func review_cast() -> Dictionary:
	return {303: Devourer.Clips.values()}


func review_folder() -> String:
	return Devourer.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	return Registry.create(body)
