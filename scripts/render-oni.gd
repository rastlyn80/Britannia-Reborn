# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://../scripts/render-golem-sand.gd"

const Fit := preload("bake-oni-enhanced.gd")
const Visual := preload("res://Presentation/SourceEnhancedOniVisual.gd")


func review_cast() -> Dictionary:
	return {Fit.Body: ["Death", "Death2"] + Fit.Clips.values() + [Fit.PeaceWalk]}


func review_folder() -> String:
	return Fit.Destination


func review_actor(_body: int) -> Node3D:
	return Visual.new()


func motion_bounds(actor: Node3D, clips: Array) -> AABB:
	var bounds := super.motion_bounds(actor, clips)
	var animator: AnimationPlayer = actor.animator
	actor.current_clip = Visual.Fire
	animator.play(Visual.Fire, 0.0)
	animator.advance(0.0)
	for sample in 18:
		animator.seek(animator.current_animation_length * sample / 17.0, true)
		if actor.flame == null or not actor.flame.visible:
			continue
		for coil: MeshInstance3D in actor.flame.get_children():
			bounds = bounds.merge(coil.global_transform * coil.mesh.get_aabb())
	actor.flame.hide()
	return bounds
