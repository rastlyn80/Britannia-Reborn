# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MeerMageFallVisual.gd"

const Stand := "MeerMageQuietStand"
const Walk := "MeerMageMeasuredWalk"
const ForestCalls := [1071931, 1071932]


func play_gait(moving: bool, speed: float) -> void:
	if dead or action_remaining > 0.0:
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	var running := moving and speed > float(locomotion.get("run_threshold_mps", 3.6))
	# The Enhanced run entry points to the neutral frames. Keep the original
	# Third Dawn run when the creature is travelling at running speed.
	var clip := "Run" if running else Walk if moving else Stand
	contact.enabled = true
	if current_clip != clip:
		current_clip = clip
		play(clip, .16)
	var reference := float(locomotion.get("run_reference_mps", 5.5)) if running else float(locomotion.get("walk_reference_mps", 1.8))
	animator.speed_scale = clampf(speed / maxf(.01, reference), float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65))) if moving else 1.0


func start_forest_call(cliloc: int) -> bool:
	if dead or cliloc not in ForestCalls:
		return false
	current_clip = "Cast"
	contact.enabled = true
	animator.speed_scale = 1.0
	action_remaining = animator.get_animation("Cast").length
	play("Cast", .12)
	animator.seek(0.0, false)
	return true


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	model.transform = source.model.transform
	var lift := Vector3.ZERO
	if source.ground_gesture.applied:
		lift = source.model.position - source.ground_gesture.restore_pose.origin
	return fall.begin_from_source(self, source, source.fall, lift)
