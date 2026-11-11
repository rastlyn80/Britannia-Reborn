# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureEventPresenter.gd"

const Lattice := preload("res://Presentation/SourceEnhancedLatticeSeekerVisual.gd")


func _localized_speech(serial: int, body: int, kind: int, cliloc: int) -> void:
	if scene.game.phase == "world" and body == 123 and kind == 0 and Lattice.DrainColours.has(cliloc):
		var avatar := scene.avatars.get(serial) as Avatar
		if avatar != null and avatar.horse_visual is Lattice:
			avatar.horse_visual.show_native_drain(cliloc)
	super._localized_speech(serial, body, kind, cliloc)
