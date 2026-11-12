# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceTerrainDaemonVisual.gd"

const WyvernWings := preload("res://Presentation/SourceWyvernWingClearance.gd")


func _init() -> void:
	wings = WyvernWings.new()
	support_extent = Vector2(4.0, 3.4)
	flight_clearance = .68
	landing_lift = .44
	interruptible_gestures = ["Fidget", "WingRear", "WyvernTailWatch"]
