# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MongbatActionsVisual.gd"

const FittedFall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd")
const Fitted := ["GargoyleWingRise", "GargoyleWingWatch", "GargoyleWingFeint", "GargoyleWingAlert"]
var gesture_support := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := FittedFall.new()
var native_flags := 0

func _ready() -> void:
	super._ready()
	gesture_support.bind(self)
	animator.mixer_applied.connect(func(): fitted_fall.settle(self))

func _physics_process(delta: float) -> void:
	gesture_support.release(self)
	super._physics_process(delta)

func set_native_combat_flags(flags: int) -> void:
	native_flags = flags

func receive_action(request: Dictionary) -> bool:
	var base := entry
	# The pinned Gargoyle flight table inherits peaceful mode before combat mode.
	if (native_flags & 0x04) != 0 and request.get("protocol") == "new" and request.get("type") == 5:
		var choices: Dictionary = entry.get("new_action_categories", {})
		if choices.get("5") == "GargoyleWingFeint":
			entry = entry.merged({"new_action_categories": choices.merged({"5": "GargoyleWingWatch"}, true)}, true)
	var accepted := super.receive_action(request)
	entry = base
	return accepted

func begin_death_from(source: Node3D) -> float:
	if source.current_clip in Fitted:
		var airborne := false
		if source.current_clip == "GargoyleWingRise":
			var floor := fitted_fall.floor_under(source)
			airborne = Ground.minimum_plane_gap(source.gesture_support.skin, source.skeleton,
				source.skeleton.global_transform, floor.position, floor.normal) > .09
		return fitted_fall.begin_from_source(self, source, source.fitted_fall, airborne)
	return super.begin_death_from(source)

func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
