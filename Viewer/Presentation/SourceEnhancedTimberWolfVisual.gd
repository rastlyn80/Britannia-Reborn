# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedFieldVisual.gd"

const Fall := preload("res://Presentation/SourceSpaceDisplayedFallPlayback.gd")
const IdleGestures := ["TimberWolfQuietStand", "TimberWolfScentWatch", "TimberWolfHowl", "TimberWolfEarAlert"]
var fall := Fall.new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.connect(settle_fall)


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead or current_clip not in entry.get("archive_grounded_gestures", []) or contact.contacts.is_empty():
		return
	var hit: Dictionary = contact.contacts.values()[0]
	var normal: Vector3 = (global_basis.inverse() * hit.normal).normalized()
	var slope := Basis(Quaternion(Vector3.UP, normal))
	model.basis = (slope * source_model_basis).scaled_local(model.scale)
	# Solve the paws against the tilted rig, then run the full-skin clearance pass.
	contact.sample(get_world_3d().direct_space_state, global_position)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	dead = true
	contact.enabled = false
	var displayed := Fall.new()
	displayed.plane = source.collapse_plane
	displayed.shift = source.collapse_shift
	if source.gesture_ground.applied:
		displayed.shift += source.model.position - source.gesture_ground.restore_pose.origin
	return fall.begin_from_source(self, source, displayed, false)


func settle_fall() -> void:
	if not fall.plane.is_empty():
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
