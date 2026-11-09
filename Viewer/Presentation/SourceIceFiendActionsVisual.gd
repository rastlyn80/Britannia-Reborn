# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "AirDeath":
		# The seven original frames hold the spread-wing pose. The separate
		# server death event still supplies the normal collapse and cadaver.
		dead = true
		contact.enabled = false
	return true
