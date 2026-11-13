# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedAntLionVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.0, 2.1))
	contact.modification_processed.connect(ground_treads)


func play_gait(moving: bool, speed: float) -> void:
	if terrain.actor != null:
		terrain.release_live()
	if not entry.has("enhanced_source_action_groups"):
		native_flags = -1
	super.play_gait(moving, speed)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	ground_treads()


func settle_fitted() -> void:
	if terrain.actor == null:
		super.settle_fitted()
		return
	if dead:
		if not terrain.plane.is_empty() and (animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty()):
			terrain.settle(self)
		return
	terrain.release_live()
	super.settle_fitted()
	ground_treads()


func ground_treads() -> void:
	if terrain.actor == null or dead:
		return
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
	model.transform = source.model.transform
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, previous, false)


func corpse_snapshot_floor() -> float:
	return super.corpse_snapshot_floor() if terrain.plane.is_empty() else terrain.snapshot_floor(self)
