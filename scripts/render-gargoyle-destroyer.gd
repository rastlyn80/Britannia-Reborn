# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Gargoyles := preload("bake-gargoyle-destroyer-enhanced.gd")
const Visual := preload("res://Presentation/ArchiveGestureVisual.gd")


func review_body() -> int:
	return Gargoyles.Enforcer if "--enforcer" in OS.get_cmdline_user_args() else Gargoyles.Destroyer


func review_cast() -> Dictionary:
	var body := review_body()
	return {body: Gargoyles.review_clips(body).values()}


func review_folder() -> String:
	return Gargoyles.destination(review_body())


func review_actor(body: int) -> Node3D:
	var row := Registry.entry(body)
	row.archive_grounded_gestures = Gargoyles.review_clips(body).values()
	return Visual.new()
