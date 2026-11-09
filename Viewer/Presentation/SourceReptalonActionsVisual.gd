# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceReptalonMountVisual.gd"

const Rest := preload("res://Presentation/FittedCreatureRest.gd")
var ground_gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()

func _ready() -> void:
	super._ready()
	Rest.install(self)
	ground_gesture.bind(self)

func _physics_process(delta: float) -> void:
	ground_gesture.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	return Rest.use_ground_support(self, super.receive_action(request))
