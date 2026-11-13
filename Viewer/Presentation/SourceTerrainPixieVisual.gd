# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedPixieVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.5, 1.5))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func update_fitted_pose() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.update_fitted_pose()
		return
	var world_lift := terrain.live_lift
	terrain.release_live()
	super.update_fitted_pose()
	model.position -= hover_shift
	hover_shift = Vector3.ZERO
	model.global_position.y += world_lift
	terrain.live_lift = world_lift


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
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.is_fitted() or source.dead:
		return terrain.begin_collapse(source)
	terrain.split = source.terrain.split
	model.transform = source.model.transform
	var shown := preload("res://Presentation/CreatureFallPlayback.gd").new()
	shown.plane = source.terrain.plane
	return terrain.begin_from_source(self, source, shown, true)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
