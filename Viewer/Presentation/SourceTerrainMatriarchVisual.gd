# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/MatriarchActionsVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.7, 2.5))
	contact.modification_processed.connect(settle)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	restore_gesture()
	terrain.sample()
	super._physics_process(delta)
	if current_clip in entry.grounded_gestures or not contact.enabled:
		settle()


func settle() -> void:
	if terrain.actor == null:
		super.settle()
	elif dead:
		terrain.settle(self)
	else:
		terrain.release_live()
		super.settle()
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
