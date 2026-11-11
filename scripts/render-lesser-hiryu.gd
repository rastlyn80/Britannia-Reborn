# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const HiryuFit := preload("bake-lesser-hiryu-enhanced.gd")


func review_cast() -> Dictionary:
	return {243: HiryuFit.Gestures.values() + HiryuFit.Gaits.values().map(func(row: Array): return row[1])}


func review_folder() -> String:
	return HiryuFit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = HiryuFit.Gestures.values()
	return load("res://Presentation/SourceEnhancedHiryuVisual.gd").new()
