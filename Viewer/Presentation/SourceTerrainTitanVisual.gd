# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedTitanVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.7, 2.45))
	contact.modification_processed.connect(settle_living)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	if is_fitted() or not contact.enabled:
		settle_living()


func settle_living() -> void:
	terrain.settle_live(.0005)


func settle_fitted() -> void:
	if terrain.actor != null and not dead:
		terrain.release_live()
	super.settle_fitted()
	if terrain.actor != null and is_fitted():
		settle_living()


func receive_action(request: Dictionary) -> bool:
	terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		terrain.prepare_collapse()
	return true


func settle_fall() -> void:
	if dead:
		terrain.settle(self)


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
