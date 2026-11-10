# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceQuadrupedCollapseVisual.gd"

const GestureGround := preload("res://Presentation/ArchiveGestureGround.gd")
const HellCatHues := [0x647, 0x650, 0x659, 0x662, 0x66b, 0x674]
var gesture_ground: GestureGround

func _ready() -> void:
	super._ready()
	if entry.has("enhanced_source_action_groups"):
		gesture_ground = GestureGround.new()
		gesture_ground.bind(self)

func _physics_process(delta: float) -> void:
	if gesture_ground != null:
		gesture_ground.release(self)
	super._physics_process(delta)

func receive_action(request: Dictionary) -> bool:
	# Stock HellCat FireBreath uses a five-frame group 12 packet before
	# sending its projectile. Normal Cat group 12 still means a collapse.
	if (native_body == 201 and (native_hue & 0x3fff) in HellCatHues
			and request.get("protocol") == "classic" and request.get("action") == 12
			and request.get("frames") == 5 and request.get("repeat_count") == 1
			and request.get("reverse") == false and request.get("repeat") == false and request.get("delay") == 0):
		if not super.receive_action(request.merged({"action": 4}, true)):
			return false
		set_meta("native_action", request.duplicate(true))
		return true
	return super.receive_action(request)
