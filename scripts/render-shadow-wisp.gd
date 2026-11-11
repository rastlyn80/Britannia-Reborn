# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Wisp := preload("bake-shadow-wisp-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedShadowWispVisual.gd")


func review_cast() -> Dictionary:
	return {Wisp.Body: Wisp.Clips.values()}


func review_folder() -> String:
	return Wisp.Destination


func review_actor(_body: int) -> Node3D:
	return Visual.new()


func minimum_box(_body: int, clip: String, index: int) -> int:
	return [0, 5, 45, 100, 100][index] if clip == Wisp.Clips[23] else 100


func motion_bounds(actor: Node3D, clips: Array) -> AABB:
	var core := super.motion_bounds(actor, clips)
	return core.merge(AABB(Vector3(-.65, .40, -.22), Vector3(1.3, 1.20, 2.82)))
