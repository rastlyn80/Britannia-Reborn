# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedArmoredGargoyleVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.1, 1.9))
	contact.modification_processed.connect(settle_alternate_fall)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_alternate_fall()


func settle_alternate_fall() -> void:
	if terrain.plane.is_empty():
		super.settle_alternate_fall()
	elif not dead:
		terrain.settle_live(.0005)
		update_landmarks()
	elif animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty():
		terrain.settle(self)


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		alternate_fall.plane = {}
		terrain.prepare_collapse()
	return true


func begin_death_from(source: Node3D) -> float:
	if not source.is_flying():
		return terrain.begin_collapse(source)
	terrain.split = source.terrain.split
	var previous: RefCounted = source.terrain
	if not source.dead:
		previous = DisplayedPose.new()
		previous.plane = source.terrain.plane
		previous.shift = source.global_basis.inverse() * Vector3.UP * source.terrain.live_lift
	return terrain.begin_from_source(self, source, previous, true)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
