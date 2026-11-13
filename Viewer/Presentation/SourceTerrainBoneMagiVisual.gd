# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedSkeletalMageVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	animator.mixer_applied.disconnect(release_gesture)
	animator.mixer_applied.disconnect(fitted_fall.settle.bind(self))
	contact.modification_processed.disconnect(support_gesture)
	terrain.bind(self, Vector2(1.4, 1.6))
	terrain.skin = gesture_skin
	animator.mixer_applied.connect(settle)
	contact.modification_processed.connect(settle)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	# The bent and scaled staff gestures use full-skin support. Applying
	# inverse leg corrections to those poses can destabilise the rig.
	contact.enabled = current_clip in ["Idle", "Walk", "Run"]
	if contact.enabled:
		super._physics_process(delta)
	settle()


func settle() -> void:
	if dead:
		if animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
			terrain.settle(self)
	else:
		terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
