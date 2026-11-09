# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFireBeetleVisual.gd"

const Rest := preload("res://Presentation/FittedCreatureRest.gd")

func _ready() -> void:
	super._ready()
	Rest.install(self)

func receive_action(request: Dictionary) -> bool:
	return Rest.use_ground_support(self, super.receive_action(request))
