# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedBlackWidowVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.2, 2.0))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture_model()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func support_gesture() -> void:
	if terrain.plane.is_empty():
		super.support_gesture()
		return
	if not dead:
		growth.apply(self, Unfold)


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		terrain.settle_live(.0005)
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.dead and (source.is_fitted() or source.growth.active or source.is_recovering()):
		terrain.split = source.terrain.split
		var shown := preload("res://Presentation/CreatureFallPlayback.gd").new()
		shown.plane = source.terrain.plane
		return terrain.begin_from_source(self, source, shown, false)
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
