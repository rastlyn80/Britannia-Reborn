# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fit := preload("bake-orc-brute-enhanced.gd")
const Visual := preload("res://Presentation/SourceScaledCreatureVisual.gd")


func review_cast() -> Dictionary:
	return {Fit.Body: ["Death"] + Fit.Clips.values() + [Fit.PeaceWalk]}


func review_folder() -> String:
	return Fit.Destination + "silhouette/" if "--brute-silhouette" in OS.get_cmdline_user_args() else Fit.Destination


func review_actor(body: int) -> Node3D:
	Registry.entry(body).assets.original = review_folder() + "%d-original.scn" % body
	return Visual.new()
