# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedDreadSpiderVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.4, 2.4))


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture_model()
	terrain.sample()
	super._physics_process(delta)
	if not terrain.plane.is_empty():
		var up: Vector3 = (global_basis.inverse() * terrain.plane.normal).normalized()
		model.basis = (Basis(Quaternion(Vector3.UP, up)) * source_model_basis).scaled_local(model.scale)
	support_gesture()


func support_gesture() -> void:
	if terrain.actor == null:
		super.support_gesture()
	elif dead:
		terrain.settle(self)
	else:
		terrain.release_live()
		super.support_gesture()
		terrain.settle_live(.0005)


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		fall.plane = {}
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
