# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceReaperGroundVisual.gd"

const EmergenceFall := preload("res://Presentation/SourceCorpserEmergenceFall.gd")
const Emerge := "Emerge"
var emergence := EmergenceFall.new()


func _init() -> void:
	terrain = emergence


func play_gait(moving: bool, speed: float) -> void:
	# Whipping Vine shares this body with the rooted Corpser. Movement
	# interrupts idle gestures, while attack and emergence keep their timing.
	if moving and current_clip in ["Fidget", "TendrilCurl", "CorpserClosePetals", "CorpserSplay"]:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func settle_living() -> void:
	super.settle_living()
	if current_clip != Emerge or animator.assigned_animation != Emerge:
		return
	var phase := animator.current_animation_position / maxf(.001, animator.current_animation_length)
	# The creature rises from below the soil. Conform the last standing pose to the terrain.
	var removed := live_lift * (1.0 - smoothstep(.78, .99, phase))
	model.global_position.y -= removed
	live_lift -= removed


func begin_death_from(source: Node3D) -> float:
	if source.current_clip == Emerge:
		return emergence.begin_emergence(self, source)
	return super.begin_death_from(source)
