# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/CreatureVisual.gd"

var gesture_ground := preload("res://Presentation/ArchiveGestureGround.gd").new()
var fitted_fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd").new()
var blade: MeshInstance3D
var unarmed_fall := false


func _ready() -> void:
	super._ready()
	blade = model.find_child("YomotsuBlade", true, false)
	assert(blade != null)
	blade.set_meta("optional_corpse_visual_prop", true)
	gesture_ground.bind(self)
	fitted_fall.skin = gesture_ground.skin
	animator.mixer_applied.connect(update_blade)


func _physics_process(delta: float) -> void:
	gesture_ground.release(self)
	if fitted_fall.plane.is_empty():
		super._physics_process(delta)


func is_fitted() -> bool:
	return current_clip in entry.get("archive_grounded_gestures", [])


func update_blade() -> void:
	blade.visible = not (unarmed_fall or is_fitted())
	if not fitted_fall.plane.is_empty():
		fitted_fall.settle(self)


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted():
		play("Death", .08)
		return animator.get_animation("Death").length
	unarmed_fall = true
	blade.hide()
	if source.gesture_ground.applied:
		model.transform = source.gesture_ground.restore_pose
	return fitted_fall.begin_from_source(self, source, source.fitted_fall, false)


func corpse_snapshot_floor() -> float:
	return NAN if fitted_fall.plane.is_empty() else fitted_fall.snapshot_floor(self)
