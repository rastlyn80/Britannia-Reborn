# SPDX-License-Identifier: GPL-3.0-or-later
extends "res://Presentation/SourceEnhancedLatticeSeekerVisual.gd"

const DisplayedPose := preload("res://Presentation/CreatureFallPlayback.gd")
var terrain := preload("res://Presentation/SourceCreatureTreadTerrain.gd").new()


func _ready() -> void:
	super._ready()
	terrain.bind(self, Vector2(1.55, 1.8))
	contact.modification_processed.connect(ground_living)


func play_gait(moving: bool, speed: float) -> void:
	if not entry.has("enhanced_source_action_groups"):
		combat_flags = -1
	super.play_gait(moving, speed)


func _physics_process(delta: float) -> void:
	if dead:
		return
	terrain.release_live()
	terrain.sample()
	super._physics_process(delta)
	ground_living()


func ground_living() -> void:
	if terrain.actor != null and not dead:
		terrain.settle_live(.0005)
		update_landmarks()
		sync_arc()


func support_air_pose() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.support_air_pose()
	else:
		ground_living()


func receive_action(request: Dictionary) -> bool:
	if not dead:
		terrain.release_live()
	if not super.receive_action(request):
		return false
	if dead:
		alternate_fall.plane = {}
		terrain.prepare_collapse()
	return true


func settle_alternate_fall() -> void:
	if terrain.actor == null or terrain.plane.is_empty():
		super.settle_alternate_fall()
	elif dead and (animator.current_animation_position > 0.0 or not terrain.blend_pose.is_empty()):
		terrain.settle(self)
	elif not dead:
		ground_living()


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
