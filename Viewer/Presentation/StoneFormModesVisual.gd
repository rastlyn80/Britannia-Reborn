# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/FittedSpellFormVisual.gd"

var gait := preload("res://Presentation/UopMonsterGait.gd").new()

func set_native_combat_flags(flags: int) -> void:
	var was_peaceful := gait.known and not gait.combat
	gait.set_flags(flags)
	if was_peaceful and gait.combat and not dead and action_remaining <= 0.0:
		# The archive links the peaceful-to-combat transition to group 28.
		current_clip = "StoneStanceRise"
		action_remaining = animator.get_animation(current_clip).length
		contact.enabled = true
		animator.speed_scale = 1.0
		play(current_clip, .12)

func play_gait(moving: bool, speed: float) -> void:
	if not gait.play(self, moving, speed, "StonePeaceWalk"):
		super.play_gait(moving, speed)
