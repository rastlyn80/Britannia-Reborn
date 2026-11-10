# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceLizardActionsVisual.gd"

var gesture_ground := preload("res://Presentation/ArchiveGestureGround.gd").new()

func _ready() -> void:
	super._ready()
	gesture_ground.bind(self)

func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	super._physics_process(delta)
