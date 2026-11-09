# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceSolenWarriorVisual.gd"

const RECOIL := "QueenShortRecoil"
var ground_gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()

func _ready() -> void:
	super._ready()
	# The new clip keeps its own floor offset in the fitted root bone.
	ground_curves = ground_curves.duplicate()
	ground_curves[RECOIL] = [[0.0, 0.0], [animator.get_animation(RECOIL).length, 0.0]]
	ground_gesture.bind(self)

func _physics_process(delta: float) -> void:
	ground_gesture.release(self)
	super._physics_process(delta)
