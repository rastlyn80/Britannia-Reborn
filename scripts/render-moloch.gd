# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fit := preload("bake-moloch-enhanced.gd")
const Visual := preload("res://Presentation/SourcePreservingCreatureVisual.gd")

func review_cast() -> Dictionary:
	return {Fit.Body: ["Death"] + Fit.Clips.values() + [Fit.PeaceWalk]}

func review_folder() -> String:
	return Fit.Destination

func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = Fit.Destination + "%d-original.scn" % body
	return Visual.new()
