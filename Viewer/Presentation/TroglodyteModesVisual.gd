# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

const COMBAT_ENTRY := "TroglodyteOpenReach"
const SPRINT := "TroglodyteSprint"
var gait := preload("res://Presentation/UopMonsterGait.gd").new()

func set_native_combat_flags(flags: int) -> void:
	var entering := gait.known and not gait.combat and (flags & 0x40) != 0
	gait.set_flags(flags)
	if entering and not dead and action_remaining <= 0.0:
		current_clip = COMBAT_ENTRY
		action_remaining = animator.get_animation(COMBAT_ENTRY).length
		contact.enabled = true
		animator.speed_scale = 1.0
		play(COMBAT_ENTRY, .12)
	elif not gait.combat and current_clip == COMBAT_ENTRY:
		action_remaining = 0.0

func play_gait(moving: bool, speed: float) -> void:
	if gait.play(self, moving, speed, "TroglodytePeaceWalk"):
		return
	var locomotion: Dictionary = entry.get("locomotion", {})
	if not moving or speed <= float(locomotion.get("run_threshold_mps", 3.6)):
		super.play_gait(moving, speed)
		return
	if dead or action_remaining > 0.0:
		return
	contact.enabled = true
	if current_clip != SPRINT:
		current_clip = SPRINT
		play(SPRINT, .18)
	var reference := maxf(.01, float(locomotion.get("run_reference_mps", 5.5)))
	animator.speed_scale = clampf(speed / reference, float(locomotion.get("rate_min", .65)),
		float(locomotion.get("rate_max", 1.65)))
