# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/FieldClassicCollapseVisual.gd"

const Grounding := preload("res://Presentation/ArchiveGestureGround.gd")
const Fall := preload("res://Presentation/DisplayedCreatureFallPlayback.gd")
const IdleGestures := ["RatForage", "RatScentCheck", "RatTailSweep", "RatNoseAlert"]
var gesture := Grounding.new()
var fall := Fall.new()


func _ready() -> void:
	super._ready()
	# A prepared scene can retain the manual clock used by its baker.
	if animator.callback_mode_process == AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL:
		animator.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE
	gesture.bind(self)
	animator.mixer_applied.connect(settle_fall)


func _physics_process(delta: float) -> void:
	gesture.release(self)
	super._physics_process(delta)


func play_gait(moving: bool, speed: float) -> void:
	if moving and current_clip in IdleGestures:
		action_remaining = 0.0
	super.play_gait(moving, speed)


func begin_death_from(source: Node3D) -> float:
	global_transform = source.global_transform
	dead = true
	contact.enabled = false
	var before := Fall.new()
	before.plane = source.collapse_plane
	before.shift = source.collapse_shift
	if source.gesture.applied:
		before.shift += source.model.position - source.gesture.restore_pose.origin
	var duration := fall.begin_from_display(self, source, before, source.current_clip, false)
	if fall.blend_pose.is_empty() and not source.dead and duration > 0.0:
		fall.blend_length = minf(.12, duration)
		for joint in source.skeleton.get_bone_count():
			fall.blend_pose.append(source.skeleton.get_bone_pose(joint))
		settle_fall()
	return duration


func settle_fall() -> void:
	if not fall.plane.is_empty():
		fall.settle(self)


func corpse_snapshot_floor() -> float:
	return fall.snapshot_floor(self) if not fall.plane.is_empty() else INF
