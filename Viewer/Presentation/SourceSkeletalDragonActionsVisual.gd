# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/ArchiveGestureVisual.gd"

func receive_action(request: Dictionary) -> bool:
	if not super.receive_action(request):
		return false
	if current_clip == "AirDeath":
		# Classic flight death holds the wing pose until the native corpse handoff.
		dead = true
		contact.enabled = false
	return true
