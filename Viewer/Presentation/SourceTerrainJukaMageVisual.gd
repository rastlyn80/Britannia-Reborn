# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedJukaMageVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.3, 1.5))
	contact.modification_processed.connect(settle_live)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_live()


func apply_blend_ground() -> void:
	if terrain.actor == null:
		super.apply_blend_ground()
		return
	if dead:
		if not terrain.plane.is_empty() and (animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty()):
			terrain.settle(self)
		return
	terrain.release_live()
	super.apply_blend_ground()
	settle_live()


func settle_live() -> void:
	if terrain.actor != null and not dead:
		terrain.settle_live(.0005)
		update_landmarks()


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		model.transform = source.model.transform
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
