# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const DaemonFit := preload("bake-chaos-daemon-enhanced.gd")


func review_cast() -> Dictionary:
	return {792: DaemonFit.Clips.values()}


func review_folder() -> String:
	return DaemonFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = DaemonFit.Clips.values()
	return load("res://Presentation/SourceEnhancedChaosDaemonVisual.gd").new()
