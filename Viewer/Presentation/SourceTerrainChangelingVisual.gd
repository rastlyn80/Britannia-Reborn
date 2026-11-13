# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTerrainInterredGrizzleVisual.gd"


func place_fitted_pose() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.place_fitted_pose()
		return
	# Keep the original hover and allow the wing tips to clear raised treads.
	settle_living()
