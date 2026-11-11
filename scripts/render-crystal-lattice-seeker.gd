# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fit := preload("bake-crystal-lattice-seeker-enhanced.gd")
const Visual := preload("SourceEnhancedLatticeSeekerVisual.gd")

func review_cast() -> Dictionary:
	return {Fit.Body: Fit.Clips.values() + [Fit.PeaceWalk]}

func review_folder() -> String:
	return Fit.Destination

func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = Fit.Destination + "%d-original.scn" % body
	var actor := Visual.new()
	actor.action_remaining = 10.0
	return actor
