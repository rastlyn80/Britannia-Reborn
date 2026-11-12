# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBogThingVisual.gd"


func _ready() -> void:
	super._ready()
	# Older prepared scenes retained the baker's manual clock.
	if animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
