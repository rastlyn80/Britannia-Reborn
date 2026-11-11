# SPDX-License-Identifier: GPL-3.0-or-later
extends "render-golem-sand.gd"

const Fit := preload("bake-frenzied-ostard-enhanced.gd")
const Profile := preload("res://Presentation/FrenziedOstardProfile.gd")


func review_cast() -> Dictionary:
	return {Profile.Body: Fit.Gestures.values() + Fit.Gaits.values().map(func(row: Array): return row[1])}


func review_folder() -> String:
	return Fit.Destination


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.merge(Profile.retained_row())
	row.assets.original = review_folder() + "%d-original.scn" % body
	row.archive_grounded_gestures = Fit.Gestures.values()
	return load(Profile.Renderer).new()
