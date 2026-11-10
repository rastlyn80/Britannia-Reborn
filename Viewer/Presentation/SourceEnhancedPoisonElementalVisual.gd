# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceFluidElementalVisual.gd"

var gesture := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()


func _ready() -> void:
	super._ready()
	gesture.bind(self)
	fitted_fall.skin = support_skin
	animator.mixer_applied.connect(fitted_fall.settle.bind(self))


func _physics_process(delta: float) -> void:
	gesture.release(self)
	super._physics_process(delta)


func begin_death_from(source: Node3D) -> float:
	if source.current_clip not in entry.get("archive_grounded_gestures", []):
		play("Death", .08)
		return animator.get_animation("Death").length
	if source.gesture.applied:
		model.transform = source.gesture.restore_pose
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
