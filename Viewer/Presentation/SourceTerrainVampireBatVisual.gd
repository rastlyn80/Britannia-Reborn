# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedVampireBatVisual.gd"

var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(2.8, 2.5))
	animator.mixer_applied.connect(settle_pose)
	contact.modification_processed.connect(settle_pose)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	settle_pose()


func support_flight() -> void:
	if terrain.plane.is_empty():
		super.support_flight()


func settle_pose() -> void:
	if terrain.plane.is_empty():
		return
	if not dead:
		var flying: bool = current_clip in entry.get("archive_grounded_gestures", [])
		terrain.settle_live(-.072 if flying else .0005)
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
	var previous: RefCounted = source.terrain
	terrain.split = previous.split
	if not source.dead:
		model.transform = source.model.transform
		previous = preload("res://Presentation/CreatureFallPlayback.gd").new()
		previous.plane = source.terrain.plane
		var flying: bool = source.current_clip in entry.get("archive_grounded_gestures", []) or source.current_clip in previous.FLIGHT
		return terrain.begin_from_source(self, source, previous, flying)
	return terrain.begin_collapse(source)


func corpse_snapshot_floor() -> float:
	return terrain.snapshot_floor(self)
