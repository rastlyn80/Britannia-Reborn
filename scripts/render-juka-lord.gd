# SPDX-License-Identifier: GPL-3.0-or-later
extends "render-golem-sand.gd"

const Lord := preload("bake-juka-lord-enhanced.gd")


func review_cast() -> Dictionary:
	return {766: Lord.LordClips.values()}


func review_folder() -> String:
	return Lord.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	var actor := Registry.create(body)
	actor.ready.connect(func(): actor.set_equipment([{"id": 0x13b1, "layer": 2, "hue": 0}]))
	return actor
